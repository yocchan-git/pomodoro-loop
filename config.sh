#!/bin/bash
# pomodoro-loop の設定。値を変えたい時はここを編集する。
# ほとんどの値は環境変数でも上書きできる（テスト用: TIME_SCALE=1 など）。

# --- データ置き場 ---------------------------------------------------------
# logs/YYYY-MM-DD.tsv、state、next_step、tomorrow_first などを置く。
: "${DATA_DIR:=${HOME}/.pomodoro}"
# 現在の状態（start/status が読む）。launchd 経由でもアクセスできるローカルに置く。
: "${STATE_FILE:=${DATA_DIR}/state}"
# toggle.sh で手動 OFF した日付（YYYYMMDD）。同じ日は launchd の自動 start をスキップする。
: "${OFF_FLAG_FILE:=${HOME}/.pomodoro-off-today}"
: "${PID_FILE:=${HOME}/.pomodoro-loop.pid}"
: "${LOG_FILE:=/tmp/pomodoro-loop.log}"

# --- 1日のリズム ----------------------------------------------------------
# "HHMM-HHMM|kind|work分|break分|長休憩までの回数|長休憩分|ラベル"
#   kind: deep / shallow / light / rest（rest は作業せずカードを1枚出すだけ）
#   長休憩までの回数 0 = 長休憩なし。どの帯にも当たらない時刻は 25/5 の「通常」帯として扱う。
# 環境変数 DAY_PROFILE_OVERRIDE（改行区切り）があれば、そちらを使う（テスト用）。
DAY_PROFILE=(
  "0600-0615|rest|0|0|0|0|朝日を浴びる（バルコニーで5〜10分）"
  "0615-1130|deep|50|10|3|30|午前の深い作業"
  "1130-1230|rest|0|0|0|0|昼食（断食明けの食事）"
  "1230-1500|shallow|25|5|4|20|午後の浅い作業（細かいタスク・事務）"
  "1500-1800|deep|50|10|3|20|午後の深い作業"
  "1800-2030|rest|0|0|0|0|運動（ジム）＋夕食"
)
if [[ -n "${DAY_PROFILE_OVERRIDE:-}" ]]; then
  DAY_PROFILE=()
  while IFS= read -r _line; do
    [[ -n "$_line" ]] && DAY_PROFILE+=("$_line")
  done <<<"$DAY_PROFILE_OVERRIDE"
  unset _line
fi

# どの帯にも当たらない時の作業 / 休憩（分）
: "${WORK_MINUTES:=25}"
: "${BREAK_MINUTES:=5}"

# 自動スケジュールの稼働時間帯（HHMM 4桁）。
# STOP_TIME になったら終業の儀式をしてループが自分で終わる。
# launchd plist の start は SCHEDULE_START_TIME、stop は安全網（STOP_TIME の少し後）。
: "${SCHEDULE_START_TIME:=0600}"
: "${SCHEDULE_STOP_TIME:=2030}"

# その日の deep 作業がこの分数に達したら、開始カードで浅い作業への切り替えを勧める
: "${DEEP_CAP_MINUTES:=240}"

# --- 離席の判定 -----------------------------------------------------------
# 休憩明けにこの秒数以上、操作がなければ「外出中」とみなす
: "${AWAY_IDLE_SECONDS:=300}"
# 作業中にこの秒数以上、操作がなければその枠を「中断」として外出中へ
: "${WORK_ABANDON_IDLE_SECONDS:=1200}"

# --- 休憩の中身 -----------------------------------------------------------
# 筋トレ動画は午後の落ち込み対策として、短い休憩にだけ・1日の上限つきで回す
: "${TRAINING_SHORTCUT:=open training video}"
: "${TRAINING_MAX_PER_DAY:=2}"
: "${TRAINING_WINDOW:=1300-1800}"

# --- 場所の判定（オフィス / WeWork など） ---------------------------------
# scutil --dns の search domain[0] と照合するドメイン（空白区切り）。一致したら office モード。
# office モードでは筋トレ動画とバルコニー系のメニューを外す。
: "${OFFICE_DNS_DOMAINS:=}"

# --- 任意の連携 -----------------------------------------------------------
# 集中モードの ON/OFF 用ショートカット名（空なら何もしない）
: "${WORK_START_SHORTCUT:=}"
: "${BREAK_START_SHORTCUT:=}"
# 長休憩（午後の浅い帯）で開く NSDR 音声の URL（空なら文章で案内するだけ）
: "${NSDR_URL:=}"

# --- 通知 -----------------------------------------------------------------
# 通知サウンド（macOS 標準: Glass / Hero / Funk / Submarine / Tink / Frog / Pop / ...）
: "${SOUND:=Glass}"
# 休憩カードを自動で閉じるまでの秒数
: "${DIALOG_TIMEOUT_SECONDS:=60}"
# 作業開始カードを出し直す間隔（秒）
: "${REMIND_SECONDS:=120}"

# --- 時計・テスト用 -------------------------------------------------------
# 1分が何秒か（テストでは 1）
: "${TIME_SCALE:=60}"
# 状態を確認する間隔（秒）。テストでは 1
: "${POLL_SECONDS:=15}"
# HHMM を入れると、その時刻から始まる仮想時計になる（実時間 1 分 = 仮想 60/TIME_SCALE 分で進む）
: "${FAKE_NOW:=}"

# --- 個人の上書き設定 -----------------------------------------------------
# git に入れたくない値（オフィスのドメインなど）は config.local.sh に書く（.gitignore 済み）。
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/config.local.sh" ]]; then
  # shellcheck source=/dev/null
  source "$(dirname "${BASH_SOURCE[0]}")/config.local.sh"
fi
