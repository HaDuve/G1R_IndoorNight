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

-- UDS class search hints (refined during discovery)
local UDS_CLASS_NAMES   = {
    "Ultra_Dynamic_Sky_C",
    "UltraDynamicSky_C",
    "BP_Ultra_Dynamic_Sky_C",
    "Ultra_Dynamic_Sky",
    "UltraDynamicSky",
    "BP_UltraDynamicSky_C",
}

-- Candidate property names — expanded for F8 discovery snapshots.
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

local function numField(obj, name)
    local v, t = readField(obj, name)
    if t == "number" then return v end
end

local function boolField(obj, name)
    local v, t = readField(obj, name)
    if t == "boolean" then return v end
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

local function firstResolved(obj, names, kind)
    for _, name in ipairs(names) do
        local v, t = readField(obj, name)
        if kind == "number" and t == "number" then
            return name, v
        end
        if kind == "bool" and t == "boolean" then
            return name, v
        end
        if kind == "any" and v ~= nil then
            return name, v, t
        end
    end
end

local function readOcclusion(uds)
    local name, v = firstResolved(uds, OCCLUSION_CANDIDATES, "number")
    return v, name
end

local function readTimeOfDay(uds)
    local name, v = firstResolved(uds, TOD_CANDIDATES, "number")
    return v, name
end

local function writeTimeOfDay(uds, tod)
    if DISCOVERY_MODE then return end
    pcall(function() uds["Time of Day"] = tod end)
    pcall(function() uds.TimeOfDay = tod end)
end

local function printCandidateGroup(label, uds, names)
    print(string.format("  [%s]", label))
    local any = false
    for _, name in ipairs(names) do
        local v, t = readField(uds, name)
        if v ~= nil then
            any = true
            print(string.format("    %-40s = %s", name, formatValue(v, t)))
        end
    end
    if not any then
        print("    (no candidate properties resolved)")
    end
end

local function discoverySnapshot()
    snapshotCount = snapshotCount + 1
    local uds = findUds()

    print("")
    print("========== G1R_IndoorNight DISCOVERY SNAPSHOT #" .. snapshotCount .. " ==========")
    print("  mode       = read-only (DISCOVERY_MODE=true, zero UDS writes)")
    print("  protocol   = pose 1 outdoor day | pose 2 deep indoor day | pose 3 same indoor ~02:00")
    print("  paste output into docs/DISCOVERY.md for lever selection")
    print("")

    if not uds then
        print("  UDS actor  = NOT FOUND")
        print("  tried      = " .. table.concat(UDS_CLASS_NAMES, ", "))
        print("================================================================")
        print("")
        return
    end

    local cls, full = actorClassName(uds)
    local occlusion, occProp = readOcclusion(uds)
    local tod, todProp = readTimeOfDay(uds)

    print("  UDS class  = " .. cls)
    print("  UDS object = " .. full)
    print("")
    print("  --- primary (first resolved candidate) ---")
    if occProp then
        print(string.format("  Player Occlusion = %.4f  (via '%s')", occlusion, occProp))
    else
        print("  Player Occlusion = UNRESOLVED (see occlusion candidates below)")
    end
    if todProp then
        print(string.format("  Time of Day      = %.1f  (via '%s')", tod, todProp))
    else
        print("  Time of Day      = UNRESOLVED (see TOD candidates below)")
    end
    print("")

    printCandidateGroup("occlusion candidates", uds, OCCLUSION_CANDIDATES)
    print("")
    printCandidateGroup("time-of-day candidates", uds, TOD_CANDIDATES)
    print("")
    printCandidateGroup("skylight candidates", uds, SKYLIGHT_CANDIDATES)
    print("")
    printCandidateGroup("interior adjustment candidates", uds, INTERIOR_CANDIDATES)
    print("")
    printCandidateGroup("lighting-brightness candidates", uds, LIGHTING_CANDIDATES)
    print("================================================================")
    print("")
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
    print("[G1R_IndoorNight] loaded — DISCOVERY MODE (read-only; F8 = snapshot; F7 = toggle inert)")
else
    print("[G1R_IndoorNight] loaded")
end

RegisterKeyBind(SNAPSHOT_KEY, function()
    ExecuteInGameThread(function()
        pcall(discoverySnapshot)
    end)
end)

RegisterKeyBind(TOGGLE_KEY, function()
    ExecuteInGameThread(function()
        setModEnabled(not modEnabled)
    end)
end)

LoopAsync(PASS_MS, function()
    ExecuteInGameThread(function()
        pcall(pass)
    end)
    return false
end)
