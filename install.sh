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

MODS_TXT="$GAME_MODS/mods.txt"
if [[ -f "$MODS_TXT" ]]; then
  if grep -qE "^[[:space:]]*${MOD_NAME}[[:space:]]*:[[:space:]]*1[[:space:]]*$" "$MODS_TXT"; then
    echo ""
    echo "mods.txt already enables $MOD_NAME"
  elif grep -qE "^[[:space:]]*${MOD_NAME}[[:space:]]*:" "$MODS_TXT"; then
    if [[ "$(uname)" == "Darwin" ]]; then
      sed -i '' -E "s/^[[:space:]]*${MOD_NAME}[[:space:]]*:.*/${MOD_NAME} : 1/" "$MODS_TXT"
    else
      sed -i -E "s/^[[:space:]]*${MOD_NAME}[[:space:]]*:.*/${MOD_NAME} : 1/" "$MODS_TXT"
    fi
    echo ""
    echo "Updated mods.txt entry to:"
    echo "  ${MOD_NAME} : 1"
  else
    echo "" >> "$MODS_TXT"
    echo "${MOD_NAME} : 1" >> "$MODS_TXT"
    echo ""
    echo "Added to mods.txt:"
    echo "  ${MOD_NAME} : 1"
  fi
else
  echo ""
  echo "mods.txt not found at:"
  echo "  $MODS_TXT"
  echo "Add manually:"
  echo "  $MOD_NAME : 1"
fi
