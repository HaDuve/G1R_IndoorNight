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
While the player is **Inside**, the mod blends Sun / Sky Lighting toward **night-level sky contribution** — lower skylight intensity, not a global sky flip. Goal is to match how interiors already look at night, not to display a moon or night sky aesthetic. Blend strength tracks **Inside Detection** when available; blending **starts at ~0.5** on that signal; below that, sky stays vanilla. Local light sources (torches, fires) stay at vanilla brightness. Toggle F7; off = instant restore. Default enabled.
_Avoid_: indoor night override, moonlit night mode

**Night-Level Sky Contribution**:
The amount of skylight / ambient sky fill that reads as acceptable indoors during daytime Game Clock. **Accepted approximation:** G1R `SetSettings` + skylight multiplier bundle (Slice 2d v3.1 in CONFIG), not raw Time of Day.
_Avoid_: moonlit night, night sky look

**Player Occlusion**:
UDS metric (0–1) for how enclosed the camera is: collision traces + optional occlusion volumes. Intended to drive Interior Adjustments and sound muffling. **Inside Detection** candidate — property identified (`Total Occlusion` on the weather occlusion component), but runtime behaviour in G1R is unverified (reads flat at 0 in initial snapshots).
_Avoid_: occlusion, inside detection

**Inside**:
Any enclosed playable space where the player should receive Indoor Sky Dimming — buildings, caves, dungeons, mines. A location can be Inside by geography while UDS Player Occlusion still reads zero; **Inside** is the player-facing concept, not a single float.
_Avoid_: interior, enclosed area

**Inside Detection**:
How the mod decides the player is Inside before blending. UDS Player Occlusion inactive in G1R (Slice 2a). **Accepted gate (Slice 2b):** `EnvironmentManagerCharacterStatics:IsUnderRoof(playerPawn)` — false outdoor, true in New Camp house HITL. F8 also probes `IndoorDetectionComponent` (`DetectionConfidence`; `bDetectedIsIndoor` stuck false). Ship fallback: F7 manual toggle.
_Avoid_: occlusion check, indoor trigger

**Implementation Lever**:
Multi-write bundle on `Ultra_Dynamic_Sky_C` — **`SetSettings`** (`UltraDynamicSkySettings`), **sky light multipliers**, **`Apply Interior Adjustments`**, and direct **sun / directional / exposure** fields. Confirmed Slice 2d (v3.1). Controller: `Gothic_Ultra_Dynamic_Controller_C` syncs sky but lever writes target UDS actor. ~~Time of Day~~ rejected (Slice 2c).
_Avoid_: override mechanism, sky hack, TOD hack

**Accepted Indoor Profile (v3.1)**:
HITL-tuned spike values in `G1R_SETTINGS_NIGHT_PROFILE`, `G1R_DIRECT_NIGHT_WRITES`, `G1R_SKY_MULTIPLIER_TARGET` — full table in `docs/DISCOVERY.md` Slice 2d. Outdoor restore: `G1R_DAY_RESTORE_*` / F12.

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

**Occlusion Diagnostic**:
Slice 2a pass: extended read-only snapshots (outdoor vs confirmed indoor, same session) to determine whether UDS Player Occlusion is **alive** (`Running` true and at least one field moves) or **dead** (pivot Inside Detection to G1R native signal; manual F7 as ship fallback).
_Avoid_: occlusion debug, F8 dump

**Apply Strategy**:
After Inside Detection and Implementation Lever are confirmed, poll-and-write on a configurable interval. Cache outdoor true lever value when below blend threshold; blend toward night-level target by inside strength. Escalate to post-tick hook only if in-game test proves G1R overwrites every frame.
_Avoid_: frame hook, tick hook

## Flagged ambiguities

**"Indoor Night" (mod name) vs Indoor Sky Dimming (goal)**:
Mod folder/name `G1R_IndoorNight` is legacy branding. Domain language uses **Indoor Sky Dimming** — reducing skylight to night-level contribution, not forcing a night sky visual.
