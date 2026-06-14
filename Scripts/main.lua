-- ============================================================================
--  G1R_IndoorNight — UE4SS Lua mod for Gothic 1 Remake
--  Occlusion-blended moonlit sky indoors (UDS). Game clock untouched.
-- ============================================================================

-- ---- CONFIG ----------------------------------------------------------------
local ENABLED           = true
local TOGGLE_KEY        = Key.F7
local TARGET_TOD        = 2300.0    -- UDS 0–2400; ~23:00 moonlit night
local OCCLUSION_START   = 0.5       -- below: no blend
local OCCLUSION_FULL    = 1.0       -- at/above: full TARGET_TOD blend
local PASS_MS           = 100       -- poll interval (ms)
local DEBUG             = false

-- UDS class search hints (refined during implementation)
local UDS_CLASS_NAMES   = {
    "Ultra_Dynamic_Sky_C",
    "UltraDynamicSky_C",
    "BP_Ultra_Dynamic_Sky_C",
}

-- ---- state -----------------------------------------------------------------
local modEnabled = ENABLED
local udsCache = nil
local trueTodCache = nil

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

local function numField(obj, name)
    if obj == nil then return nil end
    local ok, v = pcall(function() return obj[name] end)
    if ok and type(v) == "number" then return v end
end

local function blendFactor(occlusion)
    if occlusion <= OCCLUSION_START then return 0.0 end
    if occlusion >= OCCLUSION_FULL then return 1.0 end
    return (occlusion - OCCLUSION_START) / (OCCLUSION_FULL - OCCLUSION_START)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

-- ---- UDS discovery (TODO: verify property names in-game) -------------------
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
    local list = FindAllOf("Ultra_Dynamic_Sky_C")
    if list then
        for _, obj in pairs(list) do
            if safeObj(obj) then
                udsCache = obj
                log("found UDS via FindAllOf")
                return obj
            end
        end
    end
end

local function readOcclusion(uds)
    -- TODO: confirm G1R property name (candidates below)
    local candidates = {
        "Player Occlusion",
        "PlayerOcclusion",
        "Occlusion",
    }
    for _, name in ipairs(candidates) do
        local v = numField(uds, name)
        if v ~= nil then return v end
    end
end

local function readTimeOfDay(uds)
    local candidates = { "Time of Day", "TimeOfDay" }
    for _, name in ipairs(candidates) do
        local v = numField(uds, name)
        if v ~= nil then return v end
    end
end

local function writeTimeOfDay(uds, tod)
    pcall(function() uds["Time of Day"] = tod end)
    pcall(function() uds.TimeOfDay = tod end)
end

-- ---- main pass -------------------------------------------------------------
local function pass()
    if not modEnabled then return end

    local uds = findUds()
    if not uds then return end

    local trueTod = readTimeOfDay(uds)
    if trueTod == nil then return end

    local occlusion = readOcclusion(uds)
    if occlusion == nil then
        -- Occlusion unreadable yet — hold last true TOD, do not override
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
    if not modEnabled and safeObj(udsCache) and trueTodCache ~= nil then
        writeTimeOfDay(udsCache, trueTodCache)
    end
    print(string.format("[G1R_IndoorNight] %s", modEnabled and "ENABLED" or "DISABLED"))
end

-- ---- bootstrap -------------------------------------------------------------
print("[G1R_IndoorNight] loaded (stub — UDS hooks need in-game verification)")

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
