#!/usr/bin/env bash
# 「前日 10:00 〜 当日 09:59 (JST)」に学習記録があるかを判定し、Slack に通知する。
#
# 判定期間は *実際に起動した時刻ではなく* 予定時刻 (既定 10:00 JST) から逆算する。
# GitHub Actions の schedule はベストエフォートで、数十分〜数時間遅れて起動する。
# 起動時刻をそのまま基準にすると、日付をまたぐほど遅れたときに判定期間が丸 1 日
# ずれて「その日の分を黙って飛ばす」ため、直近の予定時刻に吸着させている。
#
# 必要な環境変数:
#   SLACK_BOT_TOKEN   Slack App の Bot Token (xoxb-...)
#   SLACK_CHANNEL_ID  投稿先チャンネル ID (例: C0123456789)
# 任意:
#   DRY_RUN=true      Slack に投げず、メッセージを標準出力に出すだけ
#   STUDY_LOG_FILE    最終学習日時ファイルのパス (既定: study-log/last_study_at.txt)
#   SLACK_USERNAME    投稿時の表示名 (既定: DB 講師) ※ chat:write.customize が必要
#   SLACK_ICON_EMOJI  投稿時のアイコン (既定: :books:) ※ 同上
#   NOTIFY_HOUR_JST   通知の予定時刻・時 (既定: 10)。workflow の cron と揃える
#   NOW_OVERRIDE      現在時刻を epoch で上書き（テスト用）
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/study_date_lib.sh
source scripts/study_date_lib.sh

LOG_FILE="${STUDY_LOG_FILE:-study-log/last_study_at.txt}"
DRY_RUN="${DRY_RUN:-false}"
# 空文字で渡ってきた場合も既定値にフォールバックさせる
SLACK_USERNAME="${SLACK_USERNAME:-DB 講師}"
SLACK_ICON_EMOJI="${SLACK_ICON_EMOJI:-:books:}"

# 添付の左端に出る色バー（学習した=緑 / してない=赤）
COLOR_OK="#2eb886"
COLOR_NG="#e01e5a"

NOTIFY_HOUR_JST="${NOTIFY_HOUR_JST:-10}"
NOW="${NOW_OVERRIDE:-$(date +%s)}"

# 予定時刻の少し前に起動した場合も「その日の回」とみなすための猶予。
# cron を 09:43 JST に置いて遅延が無いときが、ちょうどこのケースになる。
ANCHOR_GRACE_SECONDS="${ANCHOR_GRACE_SECONDS:-3600}"

# ANCHOR = (NOW + 猶予) 以前で最も近い NOTIFY_HOUR_JST 時ちょうど (JST)。
# 起動がどれだけ遅れても、遅延が 24 時間未満なら本来の予定時刻に吸着する。
anchor_of_day() { jst_epoch "$1 $(printf '%02d' "$NOTIFY_HOUR_JST"):00:00"; }
PROBE=$(( NOW + ANCHOR_GRACE_SECONDS ))
PROBE_DATE="$(jst_fmt "$PROBE" '%Y-%m-%d')"
ANCHOR="$(anchor_of_day "$PROBE_DATE")"
if (( ANCHOR > PROBE )); then
  ANCHOR="$(anchor_of_day "$(shift_days "$PROBE_DATE" -1)")"
fi

WINDOW_START=$(( ANCHOR - 86400 ))
WINDOW_END=$(( ANCHOR - 1 ))
WINDOW_START_DATE="$(jst_fmt "$WINDOW_START" '%Y-%m-%d')"
WINDOW_LABEL="$(jst_fmt "$WINDOW_START" '%Y-%m-%d %H:%M') 〜 $(jst_fmt "$WINDOW_END" '%Y-%m-%d %H:%M')"

# 遅延の実測値をログに残す（Slack には出さない）。慢性的に大きいなら cron の見直し材料。
LAG=$(( NOW - ANCHOR ))
printf '予定 %s / 実行 %s / 遅延 %dh%02dm\n' \
  "$(jst_fmt "$ANCHOR" '%Y-%m-%d %H:%M')" \
  "$(jst_fmt "$NOW" '%Y-%m-%d %H:%M')" \
  "$(( LAG / 3600 ))" "$(( (LAG % 3600) / 60 ))" >&2

