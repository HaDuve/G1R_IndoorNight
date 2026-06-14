#!/usr/bin/env bash
# Parse UE4SS.log for [DEBUG-night] feedback after HITL game-night indoor session.
# Usage: ./scripts/check-night-feedback.sh [path/to/UE4SS.log]
set -euo pipefail

LOG="${1:-}"
if [[ -z "$LOG" ]]; then
  for candidate in \
    "$HOME/Library/Application Support/CrossOver/Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/Gothic 1 Remake/G1R/Binaries/Win64/ue4ss/UE4SS.log" \
    "./UE4SS.log"
  do
    if [[ -f "$candidate" ]]; then
      LOG="$candidate"
      break
    fi
  done
fi

if [[ -z "$LOG" || ! -f "$LOG" ]]; then
  echo "FAIL: UE4SS.log not found. Pass path as first arg." >&2
  exit 1
fi

echo "=== Night feedback loop: $LOG ==="
echo

BUILD=$(grep -o 'build=v3\.[0-9.]*' "$LOG" | tail -1 || true)
echo "Latest mod build in log: ${BUILD:-unknown}"
echo

NIGHT_APPLIES=$(grep -c 'apply mode=indoor_night' "$LOG" || true)
POLL_ERRORS=$(grep -c 'poll pass error.*applyDayRestore' "$LOG" || true)
COLOR_ERRORS=$(grep -c "member variable 'R' but UObject instance is nullptr" "$LOG" || true)
REVERTED=$(grep '\[DEBUG-night\] REVERTED' "$LOG" | grep -cE 'night transition|night refresh|probe between|indoor_night after apply' || true)
DEBUG_LINES=$(grep -c '\[DEBUG-night\]' "$LOG" || true)

echo "indoor_night applies:  $NIGHT_APPLIES"
echo "[DEBUG-night] lines:   $DEBUG_LINES"
echo "REVERTED detections:   $REVERTED"
echo "applyDayRestore errors: $POLL_ERRORS"
echo "color struct errors:   $COLOR_ERRORS"
echo

if [[ "$COLOR_ERRORS" -gt 0 ]]; then
  echo "WARN: nullptr color struct writes detected — reload v3.3.2+ (uses SetSettings hue only)."
fi

if [[ "$POLL_ERRORS" -gt 0 ]]; then
  echo "FAIL: applyDayRestore nil — reload with v3.2.8+ (forward-ref fix)."
  exit 5
fi

if [[ "$DEBUG_LINES" -eq 0 ]]; then
  echo "FAIL: No [DEBUG-night] lines — reload game with v3.2.7+ and sleep indoors at night."
  exit 2
fi

echo "--- Last 15 [DEBUG-night] lines ---"
grep '\[DEBUG-night\]' "$LOG" | tail -15
echo

if [[ "$REVERTED" -gt 0 ]]; then
  echo "VERDICT: FRAME-FIGHT — G1R reverted day-indoor crush between our applies."
  echo "         v3.2.7 refresh should re-apply; if REVERTED persists, tighten refresh interval."
  exit 3
fi

LAST_NIGHT_LINE=$(grep 'indoor_night after apply' "$LOG" | tail -1 || true)
LAST_MULT=$(echo "$LAST_NIGHT_LINE" | grep -o 'mult=[0-9.]*' | head -1 || true)
LAST_EXP=$(echo "$LAST_NIGHT_LINE" | grep -o 'Exp=[0-9.-]*' | head -1 || true)
if [[ -n "$LAST_NIGHT_LINE" && "$LAST_MULT" == "mult=0.32" ]]; then
  echo "VERDICT: STALE CRUSH — last indoor_night readback shows day-indoor mult 0.32."
  exit 4
fi
if [[ -n "$LAST_EXP" ]]; then
  echo "Last night exposure:   $LAST_EXP"
fi

echo "VERDICT: PASS (log) — no reversion detected; confirm visually in-game."
exit 0
