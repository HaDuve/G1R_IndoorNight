#!/bin/bash
# Extract F8 discovery blocks from UE4SS.log into repo snapshots.log
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UE4SS_DIR="${G1R_UE4SS_DIR:-$SCRIPT_DIR/../Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/Gothic 1 Remake/G1R/Binaries/Win64/ue4ss}"
UE4SS_LOG="$UE4SS_DIR/UE4SS.log"
OUT="$SCRIPT_DIR/snapshots.log"

if [[ ! -f "$UE4SS_LOG" ]]; then
  echo "UE4SS.log not found: $UE4SS_LOG"
  exit 1
fi

python3 - "$UE4SS_LOG" "$OUT" <<'PY'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8", errors="replace").read()
blocks = []
for m in re.finditer(
    r"={10,}\s*G1R_IndoorNight DISCOVERY SNAPSHOT #\d+.*?={10,}\s*={10,}",
    text,
    re.S,
):
    block = m.group(0).strip()
    block = re.sub(r"^\[[^\]]+\]\s*\[Lua\]\s*", "", block, flags=re.M)
    block = re.sub(r"^\[[^\]]+\]\s*", "", block, flags=re.M)
    blocks.append(block)

if not blocks:
    print("No DISCOVERY SNAPSHOT blocks in UE4SS.log")
    sys.exit(1)

with open(dst, "w", encoding="utf-8") as f:
    f.write("\n\n".join(blocks))
    f.write("\n")

print(f"Extracted {len(blocks)} snapshot(s) -> {dst}")
PY
