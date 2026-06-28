---
name: nexus-mod-package
description: Package G1R_IndoorNight for Nexus/download release — stage Lua mod + MaxPerf config, zip, diff vs last pack, write player changelog. Use when the user asks to pack, upload, release, or update the Nexus mod zip, mod package, or ModUploads folder.
---

# Nexus mod package

## Quick start

1. Read [modupload.md](../../../modupload.md) for current shipped versions and full checklist.
2. Run the pack script (default = full Nexus pack):

```bash
.cursor/skills/nexus-mod-package/scripts/pack-nexus.sh
```

3. Update `~/Downloads/ModUploads/G1R_IndoorNight_NexusPack/00_README_INSTALLATION.txt` — version header, `build=` verify string, Part A + Part B.
4. Re-zip if README changed after the script ran.
5. Diff staged files vs repo; write human changelog (mod block + config block).
6. Run pre-upload checklist (below).

## Pack types

| Type | Flag | Default zip |
|------|------|-------------|
| Full (Lua + MaxPerf config) | `--full` | `G1R_IndoorNight_NexusPack.zip` + mirror `IndoorNight Performance.zip` |
| Scripts only | `--scripts-only` | `G1R_IndoorNight.zip` |
| Config only | `--config-only` | `G1R_IndoorNight_MaxPerf_v<N>.zip` |

**Default release = full pack.** Players expect Lua mod and MaxPerf config together unless the user says otherwise.

## Include / exclude

**Lua (exactly four files):** `main.lua`, `config.lua`, `indoornight_brightness.lua`, `indoornight_reload.lua`

**Never in upload zips:** `check-night-feedback.sh`, `tools/`, `docs/`, `install.sh`, profile variants (`Engine.ini.streaming-*`, `switch-g1r-profile.sh`), repo markdown, logs.

**Config sources (repo → pack):**

| Pack | Repo |
|------|------|
| `Config_MaxPerf/.../Engine.ini` | `Config/ProfilePack/.../Engine.ini.maxperf` |
| `Config_MaxPerf/.../GameUserSettings.ini` | `.../GameUserSettings.ini.maxperf` |
| `Config_MaxPerf/.../Scalability.ini` | `.../Scalability.ini` |

Use `.maxperf` sources — not live CrossOver `Engine.ini`.

## Versions in sync

Before upload, align:

- `Scripts/main.lua` → `MOD_BUILD`
- Staging `00_README_INSTALLATION.txt` header + verify line
- `Engine.ini.maxperf` header (e.g. v13)
- Nexus changelog copy-paste
- `modupload.md` → "Current shipped" section

## Pre-upload checklist

- [ ] `MOD_BUILD` matches README and changelog
- [ ] Four Lua files only under `G1R_IndoorNight/Scripts/`
- [ ] Config from `.maxperf` sources
- [ ] Full pack zip ≈ 17 file entries (dirs + 4 lua + 3 ini + README)
- [ ] Changelog is plain language, not a raw diff

## Changelog template

```markdown
**vX.Y.Z + MaxPerf config vN**

**Indoor Sky Dimming mod** — [one line per meaningful change]

**MaxPerf config** — [one line per meaningful change]

Install config + mod folder; enable in mods.txt. Log should show `build=vX.Y.Z-…`.
```

Compare vs last pack before writing:

```bash
REPO="$(git rev-parse --show-toplevel)"
PACK=~/Downloads/ModUploads/G1R_IndoorNight_NexusPack
diff -u "$PACK/Config_MaxPerf/Local/G1R/Saved/Config/Windows/Engine.ini" \
        "$REPO/Config/ProfilePack/Local/G1R/Saved/Config/Windows/Engine.ini.maxperf"
diff -q "$PACK/G1R_IndoorNight/Scripts/"*.lua "$REPO/Scripts/"*.lua
```

## Staging paths (local, not in git)

- `~/Downloads/ModUploads/G1R_IndoorNight_NexusPack/` — unpacked full release
- `~/Downloads/ModUploads/*.zip` — upload artifacts

Do not commit zips or `ModUploads/`.

## README in pack

Player-facing `00_README_INSTALLATION.txt` lives in staging only. Sections: contents, Part A config, Part B UE4SS mod, verify (`build=…`), troubleshooting. Copy structure from existing staging file when updating.
