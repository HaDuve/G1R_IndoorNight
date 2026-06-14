#!/bin/bash
# Extract F10/F11 spike blocks from UE4SS.log into repo spike logs
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UE4SS_DIR="${G1R_UE4SS_DIR:-$SCRIPT_DIR/../Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/Gothic 1 Remake/G1R/Binaries/Win64/ue4ss}"
UE4SS_LOG="$UE4SS_DIR/UE4SS.log"

if [[ ! -f "$UE4SS_LOG" ]]; then
  echo "UE4SS.log not found: $UE4SS_LOG"
  exit 1
fi

python3 - "$UE4SS_LOG" "$SCRIPT_DIR" <<'PY'
import re, sys
src, out_dir = sys.argv[1], sys.argv[2]

def extract(pattern, out_name):
    text = open(src, encoding="utf-8", errors="replace").read()
    blocks = []
    for m in re.finditer(pattern, text, re.S):
        block = m.group(0).strip()
        block = re.sub(r"^\[[^\]]+\]\s*\[Lua\]\s*", "", block, flags=re.M)
        block = re.sub(r"^\[[^\]]+\]\s*", "", block, flags=re.M)
        blocks.append(block)
    path = f"{out_dir}/{out_name}"
    if not blocks:
        print(f"No blocks for {out_name}")
        return 0
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n\n".join(blocks))
        f.write("\n")
    print(f"Extracted {len(blocks)} block(s) -> {path}")
    return len(blocks)

n = 0
n += extract(
    r"={10,}\s*G1R_IndoorNight TOD SPIKE \(Slice 2c\).*?={10,}\s*={10,}",
    "tod-spike.log",
)
n += extract(
    r"={10,}\s*G1R_IndoorNight G1R LEVER SPIKE \(Slice 2d\).*?={10,}\s*={10,}",
    "g1r-lever-spike.log",
)
if n == 0:
    sys.exit(1)
PY
