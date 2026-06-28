#!/usr/bin/env lua
-- Unit tests for indoornight_control (run: lua tools/test-indoornight-control.lua)

local script_dir = arg[0]:match("(.*/)")
if script_dir then
    package.path = script_dir .. "../Scripts/?.lua;" .. package.path
end

local control = require("indoornight_control")

local failures = 0

local function check(cond, msg)
    if not cond then
        print("FAIL: " .. msg)
        failures = failures + 1
    end
end

local function eq(got, want, msg)
    if got ~= want then
        print(string.format("FAIL: %s — got %q want %q", msg, got, want))
        failures = failures + 1
    end
end

eq(control.cycle("auto"), "always_on", "auto -> always_on")
eq(control.cycle("always_on"), "always_off", "always_on -> always_off")
eq(control.cycle("always_off"), "auto", "always_off -> auto")

eq(control.resolveFromConfig({ CONTROL_MODE = "always_on" }), "always_on", "CONTROL_MODE wins")
eq(control.resolveFromConfig({ CONTROL_MODE = "always_on", ENABLED = false }), "always_on", "CONTROL_MODE over ENABLED")
eq(control.resolveFromConfig({ ENABLED = false }), "always_off", "ENABLED false legacy")
eq(control.resolveFromConfig({ ENABLED = true }), "auto", "ENABLED true legacy")
eq(control.resolveFromConfig({}), "auto", "empty config")

check(control.shouldPollGate("auto"), "auto polls gate")
check(not control.shouldPollGate("always_on"), "always_on skips gate")
check(control.shouldForceIndoor("always_on"), "always_on forces indoor")
check(control.shouldSkipWrites("always_off"), "always_off skips writes")
eq(control.label("always_on"), "ALWAYS ON", "label")

if failures == 0 then
    print("ok — all control-mode tests passed")
    os.exit(0)
else
    print(failures .. " test(s) failed")
    os.exit(1)
end
