# G1R_IndoorNight

UE4SS Lua mod for **Gothic 1 Remake**. Dims Ultra Dynamic Sky when the player is **under roof** (`IsUnderRoof` gate). Game clock is untouched. **Lever policy** (what we may write vs user-owned exposure): [CONTEXT.md](./CONTEXT.md) → **Lever Boundaries**.

See [CONTEXT.md](./CONTEXT.md) for domain terms and design decisions.

## Requirements

- Gothic 1 Remake (Steam/Epic)
- [RE-UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases) (experimental build used by G1R modding community)

## Install

**Option A — symlink (dev):**

```bash
./install.sh
```

Then enable in `ue4ss/Mods/mods.txt`:

```
G1R_IndoorNight : 1
```

**Option B — manual:** copy this folder to:

```
<Gothic 1 Remake>/G1R/Binaries/Win64/ue4ss/Mods/G1R_IndoorNight/
```

Layout must be:

```
G1R_IndoorNight/Scripts/main.lua
```

## Usage

- **F7** — toggle mod on/off mid-session (instant day restore when off)
- On by default at load; polls `IsUnderRoof` every `PASS_MS` and applies v3.1 indoor dimming or day baseline

### Discovery mode (dev only)

Set `DISCOVERY_MODE = true` to re-enable read-only F8 snapshots and F10/F11/F12 spikes. See [docs/DISCOVERY.md](./docs/DISCOVERY.md).

## Config

Edit `Scripts/main.lua` — CONFIG block at top. No rebuild; save and relaunch (or UE4SS hot-reload if enabled).

### Engine profiles (CrossOver / max-perf)

Optional `Engine.ini` + `GameUserSettings.ini` profile pack with switcher: [Config/ProfilePack/](Config/ProfilePack/). Profiles: `maxperf` (default fallback), `streaming-veryhigh` (M1 Max+ opt-in), `streaming-veryhigh-extshadows` (extended CSM + mod `SHADOWS_ON_PROFILE` for caves), `streaming-crossover` (CrossOver A/B), `streaming-only` (native GPU quality test — not for CrossOver). See [Config/ProfilePack/TEST.md](Config/ProfilePack/TEST.md).

| Setting | Default | Meaning |
|---------|---------|---------|
| `ENABLED` | `true` | Start with mod active |
| `TOGGLE_KEY` | `Key.F7` | In-game toggle |
| `TARGET_TOD` | `2300` | UDS time-of-day at full occlusion (0–2400) |
| `OCCLUSION_START` | `0.5` | Below this, no blend |
| `OCCLUSION_FULL` | `1.0` | Full night-level sky contribution at max occlusion |
| `PASS_MS` | `100` | Poll interval |
| `DEBUG` | `false` | Log occlusion / TOD to UE4SS console |
| `DISCOVERY_MODE` | `false` | Read-only instrumentation; disables sky writes when `true` |
| `SNAPSHOT_KEY` | `Key.F8` | Print filtered UDS candidate snapshot |
| `TOD_SPIKE_ENABLED` | `true` | F10 one-shot TOD write test (Slice 2c; discovery mode only) |
| `TOD_SPIKE_KEY` | `Key.F10` | Key for TOD spike (avoid F9 = G1R quickload) |
| `G1R_LEVER_SPIKE_ENABLED` | `true` | F11 G1R skylight / SetSettings spike (Slice 2d) |
| `G1R_LEVER_SPIKE_KEY` | `Key.F11` | Key for G1R lever spike |
| `G1R_SKY_MULTIPLIER_TARGET` | `0.0` | F11 Dynamic/Target Sky Light Multiplier |
| `G1R_SETTINGS_NIGHT_PROFILE` | see `main.lua` | F11 `SetSettings` bundle (SkyLightIntensity, OverallIntensity, …) |
| `G1R_DIRECT_NIGHT_WRITES` | see `main.lua` | F11 direct UDS fields (sun, exposure, interior multipliers) |

## Status

Slice 3 shipped — **v3.3.12 (HITL accepted)** auto indoor dimming on **`IsUnderRoof`**; day/night split profiles; F7 toggle. See [CONTEXT.md](./CONTEXT.md) (lever rules) and [DISCOVERY.md](./docs/DISCOVERY.md) (accepted targets).
