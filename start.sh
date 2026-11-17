#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

# --scheduled (launchd 経由) の場合のみ稼働時間帯のガードを効かせる。
# 手動 ./start.sh はいつでも起動可能。
if [[ "${1:-}" == "--scheduled" ]]; then
  now=$(date +%H%M)
  if [[ "$now" < "$SCHEDULE_START_TIME" || ! "$now" < "$SCHEDULE_STOP_TIME" ]]; then
    echo "scheduled outside window (now=$now, allowed=${SCHEDULE_START_TIME}-${SCHEDULE_STOP_TIME})"
    exit 0
  fi
  if [[ -f "$OFF_FLAG_FILE" && "$(cat "$OFF_FLAG_FILE")" == "$(date +%Y%m%d)" ]]; then
    echo "manually turned off today (${OFF_FLAG_FILE}), skip scheduled start"
    exit 0
  fi
fi

# 既に走ってないか確認
if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "already running (pid=$(cat "$PID_FILE"))"
  exit 0
fi

# データ置き場を用意（logs/ など）
mkdir -p "${DATA_DIR}/logs"

# caffeinate -i でアイドルスリープを抑止しつつバックグラウンド起動
# （テスト時 POMODORO_NO_SIDE_EFFECTS=1 は caffeinate を挟まない）
if [[ "${POMODORO_NO_SIDE_EFFECTS:-}" == "1" ]]; then
  nohup "${SCRIPT_DIR}/pomodoro-loop.sh" > "$LOG_FILE" 2>&1 &
else
  nohup caffeinate -i "${SCRIPT_DIR}/pomodoro-loop.sh" \
    > "$LOG_FILE" 2>&1 &
fi
echo $! > "$PID_FILE"

echo "pomodoro started (pid=$(cat "$PID_FILE"))"
echo "data: $DATA_DIR"
echo "log: $LOG_FILE"
