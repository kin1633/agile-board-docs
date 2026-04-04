#!/bin/bash
# Marp形式のMDファイルをGamma APIでプレゼンテーションに変換するスクリプト
#
# 使い方:
#   bash scripts/gamma_generate.sh <MDファイルパス>
#
# 必須環境変数:
#   GAMMA_API_KEY  - GammaのAPIキー
# 任意環境変数:
#   GAMMA_THEME_ID - GammaのテーマID（未設定時はデフォルトテーマを使用）

set -euo pipefail

# ─────────────────────────────────────────────
# 定数
# ─────────────────────────────────────────────
readonly API_BASE="https://public-api.gamma.app/v1.0"
readonly POLL_INTERVAL=5     # ポーリング間隔（秒）
readonly TIMEOUT=300         # タイムアウト（秒）
readonly OUTPUT_DIR="dist"
readonly URLS_FILE="${OUTPUT_DIR}/gamma_urls.txt"

# ─────────────────────────────────────────────
# 依存コマンドの確認
# ─────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo "エラー: jq がインストールされていません。" >&2
  echo "インストール方法:" >&2
  echo "  macOS:  brew install jq" >&2
  echo "  Ubuntu: sudo apt-get install jq" >&2
  exit 1
fi

if ! command -v curl &>/dev/null; then
  echo "エラー: curl がインストールされていません。" >&2
  exit 1
fi

# ─────────────────────────────────────────────
# 環境変数チェック
# ─────────────────────────────────────────────
if [[ -z "${GAMMA_API_KEY:-}" ]]; then
  echo "エラー: GAMMA_API_KEY が設定されていません。" >&2
  echo ".env ファイルに GAMMA_API_KEY=<あなたのAPIキー> を設定してください。" >&2
  echo "APIキーの取得: https://gamma.app/developers" >&2
  exit 1
fi

# ─────────────────────────────────────────────
# 引数チェック
# ─────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
  echo "使い方: $0 <MDファイルパス>" >&2
  exit 1
fi

MD_FILE="$1"

if [[ ! -f "${MD_FILE}" ]]; then
  echo "エラー: ファイルが見つかりません: ${MD_FILE}" >&2
  exit 1
fi

# ─────────────────────────────────────────────
# Marpヘッダーの除去
# ファイル先頭の --- ... --- ブロック（YAML front matter）を取り除く
# ─────────────────────────────────────────────
INPUT_TEXT=$(awk '
  BEGIN { in_header=1; count=0 }
  in_header && /^---$/ {
    count++
    if (count == 2) { in_header=0 }
    next
  }
  !in_header { print }
' "${MD_FILE}")

if [[ -z "${INPUT_TEXT}" ]]; then
  echo "エラー: ファイルの内容が空です: ${MD_FILE}" >&2
  exit 1
fi

# ─────────────────────────────────────────────
# JSONペイロードの構築
# GAMMA_THEME_ID が設定されている場合はthemeIdフィールドを追加
# ─────────────────────────────────────────────
PAYLOAD=$(jq -n \
  --arg text "${INPUT_TEXT}" \
  '{
    inputText: $text,
    textMode: "preserve",
    format: "presentation",
    cardSplit: "inputTextBreaks",
    exportAs: "pptx",
    textOptions: { language: "ja" },
    imageOptions: { source: "noImages" }
  }')

if [[ -n "${GAMMA_THEME_ID:-}" ]]; then
  PAYLOAD=$(echo "${PAYLOAD}" | jq --arg theme_id "${GAMMA_THEME_ID}" '. + {themeId: $theme_id}')
fi

# ─────────────────────────────────────────────
# Gamma API へのPOSTリクエスト
# ─────────────────────────────────────────────
FILENAME=$(basename "${MD_FILE}")
echo ">>> ${FILENAME} の変換を開始します..."

# macOSのheadは負の行数に非対応のため、一時ファイルにボディを書き出してステータスコードを分離する
RESPONSE_FILE=$(mktemp)
HTTP_STATUS=$(curl -s -o "${RESPONSE_FILE}" -w "%{http_code}" \
  -X POST "${API_BASE}/generations" \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: ${GAMMA_API_KEY}" \
  -d "${PAYLOAD}")
BODY=$(cat "${RESPONSE_FILE}")
rm -f "${RESPONSE_FILE}"

if [[ "${HTTP_STATUS}" != "200" && "${HTTP_STATUS}" != "201" && "${HTTP_STATUS}" != "202" ]]; then
  echo "エラー: APIリクエストが失敗しました (HTTP ${HTTP_STATUS})" >&2
  echo "レスポンス: ${BODY}" >&2
  exit 1
fi

# generationId の取得
GENERATION_ID=$(echo "${BODY}" | jq -r '.id // .generationId // empty')

if [[ -z "${GENERATION_ID}" ]]; then
  echo "エラー: generationId が取得できませんでした。" >&2
  echo "レスポンス: ${BODY}" >&2
  exit 1
fi

echo "    generationId: ${GENERATION_ID}"
echo "    完了まで待機中..."

# ─────────────────────────────────────────────
# ポーリング（完了まで待機）
# ─────────────────────────────────────────────
ELAPSED=0

while true; do
  sleep "${POLL_INTERVAL}"
  ELAPSED=$((ELAPSED + POLL_INTERVAL))

  STATUS_RESPONSE=$(curl -s \
    -H "X-API-KEY: ${GAMMA_API_KEY}" \
    "${API_BASE}/generations/${GENERATION_ID}")

  STATUS=$(echo "${STATUS_RESPONSE}" | jq -r '.status // empty')

  case "${STATUS}" in
    completed)
      break
      ;;
    failed | error)
      echo "エラー: 生成に失敗しました。" >&2
      echo "レスポンス: ${STATUS_RESPONSE}" >&2
      exit 1
      ;;
    *)
      # タイムアウト判定
      if [[ "${ELAPSED}" -ge "${TIMEOUT}" ]]; then
        echo "エラー: タイムアウト（${TIMEOUT}秒）しました。generationId: ${GENERATION_ID}" >&2
        exit 1
      fi
      echo "    待機中... (${ELAPSED}秒経過 / ステータス: ${STATUS:-unknown})"
      ;;
  esac
done

# ─────────────────────────────────────────────
# 生成結果のURLを取得・出力
# ─────────────────────────────────────────────
GAMMA_URL=$(echo "${STATUS_RESPONSE}" | jq -r '.url // .gammaUrl // empty')
PPTX_URL=$(echo "${STATUS_RESPONSE}" | jq -r '.exportUrl // .pptxUrl // .downloadUrl // empty')

echo ""
echo "✓ 変換完了: ${FILENAME}"
echo "  Gamma URL : ${GAMMA_URL:-（URLが取得できませんでした）}"
echo "  PPTX URL  : ${PPTX_URL:-（PPTXダウンロードURLが取得できませんでした）}"

# ─────────────────────────────────────────────
# dist/gamma_urls.txt へのURL追記保存
# ─────────────────────────────────────────────
mkdir -p "${OUTPUT_DIR}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

{
  echo "# ${FILENAME} - ${TIMESTAMP}"
  echo "Gamma URL : ${GAMMA_URL:-N/A}"
  echo "PPTX URL  : ${PPTX_URL:-N/A}"
  echo ""
} >> "${URLS_FILE}"

echo "  URLを ${URLS_FILE} に保存しました。"
