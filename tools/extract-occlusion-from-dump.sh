#!/bin/bash
# Pull UDS / occlusion lines from UE4SS_ObjectDump.txt for discovery.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UE4SS_DIR="${G1R_UE4SS_DIR:-$SCRIPT_DIR/../Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/Gothic 1 Remake/G1R/Binaries/Win64/ue4ss}"
DUMP="$UE4SS_DIR/UE4SS_ObjectDump.txt"
OUT="$SCRIPT_DIR/occlusion-dump-extract.txt"

if [[ ! -f "$DUMP" ]]; then
  echo "Dump not found: $DUMP"
  echo "In-game: load a save, press Ctrl+J, wait, then re-run this script."
  exit 1
fi

{
  echo "# Extracted $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# Source: $DUMP"
  echo "# Size: $(wc -c < "$DUMP") bytes"
  echo ""
  echo "=== Ultra_Dynamic_Sky (context) ==="
  grep -n -i "Ultra_Dynamic_Sky\|UltraDynamicSky" "$DUMP" | head -80
  echo ""
  echo "=== Occlusion-related lines ==="
  grep -n -i "occlusion\|PlayerOcclusion\|Player_Occlusion" "$DUMP" | head -120
  echo ""
  echo "=== FloatProperty near UDS (first 200 hits) ==="
  grep -n -i "FloatProperty.*[Oo]cclusion\|FloatProperty.*Sky\|FloatProperty.*Time of Day\|FloatProperty.*TimeOfDay" "$DUMP" | head -200
} > "$OUT"

echo "Wrote: $OUT"
echo "Lines: $(wc -l < "$OUT")"
echo ""
echo "Send occlusion-dump-extract.txt or say 'parse occlusion dump' in chat."
