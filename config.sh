#!/bin/bash
# pomodoro-loop の設定。値を変えたい時はここを編集する。

# 作業 / 休憩の長さ（分）
WORK_MINUTES=25
BREAK_MINUTES=5

# 状態ファイル（次に起動するべきフェーズ: "work" or "break"）
# デフォルトは iCloud Drive 配下。他デバイスから観測したくない場合は ~/.pomodoro_state.txt 等に変更可
STATE_FILE="${HOME}/Library/Mobile Documents/com~apple~CloudDocs/pomodoro_state.txt"

# 通知サウンド（macOS 標準: Glass / Hero / Funk / Submarine / Tink / Frog / Pop / ...）
SOUND="Glass"

# プロセス管理用 PID ファイル
PID_FILE="${HOME}/.pomodoro-loop.pid"

# ログファイル
LOG_FILE="/tmp/pomodoro-loop.log"
