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
-- Slice 2d: G1R skylight / SetSettings lever spike (F11).
local G1R_LEVER_SPIKE_ENABLED = true
local G1R_LEVER_SPIKE_KEY     = Key.F11
local G1R_SKY_MULTIPLIER_TARGET = 0.40   -- ACCEPTED v3.1 (Slice 2d HITL)
-- Accepted indoor target — Slice 3 applies when Inside; F11 spike uses same values.
local G1R_SETTINGS_NIGHT_PROFILE = {
    SkyLightIntensity = 0.37,
    OverallIntensity = 0.56,
    DirectionalBalance = 0.38,
    NightBrightness = 0.48,
}
local G1R_DIRECT_NIGHT_WRITES = {
    { name = "Sun Light Intensity", target = 0.28 },
    { name = "Sun Light Intensity Multiplier in Interiors", target = 0.36 },
    { name = "Directional Lighting Intensity", target = 2.40 },
    { name = "Exposure Bias in Interior", target = -0.50 },
}
-- F12: restore day baseline after spike (reload also works).
local G1R_LEVER_RESET_ENABLED = true
local G1R_LEVER_RESET_KEY     = Key.F12
local G1R_DAY_RESTORE_PROFILE = {
    SkyLightIntensity = 1.00,
    OverallIntensity = 1.00,
    DirectionalBalance = 1.00,
    NightBrightness = 0.20,
}
local G1R_DAY_RESTORE_WRITES = {
    { name = "Dynamic Sky Light Multiplier", target = 1.0 },
    { name = "Target Sky Light Multiplier", target = 1.0 },
    { name = "Sky Light Intensity Multiplier in Interiors", target = 1.0 },
    { name = "Sun Light Intensity", target = 0.90 },
    { name = "Sky Light Intensity", target = 1.00 },
    { name = "Moon Light Intensity", target = 0.04 },
    { name = "Overall Intensity", target = 1.00 },
    { name = "Night Brightness", target = 0.20 },
    { name = "Directional Balance", target = 1.00 },
    { name = "Directional Lighting Intensity", target = 3.00 },
    { name = "Sun Light Intensity Multiplier in Interiors", target = 1.0 },
    { name = "Moon Light Intensity Multiplier in Interiors", target = 1.0 },
    { name = "Exposure Bias in Interior", target = 0.20 },
}
local MOD_DIR             = "Mods/G1R_IndoorNight/"
local SNAPSHOT_LOG        = MOD_DIR .. "snapshots.log"
local SNAPSHOT_SUMMARY    = MOD_DIR .. "snapshots.summary.log"
local TOD_SPIKE_LOG       = MOD_DIR .. "tod-spike.log"
local G1R_LEVER_SPIKE_LOG = MOD_DIR .. "g1r-lever-spike.log"

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

-- G1R sky controller + writable skylight multipliers (object dump Slice 2d).
local GOTHIC_CONTROLLER_CLASS_NAMES = {
    "Gothic_Ultra_Dynamic_Controller_C",
}

local G1R_SKY_MULTIPLIER_FIELDS = {
    "Dynamic Sky Light Multiplier",
    "Target Sky Light Multiplier",
    "Sky Light Intensity Multiplier in Interiors",
}

local G1R_SKY_BOOL_FIELDS = {
    "Use Gothic Day Time",
    "Apply Interior Adjustments",
}

local UDS_SETTINGS_FIELDS = {
    "SunAngle",
    "OverallIntensity",
    "Contrast",
    "Saturation",
    "DirectionalBalance",
    "NightBrightness",
    "SkyLightIntensity",
    "SkyLightTemperature",
}

-- G1R native Inside Detection (object dump Slice 2b).
local PLAYER_CONTROLLER_CLASS_NAMES = {
    "GothicPlayerControllerBaseBP_C",
    "GothicPlayerControllerBase",
}

local PLAYER_PAWN_CLASS_NAMES = {
    "GothicPlayerCharacter",
}

local INDOOR_DETECTION_COMPONENT_LINK_NAMES = {
    "OcclusionDetectionComponent",
    "m_IndoorDetectionComponent",
}

local INDOOR_DETECTION_BOOL_FIELDS = {
    "bDetectedIsIndoor",
    "bDetectedIsOutdoor",
    "bUpdateOnMove",
}

