#!/bin/bash
# shellcheck disable=SC2034  # 他ファイルから参照するグローバル変数

# DAY_PROFILE の解析。profile_find HHMM で P_* に今の帯を入れる。
# 当たらなければ WORK_MINUTES/BREAK_MINUTES の「通常」帯（P_IDX=-1）にして 1 を返す。

profile_find() {
  local hhmm=$((10#$1)) entry range s e i=0
  P_IDX=-1; P_START=0000; P_END=2400
  P_KIND=light; P_WORK=$WORK_MINUTES; P_BREAK=$BREAK_MINUTES
  P_LONGEVERY=0; P_LONGMIN=0; P_LABEL="通常"
  if [[ ${#DAY_PROFILE[@]} -eq 0 ]]; then
    return 1
  fi
  for entry in "${DAY_PROFILE[@]}"; do
    IFS='|' read -r range P_KIND P_WORK P_BREAK P_LONGEVERY P_LONGMIN P_LABEL <<<"$entry"
    s=${range%-*}
    e=${range#*-}
    if (( 10#$s <= hhmm && hhmm < 10#$e )); then
      P_START=$s; P_END=$e; P_IDX=$i
      [[ "$P_WORK" =~ ^[0-9]+$ ]] || P_WORK=$WORK_MINUTES
      [[ "$P_BREAK" =~ ^[0-9]+$ ]] || P_BREAK=$BREAK_MINUTES
      [[ "$P_LONGEVERY" =~ ^[0-9]+$ ]] || P_LONGEVERY=0
      [[ "$P_LONGMIN" =~ ^[0-9]+$ ]] || P_LONGMIN=0
      return 0
    fi
    i=$((i + 1))
  done
  P_IDX=-1; P_START=0000; P_END=2400
  P_KIND=light; P_WORK=$WORK_MINUTES; P_BREAK=$BREAK_MINUTES
  P_LONGEVERY=0; P_LONGMIN=0; P_LABEL="通常"
  return 1
}
