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

- **F7** — cycle **Mod Control Mode**: **Auto** → **Always On** → **Always Off** → **Auto**
  - **Auto** — gate-driven **Indoor Sky Dimming** (`IsUnderRoof`)
  - **Always On** — forced indoor profile everywhere (ignores gate)
  - **Always Off** — instant vanilla sky restore (no mod writes)
- Default **Auto** at load (`CONTROL_MODE` in `config.lua`); F7 changes are session-only

### Discovery mode (dev only)

Set `DISCOVERY_MODE = true` for extra DEBUG console logging. No F8–F12 keybinds (F7 only). See [docs/DISCOVERY.md](./docs/DISCOVERY.md).

## Config

Edit `Scripts/config.lua` — reload UE4SS / restart game to apply.

### Engine profiles (CrossOver / max-perf)

Optional `Engine.ini` + `GameUserSettings.ini` profile pack with switcher: [Config/ProfilePack/](Config/ProfilePack/). Profiles: `maxperf` (default fallback, v13 includes CrossOver UET subset), `streaming-veryhigh` (M1 Max+ opt-in), `streaming-veryhigh-extshadows` (extended CSM + mod `SHADOWS_ON_PROFILE` for caves), `streaming-crossover` (CrossOver A/B), `streaming-only` (native GPU quality test — not for CrossOver).

| Setting | Default | Meaning |
|---------|---------|---------|
| `CONTROL_MODE` | `"auto"` | Boot mode: `"auto"`, `"always_on"`, `"always_off"` |
| `ENABLED` | `true` | Legacy; maps to `auto` / `always_off` if `CONTROL_MODE` unset |
| `TOGGLE_KEY` | `Key.F7` | In-game mode cycle (F7 only shipped) |

## Status

Slice 7 — **v3.7.0-modcontrol** three-state **Mod Control Mode** (F7 cycle); F8–F12 keybinds retired. See [CONTEXT.md](./CONTEXT.md) and [docs/adr/0001-mod-control-mode.md](./docs/adr/0001-mod-control-mode.md).