local INDOOR_DETECTION_FLOAT_FIELDS = {
    "DetectionConfidence",
    "DetectionScore",
    "DetectionUpdatedAtTime",
    "DetectionAveragingWindowSizeSeconds",
}

local INDOOR_DETECTION_RECENT_MAX_AGE_SEC = 5.0

-- ---- state -----------------------------------------------------------------
local modEnabled = ENABLED
local udsCache = nil
local gothicControllerCache = nil
local playerControllerCache = nil
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

local function findGothicController()
    if safeObj(gothicControllerCache) then return gothicControllerCache end
    for _, className in ipairs(GOTHIC_CONTROLLER_CLASS_NAMES) do
        local ok, obj = pcall(FindFirstOf, className)
        if ok and safeObj(obj) then
            gothicControllerCache = obj
            log("found gothic controller: " .. className)
            return obj
        end
    end
    for _, className in ipairs(GOTHIC_CONTROLLER_CLASS_NAMES) do
        local list = FindAllOf(className)
        if list then
            for _, obj in pairs(list) do
                if safeObj(obj) then
                    gothicControllerCache = obj
                    log("found gothic controller via FindAllOf: " .. className)
                    return obj
                end
            end
        end
    end
end

local function readSettingsStruct(uds)
    if not uds then return nil, "no uds" end
    local settings, err
    local ok = pcall(function()
        if uds.GetSettings then
            settings = uds:GetSettings()
        elseif uds["GetSettings"] then
            settings = uds["GetSettings"](uds)
        end
    end)
    if not ok then return nil, "GetSettings threw" end
    if settings == nil then return nil, "GetSettings nil" end
    return settings, nil
end

local function readSettingsFields(settings)
    local out = {}
    if settings == nil then return out end
    for _, name in ipairs(UDS_SETTINGS_FIELDS) do
        local v, t = readField(settings, name)
        if t == "number" then
            out[name] = v
        end
    end
    return out
end

