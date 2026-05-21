#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

# 既に走ってないか確認
if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "already running (pid=$(cat "$PID_FILE"))"
  exit 0
fi

# 状態ファイル初期化（無ければ "work" で開始）
if [[ ! -f "$STATE_FILE" ]]; then
  mkdir -p "$(dirname "$STATE_FILE")"
  echo "work" > "$STATE_FILE"
  echo "initialized state: work"
fi

# caffeinate -i でアイドルスリープを抑止しつつバックグラウンド起動
nohup caffeinate -i "${SCRIPT_DIR}/pomodoro-loop.sh" \
  > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

echo "pomodoro started (pid=$(cat "$PID_FILE"), state=$(cat "$STATE_FILE"))"
echo "log: $LOG_FILE"
