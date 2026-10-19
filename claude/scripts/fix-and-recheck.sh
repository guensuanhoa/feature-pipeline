#!/usr/bin/env bash
# Một lần tự sửa: nếu lần kiểm tra trước đã PASS thì bỏ qua.
# Nếu FAIL: gọi Claude (headless) với prompt cố định để sửa, rồi chạy lại run-checks.sh.
# Luôn thoát với mã 0; dòng cuối là PIPELINE_CHECK=PASS hoặc PIPELINE_CHECK=FAIL.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_FILE="$SCRIPT_DIR/../prompts/fix-checks.md"

MODEL="${1:-sonnet}"
case "$MODEL" in
  opus|sonnet|haiku) ;;
  *) echo "Model không hợp lệ: $MODEL"; echo "PIPELINE_CHECK=FAIL"; exit 0 ;;
esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || { echo "PIPELINE_CHECK=FAIL"; exit 0; }

DIR=".specify/pipeline"
STATUS_FILE="$DIR/last-check.status"
FIX_LOG="$DIR/fix.log"
mkdir -p "$DIR"

if [[ -f "$STATUS_FILE" && "$(cat "$STATUS_FILE")" == "PASS" ]]; then
  echo "Lần kiểm tra trước đã PASS, bỏ qua bước sửa."
  echo "PIPELINE_CHECK=PASS"
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "Không tìm thấy claude CLI trong PATH."
  echo "PIPELINE_CHECK=FAIL"
  exit 0
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Thiếu file prompt: $PROMPT_FILE"
  echo "PIPELINE_CHECK=FAIL"
  exit 0
fi

echo "Kiểm tra đang FAIL, nhờ Claude ($MODEL) sửa. Log: $FIX_LOG"
{
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') model=$MODEL ====="
  claude -p "$(cat "$PROMPT_FILE")" --model "$MODEL"
  echo "claude exit code: $?"
} >>"$FIX_LOG" 2>&1

bash "$SCRIPT_DIR/run-checks.sh"
