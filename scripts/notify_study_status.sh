#!/usr/bin/env bash
# 「前日 10:00 〜 当日 09:59 (JST)」に学習記録があるかを判定し、Slack に通知する。
# この時間帯は GitHub Actions の起動時刻（毎日 10:00 JST）を基準にした 1 日分。
#
# 必要な環境変数:
#   SLACK_BOT_TOKEN   Slack App の Bot Token (xoxb-...)
#   SLACK_CHANNEL_ID  投稿先チャンネル ID (例: C0123456789)
# 任意:
#   DRY_RUN=true      Slack に投げず、メッセージを標準出力に出すだけ
#   STUDY_LOG_FILE    最終学習日時ファイルのパス (既定: study-log/last_study_at.txt)
#   SLACK_USERNAME    投稿時の表示名 (既定: DB 講師) ※ chat:write.customize が必要
#   SLACK_ICON_EMOJI  投稿時のアイコン (既定: :books:) ※ 同上
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

TODAY="$(TZ=Asia/Tokyo date +%F)"
YESTERDAY="$(shift_days "$TODAY" -1)"
WINDOW_START="$(jst_epoch "$YESTERDAY 10:00:00")"
WINDOW_END="$(jst_epoch "$TODAY 09:59:59")"
NOW="$(date +%s)"

WINDOW_LABEL="${YESTERDAY} 10:00 〜 ${TODAY} 09:59"

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
  # 手動実行などで 10:00 以降に走ったケース。今日の分はもう終わっている
  COLOR="$COLOR_OK"
  SUMMARY="今日はもう学習済みです"
  MESSAGE=":muscle: *今日はもう学習済みですね。さすが。*
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
やっていたのに記録し忘れただけなら \`./scripts/record_study.sh ${YESTERDAY}\` で更新しておきましょう。"
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
# 通知バナーやスレッド一覧には最上位の text が出るので、そこには要約を入れる。
payload="$(jq -n \
  --arg channel  "$SLACK_CHANNEL_ID" \
  --arg summary  "$SUMMARY" \
  --arg text     "$MESSAGE" \
  --arg color    "$COLOR" \
  --arg username "$SLACK_USERNAME" \
  --arg icon     "$SLACK_ICON_EMOJI" \
  '{
     channel: $channel,
     text: $summary,
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
