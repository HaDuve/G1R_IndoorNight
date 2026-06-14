#!/bin/bash
# Print latest discovery snapshots (file or UE4SS.log extract).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SNAP_LOG="$SCRIPT_DIR/snapshots.log"
MOD_SNAP="$SCRIPT_DIR/../Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/Gothic 1 Remake/G1R/Binaries/Win64/ue4ss/Mods/G1R_IndoorNight/snapshots.log"

if [[ -f "$SNAP_LOG" ]]; then
  echo "=== snapshots.log (repo) ==="
  cat "$SNAP_LOG"
  exit 0
fi

if [[ -f "$MOD_SNAP" ]]; then
  echo "=== snapshots.log (mod folder via symlink) ==="
  cat "$MOD_SNAP"
  exit 0
fi

echo "No snapshots.log yet. Trying UE4SS.log extract..."
"$SCRIPT_DIR/tools/sync-from-ue4ss-log.sh" && cat "$SNAP_LOG"
