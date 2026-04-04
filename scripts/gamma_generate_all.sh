#!/bin/bash
# 全スライドMDファイルをGamma APIで一括変換するラッパースクリプト
# 1_overview.md → 2_usage.md の順番で処理する

set -euo pipefail

# スクリプトのあるディレクトリからリポジトリルートを特定する
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# .env ファイルが存在すれば環境変数を読み込む
ENV_FILE="${REPO_ROOT}/.env"
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck source=/dev/null
  set -a
  source "${ENV_FILE}"
  set +a
fi

# 処理対象のMDファイル（順序固定）
SLIDE_FILES=(
  "${REPO_ROOT}/1_overview.md"
  "${REPO_ROOT}/2_usage.md"
)

echo "=== Gamma API 一括変換を開始します ==="
echo ""

for md_file in "${SLIDE_FILES[@]}"; do
  bash "${SCRIPT_DIR}/gamma_generate.sh" "${md_file}"
  echo ""
done

echo "=== 全ファイルの変換が完了しました ==="
