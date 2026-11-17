#!/bin/bash
# shellcheck disable=SC2034  # 他ファイルから参照するグローバル変数

# アイドル時間・Zoom・場所の判定。

# Zoom 会議中かどうか。会議中は zoom.us が UDP ソケットを張り、画面共有中は CptHost が動く。
# どちらもアクセシビリティ権限なしで判定できる。（テスト: POMODORO_FAKE_ZOOM=1）
in_zoom_meeting() {
  [[ "${POMODORO_FAKE_ZOOM:-}" == "1" ]] && return 0
  pgrep -x CptHost >/dev/null 2>&1 && return 0
  lsof -a -nP -i UDP -c zoom.us >/dev/null 2>&1
}

# 最後の操作からの秒数。（テスト: POMODORO_FAKE_IDLE=数字の入ったファイル）
raw_idle_seconds() {
  local v=""
  if [[ -n "${POMODORO_FAKE_IDLE:-}" ]]; then
    if [[ -f "$POMODORO_FAKE_IDLE" ]]; then
      v=$(tr -d '[:space:]' < "$POMODORO_FAKE_IDLE")
    fi
  else
    v=$(ioreg -c IOHIDSystem 2>/dev/null | awk '/HIDIdleTime/ {print int($NF/1000000000); exit}' || true)
  fi
  [[ "$v" =~ ^[0-9]+$ ]] || v=0
  echo "$v"
}

# Zoom 会議中は操作がなくてもアイドル扱いしない
effective_idle() {
  if in_zoom_meeting; then
    echo 0
  else
    raw_idle_seconds
  fi
}

# 場所: LOC に home / office を入れる（テスト: POMODORO_FAKE_LOCATION）
detect_location() {
  LOC=home
  if [[ -n "${POMODORO_FAKE_LOCATION:-}" ]]; then
    LOC=$POMODORO_FAKE_LOCATION
    return 0
  fi
  [[ -n "${OFFICE_DNS_DOMAINS:-}" ]] || return 0
  local dom d
  dom=$(scutil --dns 2>/dev/null | awk '/search domain\[0\]/ {print $NF; exit}' || true)
  dom=$(printf '%s' "$dom" | tr '[:upper:]' '[:lower:]')
  [[ -n "$dom" ]] || return 0
  for d in $OFFICE_DNS_DOMAINS; do
    d=$(printf '%s' "$d" | tr '[:upper:]' '[:lower:]')
    if [[ "$dom" == "$d" ]]; then
      LOC=office
      return 0
    fi
  done
  return 0
}
