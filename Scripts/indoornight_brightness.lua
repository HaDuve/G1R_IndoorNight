-- Indoor day/night brightness knobs + scaled lever targets (kept out of main.lua — 200-local limit).

local M = {}

local dayKnob = 1.0
local nightKnob = 1.2
local shadowsOnProfile = false

-- Ship targets at knob=1.0 (Slice 6d HITL). Night ship default uses nightKnob=1.2 (+20% feedback).
local BASE_DAY_SKY_MULT = 0.46

-- Shadows-on preset (streaming-veryhigh): crush ambient/skylight; keep sun/direct for contrast.
local SHADOWS_ON_DAY_SKY_MULT = 0.34
local SHADOWS_ON_DAY_SETTINGS = {
    SkyLightIntensity = 0.28,
    OverallIntensity = 0.72,
    DirectionalBalance = 0.06,
    NightBrightness = 0.418,
    SunAngle = 100.0,
}
local BASE_NIGHT_SKYLIGHT_MULT = 1.32
local BASE_NIGHT_MOON_MULT = 1.27

local BASE_DAY_SETTINGS = {
    SkyLightIntensity = 0.385,
    OverallIntensity = 0.946,
    DirectionalBalance = 0.08,
    NightBrightness = 0.418,
    SunAngle = 100.0,
}

local BASE_NIGHT_SKYLIGHT_HUE = {
    SkyLightTemperature = -0.60,
    Saturation = 0.92,
    NightBrightness = 0.44,
    OverallIntensity = 1.19,
}

local BASE_DAY_DIRECT_WRITES = {
    { name = "Sun Light Intensity", target = 0.154 },
    { name = "Sun Light Intensity Multiplier in Interiors", target = 0.11 },
    { name = "Directional Lighting Intensity", target = 0.99 },
}

local INDOOR_SKYLIGHT_COLOR = { R = 0.62, G = 0.76, B = 1.00, A = 1.00 }

local function scaleDay(v)
    return v * dayKnob
end

local function scaleNight(v)
    return v * nightKnob
end

function M.init(dayBrightness, nightBrightness, useShadowsOnProfile)
    dayKnob = dayBrightness or 1.0
    nightKnob = nightBrightness or 1.2
    shadowsOnProfile = useShadowsOnProfile or false
end

function M.usesShadowsOnProfile()
    return shadowsOnProfile
end

local function activeDaySkyMult()
    return shadowsOnProfile and SHADOWS_ON_DAY_SKY_MULT or BASE_DAY_SKY_MULT
end

local function activeDaySettings()
    return shadowsOnProfile and SHADOWS_ON_DAY_SETTINGS or BASE_DAY_SETTINGS
end

function M.daySkyMultiplier()
    return scaleDay(activeDaySkyMult())
end

function M.daySettingsProfile()
    local base = activeDaySettings()
    return {
        SkyLightIntensity = scaleDay(base.SkyLightIntensity),
        OverallIntensity = scaleDay(base.OverallIntensity),
        DirectionalBalance = scaleDay(base.DirectionalBalance),
        NightBrightness = scaleDay(base.NightBrightness),
        SunAngle = base.SunAngle,
    }
end

function M.dayDirectWrites()
    local out = {}
    for i, entry in ipairs(BASE_DAY_DIRECT_WRITES) do
        out[i] = { name = entry.name, target = scaleDay(entry.target) }
    end
    return out
end

function M.nightBrightnessWrites()
    return {
        {
            name = "Sky Light Intensity Multiplier in Interiors",
            target = scaleNight(BASE_NIGHT_SKYLIGHT_MULT),
        },
        {
            name = "Moon Light Intensity Multiplier in Interiors",
            target = scaleNight(BASE_NIGHT_MOON_MULT),
        },
    }
end

function M.nightSkylightHueProfile()
    return {
        SkyLightTemperature = BASE_NIGHT_SKYLIGHT_HUE.SkyLightTemperature,
        Saturation = BASE_NIGHT_SKYLIGHT_HUE.Saturation,
        NightBrightness = scaleNight(BASE_NIGHT_SKYLIGHT_HUE.NightBrightness),
        OverallIntensity = scaleNight(BASE_NIGHT_SKYLIGHT_HUE.OverallIntensity),
    }
end

function M.indoorSkylightColor()
    return INDOOR_SKYLIGHT_COLOR
end

return M
