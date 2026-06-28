-- G1R_IndoorNight — user settings (edit freely; reload UE4SS / restart game to apply).
-- Missing or broken file: main.lua falls back to the same defaults below.

return {
    -- Mod on at load. F7 toggles mid-session regardless.
    ENABLED = true,
    TOGGLE_KEY = Key.F7,

    -- Stronger indoor ambient crush when in-game shadows are ON (streaming-veryhigh only).
    -- SHADOWS_ON_PROFILE = true,

    SHADOWS_ON_PROFILE = false,

    INDOOR_DAY_BRIGHTNESS   = 1.0,
    INDOOR_NIGHT_BRIGHTNESS = 1.2,

    -- Transition feel (seconds)
    TRANSITION_ENTER_SEC = 4.0,   -- sky blend transition time
    EXIT_GATE_SEC        = 0.5,   -- wait before brightening when leaving a building
    ENTER_GATE_SEC       = 3.0,   -- wait before dimming when entering a building
}
