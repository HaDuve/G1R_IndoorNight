-- ============================================================================
--  G1R_IndoorNight — UE4SS Lua mod for Gothic 1 Remake
--  Occlusion-blended indoor sky dimming (UDS). Game clock untouched.
-- ============================================================================

-- ---- CONFIG ----------------------------------------------------------------
local ENABLED           = true
local TOGGLE_KEY        = Key.F7
local TARGET_TOD        = 2300.0    -- UDS 0–2400; ~23:00 moonlit night
local OCCLUSION_START   = 0.5       -- below: no blend
local OCCLUSION_FULL    = 1.0       -- at/above: full TARGET_TOD blend
local PASS_MS           = 100       -- poll interval (ms)
local DEBUG             = false

-- Discovery mode (Slice 1): read-only UDS instrumentation; no sky writes.
local DISCOVERY_MODE    = true
local SNAPSHOT_KEY      = Key.F8
-- Slice 2c: one-shot TOD write spike (F9 = G1R quickload; use F10).
local TOD_SPIKE_ENABLED = true
local TOD_SPIKE_KEY     = Key.F10
local MOD_DIR             = "Mods/G1R_IndoorNight/"
local SNAPSHOT_LOG        = MOD_DIR .. "snapshots.log"
local SNAPSHOT_SUMMARY    = MOD_DIR .. "snapshots.summary.log"
local TOD_SPIKE_LOG       = MOD_DIR .. "tod-spike.log"

-- UDS class search hints (refined during discovery)
local UDS_CLASS_NAMES   = {
    "Ultra_Dynamic_Sky_C",
    "UltraDynamicSky_C",
    "BP_Ultra_Dynamic_Sky_C",
    "Ultra_Dynamic_Sky",
    "UltraDynamicSky",
    "BP_UltraDynamicSky_C",
}

-- Occlusion read path (object dump): sky -> Weather_BP -> Player Occlusion -> Total Occlusion
local WEATHER_CLASS_NAMES = {
    "Ultra_Dynamic_Weather_C",
}

local WEATHER_LINK_NAMES = {
    "Weather_BP",
}

local PLAYER_OCCLUSION_COMPONENT_NAMES = {
    "Player Occlusion",
}

local TOTAL_OCCLUSION_FIELD = "Total Occlusion"

local OCCLUSION_COMPONENT_FIELDS = {
    "Total Occlusion",
    "Inverted Global Occlusion",
    "Full Occluded Percent",
    "Not Occluded Percent",
}

local OCCLUSION_COMPONENT_BOOL_FIELDS = {
    "Running",
    "Force Full Occlusion",
    "Finished",
    "UpdateCurrentOcclusionProfile",
    "Acquire Camera Location",
    "Calculate Rain Occlusion",
    "Use Water Level",
}

local OCCLUSION_COMPONENT_BYTE_FIELDS = {
    "Occlusion Mode",
    "Occlusion Trace Channel",
    "Show Trace Debugs",
}

local OCCLUSION_COMPONENT_MISC_FIELDS = {
    "Occlusion Update Period",
    "Max Interior Occlusion Distance",
    "TotalHits",
    "Group Id",
}

local OCCLUSION_PROFILE_ARRAYS = {
    "Current Occlusion Profile",
    "Target Occlusion Profile",
}

-- Legacy sky-actor candidates (F8 diagnostics only; not the live read path).
local OCCLUSION_CANDIDATES = {
    "Player Occlusion",
    "PlayerOcclusion",
    "Player_Occlusion",
    "Occlusion",
    "Occlusion Amount",
    "Global Occlusion",
    "Player Occlusion Value",
    "Current Occlusion",
    "Camera Occlusion",
}

local TOD_CANDIDATES = {
    "Time of Day",
    "TimeOfDay",
    "Current Time of Day",
}

local SKYLIGHT_CANDIDATES = {
    "Sky Light Intensity",
    "SkyLight Intensity",
    "Skylight Intensity",
    "Sky Light Intensity Multiplier",
    "Sky Light Color Intensity",
    "Sky Light Mode",
    "Real Time Capture",
}

local INTERIOR_CANDIDATES = {
    "Apply Interior Adjustments",
    "Interior Adjustments Enabled",
    "Interior Fog Density",
    "Interior Sky Light Intensity",
    "Interior Sun Light Intensity",
    "Interior Moon Light Intensity",
    "Interior Exposure",
    "Interior Sky Light Color",
    "Interior Sun Light Color",
    "Interior Moon Light Color",
}

