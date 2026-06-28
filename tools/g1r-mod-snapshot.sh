#!/bin/bash
# Backup, disable all G1R mods for patch testing, and restore from snapshot.
#
# Usage:
#   g1r-mod-snapshot.sh disable [--include-assets] [--label NAME]
#   g1r-mod-snapshot.sh restore [--latest | SNAPSHOT_DIR]
#   g1r-mod-snapshot.sh restore-assets [--latest | SNAPSHOT_DIR]
#   g1r-mod-snapshot.sh status
#   g1r-mod-snapshot.sh list
#
# Snapshots live in:
#   ~/Library/Application Support/CrossOver/G1R_ModSnapshots/<timestamp>[-label]/
#   ~/Library/Application Support/CrossOver/G1R_ModSnapshots/latest -> active snapshot

set -euo pipefail

CROSSOVER_ROOT="${G1R_CROSSOVER_ROOT:-$HOME/Library/Application Support/CrossOver}"
GAME_ROOT="${G1R_GAME_ROOT:-$CROSSOVER_ROOT/Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/Gothic 1 Remake}"
UE4SS_MODS="${G1R_UE4SS_MODS:-$GAME_ROOT/G1R/Binaries/Win64/ue4ss/Mods}"
CONFIG_DIR="${G1R_CONFIG_DIR:-$CROSSOVER_ROOT/Bottles/Steam/drive_c/users/crossover/AppData/Local/G1R/Saved/Config/Windows}"
VOICEOVER_DIR="$GAME_ROOT/G1R/Story/VoiceOver"
MOVIES_DIR="$GAME_ROOT/G1R/Content/Movies"
SNAPSHOT_ROOT="$CROSSOVER_ROOT/G1R_ModSnapshots"
LATEST_LINK="$SNAPSHOT_ROOT/latest"

STUB_BK2_MAX_BYTES=4096

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  disable [--include-assets] [--label NAME]
      Snapshot current mod state, then disable for vanilla patch testing:
        - mods.txt: all enabled mods -> 0
        - engine: remove active Engine.ini, GameUserSettings.ini, Scalability.ini
        - assets (optional): remove voice-over zips and stub intro .bk2 overrides

  restore [--latest | SNAPSHOT_DIR]
      Restore mods.txt, engine configs, and optional assets from a snapshot.

  restore-assets [--latest | SNAPSHOT_DIR]
      Restore voice-over zips and movie .bk2 files only (leave mods/config unchanged).

  status
      Show whether a disable snapshot exists and what is currently active.

  list
      List available snapshots.

Options:
  --include-assets   Also back up / disable voice-over zips and intro-skip movie stubs.
  --label NAME       Append label to snapshot folder name (e.g. patch-test).
  --latest           Restore from \$SNAPSHOT_ROOT/latest (default for restore).

Close Gothic 1 Remake before disable or restore.
EOF
  exit 1
}

require_game_paths() {
  local missing=0
  for path in "$UE4SS_MODS" "$CONFIG_DIR"; do
    if [[ ! -d "$path" ]]; then
      echo "Missing: $path"
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]] || exit 1
}

snapshot_name() {
  local label="${1:-}"
  local base
  base="$(date +%Y%m%d-%H%M%S)"
  if [[ -n "$label" ]]; then
    echo "${base}-${label}"
  else
    echo "$base"
  fi
}

detect_active_profile() {
  if [[ ! -f "$CONFIG_DIR/Engine.ini" ]]; then
    echo "none"
    return
  fi
  local header
  header=$(head -n 5 "$CONFIG_DIR/Engine.ini" 2>/dev/null || true)
  case "$header" in
    *"STREAMING VERY HIGH EXT SHADOWS"*) echo "streaming-veryhigh-extshadows" ;;
    *"STREAMING VERY HIGH"*) echo "streaming-veryhigh" ;;
    *"STREAMING CROSSOVER"*) echo "streaming-crossover" ;;
    *"STREAMING ONLY"*) echo "streaming-only" ;;
    *"MAX PERF"*) echo "maxperf" ;;
    *"DEFAULT LIGHTING"*|*"perf-default"*) echo "default-lighting" ;;
    *)
      for p in maxperf default-lighting streaming-only streaming-crossover streaming-veryhigh streaming-veryhigh-extshadows; do
        if [[ -f "$CONFIG_DIR/Engine.ini.$p" ]] && cmp -s "$CONFIG_DIR/Engine.ini" "$CONFIG_DIR/Engine.ini.$p" 2>/dev/null; then
          echo "$p"
          return
        fi
      done
      echo "custom"
      ;;
  esac
}

