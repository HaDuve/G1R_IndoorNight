#!/bin/bash
# Verify G1R_IndoorNight install and capture load evidence from UE4SS.log.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MOD_NAME="G1R_IndoorNight"
GAME_MODS="${G1R_UE4SS_MODS:-$SCRIPT_DIR/../Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/Gothic 1 Remake/G1R/Binaries/Win64/ue4ss/Mods}"
UE4SS_DIR="$(dirname "$GAME_MODS")"
MODS_TXT="$GAME_MODS/mods.txt"
UE4SS_LOG="$UE4SS_DIR/UE4SS.log"
LOAD_LOG="$SCRIPT_DIR/discovery/load.log"
SNAP_LOG="$SCRIPT_DIR/discovery/snapshots.log"

ok=0
fail=0

pass() { echo "OK   $1"; ok=$((ok + 1)); }
bad() { echo "FAIL $1"; fail=$((fail + 1)); }

echo "=== G1R_IndoorNight install verification ==="
echo ""

TARGET="$GAME_MODS/$MOD_NAME"
if [[ -L "$TARGET" ]]; then
  pass "symlink exists: $TARGET -> $(readlink "$TARGET")"
elif [[ -d "$TARGET" ]]; then
  pass "mod directory exists: $TARGET"
else
  bad "mod not installed at $TARGET (run ./install.sh)"
fi

if [[ -f "$MODS_TXT" ]] && grep -qE "^[[:space:]]*${MOD_NAME}[[:space:]]*:[[:space:]]*1[[:space:]]*$" "$MODS_TXT"; then
  pass "mods.txt enables ${MOD_NAME} : 1"
else
  bad "mods.txt missing enabled entry for ${MOD_NAME} : 1"
fi

if [[ -f "$UE4SS_LOG" ]]; then
  if grep -q "G1R_IndoorNight" "$UE4SS_LOG"; then
    pass "UE4SS.log mentions G1R_IndoorNight"
    echo ""
    echo "--- UE4SS.log (G1R_IndoorNight lines) ---"
    grep "G1R_IndoorNight" "$UE4SS_LOG" | tail -20
  else
    bad "UE4SS.log has no G1R_IndoorNight lines — launch G1R once after install"
  fi
else
  bad "UE4SS.log not found at $UE4SS_LOG"
fi

if [[ -f "$LOAD_LOG" ]]; then
  pass "discovery/load.log written by mod"
  echo ""
  echo "--- discovery/load.log ---"
  tail -5 "$LOAD_LOG"
else
  bad "discovery/load.log missing — mod has not loaded in-game yet"
fi

if [[ -f "$SNAP_LOG" ]]; then
  pass "discovery/snapshots.log exists (F8 was pressed)"
  echo ""
  echo "--- latest snapshot tail ---"
  tail -40 "$SNAP_LOG"
else
  echo "INFO discovery/snapshots.log missing — press F8 at each pose after load"
fi

echo ""
echo "=== $ok passed, $fail failed ==="
[[ "$fail" -eq 0 ]]
