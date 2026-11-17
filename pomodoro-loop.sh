#!/bin/bash
# 状態機械: work / break / long_break / away / rest / shutdown
# 時間は sleep の長さではなく終了時刻(epoch)で管理し、POLL_SECONDS ごとに確認する。
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"
for _lib in clock log idle dialog profile break_menu; do
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/lib/${_lib}.sh"
done
unset _lib

say() { echo "[$(date +%T)] $*"; }

# 割り込みで起きられる sleep
nap() {
  sleep "$1" &
  wait $! || true
}


# state_write state kind label start_epoch end_epoch planned_min
state_write() {
  mkdir -p "$(dirname "$STATE_FILE")"
  local tmp="${STATE_FILE}.tmp.$$"
  {
    printf 'state=%s\n' "$1"
    printf 'kind=%s\n' "$(tsv_clean "$2")"
    printf 'label=%s\n' "$(tsv_clean "$3")"
    printf 'start_epoch=%s\n' "$4"
    printf 'end_epoch=%s\n' "$5"
    printf 'planned_min=%s\n' "$6"
    printf 'updated=%s\n' "$(now_epoch)"
    printf 'hhmm=%s\n' "$(now_hhmm)"
  } > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

on_term() {
  say "stopped"
  pkill -TERM -P $$ 2>/dev/null || true
  state_write stopped "" "" 0 0 0 || true
  exit 0
}
trap on_term SIGTERM SIGINT

past_stop() { (( 10#$(now_hhmm) >= 10#$SCHEDULE_STOP_TIME && 10#$(now_hhmm) >= 10#$SCHEDULE_START_TIME )); }
before_start() { (( 10#$(now_hhmm) < 10#$SCHEDULE_START_TIME )); }

# 終了時刻まで待つ。0=到達 / 2=終業時刻になった
wait_until() {
  local end=$1 rem n
  while :; do
    rem=$(( end - $(now_epoch) ))
    if (( rem <= 0 )); then return 0; fi
    if past_stop; then return 2; fi
    n=$POLL_SECONDS
    if (( rem < n )); then n=$rem; fi
    nap "$n"
  done
}

read_file_or_empty() {
  if [[ -f "$1" ]]; then
    tsv_clean "$(cat "$1")"
  fi
}

# --- 作業開始カード -------------------------------------------------------
# WB_INTENT に入力を入れる。0=開始 / 1=外出中になった / 2=終業時刻
ask_work_start() {
  local def="" deep cap_note="" msg
  if [[ "$(today_work_count)" -eq 0 ]]; then
    def=$(read_file_or_empty "${DATA_DIR}/tomorrow_first")
  fi
  if [[ -z "$def" ]]; then
    def=$(read_file_or_empty "${DATA_DIR}/next_step")
  fi
  deep=$(today_deep_min)
  if [[ "$P_KIND" == "deep" && "$deep" -ge "$DEEP_CAP_MINUTES" ]]; then
    cap_note=$'\n'"※ 今日の deep は上限（${DEEP_CAP_MINUTES}分）に達しています。浅い作業への切り替えを推奨します。"
  fi
  msg="【${P_LABEL}】${P_WORK}分の枠（${P_KIND}）"$'\n'"今日の deep 累計: ${deep}分 / 場所: ${LOC}${cap_note}"$'\n\n'"この枠でやること1つを書いて OK。タイマーは OK を押した時点から始まります。"

  WB_INTENT=""
  # 離席判定は「カードを出してから操作がない時間」で測る（休憩中に Mac を離れていた分は数えない）
  local card_start idle since
  card_start=$(now_epoch)
  if in_zoom_meeting; then
    say "zoom meeting detected, skip work start card"
    WB_INTENT=$def
    return 0
  fi
  while :; do
    if past_stop; then return 2; fi
    play_sound
    dialog_text "Pomodoro 作業開始" "$msg" "$def" "$REMIND_SECONDS"
    case "$DLG_STATUS" in
      ok)
        WB_INTENT=$DLG_TEXT
        return 0 ;;
      zoom)
        # 会議中に開始時刻が来た: 会議も仕事なので、宣言なし（前回の次の一手）で枠を始める
        say "zoom meeting detected, start work without card"
        WB_INTENT=$def
        return 0 ;;
      timeout) : ;;
      *) nap "$REMIND_SECONDS" ;;   # Esc で閉じた時は間を置いて出し直す
    esac
    idle=$(effective_idle)
    since=$(( $(now_epoch) - card_start ))
    if (( idle > since )); then idle=$since; fi
    if (( idle >= AWAY_IDLE_SECONDS )); then
      return 1
    fi
  done
}

# --- 作業ブロック ---------------------------------------------------------
# 0=完了 / 1=中断して外出中へ / 2=終業時刻
do_work() {
  local start end planned=$P_WORK now idle actual result="" next=""
  start=$(now_epoch)
  end=$(( start + planned * TIME_SCALE ))
  state_write work "$P_KIND" "$P_LABEL" "$start" "$end" "$planned"
  say "work start: ${P_LABEL} (${P_KIND}) ${planned}min intent=${WB_INTENT}"
  run_shortcut "$WORK_START_SHORTCUT"

  while :; do
    now=$(now_epoch)
    if (( now >= end )); then break; fi
    if past_stop; then
      actual=$(secs_to_min $(( now - start )))
      log_row work "$start" "$now" "$P_KIND" "$P_LABEL" "$planned" "$actual" "$WB_INTENT" "中断" "" "$LOC"
      say "work interrupted by shutdown time"
      return 2
    fi
    idle=$(effective_idle)
    if (( idle >= WORK_ABANDON_IDLE_SECONDS )); then
      actual=$(( now - start - idle ))
      if (( actual < 0 )); then actual=0; fi
      actual=$(secs_to_min "$actual")
      log_row work "$start" "$now" "$P_KIND" "$P_LABEL" "$planned" "$actual" "$WB_INTENT" "中断" "" "$LOC"
      say "work abandoned (idle=${idle}s)"
      return 1
    fi
    nap "$POLL_SECONDS"
  done

  play_sound
  actual=$(secs_to_min $(( $(now_epoch) - start )))
  if in_zoom_meeting; then
    result="-"
    say "zoom meeting detected, skip work end questions"
  else
    dialog_buttons "Pomodoro 作業終了" "この枠どうだった？"$'\n'"○ できた / △ 途中 / × できなかった" "○" "△" "×"
    if [[ "$DLG_STATUS" == "ok" ]]; then result=$DLG_TEXT; else result="-"; fi
    dialog_text "Pomodoro 次の一手" "再開したら最初にやることを1つメモ（次の枠の入力欄に入ります）" "" 0
    if [[ "$DLG_STATUS" == "ok" ]]; then
      next=$DLG_TEXT
      mkdir -p "$DATA_DIR"
      printf '%s\n' "$next" > "${DATA_DIR}/next_step"
    fi
  fi
  log_row work "$start" "$(now_epoch)" "$P_KIND" "$P_LABEL" "$planned" "$actual" "$WB_INTENT" "$result" "$next" "$LOC"
  return 0
}

# --- 休憩 -----------------------------------------------------------------
# $1 = short | long。0=終了 / 2=終業時刻
do_break() {
  local type=$1 mins start end rc=0 state_name=break title msg actual
  mins=$P_BREAK
  if [[ "$type" == "long" ]]; then
    state_name=long_break
    if (( P_LONGMIN > 0 )); then mins=$P_LONGMIN; fi
  fi
  detect_location
  start=$(now_epoch)
  end=$(( start + mins * TIME_SCALE ))
  state_write "$state_name" "$P_KIND" "$P_LABEL" "$start" "$end" "$mins"

  if in_zoom_meeting; then
    BM_NAME="会議中（カードなし）"
    say "zoom meeting detected, skip break card"
  else
    pick_break "$type" "$(now_hhmm)" "$LOC"
    run_shortcut "$BREAK_START_SHORTCUT"
    if [[ "$BM_ACTION" == "training" ]]; then run_shortcut "$TRAINING_SHORTCUT"; fi
    if [[ "$BM_ACTION" == "nsdr" ]]; then open_url "$NSDR_URL"; fi
    if [[ "$type" == "long" ]]; then title="Pomodoro 長休憩 ${mins}分"; else title="Pomodoro 休憩 ${mins}分"; fi
    msg="${BM_NAME}"$'\n'"${BM_TEXT}"$'\n\n'"${NO_PHONE_NOTE}"
    play_sound
    dialog_info "$title" "$msg" "$DIALOG_TIMEOUT_SECONDS"
  fi
  say "${state_name}: ${BM_NAME} ${mins}min"

  wait_until "$end" || rc=$?
  play_sound
  actual=$(secs_to_min $(( $(now_epoch) - start )))
  log_row break "$start" "$(now_epoch)" "$P_KIND" "$BM_NAME" "$mins" "$actual" "" "" "" "$LOC"
  return "$rc"
}

# --- 外出中 ---------------------------------------------------------------
do_away() {
  local start idle actual stopped=0
  start=$(now_epoch)
  state_write away "" "外出中" "$start" 0 0
  say "away start"
  while :; do
    idle=$(effective_idle)
    if (( idle < AWAY_IDLE_SECONDS )); then break; fi
    if past_stop; then stopped=1; break; fi
    nap "$POLL_SECONDS"
  done
  actual=$(secs_to_min $(( $(now_epoch) - start )))
  log_row away "$start" "$(now_epoch)" "" "外出中" "" "$actual" "" "" "" "$LOC"
  say "away end (${actual}min)"
  if (( stopped == 0 )); then
    dialog_info "Pomodoro" "おかえりなさい。次の枠を始めましょう。" "$DIALOG_TIMEOUT_SECONDS"
  fi
}

# --- rest 帯 --------------------------------------------------------------
do_rest() {
  local start end rem_min rc=0 actual
  start=$(now_epoch)
  rem_min=$(( $(hhmm_to_min "$P_END") - $(hhmm_to_min "$(now_hhmm)") ))
  if (( rem_min < 1 )); then rem_min=1; fi
  end=$(( start + rem_min * TIME_SCALE ))
  state_write rest rest "$P_LABEL" "$start" "$end" "$rem_min"
  say "rest: ${P_LABEL} until ${P_END}"
  if in_zoom_meeting; then
    say "zoom meeting detected, skip rest card"
  else
    play_sound
    dialog_info "Pomodoro 休憩帯" "【${P_LABEL}】"$'\n'"この時間帯は作業しません（${P_END:0:2}:${P_END:2:2} まで）。ゆっくり休んで、終わったら作業開始カードを出します。"$'\n\n'"${NO_PHONE_NOTE}" "$DIALOG_TIMEOUT_SECONDS"
  fi
  wait_until "$end" || rc=$?
  actual=$(secs_to_min $(( $(now_epoch) - start )))
  detect_location
  log_row break "$start" "$(now_epoch)" rest "$P_LABEL" "$rem_min" "$actual" "" "" "" "$LOC"
  return "$rc"
}

# --- 終業の儀式 -----------------------------------------------------------
do_shutdown() {
  local start reflection="" tomorrow=""
  # 会議中は終わるまで待ってから儀式のカードを出す
  while in_zoom_meeting; do
    nap "$POLL_SECONDS"
  done
  start=$(now_epoch)
  state_write shutdown "" "終業の儀式" "$start" 0 0
  say "shutdown ritual"
  play_sound
  dialog_text "終業の儀式 (1/2)" "今日はここまで。今日の振り返りを1行で書いてください。" "" 0
  if [[ "$DLG_STATUS" == "ok" ]]; then reflection=$DLG_TEXT; fi
  dialog_text "終業の儀式 (2/2)" "明日の朝いちばんにやることを書いてください。（翌朝の最初の枠の入力欄に入ります）" "" 0
  if [[ "$DLG_STATUS" == "ok" ]]; then
    tomorrow=$DLG_TEXT
    mkdir -p "$DATA_DIR"
    printf '%s\n' "$tomorrow" > "${DATA_DIR}/tomorrow_first"
  fi
  : > "${DATA_DIR}/next_step"
  detect_location
  log_row shutdown "$start" "$(now_epoch)" "" "終業" "" "" "$reflection" "" "$tomorrow" "$LOC"
  state_write stopped "" "" 0 0 0
  say "shutdown done"
}

# --- メイン ---------------------------------------------------------------
main() {
  mkdir -p "${DATA_DIR}/logs"
  say "starting (profile entries=${#DAY_PROFILE[@]}, scale=${TIME_SCALE}, now=$(now_hhmm))"
  if past_stop; then
    say "after SCHEDULE_STOP_TIME (${SCHEDULE_STOP_TIME}), nothing to do"
    state_write stopped "" "" 0 0 0
    return 0
  fi

  local cycle_idx=-99 cycle_count=0 rc

  while :; do
    if past_stop; then
      do_shutdown
      return 0
    fi
    if before_start; then
      state_write waiting "" "開始待ち" 0 0 0
      nap "$POLL_SECONDS"
      continue
    fi

    profile_find "$(now_hhmm)" || true
    detect_location
    if (( P_IDX != cycle_idx )); then
      cycle_idx=$P_IDX
      cycle_count=0
    fi

    if [[ "$P_KIND" == "rest" ]]; then
      rc=0; do_rest || rc=$?
      continue
    fi

    rc=0; ask_work_start || rc=$?
    if (( rc == 1 )); then do_away; continue; fi
    if (( rc == 2 )); then continue; fi

    rc=0; do_work || rc=$?
    if (( rc == 1 )); then do_away; continue; fi
    if (( rc == 2 )); then continue; fi

    cycle_count=$(( cycle_count + 1 ))
    local btype=short
    if (( P_LONGEVERY > 0 && cycle_count >= P_LONGEVERY )); then
      btype=long
      cycle_count=0
    fi
    rc=0; do_break "$btype" || rc=$?
  done
}

main
