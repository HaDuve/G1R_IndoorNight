# G1R Indoor Night Mod — Glossary

UE4SS mod that reduces **Sky Daylight Creep** indoors when G1R runs under a **Performance Sky Profile** (Lumen off, shadows off, etc.). Game Clock is never modified.

## Language

**Game Clock**:
The in-world time used by quests, NPC schedules, sleep/wait, and UI (e.g. "Day 3, 14:30").
_Avoid_: logic time, quest time

**Sun / Sky Lighting**:
The visual sky and ambient presentation driven by Ultra Dynamic Sky — skylight contribution, sun/moon directional lights, atmosphere, fog. Independent of Game Clock for mod purposes.
_Avoid_: game time, lighting time

**Sky Daylight Creep**:
Excess outdoor-bright skylight and ambient fill visible inside buildings, caves, and mines. Observed when Game Clock is daytime; absent or acceptable when Game Clock is nighttime. Caused in part by the Performance Sky Profile trading occlusion/GI for performance.
_Avoid_: light leak, brightness bug

**Performance Sky Profile**:
Player `Engine.ini` tuning for max performance — Lumen off, shadows off, reduced AO, auto-exposure bias, etc. Makes interiors rely more on skylight capture; daytime outdoors bleeds into occluded spaces.
_Avoid_: max perf mode, darkness tweaks

**Indoor Sky Dimming**:
While the player is **Inside**, the mod occlusion-blends Sun / Sky Lighting toward **night-level sky contribution** — lower skylight intensity, not a global sky flip. Goal is to match how interiors already look at night, not to display a moon or night sky aesthetic. Blend strength tracks UDS **Player Occlusion**; blending **starts at ~0.5**; below that, sky stays vanilla. Local light sources (torches, fires) stay at vanilla brightness. Toggle F7; off = instant restore. Default enabled. Config in `Scripts/main.lua`.
_Avoid_: indoor night override, moonlit night mode

**Night-Level Sky Contribution**:
The amount of skylight / ambient sky fill UDS applies at nighttime — the reference look the mod targets indoors during daytime. Currently approximated in implementation by UDS time-of-day ~22:00–04:00 (`TARGET_TOD` default `2300`), but the outcome metric is reduced skylight, not sun/moon visibility.
_Avoid_: moonlit night, night sky look

**Player Occlusion**:
UDS metric (0–1) for how enclosed the camera is: collision traces + optional occlusion volumes. Drives Interior Adjustments, sound muffling, and G1R's interior exposure boost.
_Avoid_: occlusion, inside detection

**Inside**:
Any enclosed playable space where Player Occlusion rises — buildings, caves, dungeons, mines. Detected via UDS occlusion, not custom mod volumes.
_Avoid_: interior, enclosed area

**Extra Interior Exposure**:
Player graphics setting (`ExtraInteriorExposure` in `GameUserSettings`) that brightens indoor scenes. Shares the occlusion signal family with Player Occlusion but stacks independently — mod does not override; player balances manually.
_Avoid_: interior brightness, exposure slider

**Implementation Lever**:
The UDS property or function the mod writes to achieve Indoor Sky Dimming. **Undecided** — chosen after in-game discovery comparing day-indoors (too bright) vs night-indoors (reference). Candidates: skylight intensity, Interior Adjustments, night TOD as proxy.
_Avoid_: override mechanism, sky hack

**Discovery Protocol**:
Three in-game poses on the same UDS actor: (1) outdoor daytime, occlusion ~0 — baseline; (2) deep indoor daytime (e.g. Old Mine), high occlusion — problem state; (3) same indoor spot at nighttime — reference state. Per pose: dump class name, Player Occlusion, Time of Day, and skylight / Interior Adjustments / lighting-brightness floats. The property delta between poses 2 and 3 selects the Implementation Lever.
_Avoid_: property scan, UDS dump

**Discovery Mode**:
Temporary instrumentation in `Scripts/main.lua`: `DEBUG` logging plus a snapshot keybind (F8) that prints filtered UDS candidate fields to the UE4SS console. Read-only — no sky writes during discovery. Removed or gated off once the Implementation Lever is identified.
_Avoid_: dump script, prototype mod

**Pose 3 Procedure**:
Reach nighttime reference via in-game sleep/wait (bed, fire, or G1R wait) until ~02:00, then return to the pose-2 indoor spot and snapshot. No cheat time-set; Game Clock advances normally.
_Avoid_: cheat time, console settime

**Lever Selection Priority**:
When discovery shows multiple properties differing between pose 2 (day-indoors) and pose 3 (night-indoors), pick the Implementation Lever in order: (1) skylight/ambient intensity channel; (2) occlusion-native Interior Adjustments field; (3) night Time of Day as proxy; (4) reject if read-only or fights per-frame game sync. Blend target at full occlusion = pose-3 value for the chosen property.
_Avoid_: tie-break, winner rule

**Apply Strategy**:
After discovery, poll-and-write on a **1000 ms** interval (configurable `PASS_MS`). Cache outdoor true lever value when Player Occlusion is below `OCCLUSION_START`; blend toward pose-3 target by occlusion. Escalate to post-tick hook only if in-game test proves G1R overwrites every frame.
_Avoid_: frame hook, tick hook

## Flagged ambiguities

**"Indoor Night" (mod name) vs Indoor Sky Dimming (goal)**:
Mod folder/name `G1R_IndoorNight` is legacy branding. Domain language uses **Indoor Sky Dimming** — reducing skylight to night-level contribution, not forcing a night sky visual.
