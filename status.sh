#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

echo "=== pomodoro-loop status ==="

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "process: running (pid=$(cat "$PID_FILE"))"
else
  echo "process: not running"
fi

if [[ -f "$STATE_FILE" ]]; then
  echo "state:   $(cat "$STATE_FILE" | tr -d '[:space:]')"
else
  echo "state:   (no state file yet)"
fi

echo "config:  work=${WORK_MINUTES}min  break=${BREAK_MINUTES}min  sound=${SOUND}"
echo "log:     $LOG_FILE"
