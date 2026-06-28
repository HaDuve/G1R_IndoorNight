#!/bin/bash
# Stage G1R_IndoorNight Nexus release packs. See modupload.md and .cursor/skills/nexus-mod-package/SKILL.md
set -euo pipefail

MODE="full"
ENGINE_VER=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [--full | --scripts-only | --config-only] [--engine-ver N]

  --full           Lua + MaxPerf config → G1R_IndoorNight_NexusPack.zip (default)
  --scripts-only   Four Lua files → G1R_IndoorNight.zip
  --config-only    MaxPerf config only → G1R_IndoorNight_MaxPerf_vN.zip (requires --engine-ver)
  --engine-ver N   Engine.ini generation for config-only zip name (e.g. 13)
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full) MODE="full" ;;
    --scripts-only) MODE="scripts-only" ;;
    --config-only) MODE="config-only" ;;
    --engine-ver) shift; ENGINE_VER="${1:-}"; [[ -n "$ENGINE_VER" ]] || usage ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
  shift
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
UPLOADS="${G1R_MOD_UPLOADS:-$HOME/Downloads/ModUploads}"
PACK="$UPLOADS/G1R_IndoorNight_NexusPack"
CFG_SRC="$REPO/Config/ProfilePack/Local/G1R/Saved/Config/Windows"
CFG_DST="$PACK/Config_MaxPerf/Local/G1R/Saved/Config/Windows"
SCR_DST="$PACK/G1R_IndoorNight/Scripts"
LUA=(main.lua config.lua indoornight_brightness.lua indoornight_reload.lua)
CHECK_LUA="$SCRIPT_DIR/count-lua-locals.py"
LUA_LOCAL_LIMIT=200

warn_lua_local_limit() {
  local f lua_paths=()
  for f in "${LUA[@]}"; do
    lua_paths+=("$REPO/Scripts/$f")
  done
  if [[ ! -f "$CHECK_LUA" ]]; then
    echo "WARNING: missing $CHECK_LUA — skipping Lua local limit check" >&2
    return 0
  fi
  if ! python3 "$CHECK_LUA" "${lua_paths[@]}"; then
    echo "WARNING: one or more Lua files exceed the ${LUA_LOCAL_LIMIT} local variable limit (see above)" >&2
    return 1
  fi
}

copy_lua() {
  local dest="$1"
  mkdir -p "$dest"
  for f in "${LUA[@]}"; do
    cp "$REPO/Scripts/$f" "$dest/$f"
  done
}

copy_config() {
  local dest="$1"
  mkdir -p "$dest"
  chmod u+w "$dest/Scalability.ini" 2>/dev/null || true
  cp "$CFG_SRC/Engine.ini.maxperf" "$dest/Engine.ini"
  cp "$CFG_SRC/GameUserSettings.ini.maxperf" "$dest/GameUserSettings.ini"
  cp "$CFG_SRC/Scalability.ini" "$dest/Scalability.ini"
}

mkdir -p "$UPLOADS"

case "$MODE" in
  full)
    warn_lua_local_limit || true
    copy_config "$CFG_DST"
    copy_lua "$SCR_DST"
    find "$PACK" -name .DS_Store -delete
    cd "$UPLOADS"
    rm -f G1R_IndoorNight_NexusPack.zip
    zip -r G1R_IndoorNight_NexusPack.zip G1R_IndoorNight_NexusPack -x "*.DS_Store" -x "**/.DS_Store"
    echo "Wrote: $UPLOADS/G1R_IndoorNight_NexusPack.zip"
    echo "Next: update $PACK/00_README_INSTALLATION.txt if needed, then re-zip README-only if changed."
    ;;
  scripts-only)
    warn_lua_local_limit || true
    STAGE="$UPLOADS/_stage_scripts/G1R_IndoorNight/Scripts"
    rm -rf "$UPLOADS/_stage_scripts"
    copy_lua "$STAGE"
    cd "$UPLOADS/_stage_scripts"
    zip -r "$UPLOADS/G1R_IndoorNight.zip" G1R_IndoorNight
    rm -rf "$UPLOADS/_stage_scripts"
    echo "Wrote: $UPLOADS/G1R_IndoorNight.zip"
    ;;
  config-only)
    [[ -n "$ENGINE_VER" ]] || { echo "config-only requires --engine-ver N" >&2; exit 1; }
    STAGE="$UPLOADS/G1R_IndoorNight_MaxPerf_v${ENGINE_VER}"
    rm -rf "$STAGE"
    copy_config "$STAGE/Config_MaxPerf/Local/G1R/Saved/Config/Windows"
    cd "$UPLOADS"
    zip -r "G1R_IndoorNight_MaxPerf_v${ENGINE_VER}.zip" "$(basename "$STAGE")"
    echo "Wrote: $UPLOADS/G1R_IndoorNight_MaxPerf_v${ENGINE_VER}.zip"
    ;;
esac

MOD_BUILD="$(grep -E '^\s*local MOD_BUILD\s*=' "$REPO/Scripts/main.lua" | sed -E 's/.*=\s*"([^"]+)".*/\1/' || true)"
[[ -n "$MOD_BUILD" ]] && echo "MOD_BUILD in repo: $MOD_BUILD"