local LIGHTING_CANDIDATES = {
    "Sun Light Intensity",
    "Sun Intensity",
    "Moon Light Intensity",
    "Moon Intensity",
    "Directional Light Intensity",
    "Ambient Light Intensity",
    "Cloud Brightness",
    "Sky Brightness",
    "Overall Intensity",
    "Exposure Compensation",
    "Sunlight Intensity",
    "Moonlight Intensity",
}

-- ---- state -----------------------------------------------------------------
local modEnabled = ENABLED
local udsCache = nil
local trueTodCache = nil
local snapshotCount = 0

-- ---- helpers ---------------------------------------------------------------
local function log(msg)
    if DEBUG then print("[G1R_IndoorNight] " .. msg) end
end

local function safeObj(obj)
    if obj == nil then return false end
    local ok, addr = pcall(function()
        if not obj:IsValid() then return nil end
        return obj:GetAddress()
    end)
    return ok and addr ~= nil and addr ~= 0
end

local function readField(obj, name)
    if obj == nil then return nil, nil end
    local ok, v = pcall(function() return obj[name] end)
    if not ok then return nil, nil end
    return v, type(v)
end

local function formatValue(v, t)
    if v == nil then return "nil" end
    if t == "number" then
        return string.format("%.4f", v)
    end
    if t == "boolean" then
        return v and "true" or "false"
    end
    if t == "string" then
        return v
    end
    local ok, s = pcall(function()
        if v.ToString then return v:ToString() end
        return tostring(v)
    end)
    return ok and tostring(s) or tostring(v)
end

local function appendDiscoveryLog(text)
    local paths = { SNAPSHOT_LOG, "snapshots.log" }
    for _, path in ipairs(paths) do
        local ok, written = pcall(function()
            local f = io.open(path, "a")
            if not f then return nil end
            f:write(text)
            if not text:match("\n$") then f:write("\n") end
            f:close()
            return path
        end)
        if ok and written then return written end
    end
end

local function blendFactor(occlusion)
    if occlusion <= OCCLUSION_START then return 0.0 end
    if occlusion >= OCCLUSION_FULL then return 1.0 end
    return (occlusion - OCCLUSION_START) / (OCCLUSION_FULL - OCCLUSION_START)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function actorClassName(obj)
    if not safeObj(obj) then return "?", "?" end
    local full = "?"
    local short = "?"
    pcall(function() full = obj:GetFullName() end)
    pcall(function() short = obj:GetClass():GetFName():ToString() end)
    return short, full
end

-- ---- UDS discovery ---------------------------------------------------------
local function findUds()
    if safeObj(udsCache) then return udsCache end
    for _, className in ipairs(UDS_CLASS_NAMES) do
        local ok, obj = pcall(FindFirstOf, className)
        if ok and safeObj(obj) then
            udsCache = obj
            log("found UDS: " .. className)
            return obj
        end
    end
    for _, className in ipairs(UDS_CLASS_NAMES) do
        local list = FindAllOf(className)
        if list then
            for _, obj in pairs(list) do
                if safeObj(obj) then
                    udsCache = obj
                    log("found UDS via FindAllOf: " .. className)
                    return obj
                end
            end
        end
    end
end

local OCCLUSION_NESTED_CANDIDATES = {
    "Total Occlusion",
    "Inverted Global Occlusion",
    "Full Occluded Percent",
    "Not Occluded Percent",
    "Occlusion",
    "Player Occlusion",
    "PlayerOcclusion",
    "Value",
    "Amount",
    "Current Occlusion",
    "Global Occlusion",
    "Camera Occlusion",
    "Occlusion Amount",
}

local function isObjectValue(v, t)
    if t == "userdata" then return true end
    if t == "table" and v.IsValid then return safeObj(v) end
    return safeObj(v)
end

local function firstResolvedNumber(obj, names)
    for _, name in ipairs(names) do
        local v, t = readField(obj, name)
        if t == "number" then
            return name, v
        end
    end
end

local function followObjectLink(obj, names)
    for _, name in ipairs(names) do
        local v, t = readField(obj, name)
        if isObjectValue(v, t) then
            return v, name
        end
    end
end

local function findWeatherActor(uds)
    if uds then
        local weather, linkName = followObjectLink(uds, WEATHER_LINK_NAMES)
        if weather then
            return weather, "Weather_BP"
        end
    end
    for _, className in ipairs(WEATHER_CLASS_NAMES) do
        local ok, obj = pcall(FindFirstOf, className)
        if ok and safeObj(obj) then
            return obj, className
        end
    end
