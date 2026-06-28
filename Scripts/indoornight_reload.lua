-- Save-load sky restore (kept out of main.lua — Lua 200-local limit).

local M = {}
local deps = nil

function M.bind(d)
    deps = d
end

function M.scheduleRestore()
    if not deps then return end

    local mode = deps.getControlMode and deps.getControlMode() or "auto"

    local function tryRestore()
        local uds = deps.findUds()
        if not deps.safeObj(uds) then return false end

        if mode == "always_off" then
            deps.applyDayRestore(uds)
            deps.setOutdoorBaseline()
            print("[G1R_IndoorNight] save-load — Always Off day baseline restored build=" .. tostring(deps.MOD_BUILD))
        elseif mode == "always_on" then
            local tod = deps.readTimeOfDay(uds)
            local gameNight = deps.isGameNight(tod)
            deps.applyIndoorProfile(uds, gameNight)
            deps.setForcedIndoorBaseline(gameNight)
            print("[G1R_IndoorNight] save-load — Always On indoor profile restored build=" .. tostring(deps.MOD_BUILD))
        else
            print("[G1R_IndoorNight] save-load — Auto; gate will re-poll build=" .. tostring(deps.MOD_BUILD))
        end
        return true
    end

    if mode == "auto" then
        tryRestore()
        return
    end

    if tryRestore() then return end
    for _, delayMs in ipairs({ 500, 1500, 3000, 6000 }) do
        pcall(ExecuteWithDelay, delayMs, function()
            pcall(ExecuteInGameThread, tryRestore)
        end)
    end
end

return M
