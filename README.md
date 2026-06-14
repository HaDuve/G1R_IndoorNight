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
- On by default at load

## Config

Edit `Scripts/main.lua` — CONFIG block at top. No rebuild; save and relaunch (or UE4SS hot-reload if enabled).

| Setting | Default | Meaning |
|---------|---------|---------|
| `ENABLED` | `true` | Start with mod active |
| `TOGGLE_KEY` | `Key.F7` | In-game toggle |
| `TARGET_TOD` | `2300` | UDS time-of-day at full occlusion (0–2400) |
| `OCCLUSION_START` | `0.5` | Below this, no blend |
| `OCCLUSION_FULL` | `1.0` | Full moonlit strength |
| `PASS_MS` | `100` | Poll interval |
| `DEBUG` | `false` | Log occlusion / TOD to UE4SS console |

## Status

Implementation in progress — UDS actor discovery and occlusion read still TODO.
