# G1R_IndoorNight

UE4SS Lua mod for **Gothic 1 Remake**. Pushes Ultra Dynamic Sky toward **moonlit night** when the player is indoors, using occlusion-blended adjustments. Game clock is untouched.

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

- **F7** — toggle mod on/off mid-session (instant restore when off)
- **F8** — discovery snapshot (when `DISCOVERY_MODE = true`; read-only UDS dump to console)
- **F10** — TOD write spike (Slice 2c; rejected). F9 = G1R quickload.
- **F11** — G1R skylight lever spike (v3 moderate profile)
- **F12** — restore day baseline after F11 spike
- On by default at load

### Discovery mode (Slice 1)

With `DISCOVERY_MODE = true`, the mod performs **zero UDS writes**. Press **F8** at each pose in [docs/DISCOVERY.md](./docs/DISCOVERY.md) and paste console output into that doc for lever selection.

## Config

Edit `Scripts/main.lua` — CONFIG block at top. No rebuild; save and relaunch (or UE4SS hot-reload if enabled).

| Setting | Default | Meaning |
|---------|---------|---------|
| `ENABLED` | `true` | Start with mod active |
| `TOGGLE_KEY` | `Key.F7` | In-game toggle |
| `TARGET_TOD` | `2300` | UDS time-of-day at full occlusion (0–2400) |
| `OCCLUSION_START` | `0.5` | Below this, no blend |
| `OCCLUSION_FULL` | `1.0` | Full night-level sky contribution at max occlusion |
| `PASS_MS` | `100` | Poll interval |
| `DEBUG` | `false` | Log occlusion / TOD to UE4SS console |
| `DISCOVERY_MODE` | `true` | Read-only instrumentation; disables sky writes |
| `SNAPSHOT_KEY` | `Key.F8` | Print filtered UDS candidate snapshot |
| `TOD_SPIKE_ENABLED` | `true` | F10 one-shot TOD write test (Slice 2c; discovery mode only) |
| `TOD_SPIKE_KEY` | `Key.F10` | Key for TOD spike (avoid F9 = G1R quickload) |
| `G1R_LEVER_SPIKE_ENABLED` | `true` | F11 G1R skylight / SetSettings spike (Slice 2d) |
| `G1R_LEVER_SPIKE_KEY` | `Key.F11` | Key for G1R lever spike |
| `G1R_SKY_MULTIPLIER_TARGET` | `0.0` | F11 Dynamic/Target Sky Light Multiplier |
| `G1R_SETTINGS_NIGHT_PROFILE` | see `main.lua` | F11 `SetSettings` bundle (SkyLightIntensity, OverallIntensity, …) |
| `G1R_DIRECT_NIGHT_WRITES` | see `main.lua` | F11 direct UDS fields (sun, exposure, interior multipliers) |

## Status

Slice 2d complete — **G1R lever v3.1 accepted** (F11 spike). Next: Inside Detection (Slice 2b) then auto-apply (Slice 3). See [Discovery Protocol](./docs/DISCOVERY.md).
