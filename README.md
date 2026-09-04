# db-study

Claude をデータベース講師として学習した記録。

- カリキュラム: [CURRICULUM.md](CURRICULUM.md)
- 進捗: [PROGRESS.md](PROGRESS.md)
- 各章の記録: [lessons/](lessons/)
- 学習環境: [docker/](docker/) — MySQL 8.4

## 開始方法
Claude Code で「学習を始めましょう」と伝える。

## 学習リマインダー（Slack 通知）
毎日 10:00 JST に GitHub Actions が [`study-log/last_study_at.txt`](study-log/last_study_at.txt) を見て、
「前日」に学習していれば賞賛、していなければ指摘を Slack へ投稿する。

**「前日」の定義**: 前日 10:00 〜 当日 09:59 (JST)。
ワークフローの起動時刻 10:00 を境にした 1 日分なので、当日の朝に学習した分もこの窓に入る。

- 最終学習日時の更新: 章が終わったら `./scripts/record_study.sh`（1 行だけを上書き）
  - 後追い記録: `./scripts/record_study.sh 2026-09-04`（その日の 12:00 とみなす）
  - 時刻まで指定: `./scripts/record_study.sh 2026-09-04T21:35:00+0900`
  - 記録済みより古い日時では上書きしない
- 通知ロジック: [`scripts/notify_study_status.sh`](scripts/notify_study_status.sh) / 日付処理: [`scripts/study_date_lib.sh`](scripts/study_date_lib.sh)
- ワークフロー: [`.github/workflows/study-check.yml`](.github/workflows/study-check.yml)

### 初期設定
| 種別 | 名前 | 値 |
|---|---|---|
| Secret | `SLACK_BOT_TOKEN` | Slack App の Bot Token (`xoxb-...`)。スコープ `chat:write` が必要 |
| Variable | `SLACK_CHANNEL_ID` | 投稿先 `#db-study` のチャンネル ID (`C...`)。Bot を招待しておく |

設定場所は Settings → Secrets and variables → Actions。
チャンネル ID は Slack でチャンネル名をクリック → 一番下に表示される `C...` をコピーする。
手動実行は Actions タブの study-check → Run workflow（`dry_run` を on にすると Slack に投げずログ出力のみ）。

ローカル確認:
```bash
DRY_RUN=true ./scripts/notify_study_status.sh
```
