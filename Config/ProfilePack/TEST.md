# Profile pack — test notes

## Diagnosis: camp stutter + Jun 28 crash (2026-06-28)

**Active config at crash:** `maxperf` Engine.ini, all `sg.*=0`, DLSS upscaling + frame gen, M1 Pro / 16 GB / CrossOver.

**Crash** (`UECC-Windows-262FF563...`, ~1h54m session):

| Field | Value |
|-------|--------|
| Type | Assert — `Abort signal received` |
| OOM | No (`bIsOOM=0`; ~1.2 GB RAM free) |
| Location | **Old Camp** gate fight vs Bloodwyn (combat tags; hundreds of `fP_OC_*` actors) |
| Stack | **GameThread → UE4SS → G1R** (Lua `ExecuteInGameThread` path, not a bare GPU fault) |

**Stutter hypotheses (ranked):**

1. **Thunderstorm + camp density** — Niagara/UDS weather + many NPCs (Engine lane; not fixed by Indoor Night mod).
2. **Ultimate Engine Tweaks wholesale** — ~400 CVARs tuned for native DX12; **DirectStorage, VRS, mass parallel RHI** hurt or noop on D3DMetal. Use curated subset only.
3. **Live Engine.ini drift** — bottle had `ShaderPipelineCache.StartupMode=0` + `LazyLoadShadersWhenPSOCacheIsPresent=1` vs repo `maxperf` (`StartupMode=2`, lazy off). Re-switch profile to reset.
4. **UE4SS mod poll** — 100 ms outdoor polls + 4 s sky-transition writes indoors; v3.6.2 throttles stable-outdoor polls to ~500 ms.

**Shipped (v13):** metaltune tweaks merged into default `maxperf` (FX cap, volumetric fog, WP streaming caps, GC, predictive streaming, rain droplets off).

**A/B checklist:** Old Camp gate / New Camp market / thunderstorm fight — note FPS + hitch count. Test one session with **F7** (mod off) to isolate UE4SS crash risk.

---

## streaming-veryhigh (M1 Max user report, 2026-06)

**Source:** Community feedback — texture streaming + async loading only (no Lumen/shadow kills) improves FPS without visible quality loss on capable Macs.

**Reporter setup:** M1 Max, CrossOver 27 Preview, Game Porting Toolkit 4 Beta 1 (FPS lock). Very High preset, grass off in ini, texture streaming settings → **~30 stable fps**. With **DLSS Quality + frame gen** → **~60 fps**.

**Profile design (grill-me agreed):**

| Layer | Choice |
|-------|--------|
| Engine.ini | streaming + async + `grass.Enable=0` + D3DMetal/PSO + `t.MaxFPS=58`; **no** Lumen/shadow/exposure kills |
| Scalables | Shadows **3**, Textures **3**, View Distance **2**, GI **1** (Lumen off), rest mid-tier |
| GameUserSettings | maxperf-like neutral (gamma 2.4, no color offsets, `FrameRateLimit=58`) |
| Default | **Opt-in** — `maxperf` stays fallback for weaker Macs |

**Switch:** `./switch-g1r-profile.sh streaming-veryhigh`

**DLSS + frame gen (~60 fps):** not a separate profile. In-game: enable DLSS Quality + frame generation; optionally set `t.MaxFPS=0` or `60` in Engine.ini and match `FrameRateLimit` in GameUserSettings.

### Checklist

- [ ] FPS ≥ ~25 on M1 Max class hardware (Swamp Camp / New Camp)?
- [ ] Shadows visible vs maxperf?
- [ ] Stutter same or better than maxperf?
- [ ] Indoor Night mod (F7) — interiors acceptable without Engine exposure crush?

### Record results

| Profile | Location | FPS | Stutter | Notes |
|---------|----------|-----|---------|-------|
| streaming-veryhigh | | | | |
| maxperf (baseline) | | | | |

---

## Cave shadows + ambient (streaming-veryhigh-extshadows, 2026-06)

