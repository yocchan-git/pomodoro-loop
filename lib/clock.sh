#!/bin/bash
# shellcheck disable=SC2034  # 他ファイルから参照するグローバル変数
# shellcheck disable=SC2017

# 時計まわり。FAKE_NOW があれば仮想時計（TIME_SCALE に合わせて進む）を使う。
: "${TIME_SCALE:=60}"
: "${FAKE_NOW:=}"
LOOP_REAL_START=$(date +%s)

now_epoch() { date +%s; }

# HHMM -> 0時からの分
hhmm_to_min() {
  local h=$((10#$1))
  echo $(( (h / 100) * 60 + h % 100 ))
}

# epoch -> 仮想の「0時からの秒」
vsecs_of_epoch() {
  local e=$1 base
  if [[ -n "$FAKE_NOW" ]]; then
    base=$(( 10#${FAKE_NOW:0:2} * 3600 + 10#${FAKE_NOW:2:2} * 60 ))
    echo $(( (base + (e - LOOP_REAL_START) * 60 / TIME_SCALE) % 86400 ))
  else
    local h m s
    read -r h m s <<<"$(date -r "$e" '+%H %M %S')"
    echo $(( 10#$h * 3600 + 10#$m * 60 + 10#$s ))
  fi
}

# epoch -> HH:MM:SS（ログ用）
fmt_vtime() {
  local v
  v=$(vsecs_of_epoch "$1")
  printf '%02d:%02d:%02d' $(( v / 3600 )) $(( v % 3600 / 60 )) $(( v % 60 ))
}

# 現在の HHMM
now_hhmm() {
  local v
  v=$(vsecs_of_epoch "$(now_epoch)")
  printf '%02d%02d' $(( v / 3600 )) $(( v % 3600 / 60 ))
}

# 秒 -> 分（四捨五入）
secs_to_min() { echo $(( ($1 + TIME_SCALE / 2) / TIME_SCALE )); }
