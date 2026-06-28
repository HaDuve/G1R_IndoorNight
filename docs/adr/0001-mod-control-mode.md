# Mod Control Mode (3-state F7)

**Status:** accepted

The shipped mod used a binary F7 toggle (`ENABLED` / disabled) plus discovery spike keys F8–F12. Players need three distinct behaviors: gate-driven **Indoor Sky Dimming** (default), forced global dim when **Inside Detection** is wrong, and forced vanilla sky — without conflating those with a simple on/off.

**Decision:** Replace the boolean with **Mod Control Mode**, cycled via **F7** only: **Auto** → **Always On** → **Always Off** → **Auto**. **Auto** respects **Inside Detection** and **Sky Transition**. **Always On** applies the indoor profile everywhere (still split by **Game Clock**). **Always Off** instant-restores day baseline. All mode changes are **instant** (no **Sky Transition**). Boot default comes from `config.lua` `CONTROL_MODE`; F7 changes are session-only (no disk persistence). Mode survives map loads within a session; reload hooks re-apply per mode. Retire all other F-key bindings for this mod (F8–F12); **Discovery Mode** becomes extra DEBUG logging only. **F12** day-restore spike removed — **Always Off** is the player-facing restore path.

**Considered options:** (1) Binary toggle only — cannot force global dim without broken gate. (2) Separate keys per mode — clutters G1R key space and collides with other mods. (3) Persist F7 to disk — surprising on relaunch; config file is the durable preference.

**Consequences:** `modEnabled` boolean and `setModEnabled` flip logic must become a mode state machine. `indoornight_reload` must stop unconditional day restore on map load. Poll entry (`pass`) must branch: skip writes in **Always Off**, skip gate in **Always On**, existing path in **Auto**. Warmup + stable-ready gates apply before first write in all active modes.