local function appendSettingsFields(lines, label, settings)
    lines[#lines + 1] = string.format("  [%s]", label)
    local fields = readSettingsFields(settings)
    local any = false
    for _, name in ipairs(UDS_SETTINGS_FIELDS) do
        local v = fields[name]
        if v ~= nil then
            any = true
            lines[#lines + 1] = string.format("    %-40s = %.4f", name, v)
        end
    end
    if not any then
        lines[#lines + 1] = "    (GetSettings unavailable or no numeric fields resolved)"
    end
end

local function appendGothicControllerPath(lines, uds)
    lines[#lines + 1] = "  [gothic controller path (Slice 2d)]"
    local controller = findGothicController()
    if not controller then
        lines[#lines + 1] = "    gothic controller                      = NOT FOUND"
        return nil
    end
    local _, full = actorClassName(controller)
    lines[#lines + 1] = string.format("    controller object                      = %s", full)

    local skyLink, skyType = readField(controller, "Ultra Dynamic Sky")
    if isObjectValue(skyLink, skyType) then
        local _, skyFull = actorClassName(skyLink)
        lines[#lines + 1] = string.format("    Ultra Dynamic Sky link                 = %s", skyFull)
        if uds and safeObj(skyLink) and safeObj(uds) then
            local same = false
            pcall(function() same = skyLink:GetAddress() == uds:GetAddress() end)
            lines[#lines + 1] = string.format("    link matches findUds()               = %s", same and "true" or "false")
        end
    else
        lines[#lines + 1] = "    Ultra Dynamic Sky link                 = UNRESOLVED"
    end

    for _, name in ipairs(G1R_SKY_BOOL_FIELDS) do
        local v, t = readField(uds, name)
        if t == "boolean" then
            lines[#lines + 1] = string.format("    uds %-34s = %s", name, v and "true" or "false")
        end
    end

    for _, name in ipairs(G1R_SKY_MULTIPLIER_FIELDS) do
        local v, t = readField(uds, name)
        if t == "number" then
            lines[#lines + 1] = string.format("    uds %-34s = %.4f", name, v)
        end
    end

    return controller
end

local function applySettingsProfile(uds, profile)
    local settings = readSettingsStruct(uds)
    if not settings then
        return false, nil, nil, "GetSettings unavailable"
    end
    local before = readSettingsFields(settings)
    local ok = pcall(function()
        for key, value in pairs(profile) do
            settings[key] = value
        end
        if uds.SetSettings then
            uds:SetSettings(settings)
        else
            uds["SetSettings"](uds, settings)
        end
    end)
    local afterSettings = readSettingsStruct(uds)
    local after = afterSettings and readSettingsFields(afterSettings) or {}
    return ok, before, after, nil
end

local function writeNumericField(obj, name, value)
    if not obj or name == nil or value == nil then return false end
    local ok = pcall(function() obj[name] = value end)
    return ok
end

-- Slice 2b helpers (after isObjectValue / followObjectLink above).
local function findPlayerController()
    if safeObj(playerControllerCache) then return playerControllerCache end
    for _, className in ipairs(PLAYER_CONTROLLER_CLASS_NAMES) do
        local ok, obj = pcall(FindFirstOf, className)
        if ok and safeObj(obj) then
            playerControllerCache = obj
            log("found player controller: " .. className)
            return obj
        end
    end
    for _, className in ipairs(PLAYER_CONTROLLER_CLASS_NAMES) do
        local list = FindAllOf(className)
        if list then
            for _, obj in pairs(list) do
                if safeObj(obj) then
                    playerControllerCache = obj
                    log("found player controller via FindAllOf: " .. className)
                    return obj
                end
            end
        end
    end
end

local function findPlayerPawn(controller)
    if safeObj(controller) then
        local ok, pawn = pcall(function()
            if controller.K2_GetPawn then
                return controller:K2_GetPawn()
            end
        end)
        if ok and safeObj(pawn) then return pawn, "K2_GetPawn()" end

        for _, name in ipairs({ "Pawn", "Character", "AcknowledgedPawn" }) do
            local v, t = readField(controller, name)
            if isObjectValue(v, t) then
                return v, name
            end
        end
    end
    for _, className in ipairs(PLAYER_PAWN_CLASS_NAMES) do
        local ok, obj = pcall(FindFirstOf, className)
        if ok and safeObj(obj) then
            return obj, "FindFirstOf(" .. className .. ")"
        end
    end
end

local function findIndoorDetectionComponent(controller)
    if not safeObj(controller) then return nil, nil end

    local ok, comp = pcall(function()
        if controller.GetIndoorDetectionComponent then
            return controller:GetIndoorDetectionComponent()
        end
        if controller["GetIndoorDetectionComponent"] then
            return controller["GetIndoorDetectionComponent"](controller)
        end
    end)
    if ok and safeObj(comp) then
        return comp, "GetIndoorDetectionComponent()"
    end

    local link, linkName = followObjectLink(controller, INDOOR_DETECTION_COMPONENT_LINK_NAMES)
    if link then
        return link, linkName
    end
end

local function tryIsUnderRoof(pawn)
    if not safeObj(pawn) then return nil, "no pawn" end

    local attempts = {
        function()
            if EnvironmentManagerCharacterStatics and EnvironmentManagerCharacterStatics.IsUnderRoof then
                return EnvironmentManagerCharacterStatics:IsUnderRoof(pawn)
            end
            if EnvironmentManagerCharacterStatics and EnvironmentManagerCharacterStatics["IsUnderRoof"] then
                return EnvironmentManagerCharacterStatics["IsUnderRoof"](EnvironmentManagerCharacterStatics, pawn)
            end
        end,
        function()
            local statics = StaticFindObject("/Script/G1R.Default__EnvironmentManagerCharacterStatics")
            if statics and statics.IsUnderRoof then
                return statics:IsUnderRoof(pawn)
            end
        end,
    }

    for i, fn in ipairs(attempts) do
        local ok, result = pcall(fn)
        if ok and type(result) == "boolean" then
            return result, "attempt " .. i
        end
    end
    return nil, "IsUnderRoof call failed (see UE4SS.log)"
end

local function readIndoorDetectionSnapshot()
    local out = {
        componentVia = nil,
        bDetectedIsIndoor = nil,
        bDetectedIsOutdoor = nil,
        detectionConfidence = nil,
        detectionScore = nil,
        hasRecentDetection = nil,
        hasAnyValidDetection = nil,
        isUnderRoof = nil,
        isUnderRoofVia = nil,
    }

    local controller = findPlayerController()
    if not controller then return out end

    local comp, compVia = findIndoorDetectionComponent(controller)
    out.componentVia = compVia
    if comp then
        local v, t = readField(comp, "bDetectedIsIndoor")
        if t == "boolean" then out.bDetectedIsIndoor = v end
        v, t = readField(comp, "bDetectedIsOutdoor")
        if t == "boolean" then out.bDetectedIsOutdoor = v end
        v, t = readField(comp, "DetectionConfidence")
        if t == "number" then out.detectionConfidence = v end
        v, t = readField(comp, "DetectionScore")
        if t == "number" then out.detectionScore = v end

        pcall(function()
            if comp.HasRecentDetectionResult then
                out.hasRecentDetection = comp:HasRecentDetectionResult(INDOOR_DETECTION_RECENT_MAX_AGE_SEC)
            end
        end)
        pcall(function()
            if comp.HasAnyValidDetectionResults then
                out.hasAnyValidDetection = comp:HasAnyValidDetectionResults()
            end
        end)
    end

    local pawn = findPlayerPawn(controller)
    if pawn then
        out.isUnderRoof, out.isUnderRoofVia = tryIsUnderRoof(pawn)
    end

    return out
end

local function appendIndoorDetectionPath(lines)
    lines[#lines + 1] = "  [inside detection path (Slice 2b — outdoor F8 then indoor F8, same session)]"

    local controller = findPlayerController()
    if not controller then
        lines[#lines + 1] = "    player controller                      = NOT FOUND"
        lines[#lines + 1] = "    tried                                  = "
            .. table.concat(PLAYER_CONTROLLER_CLASS_NAMES, ", ")
        return nil
    end
    local _, controllerFull = actorClassName(controller)
    lines[#lines + 1] = string.format("    player controller                      = %s", controllerFull)

    local pawn, pawnVia = findPlayerPawn(controller)
    if pawn then
        local _, pawnFull = actorClassName(pawn)
        lines[#lines + 1] = string.format("    player pawn via                        = %s", pawnVia)
        lines[#lines + 1] = string.format("    player pawn                            = %s", pawnFull)
    else
        lines[#lines + 1] = "    player pawn                            = NOT FOUND"
    end

    local comp, compVia = findIndoorDetectionComponent(controller)
    if not comp then
        lines[#lines + 1] = "    IndoorDetectionComponent               = NOT FOUND"
        lines[#lines + 1] = "    tried                                  = GetIndoorDetectionComponent(), "
            .. table.concat(INDOOR_DETECTION_COMPONENT_LINK_NAMES, ", ")
    else
        local _, compFull = actorClassName(comp)
        lines[#lines + 1] = string.format("    component via                          = %s", compVia)
        lines[#lines + 1] = string.format("    IndoorDetectionComponent               = %s", compFull)
        lines[#lines + 1] = ""

        for _, name in ipairs(INDOOR_DETECTION_BOOL_FIELDS) do
            local v, t = readField(comp, name)
            if t == "boolean" then
                lines[#lines + 1] = string.format("    %-40s = %s", name, v and "true" or "false")
            end
        end

        for _, name in ipairs(INDOOR_DETECTION_FLOAT_FIELDS) do
            local v, t = readField(comp, name)
            if t == "number" then
                lines[#lines + 1] = string.format("    %-40s = %.4f", name, v)
            end
        end

        lines[#lines + 1] = ""
        pcall(function()
            if comp.HasRecentDetectionResult then
                local recent = comp:HasRecentDetectionResult(INDOOR_DETECTION_RECENT_MAX_AGE_SEC)
                lines[#lines + 1] = string.format(
                    "    HasRecentDetectionResult(%.1fs)          = %s",
                    INDOOR_DETECTION_RECENT_MAX_AGE_SEC,
                    recent and "true" or "false"
                )
            end
        end)
        pcall(function()
            if comp.HasAnyValidDetectionResults then
                local any = comp:HasAnyValidDetectionResults()
                lines[#lines + 1] = string.format(
                    "    HasAnyValidDetectionResults()            = %s",
                    any and "true" or "false"
                )
            end
        end)
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "  [secondary candidates]"
    if pawn then
        local underRoof, underVia = tryIsUnderRoof(pawn)
        if underRoof ~= nil then
            lines[#lines + 1] = string.format(
                "    EnvironmentManagerCharacterStatics:IsUnderRoof = %s  (via %s)",
                underRoof and "true" or "false",
                underVia
            )
        else
            lines[#lines + 1] = "    EnvironmentManagerCharacterStatics:IsUnderRoof = UNRESOLVED"
        end
    else
        lines[#lines + 1] = "    EnvironmentManagerCharacterStatics:IsUnderRoof = SKIPPED (no pawn)"
    end
    lines[#lines + 1] = "    AreaContainerDetector:IsInside           = not probed (needs detector instance)"
    lines[#lines + 1] = "    GothicTriggerVolume:m_IsInside           = not probed (volume-local; scan deferred)"

    lines[#lines + 1] = ""
    lines[#lines + 1] = "    compare protocol                       = note bDetectedIsIndoor + DetectionConfidence outdoor vs indoor"
    lines[#lines + 1] = "    ship fallback if dead                  = F7 manual toggle (no auto gate)"

    return comp
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

local function spikeWriteLine(lines, label, before, target, after, writeOk)
    lines[#lines + 1] = string.format("    [%s]", label)
    lines[#lines + 1] = string.format("      before     = %s", before and string.format("%.4f", before) or "UNREADABLE")
    lines[#lines + 1] = string.format("      write      = %.4f", target)
    lines[#lines + 1] = string.format("      write ok   = %s", writeOk and "true" or "false")
    lines[#lines + 1] = string.format("      readback   = %s", after and string.format("%.4f", after) or "UNREADABLE")
    lines[#lines + 1] = string.format("      assessment = %s", assessReadback(before, target, after))
end

local function runG1rLeverSpike()
    local lines = {}
    lines[#lines + 1] = ""
    lines[#lines + 1] = "========== G1R_IndoorNight G1R LEVER SPIKE (Slice 2d) =========="
    lines[#lines + 1] = "  trigger    = F11 one-shot"
    lines[#lines + 1] = "  protocol   = daytime indoors; F11 then F8 ~2s later for persistence"
    lines[#lines + 1] = ""

    local uds = findUds()
    local controller = findGothicController()
    if not uds then
        lines[#lines + 1] = "  UDS actor  = NOT FOUND"
        lines[#lines + 1] = "================================================================"
        lines[#lines + 1] = ""
        local text = table.concat(lines, "\n")
        print(text)
        appendModLog(text, { G1R_LEVER_SPIKE_LOG, "g1r-lever-spike.log" })
        return
    end

    local cls, full = actorClassName(uds)
    lines[#lines + 1] = "  UDS class  = " .. cls
    lines[#lines + 1] = "  UDS object = " .. full
    if controller then
        local _, ctrlFull = actorClassName(controller)
        lines[#lines + 1] = "  controller = " .. ctrlFull
    else
        lines[#lines + 1] = "  controller = NOT FOUND"
    end
    lines[#lines + 1] = ""

    local settingsBefore = readSettingsStruct(uds)
    if settingsBefore then
        appendSettingsFields(lines, "GetSettings before", settingsBefore)
        lines[#lines + 1] = ""
    else
        lines[#lines + 1] = "  GetSettings before = UNAVAILABLE"
        lines[#lines + 1] = ""
    end

    lines[#lines + 1] = "  [write attempts — multipliers + interior flag]"
    for _, name in ipairs(G1R_SKY_MULTIPLIER_FIELDS) do
        local before, t = readField(uds, name)
        if t == "number" then
            local target = G1R_SKY_MULTIPLIER_TARGET
            local writeOk = writeNumericField(uds, name, target)
            local after = select(1, readField(uds, name))
            spikeWriteLine(lines, name, before, target, after, writeOk)
        end
    end

    local applyBefore, applyType = readField(uds, "Apply Interior Adjustments")
    if applyType == "boolean" then
        local writeOk = pcall(function() uds["Apply Interior Adjustments"] = true end)
        local after = select(1, readField(uds, "Apply Interior Adjustments"))
        lines[#lines + 1] = "    [Apply Interior Adjustments]"
        lines[#lines + 1] = string.format("      before     = %s", applyBefore and "true" or "false")
        lines[#lines + 1] = "      write      = true"
        lines[#lines + 1] = string.format("      write ok   = %s", writeOk and "true" or "false")
        lines[#lines + 1] = string.format("      readback   = %s", after == nil and "UNREADABLE" or (after and "true" or "false"))
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "  [SetSettings night profile]"
    local setOk, setBefore, setAfter, setErr = applySettingsProfile(uds, G1R_SETTINGS_NIGHT_PROFILE)
    if setErr then
        lines[#lines + 1] = "    note       = " .. setErr
    else
        for key, target in pairs(G1R_SETTINGS_NIGHT_PROFILE) do
            spikeWriteLine(lines, "SetSettings." .. key, setBefore[key], target, setAfter[key], setOk)
        end
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "  [direct UDS night writes]"
    for _, entry in ipairs(G1R_DIRECT_NIGHT_WRITES) do
        local before, t = readField(uds, entry.name)
        if t == "number" then
            local writeOk = writeNumericField(uds, entry.name, entry.target)
            local after = select(1, readField(uds, entry.name))
            spikeWriteLine(lines, entry.name, before, entry.target, after, writeOk)
        else
            lines[#lines + 1] = string.format("    [%s] UNREADABLE (skipped)", entry.name)
        end
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "  note       = immediate readback; F8 ~2s later for persistence; tune CONFIG profile if still too bright/off"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "  HITL checklist:"
    lines[#lines + 1] = "    [ ] visual change toward night-indoor?"
    lines[#lines + 1] = "    [ ] Game Clock / HUD time unchanged?"
    lines[#lines + 1] = "    [ ] flicker or snap-back within ~2s?"
    lines[#lines + 1] = "    frame-fight verdict: stable | overwritten | no effect"
    lines[#lines + 1] = "================================================================"
    lines[#lines + 1] = ""

    local text = table.concat(lines, "\n")
    print(text)
    local written = appendModLog(text, { G1R_LEVER_SPIKE_LOG, "g1r-lever-spike.log" })
    if written then
        print(string.format("[G1R_IndoorNight] G1R lever spike logged -> %s", written))
    else
        print("[G1R_IndoorNight] G1R lever spike printed above (file write failed; also in UE4SS.log)")
    end
end

local function runG1rLeverReset()
    local uds = findUds()
    if not uds then
        print("[G1R_IndoorNight] F12 reset: UDS NOT FOUND")
        return
    end
    pcall(function() uds["Apply Interior Adjustments"] = false end)
    applySettingsProfile(uds, G1R_DAY_RESTORE_PROFILE)
    for _, entry in ipairs(G1R_DAY_RESTORE_WRITES) do
        writeNumericField(uds, entry.name, entry.target)
    end
    print("[G1R_IndoorNight] F12 — day baseline restore applied (multipliers/sun/exposure/SetSettings)")
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
    lines[#lines + 1] = "  protocol   = Slice 2b: outdoor F8 then indoor F8; compare Inside Detection fields"
    lines[#lines + 1] = "  paste output into docs/DISCOVERY.md for gate selection (Slice 3)"
    lines[#lines + 1] = ""

    if not uds then
        lines[#lines + 1] = "  UDS actor  = NOT FOUND"
        lines[#lines + 1] = "  tried      = " .. table.concat(UDS_CLASS_NAMES, ", ")
        lines[#lines + 1] = ""
        appendIndoorDetectionPath(lines)
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

    local indoor = readIndoorDetectionSnapshot()
    lines[#lines + 1] = ""
    lines[#lines + 1] = "  --- inside detection primary (Slice 2b) ---"
    if indoor.bDetectedIsIndoor ~= nil then
        lines[#lines + 1] = string.format(
            "  bDetectedIsIndoor    = %s",
            indoor.bDetectedIsIndoor and "true" or "false"
        )
    else
        lines[#lines + 1] = "  bDetectedIsIndoor    = UNRESOLVED"
    end
    if indoor.detectionConfidence ~= nil then
        lines[#lines + 1] = string.format("  DetectionConfidence  = %.4f", indoor.detectionConfidence)
    else
        lines[#lines + 1] = "  DetectionConfidence  = UNRESOLVED"
    end
    if indoor.isUnderRoof ~= nil then
        lines[#lines + 1] = string.format(
            "  IsUnderRoof          = %s",
            indoor.isUnderRoof and "true" or "false"
        )
    else
        lines[#lines + 1] = "  IsUnderRoof          = UNRESOLVED"
    end
    lines[#lines + 1] = ""

    appendOcclusionPath(lines, uds)
    lines[#lines + 1] = ""
    appendIndoorDetectionPath(lines)
    lines[#lines + 1] = ""
    appendGothicControllerPath(lines, uds)
    local settings = readSettingsStruct(uds)
    if settings then
        lines[#lines + 1] = ""
        appendSettingsFields(lines, "GetSettings (UltraDynamicSkySettings)", settings)
    end
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
    lines[#lines + 1] = ""
    appendCandidateGroup(lines, "g1r skylight multiplier candidates", uds, G1R_SKY_MULTIPLIER_FIELDS)
    lines[#lines + 1] = ""
    do
        local names = {}
        for _, entry in ipairs(G1R_DIRECT_NIGHT_WRITES) do
            names[#names + 1] = entry.name
        end
        appendCandidateGroup(lines, "g1r direct night lever candidates", uds, names)
    end
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
        local indoor = readIndoorDetectionSnapshot()
        local indoorPart = ""
        if indoor.bDetectedIsIndoor ~= nil then
            indoorPart = indoorPart .. string.format(
                " indoor=%s",
                indoor.bDetectedIsIndoor and "true" or "false"
            )
        end
        if indoor.detectionConfidence ~= nil then
            indoorPart = indoorPart .. string.format(" conf=%.4f", indoor.detectionConfidence)
        end
        if indoor.isUnderRoof ~= nil then
            indoorPart = indoorPart .. string.format(
                " underRoof=%s",
                indoor.isUnderRoof and "true" or "false"
            )
        end
        local summary = string.format(
            "snapshot #%d class=%s occlusion=%s (%.4f) tod=%s (%.1f)%s",
            snapshotCount,
            cls,
            occProp or "UNRESOLVED",
            occlusion or -1,
            todProp or "UNRESOLVED",
            tod or -1,
            indoorPart
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

local function reportPcallError(label, ok, err)
    if not ok then
        print(string.format("[G1R_IndoorNight] %s error: %s", label, tostring(err)))
    end
end

-- ---- bootstrap -------------------------------------------------------------
if DISCOVERY_MODE then
    local spikeParts = {}
    if TOD_SPIKE_ENABLED then spikeParts[#spikeParts + 1] = "F10 = TOD spike" end
    if G1R_LEVER_SPIKE_ENABLED then spikeParts[#spikeParts + 1] = "F11 = G1R lever spike (v3.1)" end
    if G1R_LEVER_RESET_ENABLED then spikeParts[#spikeParts + 1] = "F12 = restore day baseline" end
    local spikeHint = #spikeParts > 0 and ("; " .. table.concat(spikeParts, "; ")) or ""
    print("[G1R_IndoorNight] loaded — DISCOVERY MODE (F8 = snapshot (Slice 2b inside detection)" .. spikeHint .. "; output -> snapshots.log + UE4SS.log)")
else
    print("[G1R_IndoorNight] loaded")
end

if DISCOVERY_MODE then
    RegisterKeyBind(SNAPSHOT_KEY, function()
        ExecuteInGameThread(function()
            print("[G1R_IndoorNight] F8 snapshot requested...")
            reportPcallError("F8 snapshot", pcall(discoverySnapshot))
        end)
    end)

    if TOD_SPIKE_ENABLED then
        RegisterKeyBind(TOD_SPIKE_KEY, function()
            ExecuteInGameThread(function()
                reportPcallError("F10 TOD spike", pcall(runTodSpike))
            end)
        end)
    end

    if G1R_LEVER_SPIKE_ENABLED then
        RegisterKeyBind(G1R_LEVER_SPIKE_KEY, function()
            ExecuteInGameThread(function()
                reportPcallError("F11 G1R lever spike", pcall(runG1rLeverSpike))
            end)
        end)
    end

    if G1R_LEVER_RESET_ENABLED then
        RegisterKeyBind(G1R_LEVER_RESET_KEY, function()
            ExecuteInGameThread(function()
                reportPcallError("F12 day restore", pcall(runG1rLeverReset))
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
