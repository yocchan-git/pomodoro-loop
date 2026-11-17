#!/bin/bash
# shellcheck disable=SC2034  # 他ファイルから参照するグローバル変数

# ダイアログ。文字列はすべて osascript の argv で渡す（スクリプトに埋め込まない）。
# 結果は DLG_STATUS (ok|timeout|cancel|zoom) と DLG_TEXT に入れる。
# Zoom 会議中（画面共有中を含む）は、ダイアログ・音・ショートカット・URL を一切出さない（DLG_STATUS=zoom）。
# 表示中に会議が始まった場合も、ダイアログを閉じる（_osa 参照）。
# テスト: POMODORO_DIALOG_MOCK=ファイル で、入力を伴うダイアログ（text/buttons）は
#   1行ずつ回答を読む（<CANCEL> / <TIMEOUT> も可。尽きたら既定値）。info は消費せず stderr に出すだけ。
#   POMODORO_NO_SIDE_EFFECTS=1 で afplay / shortcuts / open を実行しない。

: "${POMODORO_DIALOG_MOCK:=}"
: "${POMODORO_NO_SIDE_EFFECTS:=}"

read -r -d '' OSA_TEXT <<'AS' || true
on run argv
  set ttl to item 1 of argv
  set msg to item 2 of argv
  set def to item 3 of argv
  set secs to (item 4 of argv) as integer
  tell application "System Events"
    activate
    if secs > 0 then
      set r to display dialog msg with title ttl default answer def buttons {"OK"} default button "OK" with icon note giving up after secs
    else
      set r to display dialog msg with title ttl default answer def buttons {"OK"} default button "OK" with icon note
    end if
    if gave up of r then
      return "TIMEOUT"
    end if
    return "OK" & linefeed & (text returned of r)
  end tell
end run
AS

read -r -d '' OSA_BUTTONS <<'AS' || true
on run argv
  set ttl to item 1 of argv
  set msg to item 2 of argv
  set btns to items 3 thru -1 of argv
  tell application "System Events"
    activate
    set r to display dialog msg with title ttl buttons btns default button (item 1 of btns) with icon note
    return "OK" & linefeed & (button returned of r)
  end tell
end run
AS

read -r -d '' OSA_INFO <<'AS' || true
on run argv
  set ttl to item 1 of argv
  set msg to item 2 of argv
  set secs to (item 3 of argv) as integer
  tell application "System Events"
    activate
    if secs > 0 then
      display dialog msg with title ttl buttons {"OK"} default button "OK" with icon note giving up after secs
    else
      display dialog msg with title ttl buttons {"OK"} default button "OK" with icon note
    end if
  end tell
  return "OK"
end run
AS

# osascript をバックグラウンドで走らせて wait する（SIGTERM で trap が即座に動けるように）
# 結果: OSA_RC / OSA_OUT
_osa() {
  local script=$1 tmp pid rc=0
  shift
  tmp=$(mktemp "${TMPDIR:-/tmp}/pomodoro-osa.XXXXXX")
  osascript - "$@" >"$tmp" 2>/dev/null <<<"$script" &
  pid=$!
  OSA_ZOOM=0
  # 表示中に Zoom 会議・画面共有が始まったらダイアログを閉じる。
  # ダイアログは System Events が持っているため、osascript を kill しても消えない。
  # System Events を終了させると消える（次に使うとき自動で再起動する）。
  while kill -0 "$pid" 2>/dev/null; do
    if in_zoom_meeting; then
      kill "$pid" 2>/dev/null || true
      pkill -x "System Events" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      rm -f "$tmp"
      OSA_OUT=""; OSA_RC=0; OSA_ZOOM=1
      return 0
    fi
    sleep 2 &
    wait $! || true
  done
  wait "$pid" || rc=$?
  OSA_OUT=$(cat "$tmp")
  rm -f "$tmp"
  OSA_RC=$rc
}

# OSA_OUT を DLG_STATUS / DLG_TEXT に（Esc などで osascript が非ゼロ終了 = cancel）
_osa_parse() {
  DLG_STATUS=ok
  DLG_TEXT=""
  if [[ "${OSA_ZOOM:-0}" == "1" ]]; then
    DLG_STATUS=zoom
    return 0
  fi
  if [[ "$OSA_RC" -ne 0 ]]; then
    DLG_STATUS=cancel
    return 0
  fi
  local first=${OSA_OUT%%$'\n'*}
  if [[ "$first" == "TIMEOUT" ]]; then
    DLG_STATUS=timeout
  elif [[ "$OSA_OUT" == *$'\n'* ]]; then
    DLG_TEXT=$(tsv_clean "${OSA_OUT#*$'\n'}")
  fi
  return 0
}

