#!/bin/bash
# shellcheck disable=SC2034  # 他ファイルから参照するグローバル変数

# 休憩メニュー。種類・時間帯・場所・筋トレ回数から1つ選び、BM_KEY / BM_NAME / BM_TEXT / BM_ACTION を設定する。
# 同じものが連続しないよう、直前のキーを DATA_DIR/last_break に覚えて除外する。

TRAINING_LABEL="筋トレ動画"
NO_PHONE_NOTE="※ 休憩中はスマホ・SNS・YouTube は触らない（注意が前の作業に残るのと、ドーパミンの消耗を避けるため）"

# in_range HHMM "HHMM-HHMM"
in_range() {
  local s=${2%-*} e=${2#*-}
  (( 10#$1 >= 10#$s && 10#$1 < 10#$e ))
}

# pick_break short|long HHMM location   （P_KIND は profile_find 済み）
pick_break() {
  local type=$1 hhmm=$2 loc=$3 last="" cands="" k
  local -a all filtered
  if [[ -f "${DATA_DIR}/last_break" ]]; then
    last=$(cat "${DATA_DIR}/last_break")
  fi

  if [[ "$type" == "long" ]]; then
    if [[ "$P_KIND" == "shallow" ]]; then
      cands="nsdr nap"
    else
      cands="indoor_walk"
      if [[ "$loc" == "home" ]]; then cands="$cands balcony_long"; fi
    fi
  else
    cands="stretch eyes"
    if [[ "$loc" == "home" ]]; then
      cands="$cands exercise balcony"
      if (( 10#$hhmm < 1200 )); then cands="$cands balcony"; fi   # 午前は優先
      if [[ -n "${TRAINING_SHORTCUT:-}" ]] \
         && (( $(today_training_count) < TRAINING_MAX_PER_DAY )) \
         && in_range "$hhmm" "$TRAINING_WINDOW"; then
        cands="$cands training"
      fi
    else
      cands="$cands office_walk"
    fi
  fi

  # shellcheck disable=SC2206
  all=($cands)
  filtered=()
  for k in "${all[@]}"; do
    if [[ "$k" != "$last" ]]; then filtered+=("$k"); fi
  done
  if [[ ${#filtered[@]} -eq 0 ]]; then filtered=("${all[@]}"); fi
  BM_KEY=${filtered[$(( RANDOM % ${#filtered[@]} ))]}
  mkdir -p "$DATA_DIR"
  echo "$BM_KEY" > "${DATA_DIR}/last_break"

  BM_ACTION=""
  case "$BM_KEY" in
    balcony)
      BM_NAME="バルコニーで遠くを見る＋ため息2回"
      BM_TEXT="バルコニーに出て、できるだけ遠くを見る。鼻から2回吸って口から長く吐く「ため息2回（cyclic sighing）」を数セット。" ;;
    stretch)
      BM_NAME="水＋ストレッチ"
      BM_TEXT="水を飲んで、首・肩・股関節をゆっくり伸ばす。" ;;
    exercise)
      BM_NAME="軽い運動3分"
      BM_TEXT="息が上がらない程度に、スクワットや足踏みなどを3分。疲れを残さない強度で。" ;;
    eyes)
      BM_NAME="目を閉じて何もしない"
      BM_TEXT="座って目を閉じ、何もしない3分。考えが浮かんでも追わない。" ;;
    office_walk)
      BM_NAME="席を立って歩く"
      BM_TEXT="席を立って少し歩き、水を飲む。画面から目を離して遠くを見る。" ;;
    training)
      BM_NAME="$TRAINING_LABEL"
      BM_TEXT="午後の落ち込み対策に、短い筋トレ動画を1本。（今日 $(( $(today_training_count) + 1 ))/${TRAINING_MAX_PER_DAY} 回目）"
      BM_ACTION="training" ;;
    nsdr)
      BM_NAME="NSDR（脱力して休む）"
      BM_TEXT="横になるか椅子にもたれて、NSDR で脱力する。"
      if [[ -n "${NSDR_URL:-}" ]]; then BM_TEXT="${BM_TEXT}音声を開きます。"; fi
      BM_ACTION="nsdr" ;;
    nap)
      BM_NAME="仮眠（20分以内）"
      BM_TEXT="アラームをかけて20分以内の仮眠。寝られなくても目を閉じて横になるだけでよい。" ;;
    indoor_walk)
      BM_NAME="室内を歩く＋水分＋軽食"
      BM_TEXT="部屋の中を歩き、水分と軽食をとる。" ;;
    balcony_long)
      BM_NAME="バルコニーで休む"
      BM_TEXT="バルコニーで外の空気を吸い、遠くを見てぼんやりする。" ;;
    *)
      BM_NAME="休憩"
      BM_TEXT="画面から離れて休む。" ;;
  esac
}
