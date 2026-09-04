# 日付ユーティリティ（GNU date / BSD date 両対応）。source して使う。
# 学習記録は常に JST(+0900) で扱う。日本には DST がないのでオフセットは固定。

if date -d "2000-01-01" +%F >/dev/null 2>&1; then
  # GNU date (Linux / GitHub Actions runner)
  shift_days()  { date -u -d "$1 $2 day" +%F; }                       # $1=YYYY-MM-DD $2=±N
  jst_epoch()   { TZ=Asia/Tokyo date -d "$1" +%s; }                   # $1="YYYY-MM-DD HH:MM:SS"
  stamp_epoch() { date -d "$1" +%s; }                                 # $1=ISO8601 (+0900 付き)
  jst_fmt()     { TZ=Asia/Tokyo date -d "@$1" "+$2"; }                # $1=epoch $2=format
else
  # BSD date (macOS)
  shift_days()  { date -u -j -v"$2"d -f "%Y-%m-%d" "$1" +%F; }
  jst_epoch()   { TZ=Asia/Tokyo date -j -f "%Y-%m-%d %H:%M:%S" "$1" +%s; }
  stamp_epoch() { date -j -f "%Y-%m-%dT%H:%M:%S%z" "$1" +%s; }
  jst_fmt()     { TZ=Asia/Tokyo date -r "$1" "+$2"; }
fi

DATE_RE='^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
STAMP_RE='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{4}$'

# 記録ファイルから最終学習日時を epoch で取り出す。未記録なら空文字を返す。
# 日付だけ (YYYY-MM-DD) が書かれていた場合は、その日の 12:00 JST とみなす。
read_last_epoch() {
  local file="$1" raw
  [[ -f "$file" ]] || return 0
  raw="$(grep -vE '^\s*(#|$)' "$file" | head -n 1 | tr -d '[:space:]' || true)"
  [[ -n "$raw" ]] || return 0

  if [[ "$raw" =~ $STAMP_RE ]]; then
    stamp_epoch "$raw"
  elif [[ "$raw" =~ $DATE_RE ]]; then
    jst_epoch "$raw 12:00:00"
  else
    echo "学習記録の書式が不正です: ${file} → '${raw}'" >&2
    return 1
  fi
}
