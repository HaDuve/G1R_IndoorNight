# Discovery Protocol — Slice 1

**Status:** **Slice 6d v3.5.1 (HITL tuning).** Slice 3 v3.3.12 baseline accepted. Tracker issues #1, #4, #5, #6 closed (2026-06-14).

## Slice 6d — HITL transition feel validation (**v3.5.1 — tuning applied**)

**Issue:** [#15](https://github.com/HaDuve/G1R_IndoorNight/issues/15)

**Findings (2026-06-15 HITL):**

| Check | Result | Action |
|-------|--------|--------|
| Doorway flicker (<3s) does not trigger dimming | **Pass** | — |
| Enter stable indoor (~4s fade) | **Pass** | — |
| Back-out mid-enter (~1s revert) | **Pass** | — |
| F7 off instant outdoor | **Pass** | — |
| Game-night indoor swap + torches | **Pass** | — |
| Exit indoor feels sluggish vs enter | **Adjust** | Asymmetric Gate Stability: **1s** to confirm outdoor when leaving stable indoor; **3s** to re-enter indoor |
| Day + night indoor still too dark | **Adjust** | All crush targets **×1.10** (+10% brightness) |

**Shipped (v3.5.1-s6d):** `MOD_BUILD = v3.5.1-s6d`; asymmetric gate checkpoints; updated lever targets below.

**Updated targets (Slice 6d ×1.10 on v3.3.12):**

| Lever | Indoor day | Indoor night |
|-------|------------|--------------|
| Skylight multipliers | **0.46** | **1.0** |
| `SetSettings.SkyLightIntensity` | **0.385** | restore **1.0** |
| `SetSettings.OverallIntensity` | **0.946** | **1.19** |
| `SetSettings.NightBrightness` | **0.418** | **0.44** |
| `Sun Light Intensity` | **0.154** | **0.90** |
| `Sun Light Intensity Mult in Interiors` | **0.11** | **1.0** |
| `Directional Lighting Intensity` | **0.99** | **3.0** |
| `Sky Light Intensity Mult in Interiors` | **0.46** (via mult) | **1.32** |
| `Moon Light Intensity Mult in Interiors` | — | **1.27** |

**Gate Stability (Slice 6d):** Exit stable indoor → outdoor: **1s** checkpoint. Enter outdoor → indoor: **1s / 2s / 3s** checkpoints unchanged.

## Slice 3 — Auto Apply on `IsUnderRoof` (**v3.3.12 shipped — HITL accepted**)

**Shipped:** `DISCOVERY_MODE = false`; poll `IsUnderRoof` every 100 ms; modes `indoor_day` / `indoor_night` / `outdoor`; F7 toggle + day restore.

**Lever policy (HITL 2026-06-14):** See **`CONTEXT.md` → Lever Boundaries**. Summary: **never write `Exposure Bias in Interior` while indoors** (player **Extra Interior Exposure** owns it). Never write raw TOD or local lights. Night brightness via `NightBrightness`, skylight/moon multipliers, `OverallIntensity` — not exposure.

**HITL (2026-06-14, v3.3.12 — accepted):**

| Check | Result |
|-------|--------|
| Outdoor daytime / night baseline | **Pass** |
| Indoor day (dim + cave feel) | **Pass** — v3.3.12 (crush 0.42, no hue) |
| Indoor night (torches, readability) | **Pass** — v3.3.4+ (no exposure writes) |
| Extra Interior Exposure respected indoors | **Pass** |
| Game Clock unchanged | **Pass** |
| F7 off / on toggle | **Pass** |

**Accepted targets (v3.3.12)** — `Scripts/main.lua` CONFIG:

| Lever | Indoor day | Indoor night |
|-------|------------|--------------|
| Skylight multipliers | **0.42** | **1.0** |
| `Apply Interior Adjustments` | **true** | **false** |
| `SetSettings.SkyLightIntensity` | **0.35** | restore **1.0** |
| `SetSettings.OverallIntensity` | **0.86** | **1.08** |
| `SetSettings.DirectionalBalance` | **0.08** | restore **1.0** |
| `SetSettings.NightBrightness` | **0.38** | **0.40** |
| `SetSettings.Contrast` | *(not written)* | *(not written)* |
| `SetSettings.SkyLightTemperature` | *(not written)* | **-0.60** |
| `SetSettings.Saturation` | *(not written)* | **0.92** |
| `SetSettings.SunAngle` | **100** | — |
| `Sun Light Intensity` | **0.14** | **0.90** |
| `Sun Light Intensity Mult in Interiors` | **0.10** | **1.0** |
| `Directional Lighting Intensity` | **0.90** | **3.0** |
| `Sky Light Intensity Mult in Interiors` | **0.42** (via mult) | **1.20** |
| `Moon Light Intensity Mult in Interiors` | — | **1.15** |
| **`Exposure Bias in Interior`** | **do not write** | **do not write** |

**Historical (v3.2):** Day-indoor crush experiment; game-night double-dim fixed in v3.2.6–v3.3.x. Exposure-based night tuning abandoned v3.3.4 (fought user slider).

<details>
<summary>v3.2 table (archive)</summary>

| Lever (v3.2 day-indoor) | Target |
|-------------------------|--------|
| Skylight multipliers | **0.32** |
| `SetSettings.SkyLightIntensity` | **0.30** |
| `SetSettings.OverallIntensity` | **0.45** |
| `SetSettings.DirectionalBalance` | **0.30** |
| `SetSettings.NightBrightness` | **0.38** (day clock only) |
| `Sun Light Intensity` | **0.22** |
| `Sun Light Intensity Multiplier in Interiors` | **0.29** |
| `Directional Lighting Intensity` | **1.92** |
| `Exposure Bias in Interior` | ~~**-0.60**~~ → **not written (v3.3.6)** |

</details>

## Slice 2d — G1R Skylight Lever Spike (**COMPLETE — ACCEPTED**)

**Verdict (2026-06-14):** Implementation Lever **confirmed** on G1R path (`SetSettings` + skylight multipliers + direct sun/exposure). Raw UDS `Time of Day` rejected (Slice 2c). HITL accepted **v3.1** profile after v1 (too little) → v2 (pitch black) → v3 → v3.1 tuning.

| Check | Result |
|-------|--------|
| Visual night-indoor (daytime Game Clock) | **Yes** — v3.1 accepted |
| Writes persist | **Yes** |
| Game Clock unchanged | **Yes** |
| Frame-fight | Values stick across session; Slice 3 may still need poll/post-tick |

**Accepted target profile (v3.1)** — `Scripts/main.lua` CONFIG:

| Lever | Target |
|-------|--------|
| `Dynamic/Target Sky Light Multiplier`, interior skylight mult | **0.40** |
| `Apply Interior Adjustments` | **true** |
| `SetSettings.SkyLightIntensity` | **0.37** |
| `SetSettings.OverallIntensity` | **0.56** |
| `SetSettings.DirectionalBalance` | **0.38** |
| `SetSettings.NightBrightness` | **0.48** |
| `Sun Light Intensity` | **0.28** |
| `Sun Light Intensity Multiplier in Interiors` | **0.36** |
| `Directional Lighting Intensity` | **2.40** |
| `Exposure Bias in Interior` | **-0.50** |

**Day restore:** F12 or relaunch (see `G1R_DAY_RESTORE_*` in CONFIG).

**Slice 3:** ~~Apply v3.1 bundle when **`IsUnderRoof`**~~ **shipped** — see Slice 3 section above. F7 manual override remains.

## Slice 2c — TOD Lever Write Spike (**COMPLETE — REJECTED**)

**Verdict (2026-06-14):** Raw `Time of Day` on `Ultra_Dynamic_Sky_C` is **not a viable Implementation Lever**.

| Check | Result |
|-------|--------|
| Lua write + immediate readback | **Yes** — 991→2300, 1003→2300 (`write ok=true`, readback=2300) |
| Persists to next F8 (~3s later) | **No** — post-F10 F8 shows 992.7 / 1003.8 (Game Clock drift only) |
| Visual change toward night-indoor | **No** (HITL) |
| Game Clock / HUD time unchanged | **Yes** (expected) |
| Frame-fight verdict | **overwritten + no visual effect** |

**Interpretation:** G1R's `GothicUltraDynamicSky` wrapper re-syncs sky from **Game Clock** every tick. The `Time of Day` float we read/write is a stale or non-authoritative mirror — writing it does not drive rendered lighting.

**Retrospective on Slice 1 lever pick:** Pose 2→3 TOD delta (676→2291) was **confounded** — pose 3 required advancing Game Clock to night via sleep/wait, not an independent sky control. Skylight/sun/moon top-level floats were identical across all poses.

**Next lever candidates:** `GothicUltraDynamicSky` (`DayNightIntensity`, `SetSettings` + `UltraDynamicSkySettings.SkyLightIntensity` / `NightBrightness`); or post-tick re-apply after G1R sync (high frame-fight risk).

### Protocol (reference)

Daytime **Game Clock**. F8 → F10 → F8 per pose. F10 = one-shot write; F9 = G1R quickload. Sync: `./tools/sync-from-ue4ss-log.sh` (snapshots) + grep `TOD SPIKE` in UE4SS.log.

## Slice 2a — Occlusion Diagnostic (**COMPLETE**)

**Verdict (2026-06-14):** UDS Player Occlusion **INACTIVE** in G1R.

Outdoor vs New Camp house (same session): identical diagnostics — `Running=false`, `TotalHits=0`, `Max Interior Occlusion Distance=0`, `Total Occlusion=0`, `Apply Interior Adjustments=false`. Location was valid; component never started.

**Pivot:** Inside Detection → G1R native signal (Slice 2b). Ship fallback → F7 manual toggle.

## Slice 2b — G1R Inside Detection (**COMPLETE — ACCEPTED**)

**Verdict (2026-06-14):** **`EnvironmentManagerCharacterStatics:IsUnderRoof`** is the Slice 3 gate. Outdoor vs New Camp house (same session, daytime Game Clock): `IsUnderRoof` false → true. **`bDetectedIsIndoor` rejected** (stuck false both poses). **`DetectionConfidence`** tracks inversely (1.0 outdoor → 0.0 indoor) — optional graded secondary; primary gate is bool `IsUnderRoof`.

| Signal | Outdoor F8 #1 | Indoor F8 #2 | Gate? |
|--------|---------------|--------------|-------|
| **`IsUnderRoof`** | false | **true** | **Yes — primary** |
| `DetectionConfidence` | 1.0000 | 0.0000 | Optional graded (`1 - confidence`) |
| `DetectionScore` | -4.0579 | -0.0072 | Diagnostic only |
| `bDetectedIsIndoor` | false | false | **No — stuck** |
| `bDetectedIsOutdoor` | true | true | No delta |
| UDS `Total Occlusion` | 0 | 0 | Dead (Slice 2a) |

**Read path (Slice 3):** `GothicPlayerControllerBaseBP_C` → pawn (`Pawn` / `K2_GetPawn()`) → `EnvironmentManagerCharacterStatics:IsUnderRoof(pawn)`.

**IndoorDetectionComponent path (F8 diagnostic):** `GetIndoorDetectionComponent()` → `OcclusionDetectionComponent` on player controller. Alive (`HasRecentDetectionResult=true`) but `bDetectedIsIndoor` unusable.

**Ship fallback:** F7 manual toggle if `IsUnderRoof` false-positives appear in caves/mines (HITL pending there).

**HITL sync:** `./tools/sync-from-ue4ss-log.sh` → `snapshots.log` (#1 outdoor, #2 indoor).

<details>
<summary>Outdoor snapshot #1 (primary lines)</summary>

```
bDetectedIsIndoor = false | DetectionConfidence = 1.0000 | IsUnderRoof = false
bDetectedIsOutdoor = true | DetectionScore = -4.0579
```

</details>

<details>
<summary>Indoor snapshot #2 (primary lines)</summary>

```
bDetectedIsIndoor = false | DetectionConfidence = 0.0000 | IsUnderRoof = true
bDetectedIsOutdoor = true | DetectionScore = -0.0072
```

</details>

## Slice 2a — Occlusion Diagnostic (reference protocol)

**Goal:** Determine whether UDS Player Occlusion is **alive** or **dead** in G1R.

**Protocol:** Same session — F8 **outdoor**, then F8 **indoor** (New Camp house or equivalent). Sync with `./tools/sync-from-ue4ss-log.sh`.

**Verdict criteria:**

| Observation | Verdict |
|-------------|---------|
| `Running = false` indoors | UDS occlusion **inactive** → pivot Inside Detection to G1R native signal |
| `Running = true`, any float/array differs outdoor vs indoor | UDS occlusion **alive** → keep as gate candidate |
| `Running = true`, all fields identical | UDS occlusion **non-functional** → pivot |

**Pivot plan:** G1R native interior signal (discovery); ship fallback = F7 manual toggle.

**Lever:** **`SetSettings` + G1R skylight multipliers** — **ACCEPTED** (Slice 2d v3.1). ~~Time of Day~~ rejected (Slice 2c).

---

## Identified (Slice 1)

| Item | Result |
|------|--------|
| UDS class | `Ultra_Dynamic_Sky_C` |
| UDS actor | `...MainMap:PersistentLevel.Ultra_Dynamic_Sky_C_UAID_18C04DDD879FCE6B01_2138010464` |
| Time of Day property | `Time of Day` (float 0–2400) |
| Player Occlusion | **`Total Occlusion`** via `Weather_BP` → `Player Occlusion` — path reads; **runtime flat (0) pending Slice 2a** |
| Provisional lever | ~~`Time of Day`~~ → **`SetSettings` + multipliers** (Slice 2d accepted) |

## Readable float comparison

| Property | Pose 1 outdoor day | Pose 2 indoor day | Pose 3 indoor night |
|----------|-------------------|-------------------|---------------------|
| Time of Day | 660.7 (~11:00) | 676.1 (~11:16) | **2290.6 (~22:55)** |
| Sky Light Intensity | 1.0 | 1.0 | 1.0 |
| Sun Light Intensity | 0.9 | 0.9 | 0.9 |
| Moon Light Intensity | 0.04 | 0.04 | 0.04 |
| Overall Intensity | 1.0 | 1.0 | 1.0 |
| Apply Interior Adjustments | false | false | false |

**Pose 2 → 3 (lever selection pair):** only **Time of Day** changed (676 → 2291).

**Pose 1 → 2:** TOD drift from travel (~16 min game time); no skylight/sun/moon delta.

## Lever selection

**Chosen lever (provisional):** `Time of Day`

| Property | Pose 2 | Pose 3 | Notes |
|----------|--------|--------|-------|
| Time of Day | 676.1 | 2290.6 | Only readable delta; night reference ~23:00 not ~02:00 but valid night look |
| Sky Light Intensity | 1.0 | 1.0 | No top-level delta |

**Blend target at full occlusion:** ~2290 (pose 3) or config `TARGET_TOD` (2300).

**Risks for Slice 2:**
- G1R may resync TOD from Game Clock every frame — needs in-game test
- Without occlusion float, cannot gate blend by “how indoor” — **use Weather → Player Occlusion → Total Occlusion** (see object dump parse below)

## Object dump parse (UE4SS_ObjectDump.txt)

**Why F8 showed UObject for every occlusion name on sky:** those names are not float fields on `Ultra_Dynamic_Sky_C`. Live occlusion lives on a separate component owned by the weather actor.

### Actor graph (MainMap)

```
Ultra_Dynamic_Sky_C          (sky lighting, TOD)
  └─ Weather_BP  ──────────► Ultra_Dynamic_Weather_C
                                 └─ Player Occlusion  ──► UDS_PlayerOcclusion_C
                                                              └─ Total Occlusion  (double, 0–1)
```

Level instances:

| Actor | Path |
|-------|------|
| Sky | `...PersistentLevel.Ultra_Dynamic_Sky_C_UAID_18C04DDD879FCE6B01_2138010464` |
| Weather | `...PersistentLevel.Ultra_Dynamic_Weather_C_UAID_18C04DDD879FD16B01_1709997616` |
| Occlusion | `...Ultra_Dynamic_Weather_C_....Player Occlusion` → `UDS_PlayerOcclusion_C` |

### Read path for Slice 2

1. Find `Ultra_Dynamic_Sky_C` (existing mod logic).
2. Read `Weather_BP` (`ObjectProperty`, offset `0xB80`) → `Ultra_Dynamic_Weather_C`.
3. Read `Player Occlusion` (`ObjectProperty`, offset `0x3A0`) → `UDS_PlayerOcclusion_C`.
4. Read **`Total Occlusion`** (`DoubleProperty`, offset `0x238`) — primary 0–1 indoor signal.

Lua property names (exact spacing):

- `"Weather_BP"` or find weather actor separately
- `"Player Occlusion"` (space, on weather actor)
- `"Total Occlusion"` (on occlusion component)

### UDS_PlayerOcclusion_C — useful fields

| Property | Type | Offset | Role |
|----------|------|--------|------|
| **Total Occlusion** | Double | 0x238 | **Primary lever** — blended 0–1 result |
| Inverted Global Occlusion | Double | 0x120 | Alternate / inverted signal |
| Full Occluded Percent | Double | 0x128 | Trace hit fraction (fully occluded) |
| Not Occluded Percent | Double | 0x130 | Trace hit fraction (open sky) |
| Current Occlusion Profile | Array[Double] | 0xF0 | Per-category profile (interp’d) |
| Target Occlusion Profile | Array[Double] | 0xD8 | Target profile |
| Occlusion Update Period | Double | 0xE8 | Poll rate (config) |
| Running | Bool | 0x119 | Component active |

### Ultra_Dynamic_Sky_C — occlusion-related (config only, not live value)

| Property | Type | Notes |
|----------|------|-------|
| Apply Interior Adjustments | Bool | false in all 3 poses |
| Occlusion Sampling Mode | Byte | Trace mode config |
| Interior Occlusion Update Period | Double | Sky-side update rate |
| Fraction of Trace Hits for No/Full Occlusion | Double | Thresholds |
| Sky Light Intensity Multiplier in Interiors | Double | Applied when occluded |

No `Player Occlusion` float or object on sky class itself.

### Time of Day (confirmed)

| Property | Type | Offset | F8 name |
|----------|------|--------|---------|
| Time Of Day | Double | 0x478 | `Time of Day` (works in F8) |
| Internal Time of Day | Double | 0xB78 | |
| Replicated Time of Day | Double | 0xF30 | |

G1R wraps sky in `GothicUltraDynamicSky` (`/Script/G1R.GothicUltraDynamicSky`) with settings struct `UltraDynamicSkySettings` — separate from UDS occlusion.

### Verification still needed

F8 snapshots were taken **before** wiring the Weather → Occlusion path. Re-test:

- **Pose 1 outdoor:** `Total Occlusion` ≈ 0
- **Pose 2 indoor day:** `Total Occlusion` high (e.g. 0.7–1.0)
- **Pose 3 indoor night:** same occlusion as pose 2; TOD differs

Extract script: `./tools/extract-occlusion-from-dump.sh` → `occlusion-dump-extract.txt`

---

## Occlusion follow-up (superseded by dump parse above)

F8 struct/UObject hits on sky actor were **false positives** — wrong object, wrong property names. Use weather component path instead.

---

## Pose 1 — outdoor daytime baseline

**Resolved identifiers:**

| Field | Value | Property name |
|-------|-------|---------------|
| UDS class | `Ultra_Dynamic_Sky_C` | actor class |
| Player Occlusion | UNRESOLVED | struct refs |
| Time of Day | 660.7 | `Time of Day` |

<details>
<summary>Full snapshot #1</summary>

```
========== G1R_IndoorNight DISCOVERY SNAPSHOT #1 ==========
  UDS class  = Ultra_Dynamic_Sky_C
  Player Occlusion = UNRESOLVED
  Time of Day      = 660.7  (via 'Time of Day')
  Sky Light Intensity = 1.0000
  Sun Light Intensity = 0.9000
  Moon Light Intensity = 0.0400
  Apply Interior Adjustments = false
================================================================
```

</details>

---

## Pose 2 — deep indoor daytime

**Resolved identifiers:**

| Field | Value | Property name |
|-------|-------|---------------|
| UDS class | `Ultra_Dynamic_Sky_C` | actor class |
| Player Occlusion | UNRESOLVED | struct refs |
| Time of Day | 676.1 | `Time of Day` |

<details>
<summary>Full snapshot #2</summary>

```
========== G1R_IndoorNight DISCOVERY SNAPSHOT #2 ==========
  UDS class  = Ultra_Dynamic_Sky_C
  Player Occlusion = UNRESOLVED
  Time of Day      = 676.1  (via 'Time of Day')
  Sky Light Intensity = 1.0000
  Sun Light Intensity = 0.9000
  Moon Light Intensity = 0.0400
  Apply Interior Adjustments = false
================================================================
```

</details>

---

## Pose 3 — same indoor spot at night

**Resolved identifiers:**

| Field | Value | Property name |
|-------|-------|---------------|
| UDS class | `Ultra_Dynamic_Sky_C` | actor class |
| Player Occlusion | UNRESOLVED | struct refs |
| Time of Day | 2290.6 | `Time of Day` |

<details>
<summary>Full snapshot #3</summary>

```
========== G1R_IndoorNight DISCOVERY SNAPSHOT #3 ==========
  UDS class  = Ultra_Dynamic_Sky_C
  Player Occlusion = UNRESOLVED
  Time of Day      = 2290.6  (via 'Time of Day')
  Sky Light Intensity = 1.0000
  Sun Light Intensity = 0.9000
  Moon Light Intensity = 0.0400
  Apply Interior Adjustments = false
================================================================
```

</details>

---

## After discovery

1. ~~**Slice 2a:**~~ Occlusion Diagnostic — UDS dead
2. ~~**Slice 2b:**~~ G1R Inside Detection — **`IsUnderRoof` accepted** (F8 probe + HITL)
3. ~~**Slice 2c:**~~ TOD rejected
4. ~~**Slice 2d:**~~ G1R lever v3.1 accepted
5. **Slice 3:** Auto apply accepted profile when Inside; `DISCOVERY_MODE = false`