end

local function findPlayerOcclusionComponent(weather, weatherVia)
    local comp, linkName = followObjectLink(weather, PLAYER_OCCLUSION_COMPONENT_NAMES)
    if comp then
        return comp, weatherVia .. " -> " .. linkName
    end
    local ok, obj = pcall(FindFirstOf, "UDS_PlayerOcclusion_C")
    if ok and safeObj(obj) then
        return obj, weatherVia .. " -> UDS_PlayerOcclusion_C (FindFirstOf)"
    end
end

local function readOcclusionFromComponent(comp, via)
    local v, t = readField(comp, TOTAL_OCCLUSION_FIELD)
    if t == "number" then
        return v, via .. " -> " .. TOTAL_OCCLUSION_FIELD
    end
    local field, value = firstResolvedNumber(comp, OCCLUSION_NESTED_CANDIDATES)
    if field then
        return value, via .. " -> " .. field
    end
end

local function readNestedOcclusion(uds)
    for _, containerName in ipairs(OCCLUSION_CANDIDATES) do
        local container, t = readField(uds, containerName)
        if isObjectValue(container, t) then
            local field, value = firstResolvedNumber(container, OCCLUSION_NESTED_CANDIDATES)
            if field then
                return value, containerName .. "." .. field
            end
        end
    end
end

local function readOcclusion(uds)
    local weather, weatherVia = findWeatherActor(uds)
    if weather then
        local comp, compVia = findPlayerOcclusionComponent(weather, weatherVia)
        if comp then
            local value, propPath = readOcclusionFromComponent(comp, compVia)
            if value ~= nil then
                return value, propPath
            end
        end
    end

    local name, v = firstResolvedNumber(uds, OCCLUSION_CANDIDATES)
    if v ~= nil then
        return v, name
    end
    return readNestedOcclusion(uds)
end

