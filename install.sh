#!/bin/bash
# Symlink G1R_IndoorNight into the CrossOver G1R UE4SS Mods folder.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MOD_NAME="G1R_IndoorNight"

# Default CrossOver bottle path for this workspace
GAME_MODS="${G1R_UE4SS_MODS:-$SCRIPT_DIR/../Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/Gothic 1 Remake/G1R/Binaries/Win64/ue4ss/Mods}"

if [[ ! -d "$GAME_MODS" ]]; then
  echo "UE4SS Mods folder not found:"
  echo "  $GAME_MODS"
  echo ""
  echo "Set G1R_UE4SS_MODS to your ue4ss/Mods path and retry."
  exit 1
fi

TARGET="$GAME_MODS/$MOD_NAME"

if [[ -e "$TARGET" && ! -L "$TARGET" ]]; then
  echo "Refusing to overwrite existing directory: $TARGET"
  exit 1
fi

ln -sfn "$SCRIPT_DIR" "$TARGET"
echo "Linked:"
echo "  $TARGET -> $SCRIPT_DIR"
echo ""
echo "Add to mods.txt if not already present:"
echo "  $MOD_NAME : 1"
