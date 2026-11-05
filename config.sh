#!/bin/bash
# pomodoro-loop の設定。値を変えたい時はここを編集する。

# 作業 / 休憩の長さ（分）
WORK_MINUTES=25
BREAK_MINUTES=5

# 状態ファイル（次に起動するべきフェーズ: "work" or "break"）
# デフォルトはローカル (HOME 直下)。launchd 経由起動でもアクセスできるのでこれが安全。
# iCloud Drive に置きたい場合は下を有効化（要 Full Disk Access、launchd 経由ではブロックされる点に注意）
# STATE_FILE="${HOME}/Library/Mobile Documents/com~apple~CloudDocs/pomodoro_state.txt"
STATE_FILE="${HOME}/.pomodoro_state.txt"

# 通知サウンド（macOS 標準: Glass / Hero / Funk / Submarine / Tink / Frog / Pop / ...）
SOUND="Glass"

# 休憩開始時に実行する macOS ショートカット名（空文字なら何もしない）
BREAK_SHORTCUT="open training video"

# カード（ダイアログ）を自動で閉じるまでの秒数
DIALOG_TIMEOUT_SECONDS=60

# toggle.sh で手動 OFF した日付（YYYYMMDD）を記録するファイル。
# 同じ日は launchd 経由の自動 start（再起動時の RunAtLoad 含む）をスキップする。
OFF_FLAG_FILE="${HOME}/.pomodoro-off-today"

# プロセス管理用 PID ファイル
PID_FILE="${HOME}/.pomodoro-loop.pid"

# ログファイル
LOG_FILE="/tmp/pomodoro-loop.log"

# 自動スケジュールの稼働時間帯（HHMM 4桁）
# `start.sh --scheduled` で起動された時、この範囲外なら何もせず exit する。
# launchd plist (launchd/local.pomodoro-loop.start.plist / .stop.plist) の Hour/Minute と一致させる。
SCHEDULE_START_TIME="1400"
SCHEDULE_STOP_TIME="2200"