**Symptoms (HITL):** **A** directional shadows stop short in deep caves; **B** distant cave floor too bright (skylight bleed).

### Engine lane A — FAILED FPS HITL (2026-06-20)

| Variant | Shadow reach | FPS (DLSS+FG) | Verdict |
|---------|--------------|---------------|---------|
| Full CSM (`DistanceScale=2.0`, 4 cascades) | Noticeably better | Too low | Not worth it |
| Lite (`DistanceScale=1.25` only) | Worse than full | Still too low | Abandon |

**Shipped approach (D):** `streaming-veryhigh` + mod `SHADOWS_ON_PROFILE = true`. Accept shorter geometric shadow reach on CrossOver; mod handles ambient/distance darkness (symptom B). Nearby shadows at `sg.ShadowQuality=3` stay on.

`-extshadows` profile retained for reference only — do not use on CrossOver.

### Mod lane B — active

| Symptom | Fix |
|---------|-----|
| **B** bright distance | `SHADOWS_ON_PROFILE = true` in `Scripts/config.lua` — skylight-focused day crush |

**Activate:**

1. `./switch-g1r-profile.sh streaming-veryhigh`
2. `SHADOWS_ON_PROFILE = true` in mod `config.lua`; reload UE4SS / restart game

### Checklist

- [ ] FPS back to ~55–60 with DLSS+FG on `streaming-veryhigh`?
- [ ] Distant cave floor darker indoors (day clock) with mod flag on?
- [ ] Shadow reach acceptable at cave mouth / near range (not deep geometric)?

### Record results

| Setup | Location | FPS | Shadow reach | Distant brightness | Notes |
|-------|----------|-----|--------------|-------------------|-------|
| veryhigh + mod flag | | | | | |

---

## streaming-only on CrossOver: FAILED (2026-06-16)

**Result:** under 20 FPS, heavy stutter.

**Cause:** `streaming-only` turns on Epic Lumen (`sg.GlobalIlluminationQuality=3`), Epic shadows (`3`), high foliage/textures. On CrossOver/D3DMetal that is far heavier than `maxperf`, which disables Lumen/shadows in **both** Engine.ini and GameUserSettings.

The original user report ("streaming blocks only, no quality loss") likely applies to **native Windows + discrete GPU** players already on high settings — not macOS CrossOver.

**Revert:** `./switch-g1r-profile.sh maxperf`

---

## CrossOver A/B test (use this instead)

Compare whether you still need maxperf's **Engine.ini lighting hacks** if streaming tweaks alone + low in-game settings are enough.

| Profile | Engine.ini | GameUserSettings | Use on CrossOver? |
|---------|------------|------------------|-------------------|
| `maxperf` | streaming + Lumen/shadow off + exposure/foliage hacks | low scalables | **daily driver / fallback** |
| `streaming-veryhigh` | streaming + async + grass off; shadows via scalables | high shadows/textures, GI off | **opt-in** (M1 Max+ reference) |
| `streaming-veryhigh-extshadows` | veryhigh + extended CSM shadow reach | same as veryhigh | **opt-in** + mod `SHADOWS_ON_PROFILE` for cave ambient |
| `streaming-crossover` | streaming + async only | your low playable settings | **A/B test** |
| `streaming-only` | streaming + async only | Epic Lumen/shadows/textures | **no** — quality reference only |

### Steps

1. Close game.
2. Baseline: `./switch-g1r-profile.sh maxperf` → launch → note FPS in Swamp Camp / New Camp.
3. Test: `./switch-g1r-profile.sh streaming-crossover` → relaunch → same spot.
4. Revert: `./switch-g1r-profile.sh maxperf`

### Checklist

- [ ] FPS within ~5% of maxperf?
- [ ] Stutter same or better?
- [ ] Indoors brighter (more skylight bleed)? → Indoor Night mod (F7) may matter more without Engine exposure crush.

### Record results

| Profile | Location | FPS | Stutter | Notes |
|---------|----------|-----|---------|-------|
| maxperf | | | | |
| streaming-crossover | | | | |