local function readDoubleArray(obj, fieldName)
    local v, t = readField(obj, fieldName)
    if v == nil then return {} end

    local values = {}
    local function push(n)
        if type(n) == "number" then
            values[#values + 1] = n
        end
    end

    if t == "table" then
        for _, item in ipairs(v) do
            push(item)
        end
        if #values == 0 then
            for _, item in pairs(v) do
                push(item)
            end
        end
    end

    if #values == 0 then
        pcall(function()
            if v.GetArrayNum then
                local n = v:GetArrayNum()
                for i = 0, n - 1 do
                    if v.Get then
                        push(v:Get(i))
                    else
                        push(v[i])
                    end
                end
            end
        end)
    end

    return values
end

local function appendDoubleArray(lines, label, values)
    if #values == 0 then
        lines[#lines + 1] = string.format("    %-40s = (empty or unreadable)", label)
        return
    end
    local parts = {}
    for i, n in ipairs(values) do
        parts[#parts + 1] = string.format("[%d]=%.4f", i - 1, n)
    end
    lines[#lines + 1] = string.format("    %-40s = %s", label, table.concat(parts, " "))
end

local function appendOcclusionPath(lines, uds)
    lines[#lines + 1] = "  [occlusion path (Weather -> Player Occlusion -> Total Occlusion)]"
    local weather, weatherVia = findWeatherActor(uds)
    if not weather then
        lines[#lines + 1] = "    weather actor                          = NOT FOUND"
        return nil
    end
    local _, weatherFull = actorClassName(weather)
    lines[#lines + 1] = string.format("    weather via                            = %s", weatherVia)
    lines[#lines + 1] = string.format("    weather object                         = %s", weatherFull)

    local comp, compVia = findPlayerOcclusionComponent(weather, weatherVia)
    if not comp then
        lines[#lines + 1] = "    player occlusion component             = NOT FOUND"
        return nil
    end
    local _, compFull = actorClassName(comp)
    lines[#lines + 1] = string.format("    component via                          = %s", compVia)
    lines[#lines + 1] = string.format("    component object                       = %s", compFull)

    lines[#lines + 1] = ""
    lines[#lines + 1] = "  [occlusion diagnostic — Slice 2a: compare outdoor vs indoor, same session]"

    for _, name in ipairs(OCCLUSION_COMPONENT_BOOL_FIELDS) do
        local v, t = readField(comp, name)
        if t == "boolean" then
            lines[#lines + 1] = string.format("    %-40s = %s", name, v and "true" or "false")
        end
    end

    for _, name in ipairs(OCCLUSION_COMPONENT_BYTE_FIELDS) do
        local v, t = readField(comp, name)
        if t == "number" then
            lines[#lines + 1] = string.format("    %-40s = %.0f", name, v)
        end
    end

    for _, name in ipairs(OCCLUSION_COMPONENT_MISC_FIELDS) do
        local v, t = readField(comp, name)
        if t == "number" then
            local fmt = (name == "TotalHits" or name == "Group Id") and "%.0f" or "%.4f"
            lines[#lines + 1] = string.format("    %-40s = " .. fmt, name, v)
        end
    end

    lines[#lines + 1] = ""
    for _, name in ipairs(OCCLUSION_COMPONENT_FIELDS) do
        local v, t = readField(comp, name)
        if t == "number" then
            lines[#lines + 1] = string.format("    %-40s = %.4f", name, v)
        end
    end

    for _, name in ipairs(OCCLUSION_PROFILE_ARRAYS) do
        appendDoubleArray(lines, name, readDoubleArray(comp, name))
    end

    local _, runningType = readField(comp, "Running")
    local running = runningType == "boolean" and select(1, readField(comp, "Running"))
    lines[#lines + 1] = ""
    if running == false then
        lines[#lines + 1] = "    verdict                                = Running=false -> UDS occlusion likely INACTIVE"
    elseif running == true then
        lines[#lines + 1] = "    verdict                                = Running=true -> compare floats/arrays vs outdoor snapshot"
    else
        lines[#lines + 1] = "    verdict                                = Running unreadable -> check fields above"
    end

    return comp
end

local function readTimeOfDay(uds)
    local name, v = firstResolvedNumber(uds, TOD_CANDIDATES)
    return v, name
end

local TOD_WRITE_ALIASES = {
    "Time of Day",
    "TimeOfDay",
    "Current Time of Day",
    "Internal Time of Day",
    "Replicated Time of Day",
}

local function writeTimeOfDay(uds, tod, force)
    if DISCOVERY_MODE and not force then return false end
    local written = false
    local _, primaryProp = readTimeOfDay(uds)
    if primaryProp then
        local ok = pcall(function() uds[primaryProp] = tod end)
        written = ok or written
    end
    for _, name in ipairs(TOD_WRITE_ALIASES) do
        if name ~= primaryProp then
            local ok = pcall(function() uds[name] = tod end)
            written = ok or written
        end
    end
    return written
end

local function appendModLog(text, paths)
    paths = paths or { SNAPSHOT_LOG, "snapshots.log" }
    for _, path in ipairs(paths) do
        local ok, written = pcall(function()
            local f = io.open(path, "a")
            if not f then return nil end
            f:write(text)
            if not text:match("\n$") then f:write("\n") end
            f:close()
            return path
        end)
        if ok and written then return written end
    end
end

local function assessReadback(before, target, after)
    if after == nil then return "UNREADABLE"
    end
    if math.abs(after - target) < 0.5 then
        if before and math.abs(after - before) < 0.5 then
            return "NO CHANGE (write may have failed or value already matched)"
        end
        return "STABLE (matches write target)"
    end
    if before and math.abs(after - before) < 0.5 then
        return "REVERTED (readback ~= before; likely frame-fight)"
    end
    return string.format("PARTIAL (readback=%.1f)", after)
end

local function runTodSpike()
    local lines = {}
    lines[#lines + 1] = ""
    lines[#lines + 1] = "========== G1R_IndoorNight TOD SPIKE (Slice 2c) =========="
    lines[#lines + 1] = "  trigger    = F10 one-shot (F9 reserved for G1R quickload)"
    lines[#lines + 1] = "  protocol   = daytime Game Clock; press F10 indoors; note sky + HUD clock"
    lines[#lines + 1] = ""

    local uds = findUds()
    if not uds then
        lines[#lines + 1] = "  UDS actor  = NOT FOUND"
        lines[#lines + 1] = "================================================================"
        lines[#lines + 1] = ""
        local text = table.concat(lines, "\n")
        print(text)
        appendModLog(text, { TOD_SPIKE_LOG, "tod-spike.log", SNAPSHOT_LOG, "snapshots.log" })
        return
    end

    local cls, full = actorClassName(uds)
    local before, prop = readTimeOfDay(uds)
    local target = TARGET_TOD

    lines[#lines + 1] = "  UDS class  = " .. cls
    lines[#lines + 1] = "  UDS object = " .. full
    lines[#lines + 1] = string.format("  prop       = %s", prop or "UNRESOLVED")
    lines[#lines + 1] = string.format("  before     = %s", before and string.format("%.1f", before) or "UNREADABLE")
    lines[#lines + 1] = string.format("  write      = %.1f (TARGET_TOD)", target)

    local writeOk = writeTimeOfDay(uds, target, true)
    lines[#lines + 1] = string.format("  write ok   = %s", writeOk and "true" or "false")

    local after, afterProp = readTimeOfDay(uds)
    local verdict = assessReadback(before, target, after)
    lines[#lines + 1] = string.format("  readback   = %s  (via '%s')", after and string.format("%.1f", after) or "UNREADABLE", afterProp or "?")
    lines[#lines + 1] = string.format("  assessment = %s", verdict)
    lines[#lines + 1] = "  note       = immediate readback only; press F8 ~2s later to test persistence (G1R may resync)"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "  HITL checklist (record in issue #9 or docs/DISCOVERY.md):"
    lines[#lines + 1] = "    [ ] visual change toward night-indoor?"
    lines[#lines + 1] = "    [ ] Game Clock / HUD time unchanged?"
    lines[#lines + 1] = "    [ ] flicker or snap-back within ~2s?"
    lines[#lines + 1] = "    frame-fight verdict: stable | overwritten | no effect"
    lines[#lines + 1] = "================================================================"
    lines[#lines + 1] = ""

    local text = table.concat(lines, "\n")
    print(text)

    local written = appendModLog(text, { TOD_SPIKE_LOG, "tod-spike.log" })
    if written then
        print(string.format("[G1R_IndoorNight] TOD spike logged -> %s", written))
    else
        print("[G1R_IndoorNight] TOD spike printed above (file write failed; also in UE4SS.log)")
    end
end

local function appendCandidateGroup(lines, label, uds, names)
    lines[#lines + 1] = string.format("  [%s]", label)
    local any = false
    for _, name in ipairs(names) do
        local v, t = readField(uds, name)
        if v ~= nil then
            any = true
            local line = string.format("    %-40s = %s", name, formatValue(v, t))
            if label:match("occlusion") and isObjectValue(v, t) then
                local nestedName, nestedVal = firstResolvedNumber(v, OCCLUSION_NESTED_CANDIDATES)
                if nestedName then
                    line = line .. string.format("  -> %s = %.4f", nestedName, nestedVal)
                end
            end
            lines[#lines + 1] = line
        end
    end
    if not any then
        lines[#lines + 1] = "    (no candidate properties resolved)"
    end
end

local function buildDiscoverySnapshot()
    snapshotCount = snapshotCount + 1
    local lines = {}
    local uds = findUds()

    lines[#lines + 1] = ""
    lines[#lines + 1] = "========== G1R_IndoorNight DISCOVERY SNAPSHOT #" .. snapshotCount .. " =========="
    lines[#lines + 1] = "  mode       = read-only (DISCOVERY_MODE=true, zero UDS writes)"
    lines[#lines + 1] = "  protocol   = Slice 2a: outdoor F8 then indoor F8 (same session); compare Running + floats/arrays"
    lines[#lines + 1] = "  paste output into docs/DISCOVERY.md for lever selection"
    lines[#lines + 1] = ""

    if not uds then
        lines[#lines + 1] = "  UDS actor  = NOT FOUND"
        lines[#lines + 1] = "  tried      = " .. table.concat(UDS_CLASS_NAMES, ", ")
        lines[#lines + 1] = "================================================================"
        lines[#lines + 1] = ""
        return table.concat(lines, "\n"), nil, nil, nil, nil
    end

    local cls, full = actorClassName(uds)
    local occlusion, occProp = readOcclusion(uds)
    local tod, todProp = readTimeOfDay(uds)

    lines[#lines + 1] = "  UDS class  = " .. cls
    lines[#lines + 1] = "  UDS object = " .. full
    lines[#lines + 1] = ""
    lines[#lines + 1] = "  --- primary (first resolved candidate) ---"
    if occProp then
        lines[#lines + 1] = string.format("  Player Occlusion = %.4f  (via '%s')", occlusion, occProp)
    else
        lines[#lines + 1] = "  Player Occlusion = UNRESOLVED (see occlusion candidates below)"
    end
    if todProp then
        lines[#lines + 1] = string.format("  Time of Day      = %.1f  (via '%s')", tod, todProp)
    else
        lines[#lines + 1] = "  Time of Day      = UNRESOLVED (see TOD candidates below)"
    end
    lines[#lines + 1] = ""

    appendOcclusionPath(lines, uds)
    lines[#lines + 1] = ""
    appendCandidateGroup(lines, "legacy sky occlusion candidates", uds, OCCLUSION_CANDIDATES)
    lines[#lines + 1] = ""
    appendCandidateGroup(lines, "time-of-day candidates", uds, TOD_CANDIDATES)
    lines[#lines + 1] = ""
    appendCandidateGroup(lines, "skylight candidates", uds, SKYLIGHT_CANDIDATES)
    lines[#lines + 1] = ""
    appendCandidateGroup(lines, "interior adjustment candidates", uds, INTERIOR_CANDIDATES)
    lines[#lines + 1] = ""
    appendCandidateGroup(lines, "lighting-brightness candidates", uds, LIGHTING_CANDIDATES)
    lines[#lines + 1] = "================================================================"
    lines[#lines + 1] = ""

    return table.concat(lines, "\n"), cls, occProp, occlusion, todProp, tod
end

local function discoverySnapshot()
    local text, cls, occProp, occlusion, todProp, tod = buildDiscoverySnapshot()
    print(text)

    local written = appendDiscoveryLog(text)
    if written then
        print(string.format("[G1R_IndoorNight] snapshot #%d saved -> %s", snapshotCount, written))
    else
        print(string.format(
            "[G1R_IndoorNight] snapshot #%d printed above (file write failed; also in UE4SS.log)",
            snapshotCount
        ))
    end

    if cls then
        local summary = string.format(
            "snapshot #%d class=%s occlusion=%s (%.4f) tod=%s (%.1f)",
            snapshotCount,
            cls,
            occProp or "UNRESOLVED",
            occlusion or -1,
            todProp or "UNRESOLVED",
            tod or -1
        )
        pcall(function()
            local f = io.open(SNAPSHOT_SUMMARY, "a")
            if f then f:write(summary .. "\n"); f:close() end
        end)
    end
end

-- ---- main pass (disabled for writes when DISCOVERY_MODE) -------------------
local function pass()
    if DISCOVERY_MODE then return end
    if not modEnabled then return end

    local uds = findUds()
    if not uds then return end

    local trueTod, _ = readTimeOfDay(uds)
    if trueTod == nil then return end

    local occlusion, _ = readOcclusion(uds)
    if occlusion == nil then
        return
    end

    local t = blendFactor(occlusion)
    if t <= 0.0 then
        trueTodCache = trueTod
        return
    end

    trueTodCache = trueTod
    local blended = lerp(trueTod, TARGET_TOD, t)
    writeTimeOfDay(uds, blended)

    log(string.format("occ=%.2f t=%.2f true=%.0f blend=%.0f", occlusion, t, trueTod, blended))
end

local function setModEnabled(next)
    if modEnabled == next then return end
    modEnabled = next
    if not DISCOVERY_MODE and not modEnabled and safeObj(udsCache) and trueTodCache ~= nil then
        writeTimeOfDay(udsCache, trueTodCache)
    end
    print(string.format("[G1R_IndoorNight] %s", modEnabled and "ENABLED" or "DISABLED"))
end

-- ---- bootstrap -------------------------------------------------------------
if DISCOVERY_MODE then
    local spikeHint = TOD_SPIKE_ENABLED and "; F10 = TOD write spike (Slice 2c)" or ""
    print("[G1R_IndoorNight] loaded — DISCOVERY MODE (F8 = snapshot" .. spikeHint .. "; output -> snapshots.log + UE4SS.log)")
else
    print("[G1R_IndoorNight] loaded")
end

if DISCOVERY_MODE then
    RegisterKeyBind(SNAPSHOT_KEY, function()
        ExecuteInGameThread(function()
            pcall(discoverySnapshot)
        end)
    end)

    if TOD_SPIKE_ENABLED then
        RegisterKeyBind(TOD_SPIKE_KEY, function()
            ExecuteInGameThread(function()
                pcall(runTodSpike)
            end)
        end)
    end
end

RegisterKeyBind(TOGGLE_KEY, function()
    ExecuteInGameThread(function()
        setModEnabled(not modEnabled)
    end)
end)

if not DISCOVERY_MODE then
    LoopAsync(PASS_MS, function()
        ExecuteInGameThread(function()
            pcall(pass)
        end)
        return false
    end)
end
