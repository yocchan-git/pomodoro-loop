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

# プロセス管理用 PID ファイル
PID_FILE="${HOME}/.pomodoro-loop.pid"

# ログファイル
LOG_FILE="/tmp/pomodoro-loop.log"

# 自動スケジュールの稼働時間帯（HHMM 4桁）
# `start.sh --scheduled` で起動された時、この範囲外なら何もせず exit する。
# launchd plist (launchd/local.pomodoro-loop.start.plist / .stop.plist) の Hour/Minute と一致させる。
SCHEDULE_START_TIME="0830"
SCHEDULE_STOP_TIME="2030"
