# PRD: Mod Control Mode (3-state F7)

_Tracker: [Issue #20](https://github.com/HaDuve/G1R_IndoorNight/issues/20) (`ready-for-agent`)_

## Problem Statement

Gothic 1 Remake players running the Indoor Night UE4SS mod under a **Performance Sky Profile** suffer **Sky Daylight Creep** indoors. The mod gates **Indoor Sky Dimming** on **Inside Detection** (`IsUnderRoof`), but the gate is sometimes wrong — interiors stay too bright, or the player wants to preview forced dim / vanilla sky without reloading. A binary F7 on/off conflates “mod disabled” with “gate-driven dimming” and offers no way to force indoor treatment everywhere. Discovery spike keys (F8–F12) clutter the key space, collide with other mods, and are not appropriate for ship builds.

## Solution

Introduce **Mod Control Mode** — three explicit states cycled with **F7** (the only shipped keybind for this mod):

1. **Auto** (default) — normal **Apply Strategy**: **Gate Stability**, **Sky Transition**, **Indoor Sky Dimming** when **Inside**.
2. **Always On** — ignore **Inside Detection**; apply indoor `indoor_day` / `indoor_night` profiles everywhere per **Game Clock**; instant clock swaps.
3. **Always Off** — no sky writes; instant `G1R_DAY_RESTORE_*` day baseline (replaces F12 spike).

Boot default from `config.lua` `CONTROL_MODE`. F7 changes are in-memory for the session only. Console logs mode on each F7 press and in the boot banner. Retire F8–F12 keybinds; **Discovery Mode** logs extra DEBUG on poll/gate events only.

## User Stories

1. As a player in **Auto**, I want indoor areas to dim automatically when **Inside Detection** confirms, so that I do not need to micromanage lighting in caves and buildings.
2. As a player in **Auto**, I want outdoor areas to return to day baseline via **Sky Transition**, so that leaving a building does not leave me in cave-dark lighting.
3. As a player, I want to press F7 once to reach **Always On**, so that I can force **Indoor Sky Dimming** everywhere when the gate fails indoors.
4. As a player, I want to press F7 twice to reach **Always Off**, so that I can instantly escape to vanilla sky without reloading UE4SS.
5. As a player, I want to press F7 a third time to return to **Auto**, so that I can resume normal gate-driven behavior.
6. As a player, I want F7 mode changes to apply instantly, so that the key feels like a responsive override rather than a slow blend.
7. As a player, I want the UE4SS console to print the new mode on each F7 press, so that I know which of the three states I am in.
8. As a player, I want the mod boot banner to show the current **Mod Control Mode**, so that I can confirm the session started in the expected state after reload.
9. As a player who set `CONTROL_MODE = "always_off"` in config, I want the game to start with vanilla sky, so that I can permanently opt out without pressing F7 every session.
10. As a player who set `CONTROL_MODE = "always_on"` in config, I want forced dim after the normal warmup period, so that the world does not flicker during UDS init.
11. As a player, I want my F7 choice to persist across fast travel and map loads within one play session, so that the toggle does not “forget” after loading a new area.
12. As a player, I want F7 mode **not** saved to disk, so that relaunching the game returns me to my config default rather than a forgotten override.
13. As a player in **Always On** during daytime **Game Clock**, I want the `indoor_day` crush profile outdoors, so that forced dim matches what I would see inside at noon.
14. As a player in **Always On** at night **Game Clock**, I want the `indoor_night` profile outdoors, so that night gameplay keeps torch/skylift behavior instead of day crush.
15. As a player who sleeps from day to night in **Always On**, I want an instant profile swap, so that clock progression behaves like **Auto** indoors.
16. As a player in **Always Off** inside a cave, I want instant brightening, so that I can screenshot or compare vanilla lighting immediately.
17. As a player switching from **Always Off** to **Auto** while indoors, I want indoor dim to re-apply on the next gate evaluation, so that I do not need to leave and re-enter the building.
18. As a player switching from **Always On** to **Auto** while outdoors, I want instant day restore, so that the open world is not left crushed.
19. As a player, I want only F7 bound by this mod, so that F8–F12 remain available to G1R and other mods.
20. As a player with legacy `ENABLED = false` in config, I want that to map to **Always Off** at boot, so that existing configs keep working.
21. As a player with legacy `ENABLED = true` in config, I want that to map to **Auto** at boot, so that existing configs keep working.
22. As a developer, I want `CONTROL_MODE` to override legacy `ENABLED` when both are set, so that migration is unambiguous.
23. As a developer, I want a small pure-Lua control-mode module, so that cycle logic and config parsing are testable without UE4SS.
24. As a developer, I want map-load restore to respect the current mode, so that **Always On** is not wiped by unconditional day restore.
25. As a developer, I want **Always Off** to skip the poll write path entirely, so that we do not fight G1R every frame with restore writes.
26. As a developer, I want **Discovery Mode** to add DEBUG logging without registering keys, so that ship and dev builds share one key surface.
27. As a document reader, I want an ADR explaining why three states exist, so that future contributors do not collapse back to binary toggle.
28. As a player on mount (rideable/scavenger), I want **Mod Control Mode** unchanged while sky poll suspends, so that dismount resumes the same override.
29. As a player in **Auto** when `IsUnderRoof` is unavailable, I want the mod to hold state and log once, so that transient API failures do not spam or corrupt sky.
30. As a player, I want **Lever Boundaries** unchanged per mode except where **Always Off** triggers outdoor restore writes, so that **Extra Interior Exposure** stays player-owned indoors.

## Implementation Decisions

### Modules to build or modify

| Module | Role | Depth |
|--------|------|-------|
| **Control mode** (new) | Parse `CONTROL_MODE` / legacy `ENABLED`; cycle F7; predicates (`isAuto`, `isAlwaysOn`, `isAlwaysOff`, `shouldPollGate`, `shouldForceIndoor`, `shouldSkipWrites`); console labels | Deep — pure Lua, unit-testable |
| **Config loader** | Extend defaults with `CONTROL_MODE`; migration from `ENABLED` | Shallow — extend existing loader |
| **Poll orchestrator** | Branch `pass()` on control mode: **Auto** = current gate/transition path; **Always On** = game-clock-only indoor apply; **Always Off** = early return before writes | Shallow — wires existing apply functions |
| **Mode switch handler** | Replace `setModEnabled(boolean)` with `setControlMode(next)` / `cycleControlMode()`; reset sky state; instant apply or restore | Medium |
| **Reload coordinator** | Accept current mode; **Always Off** → day restore; **Always On** → forced indoor after UDS ready; **Auto** → gate re-poll (no forced outdoor baseline) | Medium — fixes current unconditional restore |
| **Keybind bootstrap** | Register **F7** only; remove all `RegisterKeyBind` for F8–F12 (including discovery block) | Shallow |
| **Discovery instrumentation** | `DISCOVERY_MODE` adds DEBUG logs on poll/gate events; snapshot/spike functions remain unwired | Shallow |
| **Brightness profiles** | No change to `indoornight_brightness` lever math | Unchanged |

### Control mode state machine

```lua
-- cycle order (F7)
local CYCLE = { "auto", "always_on", "always_off" }

-- config.lua values
CONTROL_MODE = "auto" | "always_on" | "always_off"
-- legacy: ENABLED true -> auto, false -> always_off (CONTROL_MODE wins if set)
```

### Mode switch behavior (instant)

| From → To | Action |
|-----------|--------|
| any → **Always Off** | `applyDayRestore`; clear stable indoor state |
| any → **Always On** | `applyIndoorProfile` for current game clock |
| any → **Auto** | If inside gate true → indoor apply; else → day restore |
| **Auto** poll | Existing gate + **Sky Transition** path |
| **Always On** poll | Skip gate; apply indoor profile; refresh on game-night frame-fight if needed |
| **Always Off** poll | Return before writes (after warmup if needed for readiness only) |

### Persistence rules

- **Disk:** none for F7
- **Session:** in-memory mode survives map load / fast travel
- **Boot:** `config.lua` `CONTROL_MODE`; warmup + stable-ready before first write in active modes

### Feedback contract

- F7: `[G1R_IndoorNight] Mod Control Mode: AUTO|ALWAYS ON|ALWAYS OFF`
- Boot banner includes current mode string

### Documentation updates

- `CONTEXT.md` — already updated (**Mod Control Mode** glossary)
- `docs/adr/0001-mod-control-mode.md` — accepted
- `README.md`, `HANDOFF.md`, `docs/DISCOVERY.md` — remove F8–F12 ship references; document F7 cycle and `CONTROL_MODE`

## Testing Decisions

**Principle:** Test external behavior of pure Lua modules; do not assert UE4SS hook internals.

| Module | Tests | Approach |
|--------|-------|----------|
| **Control mode** | Yes | New minimal Lua test runner or busted-style spec if added; table-driven tests for cycle order, config migration, predicates |
| **Reload coordinator** | Optional | Mock deps table; assert which restore/apply callback fires per mode |
| **Poll orchestrator** | No unit tests | HITL in-game: Swamp Camp F7 cycle, cave gate, fast travel, sleep clock swap in **Always On** |
| **Keybind bootstrap** | Manual | Confirm only F7 registered; F8–F12 inert for this mod |

**Prior art:** No automated tests exist in repo today; first tests likely live alongside new control module.

**Suggested HITL checklist:**

- [ ] Boot `auto` — indoor dims on enter, outdoor blends on exit
- [ ] F7 → **Always On** outdoors at noon — instant crush
- [ ] F7 → **Always Off** in cave — instant bright
- [ ] F7 → **Auto** — gate resumes
- [ ] Fast travel in **Always On** — stays crushed after load
- [ ] UE4SS reload — resets to config default
- [ ] `ENABLED = false` only — boots **Always Off**

## Out of Scope

- On-screen HUD for current mode
- Disk persistence of F7 choice
- Changing `TOGGLE_KEY` away from F7 in ship docs (config key may remain for power users)
- Modifying other mods’ keybindings
- Re-wiring discovery snapshot/spike functions to new triggers
- Changes to **Accepted Indoor Profile** lever values or **SHADOWS_ON_PROFILE** math
- Engine profile pack / `switch-g1r-profile.sh` changes

## Further Notes

- ADR: `docs/adr/0001-mod-control-mode.md`
- Glossary: `CONTEXT.md` → **Mod Control Mode**, **Apply Strategy**, **Discovery Mode**
- `indoornight_reload.scheduleRestore` today always calls `applyDayRestore` — must become mode-aware (known code contradiction)
- `pass()` early-outs on `not modEnabled` — replace with mode predicates
- Confirm module split with implementer: extract `indoornight_control.lua` before growing `main.lua` further (Lua 200-local limit already motivated `indoornight_reload` extraction)
