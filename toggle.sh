#!/bin/bash
# ワンクリック ON/OFF 切替。動いていれば停止、止まっていれば開始する。
# 停止した日は OFF_FLAG_FILE に日付を書き、その日の自動 start（再起動時含む）を抑止する。
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

banner() {
  osascript -e "display notification \"$1\" with title \"Pomodoro\"" >/dev/null 2>&1 || true
}

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  "${SCRIPT_DIR}/stop.sh"
  date +%Y%m%d > "$OFF_FLAG_FILE"
  banner "OFF にしました"
else
  rm -f "$OFF_FLAG_FILE"
  "${SCRIPT_DIR}/start.sh"
  banner "ON にしました"
fi
