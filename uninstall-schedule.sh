#!/bin/bash
# pomodoro-loop の自動スケジュールを解除する。
# 現在動いている pomodoro 本体は止めない（必要なら ./stop.sh も叩く）。
set -euo pipefail

TARGET_DIR="${HOME}/Library/LaunchAgents"

for label in com.yoshiharu.pomodoro-loop.start com.yoshiharu.pomodoro-loop.stop; do
  dst="${TARGET_DIR}/${label}.plist"

  if [[ -f "$dst" ]]; then
    launchctl unload "$dst" 2>/dev/null || true
    rm -f "$dst"
    echo "uninstalled: $label"
  else
    echo "not installed: $label"
  fi
done
