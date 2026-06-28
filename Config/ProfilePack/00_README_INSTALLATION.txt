G1R — CrossOver / macOS Config: Profile Pack (profiles + switcher)
Version: 1.3.0

WHAT THIS PACK CONTAINS

Engine/user-settings profiles plus a switch script:

  maxperf             — no grass/shadows/Lumen + CrossOver UET subset (v13); default fallback
  default-lighting    — perf tweaks; Lumen + shadows stay on; darker caves
  streaming-only      — Epic Lumen/shadows/textures ON; Engine streaming only (NOT for CrossOver)
  streaming-crossover — streaming Engine + low maxperf settings (CrossOver A/B vs maxperf)
  streaming-veryhigh  — streaming + shadows on, GI off, high textures (M1 Max+ opt-in)
  streaming-veryhigh-extshadows — veryhigh + extended CSM; pair with mod SHADOWS_ON_PROFILE

Shared: Scalability.ini (6144 MB texture pool, 12 GB VRAM tier)


CONFIG LOCATION

Windows / Steam:
  %LOCALAPPDATA%\G1R\Saved\Config\Windows\

macOS / CrossOver:
  ~/Library/Application Support/CrossOver/Bottles/Steam/drive_c/users/crossover/AppData/Local/G1R/Saved/Config/Windows/

Linux / Proton example:
  <SteamLibrary>/steamapps/compatdata/1297900/pfx/drive_c/users/steamuser/AppData/Local/G1R/Saved/Config/Windows/


INSTALLATION

1. Close Gothic 1 Remake completely.
2. Back up your existing config files in the folder above.
3. Copy everything from:
     Local/G1R/Saved/Config/Windows/
   into your config folder. You should have:
     Engine.ini.maxperf
     Engine.ini.default-lighting
     Engine.ini.streaming-only
     Engine.ini.streaming-crossover
     Engine.ini.streaming-veryhigh
     GameUserSettings.ini.maxperf
     GameUserSettings.ini.default-lighting
     GameUserSettings.ini.streaming-only
     GameUserSettings.ini.streaming-crossover
     GameUserSettings.ini.streaming-veryhigh
     Scalability.ini
     switch-g1r-profile.sh
4. Activate a profile (macOS / Linux / CrossOver):
     cd "<config folder>"
     chmod +x switch-g1r-profile.sh
     ./switch-g1r-profile.sh backup
     ./switch-g1r-profile.sh streaming-veryhigh
     ./switch-g1r-profile.sh streaming-crossover
     ./switch-g1r-profile.sh streaming-only
     ./switch-g1r-profile.sh maxperf
     ./switch-g1r-profile.sh default-lighting
     ./switch-g1r-profile.sh list
5. The script auto-backs up before each switch (use --no-backup to skip).
   Engine.ini is set read-only after switching.


MANUAL SWITCH (Windows, no script)

  copy /Y Engine.ini.streaming-veryhigh Engine.ini
  copy /Y GameUserSettings.ini.streaming-veryhigh GameUserSettings.ini
  attrib +R Engine.ini


STREAMING-VERYHIGH PROFILE

Based on community feedback (M1 Max, CrossOver 27, GPT 4 Beta 1): texture streaming +
async loading only — no Engine.ini Lumen/shadow kills — improves FPS without quality loss.

  ~30 fps stable: streaming-veryhigh as shipped (58 fps cap in ini; GPT can lock lower)
  ~60 fps: enable DLSS Quality + frame gen in-game; optionally raise/remove t.MaxFPS cap

If FPS drops below playable, revert: ./switch-g1r-profile.sh maxperf


STREAMING-ONLY PROFILE

**CrossOver warning:** `streaming-only` enables Epic Lumen + shadows. Tested 2026-06-16: under 20 FPS on CrossOver. Do not use for daily play on Mac.

For CrossOver quality vs maxperf, try `streaming-veryhigh` (shadows on, GI off) or `streaming-crossover` for A/B testing. See TEST.md.


NOTES

- Scalability.ini is shared by all profiles; copy it once.
- Backups land in backups/YYYYMMDD-HHMMSS/ next to the script.
- Indoor Night UE4SS mod (F7) still works; higher-quality profiles may rely on it more indoors than maxperf.
