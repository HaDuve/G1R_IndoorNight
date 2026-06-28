# Handoff — G1R_IndoorNight

**Date:** 2026-06-14  
**Repo:** `/Users/hiono/Library/Application Support/CrossOver/G1R_IndoorNight/`  
**Status:** Design complete; repo scaffolded; UDS runtime hooks unverified

---

## Goal

Build a UE4SS Lua mod for **Gothic 1 Remake** that makes **Sun / Sky Lighting** (Ultra Dynamic Sky) behave like **moonlit night** whenever the player is indoors — without changing the **Game Clock**.

Indoors = buildings, caves, dungeons, mines — detected via UDS **Player Occlusion**, not custom volume logic.

---

## Resolved design (grill-with-docs session)

| Decision | Choice |
|----------|--------|
| Game clock | **Never modified** |
| Sun vs clock | Override **UDS sky/sun only** — clock stays at true in-world time |
| Blend mode | **Occlusion-blended (B)** — not a global sky flip |
| Target look | **Moonlit night (B)** — UDS TOD ~22:00–04:00; default config `2300` |
| Occlusion threshold | **Starts at ~0.5**; below = vanilla sky |
| Torches / fires | **Vanilla brightness** |
| Extra Interior Exposure | **Respect player setting (B)** — mod does not counteract; user balances sliders |
| Toggle | **F7** — cycle **Mod Control Mode** (Auto → Always On → Always Off); default **Auto** |
| Config | **Full block** at top of `Scripts/main.lua` |
| Mod name | `G1R_IndoorNight` |

Domain glossary: see [`CONTEXT.md`](./CONTEXT.md) (do not duplicate here).

---

## Repo layout

```
G1R_IndoorNight/
├── CONTEXT.md          # Glossary + design terms
├── HANDOFF.md          # This file
├── README.md           # Install, config table, status
├── install.sh          # Symlink into CrossOver UE4SS Mods folder
├── .gitignore
└── Scripts/
    └── main.lua        # CONFIG + stub implementation
```

- **Git:** `git init` done; **no commits yet**
- **Game install path (CrossOver bottle):**  
  `.../Gothic 1 Remake/G1R/Binaries/Win64/ue4ss/Mods/`
- **Existing UE4SS setup:** `FocusNearbyPickups` enabled; shared `G1R.lua` at `ue4ss/Mods/shared/G1R/`
- **G1R uses Ultra Dynamic Sky** (confirmed in game credits)

---

## What's implemented (stub)

`Scripts/main.lua` includes:

- CONFIG block (`ENABLED`, `TOGGLE_KEY`, `TARGET_TOD`, `OCCLUSION_START`, `OCCLUSION_FULL`, `DEBUG`)
- F7 toggle with instant restore attempt via cached `trueTodCache`
- `LoopAsync` poll every 1 s (fixed `PASS_MS` in `main.lua`)
- UDS discovery via `FindFirstOf` / `FindAllOf` with candidate class names
- Occlusion / TOD read/write with candidate property names (unverified)
- Blend math: linear lerp from true TOD → `TARGET_TOD` between `OCCLUSION_START` and `OCCLUSION_FULL`

**Not done:** in-game verification of UDS class, property names, and whether G1R re-syncs TOD every frame (may fight the mod).

---

## Known implementation risks

1. **Property names unknown** — candidates in `main.lua`: occlusion (`Player Occlusion`, `PlayerOcclusion`, `Occlusion`); TOD (`Time of Day`, `TimeOfDay`). Must dump UDS actor in-game (UE4SS console / `dump_object.lua` / `ActorDumperMod`).
2. **True TOD capture** — current stub reads TOD *after* game may have already applied values; need to capture G1R's authoritative outdoor TOD separately (hook, or read before blend, or store when occlusion = 0).
3. **Frame fight** — if G1R sets UDS TOD from game clock every tick, mod must apply blend *after* game update or override Interior Adjustments instead of raw TOD.
4. **ExtraInteriorExposure** — stacks with mod darkening; by design the player balances manually.
5. **`install.sh` not run yet** — mod not symlinked into game `Mods/`; `mods.txt` entry not added.

---

## Next steps (recommended order)

1. Run `./install.sh`; add `G1R_IndoorNight : 1` to `ue4ss/Mods/mods.txt`
2. Launch game; enable `DEBUG = true` in `main.lua`
3. Find UDS actor + occlusion property (console / object dump while standing outdoors vs deep in mine)
4. Fix true-TOD tracking so blend doesn't drift
5. Tune `TARGET_TOD`, `OCCLUSION_START` in Old Mine / hut / cave mouth
6. Initial git commit once stub works or discovery notes are captured
7. Optional: add `docs/adr/` if a hard-to-reverse hook decision is made (e.g. hook vs poll)

---

## Install quick reference

```bash
cd "/Users/hiono/Library/Application Support/CrossOver/G1R_IndoorNight"
./install.sh
# Add to ue4ss/Mods/mods.txt:
# G1R_IndoorNight : 1
```

Config lives in `Scripts/main.lua` — no rebuild; relaunch or UE4SS hot-reload.

---

## Suggested skills (next agent)

| Skill | When |
|-------|------|
| **`diagnose`** | UDS hooks not working; blend fights game sync; F7 restore wrong |
| **`grill-with-docs`** | New design branches (e.g. hook vs poll, ADR-worthy trade-offs) |
| **`prototype`** | Quick throwaway script to dump UDS fields before committing to main.lua structure |
| **`review-bugbot`** | Before first commit / PR if scope grows |

---

## References

- [`CONTEXT.md`](./CONTEXT.md) — glossary
- [`README.md`](./README.md) — install + config table
- [`Scripts/main.lua`](./Scripts/main.lua) — current stub
- UDS docs (Interior Adjustments / Player Occlusion): https://www.ultradynamicsky.com/Documentation/V9/9-4
- FocusNearbyPickups patterns: `.../ue4ss/Mods/FocusNearbyPickups/Scripts/main.lua` (LoopAsync, ExecuteInGameThread, RegisterKeyBind)

---

## Open questions

- Exact UDS Blueprint class name in G1R shipping build
- Exact occlusion float property name on that actor
- Does G1R drive UDS TOD from game clock every frame?
- Is Interior Adjustments override cleaner than TOD lerp for this mod?
