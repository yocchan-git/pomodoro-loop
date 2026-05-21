#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

notify() {
  local title="$1"
  local msg="$2"
  osascript -e "display notification \"${msg}\" with title \"${title}\" sound name \"${SOUND}\""
}

read_state() {
  if [[ -f "$STATE_FILE" ]]; then
    cat "$STATE_FILE" | tr -d '[:space:]'
  else
    echo "work"
  fi
}

write_state() {
  mkdir -p "$(dirname "$STATE_FILE")"
  echo "$1" > "$STATE_FILE"
}

trap 'echo "[$(date +%T)] stopped"; exit 0' SIGTERM SIGINT

# 起動直後の announcement
state=$(read_state)
echo "[$(date +%T)] starting in state=${state}"
if [[ "$state" == "work" ]]; then
  notify "Pomodoro 作業開始" "${WORK_MINUTES} 分集中"
else
  notify "Pomodoro 休憩開始" "${BREAK_MINUTES} 分休む"
fi

while true; do
  state=$(read_state)

  if [[ "$state" == "work" ]]; then
    sleep $((WORK_MINUTES * 60))
    write_state "break"
    echo "[$(date +%T)] work -> break"
    notify "Pomodoro 休憩開始" "${BREAK_MINUTES} 分休む"
  else
    sleep $((BREAK_MINUTES * 60))
    write_state "work"
    echo "[$(date +%T)] break -> work"
    notify "Pomodoro 作業開始" "${WORK_MINUTES} 分集中"
  fi
done
