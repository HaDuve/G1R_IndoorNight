#!/bin/bash
# Switch Gothic 1 Remake CrossOver config profiles.
# Usage: switch-g1r-profile.sh {maxperf|default-lighting|streaming-only|backup|list} [--no-backup]

set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILE="${1:-}"
SKIP_BACKUP=false

if [[ "${2:-}" == "--no-backup" ]]; then
  SKIP_BACKUP=true
fi

PROFILES=(maxperf default-lighting streaming-only streaming-crossover streaming-veryhigh streaming-veryhigh-extshadows)

usage() {
  echo "Usage: $(basename "$0") {maxperf|default-lighting|streaming-only|streaming-crossover|streaming-veryhigh|streaming-veryhigh-extshadows|backup|list} [--no-backup]"
  echo ""
  echo "  maxperf                        — no grass/shadows/Lumen + CrossOver UET subset (v13); default fallback"
  echo "  default-lighting               — perf tweaks; Lumen + shadows stay on"
  echo "  streaming-only                 — Epic quality; streaming Engine only (NOT for CrossOver — see TEST.md)"
  echo "  streaming-crossover            — streaming Engine + low maxperf settings (CrossOver A/B test)"
  echo "  streaming-veryhigh             — streaming + shadows on, GI off, high textures (M1 Max+ opt-in)"
  echo "  streaming-veryhigh-extshadows  — veryhigh + DistanceScale 1.25; pair with mod SHADOWS_ON_PROFILE"
  echo "  backup            — snapshot active Engine.ini, GameUserSettings.ini, Scalability.ini"
  echo "  list              — show available profiles and active profile"
  echo ""
  echo "  --no-backup       — skip auto-backup before profile switch"
  exit 1
}

do_backup() {
  local backup_dir="$CONFIG_DIR/backups/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup_dir"
  local copied=0
  for f in Engine.ini GameUserSettings.ini Scalability.ini; do
    if [[ -f "$CONFIG_DIR/$f" ]]; then
      cp "$CONFIG_DIR/$f" "$backup_dir/$f"
      copied=$((copied + 1))
    fi
  done
  if [[ $copied -eq 0 ]]; then
    echo "Nothing to back up in $CONFIG_DIR"
    return 1
  fi
  echo "Backup saved: $backup_dir"
}

detect_active_profile() {
  if [[ ! -f "$CONFIG_DIR/Engine.ini" ]]; then
    echo "unknown (no Engine.ini)"
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
      for p in "${PROFILES[@]}"; do
        if [[ -f "$CONFIG_DIR/Engine.ini.$p" ]] && cmp -s "$CONFIG_DIR/Engine.ini" "$CONFIG_DIR/Engine.ini.$p" 2>/dev/null; then
          echo "$p"
          return
        fi
      done
      echo "custom / unknown"
      ;;
  esac
}

do_list() {
  echo "Config dir: $CONFIG_DIR"
  echo ""
  echo "Available profiles:"
  for p in "${PROFILES[@]}"; do
    local engine_ok="missing"
    local gus_ok="missing"
    [[ -f "$CONFIG_DIR/Engine.ini.$p" ]] && engine_ok="ok"
    [[ -f "$CONFIG_DIR/GameUserSettings.ini.$p" ]] && gus_ok="ok"
    echo "  $p  (Engine.ini.$p: $engine_ok, GameUserSettings.ini.$p: $gus_ok)"
  done
  echo ""
  echo "Shared: Scalability.ini ($([[ -f "$CONFIG_DIR/Scalability.ini" ]] && echo ok || echo missing))"
  echo "Active profile: $(detect_active_profile)"
}

switch_profile() {
  local profile="$1"

  for f in "Engine.ini.$profile" "GameUserSettings.ini.$profile"; do
    if [[ ! -f "$CONFIG_DIR/$f" ]]; then
      echo "Missing profile file: $CONFIG_DIR/$f"
      exit 1
    fi
  done

  if [[ "$SKIP_BACKUP" == false ]]; then
    do_backup
    echo ""
  fi

  chmod u+w "$CONFIG_DIR/Engine.ini" 2>/dev/null || true
  cp "$CONFIG_DIR/Engine.ini.$profile" "$CONFIG_DIR/Engine.ini"
  chmod 444 "$CONFIG_DIR/Engine.ini"

  cp "$CONFIG_DIR/GameUserSettings.ini.$profile" "$CONFIG_DIR/GameUserSettings.ini"

  if [[ ! -f "$CONFIG_DIR/Scalability.ini" ]]; then
    echo "Warning: Scalability.ini missing — texture pool may reset to vanilla 1000 MB"
  fi

  echo "Active profile: $profile"
  echo "  Engine.ini            <- Engine.ini.$profile (read-only)"
  echo "  GameUserSettings.ini  <- GameUserSettings.ini.$profile"
  echo "  Scalability.ini       <- shared (unchanged)"
  echo ""
  echo "Relaunch the game for changes to take effect."
}

[[ -n "$PROFILE" ]] || usage

case "$PROFILE" in
  backup)
    do_backup
    ;;
  list)
    do_list
    ;;
  maxperf-metaltune)
    echo "Note: maxperf-metaltune merged into maxperf (v13); switching maxperf."
    switch_profile maxperf
    ;;
  maxperf|default-lighting|streaming-only|streaming-crossover|streaming-veryhigh|streaming-veryhigh-extshadows)
    switch_profile "$PROFILE"
    ;;
  *)
    usage
    ;;
esac
