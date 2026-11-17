#!/bin/bash
# shellcheck disable=SC2034  # 他ファイルから参照するグローバル変数

# TSV ログと、そこからの集計。
# columns: type start end kind label planned_min actual_min intent result next_step location

TSV_HEADER=$'type\tstart\tend\tkind\tlabel\tplanned_min\tactual_min\tintent\tresult\tnext_step\tlocation'

# タブ・改行を空白に（TSV を壊さない）
tsv_clean() { printf '%s' "$1" | tr '\t\r\n' '   '; }

log_today_file() { echo "${DATA_DIR}/logs/$(date +%F).tsv"; }

# log_row type start_epoch end_epoch kind label planned actual intent result next_step location
log_row() {
  local f
  f=$(log_today_file)
  mkdir -p "$(dirname "$f")"
  if [[ ! -f "$f" ]]; then
    printf '%s\n' "$TSV_HEADER" > "$f"
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(tsv_clean "$1")" "$(fmt_vtime "$2")" "$(fmt_vtime "$3")" \
    "$(tsv_clean "$4")" "$(tsv_clean "$5")" "$(tsv_clean "$6")" "$(tsv_clean "$7")" \
    "$(tsv_clean "$8")" "$(tsv_clean "$9")" "$(tsv_clean "${10}")" "$(tsv_clean "${11}")" >> "$f"
}

# 今日の集計
_tsv_awk() {
  local f
  f=$(log_today_file)
  if [[ -f "$f" ]]; then
    awk -F'\t' "$1" "$f"
  else
    echo 0
  fi
}
today_work_count() { _tsv_awk '$1=="work" {n++} END{print n+0}'; }
today_deep_min() { _tsv_awk '$1=="work" && $4=="deep" {s+=$7} END{print s+0}'; }
today_training_count() { _tsv_awk '$1=="break" && $5=="筋トレ動画" {n++} END{print n+0}'; }