# モックの次の1行を MOCK_LINE に。尽きていたら 1。
_mock_next() {
  local pos_file="${POMODORO_DIALOG_MOCK}.pos" n=0 total
  if [[ -f "$pos_file" ]]; then
    n=$(cat "$pos_file")
  fi
  n=$((n + 1))
  total=$(awk 'END{print NR}' "$POMODORO_DIALOG_MOCK")
  if (( n > total )); then
    return 1
  fi
  MOCK_LINE=$(sed -n "${n}p" "$POMODORO_DIALOG_MOCK")
  echo "$n" > "$pos_file"
  return 0
}

# Zoom 会議中なら DLG_STATUS=zoom にして 0 を返す（ダイアログは出さない）
_zoom_skip() {
  if in_zoom_meeting; then
    echo "[zoom] skip dialog:$1 $2" >&2
    DLG_STATUS=zoom; DLG_TEXT=""
    return 0
  fi
  return 1
}

_mock_log() { printf '[dialog:%s] %s | %s\n' "$1" "$2" "$3" >&2; }

# dialog_text title msg default timeout_secs(0=なし)
dialog_text() {
  local title=$1 msg=$2 def=${3:-} secs=${4:-0}
  if _zoom_skip text "$title"; then DLG_TEXT=$def; return 0; fi
  if [[ -n "$POMODORO_DIALOG_MOCK" ]]; then
    _mock_log text "$title" "$(tsv_clean "$msg") (default=$def, timeout=$secs)"
    DLG_STATUS=ok
    DLG_TEXT=$def
    if _mock_next; then
      case "$MOCK_LINE" in
        '<CANCEL>')  DLG_STATUS=cancel; DLG_TEXT="" ;;
        '<TIMEOUT>') DLG_STATUS=timeout; DLG_TEXT="" ;;
        *)           DLG_TEXT=$(tsv_clean "$MOCK_LINE") ;;
      esac
    fi
    return 0
  fi
  _osa "$OSA_TEXT" "$title" "$msg" "$def" "$secs"
  _osa_parse
}

# dialog_buttons title msg button1 [button2 button3]  （先頭が既定。結果は DLG_TEXT）
dialog_buttons() {
  local title=$1 msg=$2
  shift 2
  if _zoom_skip buttons "$title"; then return 0; fi
  if [[ -n "$POMODORO_DIALOG_MOCK" ]]; then
    _mock_log buttons "$title" "$(tsv_clean "$msg") (buttons=$*)"
    DLG_STATUS=ok
    DLG_TEXT=$1
    if _mock_next; then
      if [[ "$MOCK_LINE" == '<CANCEL>' ]]; then
        DLG_STATUS=cancel; DLG_TEXT=""
      else
        DLG_TEXT=$MOCK_LINE
      fi
    fi
    return 0
  fi
  _osa "$OSA_BUTTONS" "$title" "$msg" "$@"
  _osa_parse
}

# dialog_info title msg timeout_secs(0=なし)  OK を押す or タイムアウトで閉じる
dialog_info() {
  local title=$1 msg=$2 secs=${3:-0}
  if _zoom_skip info "$title"; then return 0; fi
  if [[ -n "$POMODORO_DIALOG_MOCK" ]]; then
    _mock_log info "$title" "$(tsv_clean "$msg") (timeout=$secs)"
    DLG_STATUS=ok; DLG_TEXT=""
    return 0
  fi
  _osa "$OSA_INFO" "$title" "$msg" "$secs"
  _osa_parse
}

play_sound() {
  [[ "$POMODORO_NO_SIDE_EFFECTS" == "1" ]] && return 0
  in_zoom_meeting && return 0
  local f="/System/Library/Sounds/${SOUND}.aiff"
  if [[ -f "$f" ]]; then
    afplay "$f" >/dev/null 2>&1 &
  fi
  return 0
}

# run_shortcut "ショートカット名"（空なら何もしない）
run_shortcut() {
  [[ -n "${1:-}" ]] || return 0
  if in_zoom_meeting; then
    echo "[zoom] skip shortcut: $1" >&2
    return 0
  fi
  if [[ "$POMODORO_NO_SIDE_EFFECTS" == "1" ]]; then
    echo "[side-effect skipped] shortcuts run $1" >&2
    return 0
  fi
  shortcuts run "$1" >/dev/null 2>&1 &
  return 0
}

open_url() {
  [[ -n "${1:-}" ]] || return 0
  if in_zoom_meeting; then
    echo "[zoom] skip open: $1" >&2
    return 0
  fi
  if [[ "$POMODORO_NO_SIDE_EFFECTS" == "1" ]]; then
    echo "[side-effect skipped] open $1" >&2
    return 0
  fi
  open "$1" >/dev/null 2>&1 || true
  return 0
}
