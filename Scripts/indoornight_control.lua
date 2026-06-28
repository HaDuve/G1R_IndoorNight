-- Mod Control Mode — pure Lua (testable without UE4SS).

local M = {}

M.CYCLE = { "auto", "always_on", "always_off" }

local LABELS = {
    auto       = "AUTO",
    always_on  = "ALWAYS ON",
    always_off = "ALWAYS OFF",
}

local VALID = {
    auto       = true,
    always_on  = true,
    always_off = true,
}

function M.normalize(mode)
    if type(mode) ~= "string" then return "auto" end
    local lower = string.lower(mode):gsub("-", "_")
    if VALID[lower] then return lower end
    return "auto"
end

function M.resolveFromConfig(cfg)
    if cfg == nil then return "auto" end
    if cfg.CONTROL_MODE ~= nil then
        return M.normalize(cfg.CONTROL_MODE)
    end
    if cfg.ENABLED == false then return "always_off" end
    return "auto"
end

function M.cycle(mode)
    mode = M.normalize(mode)
    for i, m in ipairs(M.CYCLE) do
        if m == mode then
            return M.CYCLE[(i % #M.CYCLE) + 1]
        end
    end
    return M.CYCLE[1]
end

function M.isAuto(mode)
    return M.normalize(mode) == "auto"
end

function M.isAlwaysOn(mode)
    return M.normalize(mode) == "always_on"
end

function M.isAlwaysOff(mode)
    return M.normalize(mode) == "always_off"
end

function M.shouldSkipWrites(mode)
    return M.isAlwaysOff(mode)
end

function M.shouldPollGate(mode)
    return M.isAuto(mode)
end

function M.shouldForceIndoor(mode)
    return M.isAlwaysOn(mode)
end

function M.label(mode)
    return LABELS[M.normalize(mode)] or "AUTO"
end

return M
