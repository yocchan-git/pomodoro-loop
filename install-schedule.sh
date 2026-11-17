#!/bin/bash
# pomodoro-loop の自動 start/stop スケジュールを LaunchAgent として登録する。
# デフォルト: 06:00 start / 21:00 stop（毎日。stop は安全網で、通常はループが 20:30 に自分で終わる）。
# 時刻を変えたい場合は launchd/*.plist の Hour/Minute を編集してから再実行（冪等）。
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TARGET_DIR="${HOME}/Library/LaunchAgents"
mkdir -p "$TARGET_DIR"

for label in local.pomodoro-loop.start local.pomodoro-loop.stop; do
  src="${SCRIPT_DIR}/launchd/${label}.plist"
  dst="${TARGET_DIR}/${label}.plist"

  # 既に load 済みなら一度 unload（冪等）
  launchctl unload "$dst" 2>/dev/null || true

  # plist 内の __SCRIPT_DIR__ プレースホルダを実パスに置換しながら cp
  sed "s|__SCRIPT_DIR__|${SCRIPT_DIR}|g" "$src" > "$dst"

  launchctl load "$dst"
  echo "installed: $label"
done

echo "---"
echo "schedule installed:"
echo "  start: 06:00 every day"
echo "  stop:  21:00 every day (safety net; the loop ends itself at SCHEDULE_STOP_TIME)"
echo ""
echo "verify with: launchctl list | grep pomodoro"
echo "logs:        tail -f /tmp/pomodoro-schedule.log"
