#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

if [[ ! -f "$PID_FILE" ]]; then
  echo "not running (no pid file)"
  exit 0
fi

pid=$(cat "$PID_FILE")

if ! kill -0 "$pid" 2>/dev/null; then
  echo "stale pid file ($pid). removing."
  rm -f "$PID_FILE"
  exit 0
fi

# caffeinate プロセス + その子の pomodoro-loop.sh を一緒に終わらせる
pkill -TERM -P "$pid" 2>/dev/null || true
kill -TERM "$pid" 2>/dev/null || true

# 念のため少し待って残存確認
sleep 1
if kill -0 "$pid" 2>/dev/null; then
  kill -KILL "$pid" 2>/dev/null || true
fi

rm -f "$PID_FILE"
echo "pomodoro stopped (pid=$pid)"
