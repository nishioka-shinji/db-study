#!/usr/bin/env bash
# 最終学習日時を study-log/last_study_at.txt に記録する（1 行だけの上書き）。
#
# 使い方:
#   ./scripts/record_study.sh                       今の時刻(JST)で更新
#   ./scripts/record_study.sh 2026-09-04            その日の 12:00 JST として後追い記録
#   ./scripts/record_study.sh 2026-09-04T21:35:00+0900   時刻まで指定して後追い記録
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/study_date_lib.sh
source scripts/study_date_lib.sh

LOG_FILE="${STUDY_LOG_FILE:-study-log/last_study_at.txt}"
INPUT="${1:-}"

if [[ -z "$INPUT" ]]; then
  STAMP="$(TZ=Asia/Tokyo date +%Y-%m-%dT%H:%M:%S%z)"
elif [[ "$INPUT" =~ $DATE_RE ]]; then
  STAMP="${INPUT}T12:00:00+0900"   # 日付だけ渡された場合は正午とみなす
elif [[ "$INPUT" =~ $STAMP_RE ]]; then
  STAMP="$INPUT"
else
  echo "日付は YYYY-MM-DD か YYYY-MM-DDThh:mm:ss+0900 の形式で指定してください: ${INPUT}" >&2
  exit 1
fi

NEW_EPOCH="$(stamp_epoch "$STAMP")"
CURRENT_EPOCH="$(read_last_epoch "$LOG_FILE")"

# より新しい記録を古い日時で上書きしない（"last" の意味を壊さないため）
if [[ -n "$CURRENT_EPOCH" ]] && (( NEW_EPOCH <= CURRENT_EPOCH )); then
  echo "記録済みの $(jst_fmt "$CURRENT_EPOCH" '%Y-%m-%d %H:%M') 以前なので更新しません（指定: ${STAMP}）"
  exit 0
fi

mkdir -p "$(dirname "$LOG_FILE")"
printf '%s\n' "$STAMP" > "$LOG_FILE"
echo "最終学習日時を $(jst_fmt "$NEW_EPOCH" '%Y-%m-%d %H:%M') に更新しました（${LOG_FILE}）"
