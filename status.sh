#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"
# shellcheck source=lib/clock.sh
source "${SCRIPT_DIR}/lib/clock.sh"
# shellcheck source=lib/log.sh
source "${SCRIPT_DIR}/lib/log.sh"

# state ファイルの値を読む（source はしない）
sval() {
  if [[ -f "$STATE_FILE" ]]; then
    grep "^$1=" "$STATE_FILE" 2>/dev/null | head -n1 | cut -d= -f2- || true
  fi
}

echo "=== pomodoro-loop status ==="

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "process: running (pid=$(cat "$PID_FILE"))"
else
  echo "process: not running"
fi

if [[ -f "$STATE_FILE" ]]; then
  state=$(sval state)
  if [[ -z "$state" ]]; then
    echo "state:   (unreadable state file: $STATE_FILE)"
  else
    echo "state:   ${state}"
    kind=$(sval kind); label=$(sval label)
    echo "band:    ${label:--}${kind:+ (${kind})}"
    end_epoch=$(sval end_epoch)
    if [[ "$end_epoch" =~ ^[0-9]+$ && "$end_epoch" -gt 0 ]]; then
      rem=$(( end_epoch - $(now_epoch) ))
      if (( rem < 0 )); then rem=0; fi
      echo "remain:  $(( rem / 60 ))分$(( rem % 60 ))秒"
    fi
  fi
else
  echo "state:   (no state file yet)"
fi

echo "today:   work=$(today_work_count)枠  deep=$(today_deep_min)/${DEEP_CAP_MINUTES}分  筋トレ=$(today_training_count)/${TRAINING_MAX_PER_DAY}回"
echo "window:  ${SCHEDULE_START_TIME}-${SCHEDULE_STOP_TIME}"
echo "data:    $DATA_DIR"
echo "log:     $LOG_FILE"
