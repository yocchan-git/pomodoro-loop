#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

notify() {
  local title="$1"
  local msg="$2"

  # サウンドを非同期で再生（ダイアログはサウンド指定を持てないため afplay で鳴らす）
  local sound_file="/System/Library/Sounds/${SOUND}.aiff"
  if [[ -f "$sound_file" ]]; then
    afplay "$sound_file" >/dev/null 2>&1 &
  fi

  # ダイアログを最前面に表示し、OK を押すか DIALOG_TIMEOUT_SECONDS 経過で閉じる。
  # System Events 経由 + activate で、バックグラウンド (launchd) 起動でも前面に出す。
  # ユーザーが Esc などで閉じると非ゼロ終了するため、ループを止めないよう || true。
  osascript >/dev/null 2>&1 <<EOF || true
tell application "System Events"
  activate
  display dialog "${msg}" with title "${title}" buttons {"OK"} default button "OK" with icon note giving up after ${DIALOG_TIMEOUT_SECONDS}
end tell
EOF
}

# Zoom 会議中かどうか。会議中は zoom.us が UDP ソケットを張り、画面共有中は CptHost が動く。
# どちらもアクセシビリティ権限なしで判定できる。
in_zoom_meeting() {
  pgrep -x CptHost >/dev/null 2>&1 && return 0
  lsof -a -nP -i UDP -c zoom.us >/dev/null 2>&1
}

# 作業 / 休憩開始の告知。Zoom 会議中はカードも筋トレ動画も出さない。
announce() {
  local phase="$1"

  if in_zoom_meeting; then
    echo "[$(date +%T)] zoom meeting detected, skip announce (${phase})"
    return 0
  fi

  if [[ "$phase" == "work" ]]; then
    notify "Pomodoro 作業開始" "${WORK_MINUTES} 分集中"
  else
    if [[ -n "${BREAK_SHORTCUT:-}" ]]; then
      shortcuts run "$BREAK_SHORTCUT" >/dev/null 2>&1 &
    fi
    notify "Pomodoro 休憩開始" "${BREAK_MINUTES} 分休む"
  fi
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
announce "$state"

while true; do
  state=$(read_state)

  if [[ "$state" == "work" ]]; then
    sleep $((WORK_MINUTES * 60))
    write_state "break"
    echo "[$(date +%T)] work -> break"
    announce "break"
  else
    sleep $((BREAK_MINUTES * 60))
    write_state "work"
    echo "[$(date +%T)] break -> work"
    announce "work"
  fi
done