LAST_EPOCH="$(read_last_epoch "$LOG_FILE")"

if [[ -z "$LAST_EPOCH" ]]; then
  COLOR="$COLOR_NG"
  SUMMARY="まだ学習記録がありません"
  MESSAGE=":eyes: *まだ学習記録がありません。*
\`${LOG_FILE}\` が空です。最初の 1 章、今日はじめませんか？"

elif (( LAST_EPOCH >= WINDOW_START && LAST_EPOCH <= WINDOW_END )); then
  COLOR="$COLOR_OK"
  SUMMARY="昨日は学習していました"
  MESSAGE=":tada: *昨日（${WINDOW_LABEL}）はちゃんと学習してましたね！えらい。*
最終学習: $(jst_fmt "$LAST_EPOCH" '%Y-%m-%d %H:%M')
この調子で今日も 1 章いきましょう。"

elif (( LAST_EPOCH > WINDOW_END )); then
  # 判定期間より後に学習済み。手動実行や、起動が大きく遅れた回で起きる
  COLOR="$COLOR_OK"
  SUMMARY="判定期間の後に学習済みです"
  MESSAGE=":muscle: *もう次の学習を済ませていますね。さすが。*
最終学習: $(jst_fmt "$LAST_EPOCH" '%Y-%m-%d %H:%M')
（判定対象の ${WINDOW_LABEL} には記録がありません）"

else
  DIFF=$(( NOW - LAST_EPOCH ))
  if (( DIFF < 86400 )); then
    AGO="$(( DIFF / 3600 )) 時間前"
  else
    AGO="$(( DIFF / 86400 )) 日前"
  fi
  COLOR="$COLOR_NG"
  SUMMARY="昨日の学習記録がありません（最終学習: $(jst_fmt "$LAST_EPOCH" '%Y-%m-%d %H:%M')）"
  MESSAGE=":eyes: *昨日（${WINDOW_LABEL}）の学習記録がありません。昨日は学習しましたか？*
最終学習: $(jst_fmt "$LAST_EPOCH" '%Y-%m-%d %H:%M')（${AGO}）
やっていたのに記録し忘れただけなら \`./scripts/record_study.sh ${WINDOW_START_DATE}\` で更新しておきましょう。"
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "--- DRY RUN (Slack へは送信しません) ---"
  echo "color: ${COLOR} / summary: ${SUMMARY}"
  echo "$MESSAGE"
  exit 0
fi

: "${SLACK_BOT_TOKEN:?SLACK_BOT_TOKEN が未設定です（リポジトリ Secrets に登録してください）}"
: "${SLACK_CHANNEL_ID:?SLACK_CHANNEL_ID が未設定です（リポジトリ Variables に登録してください）}"

# 色バーを付けるため attachments を使う。
# 最上位に text を置くと本文が二重に表示されるので置かない。
# 通知バナーに出る文言は attachment の fallback で指定する。
payload="$(jq -n \
  --arg channel  "$SLACK_CHANNEL_ID" \
  --arg summary  "$SUMMARY" \
  --arg text     "$MESSAGE" \
  --arg color    "$COLOR" \
  --arg username "$SLACK_USERNAME" \
  --arg icon     "$SLACK_ICON_EMOJI" \
  '{
     channel: $channel,
     username: $username,
     icon_emoji: $icon,
     attachments: [
       { color: $color, fallback: $summary, text: $text, mrkdwn_in: ["text"] }
     ]
   }')"

response="$(curl -sS -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer ${SLACK_BOT_TOKEN}" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data "$payload")"

if [[ "$(jq -r '.ok' <<<"$response")" != "true" ]]; then
  echo "Slack への投稿に失敗しました: $(jq -r '.error // .' <<<"$response")" >&2
  exit 1
fi

echo "Slack に通知しました (channel: ${SLACK_CHANNEL_ID} / name: ${SLACK_USERNAME} / color: ${COLOR})"