write_manifest() {
  local snap_dir="$1"
  local include_assets="$2"
  {
    echo "created=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "include_assets=$include_assets"
    echo "active_profile=$(detect_active_profile)"
    echo "game_root=$GAME_ROOT"
    echo "config_dir=$CONFIG_DIR"
    echo "ue4ss_mods=$UE4SS_MODS"
    echo ""
    echo "[enabled_mods_before_disable]"
    grep -E '[[:space:]]*:[[:space:]]*1[[:space:]]*$' "$UE4SS_MODS/mods.txt" || true
  } > "$snap_dir/MANIFEST.txt"
}

backup_config_dir() {
  local dest="$1"
  mkdir -p "$dest"
  local copied=0
  shopt -s nullglob
  for f in \
    Engine.ini GameUserSettings.ini Scalability.ini \
    Engine.ini.* GameUserSettings.ini.* \
    switch-g1r-profile.sh; do
    if [[ -f "$CONFIG_DIR/$f" ]]; then
      cp -p "$CONFIG_DIR/$f" "$dest/$f"
      copied=$((copied + 1))
    fi
  done
  shopt -u nullglob
  if [[ $copied -eq 0 ]]; then
    echo "Warning: no config files copied from $CONFIG_DIR"
  fi
}

backup_assets() {
  local snap_dir="$1"
  local voice_dest="$snap_dir/assets/voiceover"
  local movies_dest="$snap_dir/assets/movies"
  mkdir -p "$voice_dest" "$movies_dest"

  shopt -s nullglob
  for zip in "$VOICEOVER_DIR"/*.zip; do
    [[ "$zip" == *.bak* ]] && continue
    cp -p "$zip" "$voice_dest/"
  done
  for bk2 in "$MOVIES_DIR"/*.bk2; do
    cp -p "$bk2" "$movies_dest/"
  done
  shopt -u nullglob
}

disable_assets() {
  local snap_dir="$1"
  echo ""
  echo "Disabling asset overrides..."

  shopt -s nullglob
  local voice_removed=0
  for zip in "$VOICEOVER_DIR"/*.zip; do
    [[ "$zip" == *.bak* ]] && continue
    rm -f "$zip"
    voice_removed=$((voice_removed + 1))
  done

  local stub_removed=0
  for bk2 in "$MOVIES_DIR"/*.bk2; do
    local size
    size=$(stat -f%z "$bk2" 2>/dev/null || stat -c%s "$bk2")
    if [[ "$size" -le "$STUB_BK2_MAX_BYTES" ]]; then
      rm -f "$bk2"
      stub_removed=$((stub_removed + 1))
    fi
  done
  shopt -u nullglob

  echo "  voice-over zips removed: $voice_removed (game uses pak audio)"
  echo "  stub intro .bk2 removed: $stub_removed (game uses pak movies)"
  if [[ $stub_removed -gt 0 ]]; then
    echo "  If logos still skip, run Steam -> Verify integrity for Gothic 1 Remake."
  fi
  echo "  Asset backup: $snap_dir/assets/"
}

disable_engine_configs() {
  echo ""
  echo "Disabling engine profile overrides..."
  chmod u+w "$CONFIG_DIR/Engine.ini" 2>/dev/null || true
  rm -f "$CONFIG_DIR/Engine.ini" "$CONFIG_DIR/GameUserSettings.ini" "$CONFIG_DIR/Scalability.ini"
  echo "  Removed active Engine.ini, GameUserSettings.ini, Scalability.ini"
  echo "  Game will regenerate vanilla configs on next launch."
  echo "  Profile variants (Engine.ini.maxperf, etc.) left in place but inactive."
}

disable_mods_txt() {
  local snap_dir="$1"
  cp -p "$UE4SS_MODS/mods.txt" "$snap_dir/mods.txt"
  awk '{
    if ($0 ~ /:[[:space:]]*1[[:space:]]*$/) {
      sub(/:[[:space:]]*1[[:space:]]*$/, " : 0")
    }
    print
  }' "$UE4SS_MODS/mods.txt" > "$UE4SS_MODS/mods.txt.tmp"
  mv "$UE4SS_MODS/mods.txt.tmp" "$UE4SS_MODS/mods.txt"
  echo ""
  echo "Disabled all UE4SS mods in mods.txt (was backed up to snapshot)."
}

cmd_disable() {
  local include_assets=false
  local label=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --include-assets) include_assets=true ;;
      --label) shift; label="${1:-}"; [[ -n "$label" ]] || usage ;;
      *) usage ;;
    esac
    shift
  done

  require_game_paths

  local snap_dir="$SNAPSHOT_ROOT/$(snapshot_name "$label")"
  mkdir -p "$snap_dir/config"
  write_manifest "$snap_dir" "$include_assets"
  backup_config_dir "$snap_dir/config"
  disable_mods_txt "$snap_dir"
  disable_engine_configs

  if [[ "$include_assets" == true ]]; then
    if [[ ! -d "$VOICEOVER_DIR" || ! -d "$MOVIES_DIR" ]]; then
      echo "Warning: asset paths missing; skipping asset backup/disable."
    else
      backup_assets "$snap_dir"
      disable_assets "$snap_dir"
    fi
  fi

  mkdir -p "$SNAPSHOT_ROOT"
  ln -sfn "$snap_dir" "$LATEST_LINK"

  echo ""
  echo "Snapshot saved: $snap_dir"
  echo "Latest link:    $LATEST_LINK"
  echo ""
  echo "Patch-test ready. Relaunch Gothic 1 Remake (vanilla configs + no UE4SS mods)."
  echo "Restore with: $(basename "$0") restore --latest"
}

resolve_snapshot_dir() {
  local arg="${1:-}"
  if [[ -z "$arg" || "$arg" == "--latest" ]]; then
    if [[ -L "$LATEST_LINK" || -d "$LATEST_LINK" ]]; then
      echo "$(cd "$LATEST_LINK" && pwd)"
      return
    fi
    echo "No snapshot at $LATEST_LINK" >&2
    exit 1
  fi
  if [[ -d "$arg" ]]; then
    echo "$(cd "$arg" && pwd)"
    return
  fi
  if [[ -d "$SNAPSHOT_ROOT/$arg" ]]; then
    echo "$(cd "$SNAPSHOT_ROOT/$arg" && pwd)"
    return
  fi
  echo "Snapshot not found: $arg" >&2
  exit 1
}

restore_config_dir() {
  local snap_dir="$1"
  local src="$snap_dir/config"
  if [[ ! -d "$src" ]]; then
    echo "Missing config backup in snapshot."
    exit 1
  fi

  echo "Restoring engine configs..."
  chmod u+w "$CONFIG_DIR/Engine.ini" "$CONFIG_DIR/GameUserSettings.ini" "$CONFIG_DIR/Scalability.ini" 2>/dev/null || true
  shopt -s nullglob
  for f in "$src"/*; do
    cp -p "$f" "$CONFIG_DIR/$(basename "$f")"
  done
  shopt -u nullglob

  if [[ -f "$CONFIG_DIR/Engine.ini" ]]; then
    chmod 444 "$CONFIG_DIR/Engine.ini" 2>/dev/null || true
  fi
  echo "  Restored from $src"
  echo "  Active profile (from snapshot): $(grep '^active_profile=' "$snap_dir/MANIFEST.txt" 2>/dev/null | cut -d= -f2- || echo unknown)"
}

restore_assets() {
  local snap_dir="$1"
  local voice_src="$snap_dir/assets/voiceover"
  local movies_src="$snap_dir/assets/movies"
  if [[ ! -d "$voice_src" && ! -d "$movies_src" ]]; then
    echo "No asset backup in snapshot; skipping asset restore."
    return
  fi

  echo ""
  echo "Restoring asset overrides..."
  if [[ -d "$voice_src" ]]; then
    mkdir -p "$VOICEOVER_DIR"
    shopt -s nullglob
    for zip in "$voice_src"/*.zip; do
      cp -p "$zip" "$VOICEOVER_DIR/"
    done
    shopt -u nullglob
    echo "  voice-over zips restored to $VOICEOVER_DIR"
  fi
  if [[ -d "$movies_src" ]]; then
    mkdir -p "$MOVIES_DIR"
    shopt -s nullglob
    for bk2 in "$movies_src"/*.bk2; do
      cp -p "$bk2" "$MOVIES_DIR/"
    done
    shopt -u nullglob
    echo "  movie .bk2 files restored to $MOVIES_DIR"
  fi
}

restore_mods_txt() {
  local snap_dir="$1"
  if [[ ! -f "$snap_dir/mods.txt" ]]; then
    echo "Missing mods.txt in snapshot."
    exit 1
  fi
  cp -p "$snap_dir/mods.txt" "$UE4SS_MODS/mods.txt"
  echo ""
  echo "Restored mods.txt:"
  grep -E '[[:space:]]*:[[:space:]]*1[[:space:]]*$' "$UE4SS_MODS/mods.txt" || echo "  (no mods enabled)"
}

cmd_restore() {
  local snap_arg="--latest"
  if [[ $# -gt 0 ]]; then
    snap_arg="$1"
  fi

  require_game_paths
  local snap_dir
  snap_dir="$(resolve_snapshot_dir "$snap_arg")"

  echo "Restoring from: $snap_dir"
  restore_mods_txt "$snap_dir"
  restore_config_dir "$snap_dir"
  restore_assets "$snap_dir"

  echo ""
  echo "Restore complete. Relaunch Gothic 1 Remake."
  echo "Re-enable IndoorNight symlink if needed: ./install.sh"
}

cmd_restore_assets() {
  local snap_arg="--latest"
  if [[ $# -gt 0 ]]; then
    snap_arg="$1"
  fi

  require_game_paths
  local snap_dir
  snap_dir="$(resolve_snapshot_dir "$snap_arg")"

  echo "Restoring assets from: $snap_dir"
  restore_assets "$snap_dir"
  echo ""
  echo "Asset restore complete. Relaunch Gothic 1 Remake."
}

cmd_status() {
  require_game_paths
  echo "Paths:"
  echo "  UE4SS mods: $UE4SS_MODS"
  echo "  Config:     $CONFIG_DIR"
  echo "  Snapshots:  $SNAPSHOT_ROOT"
  echo ""

  if [[ -L "$LATEST_LINK" || -d "$LATEST_LINK" ]]; then
    echo "Latest snapshot: $(readlink "$LATEST_LINK" 2>/dev/null || echo "$LATEST_LINK")"
    if [[ -f "$LATEST_LINK/MANIFEST.txt" ]]; then
      echo ""
      cat "$LATEST_LINK/MANIFEST.txt"
    fi
  else
    echo "Latest snapshot: none"
  fi

  echo ""
  echo "Enabled UE4SS mods:"
  grep -E '[[:space:]]*:[[:space:]]*1[[:space:]]*$' "$UE4SS_MODS/mods.txt" || echo "  (none)"
  echo ""
  echo "Engine active profile: $(detect_active_profile)"
  echo "Active configs:"
  for f in Engine.ini GameUserSettings.ini Scalability.ini; do
    if [[ -f "$CONFIG_DIR/$f" ]]; then
      echo "  $f: present"
    else
      echo "  $f: missing (vanilla regen on launch)"
    fi
  done

  if [[ -d "$VOICEOVER_DIR" ]]; then
    local zip_count=0
    shopt -s nullglob
    for zip in "$VOICEOVER_DIR"/*.zip; do
      [[ "$zip" == *.bak* ]] && continue
      zip_count=$((zip_count + 1))
    done
    shopt -u nullglob
    echo ""
    echo "Voice-over override zips: $zip_count"
  fi

  if [[ -d "$MOVIES_DIR" ]]; then
    local stub_count=0
    shopt -s nullglob
    for bk2 in "$MOVIES_DIR"/*.bk2; do
      local size
      size=$(stat -f%z "$bk2" 2>/dev/null || stat -c%s "$bk2")
      [[ "$size" -le "$STUB_BK2_MAX_BYTES" ]] && stub_count=$((stub_count + 1))
    done
    shopt -u nullglob
    echo "Intro-skip stub .bk2 files: $stub_count"
  fi
}

cmd_list() {
  if [[ ! -d "$SNAPSHOT_ROOT" ]]; then
    echo "No snapshots yet."
    exit 0
  fi
  echo "Snapshots in $SNAPSHOT_ROOT:"
  local latest_target=""
  if [[ -L "$LATEST_LINK" ]]; then
    latest_target="$(basename "$(readlink "$LATEST_LINK")")"
  fi
  for dir in "$SNAPSHOT_ROOT"/*; do
    [[ -d "$dir" ]] || continue
    [[ "$(basename "$dir")" == "latest" ]] && continue
    local marker=""
    [[ "$(basename "$dir")" == "$latest_target" ]] && marker=" <- latest"
    local assets=""
    [[ -d "$dir/assets" ]] && assets=" [assets]"
    echo "  $(basename "$dir")$assets$marker"
  done
}

main() {
  [[ $# -ge 1 ]] || usage
  case "$1" in
    disable) shift; cmd_disable "$@" ;;
    restore) shift; cmd_restore "$@" ;;
    restore-assets) shift; cmd_restore_assets "$@" ;;
    status) cmd_status ;;
    list) cmd_list ;;
    -h|--help|help) usage ;;
    *) usage ;;
  esac
}

main "$@"
