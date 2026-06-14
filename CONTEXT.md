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
While the player is **Inside** (`IsUnderRoof=true`), the mod dims **sky contribution** toward a unified dark-cave feel — not a global sky flip or moonlit aesthetic. **Day Game Clock:** crushed skylight multipliers + `SetSettings` dim bundle. **Night Game Clock:** clear day crush, native night + torches, skylight/moon brightness lifts — **no exposure writes** (see **Lever Boundaries**). When **Outside**, day baseline is restored via **Sky Transition**. Local light sources (torches, fires) stay at vanilla brightness. **F7** toggle off = **instant** day restore (manual escape hatch; no blend). Default enabled.
_Avoid_: indoor night override, moonlit night mode

**Extra Interior Exposure**:
G1R graphics user setting mapped to UDS **`Exposure Bias in Interior`**. **Owned by the player** while indoors — the mod must not write this field on the indoor poll path (day or night). Brightness tuning uses skylight, `NightBrightness`, sun/moon multipliers, and `SetSettings` intensity instead. Outdoor restore and F12 may reset exposure to vanilla baseline.
_Avoid_: interior exposure mod, exposure crush

**Transition Perceived Brightness**:
Visible bright/dark swings when crossing the **Inside** gate — caused by simultaneous jumps in the allowed **Implementation Lever** bundle (skylight multipliers, `SetSettings` intensities, sun/directional fields), **not** by writes to **Extra Interior Exposure**. Fix: linearly lerp allowed levers over a **Sky Transition**; do not animate or write `Exposure Bias in Interior` while **Inside**.
_Avoid_: exposure transition, exposure spike

**Sky Transition**:
Gradual change between sky profiles when the **Inside** gate confirms or releases. **Enter:** linear lerp of allowed **Implementation Lever** fields toward the target profile over ~4s (`TRANSITION_ENTER_MS`) after **Gate Stability** passes. **Revert:** if the gate flips during pending confirmation or an active enter transition, fast linear lerp (~1s) back to the **Last Stable Profile** (fully outdoor or fully indoor). Does not animate **Extra Interior Exposure** while **Inside**. Game-clock-only `indoor_day` ↔ `indoor_night` swaps while **Inside** are **instant** (not blended).
_Avoid_: blend transition, fade, crossfade

**Last Stable Profile**:
The sky lever bundle last fully applied and confirmed — outdoor baseline (`G1R_DAY_RESTORE_*`) or indoor day/night target (`applyIndoorProfile`). Used as the revert target when a **Sky Transition** is cancelled mid-blend.
_Avoid_: previous state, rollback target

**Lever Boundaries**:
Hard rules for what Slice 3 may write. Source of truth: `Scripts/main.lua` CONFIG + apply functions (`applyIndoorProfile`, `applyNightIndoorClear`, `applyDayRestore`). **v3.3.12 (HITL accepted).**

| Category | Field / lever | Indoor day | Indoor night | Outdoor leave / F7 off / F12 |
|----------|---------------|------------|--------------|------------------------------|
| **Forbidden (never)** | `Time of Day` (raw UDS) | — | — | — |
| **Forbidden (never)** | Torch / local light actors | — | — | — |
| **Forbidden (failed)** | `Interior Sky Light Color` struct | skip | skip | — |
| **Forbidden (failed)** | `SkyLightColorMultiplier*` structs | skip | skip | — |
| **User-owned** | `Exposure Bias in Interior` | **do not write** | **do not write** | restore vanilla (`G1R_DAY_RESTORE_WRITES`) |
| **SetSettings** | `SkyLightIntensity`, `OverallIntensity`, `DirectionalBalance` | write | night: partial | restore |
| **SetSettings** | `NightBrightness` | write (day clock) | write (boost) | restore |
| **SetSettings** | `SkyLightTemperature`, `Saturation` | **do not write** | write | restore |
| **SetSettings** | `Contrast` | **do not write** | **do not write** (keeps restore ~0.15) | restore |
| **SetSettings** | `SunAngle` | write | — | restore |
| **Multipliers** | `Dynamic/Target Sky Light Multiplier`, interior skylight mult | **0.42** | **1.0** (clear crush) | **1.0** |
| **Flag** | `Apply Interior Adjustments` | **true** | **false** | **false** |
| **Direct UDS** | Sun / directional crush fields | write | restore values (not exposure) | restore |
| **Direct UDS** | `Sky Light Intensity Mult in Interiors` | via multipliers | **1.20** | restore |
| **Direct UDS** | `Moon Light Intensity Mult in Interiors` | — | **1.15** | restore |

**Accepted Indoor Profile (v3.3.12)**:
HITL-accepted values in `Scripts/main.lua` CONFIG — day: `G1R_SETTINGS_INDOOR_DAY_PROFILE` + `G1R_DIRECT_INDOOR_DAY_WRITES` + skylight mult **0.42** (no day hue); night: `applyNightIndoorClear` + `G1R_NIGHT_INDOOR_BRIGHTNESS_WRITES` + `G1R_SETTINGS_INDOOR_NIGHT_SKYLIGHT_HUE`. Outdoor restore: `G1R_DAY_RESTORE_*` / F12.

**Implementation Lever**:
Multi-write bundle on `Ultra_Dynamic_Sky_C` — **`SetSettings`** (`UltraDynamicSkySettings`), **sky light multipliers**, **`Apply Interior Adjustments`**, and direct **sun / directional** fields. **Not** routine exposure writes indoors (see **Extra Interior Exposure**). Controller: `Gothic_Ultra_Dynamic_Controller_C` syncs sky but lever writes target UDS actor. ~~Time of Day~~ rejected (Slice 2c).
_Avoid_: override mechanism, sky hack, TOD hack

**Accepted Indoor Profile (v3.1)**:
Superseded for ship by **Accepted Indoor Profile (v3.3.12)**. Retained in `docs/DISCOVERY.md` Slice 2d as spike reference only.

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

**Gate Stability**:
Debounce before arming an enter **Sky Transition**. After the first `IsUnderRoof` flip, the gate must still agree at **1s, 2s, and 3s** checkpoints (same poll interval). Any disagreement resets the window. Prevents doorway/threshold flicker from triggering a blend. Applies only to inside/outside changes — not **F7** (instant), not game-clock `indoor_day` ↔ `indoor_night` swaps (instant).
_Avoid_: debounce, hysteresis, gate delay

**Apply Strategy**:
Poll `IsUnderRoof` every `PASS_MS` (default 100 ms). Modes: `indoor_day` (game clock daytime), `indoor_night` (TOD ≥2000 or ≤600), `outdoor`. **Inside/outside changes:** **Gate Stability** (3s checkpoints) then enter **Sky Transition** (~4s linear lerp of allowed levers; `TRANSITION_ENTER_MS`). Gate flip during pending or active enter → ~1s fast revert to **Last Stable Profile**. **Game-clock-only changes** while **Inside** (`indoor_day` ↔ `indoor_night`): **instant** profile swap (typically once per day via sleep/wait; acceptable one-time spike). **F7** off / on: instant restore or re-poll (no blend). `indoor_night` may still refresh ~2s when stably indoors (frame-fight). Outdoor leave: `G1R_DAY_RESTORE_*` via blend; exposure reset when fully outdoor. When `IsUnderRoof` unavailable, log once and hold state.
_Avoid_: frame hook, tick hook

## Flagged ambiguities

**"Indoor Night" (mod name) vs Indoor Sky Dimming (goal)**:
Mod folder/name `G1R_IndoorNight` is legacy branding. Domain language uses **Indoor Sky Dimming** — reducing skylight to night-level contribution, not forcing a night sky visual.
