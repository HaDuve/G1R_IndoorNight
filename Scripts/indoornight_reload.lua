-- Save-load outdoor sky restore (kept out of main.lua — Lua 200-local limit).

local M = {}
local deps = nil

function M.bind(d)
    deps = d
end

function M.scheduleRestore()
    if not deps then return end

    local function tryRestore()
        local uds = deps.findUds()
        if not deps.safeObj(uds) then return false end
        deps.applyDayRestore(uds)
        deps.setOutdoorBaseline()
        print("[G1R_IndoorNight] save-load — outdoor sky baseline restored build=" .. tostring(deps.MOD_BUILD))
        return true
    end

    if tryRestore() then return end
    for _, delayMs in ipairs({ 500, 1500, 3000, 6000 }) do
        pcall(ExecuteWithDelay, delayMs, function()
            pcall(ExecuteInGameThread, tryRestore)
        end)
    end
end

return M
