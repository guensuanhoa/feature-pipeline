#!/usr/bin/env bash
# Chạy build/lint/test bằng lệnh cố định trong commands.env và đọc exit code.
# Luôn thoát với mã 0; kết quả nằm ở dòng cuối: PIPELINE_CHECK=PASS hoặc PIPELINE_CHECK=FAIL.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || { echo "PIPELINE_CHECK=FAIL"; exit 0; }

DIR=".specify/pipeline"
FILE="$DIR/commands.env"
LOG="$DIR/last-check.log"
STATUS_FILE="$DIR/last-check.status"
mkdir -p "$DIR"

if [[ ! -f "$FILE" ]]; then
  echo "Thiếu $FILE"
  echo "FAIL" > "$STATUS_FILE"
  echo "PIPELINE_CHECK=FAIL"
  exit 0
fi

BUILD_CMD=""
LINT_CMD=""
TEST_CMD=""
# shellcheck disable=SC1090
source "$FILE"

: > "$LOG"
STATUS="PASS"

run_step() {
  local name="$1"
  local cmd="$2"
  if [[ -z "$cmd" ]]; then
    echo "[$name] bỏ qua (chưa cấu hình)" | tee -a "$LOG"
    return
  fi
  echo "[$name] $cmd" | tee -a "$LOG"
  if bash -c "$cmd" >>"$LOG" 2>&1; then
    echo "[$name] OK" | tee -a "$LOG"
  else
    echo "[$name] FAIL (chi tiết trong $LOG)" | tee -a "$LOG"
    STATUS="FAIL"
  fi
}

run_step build "$BUILD_CMD"
run_step lint "$LINT_CMD"
run_step test "$TEST_CMD"

# Không có lệnh test thì không thể xác nhận implement đúng
if [[ -z "$TEST_CMD" ]]; then
  echo "[test] FAIL: chưa cấu hình TEST_CMD" | tee -a "$LOG"
  STATUS="FAIL"
fi

echo "$STATUS" > "$STATUS_FILE"
echo "PIPELINE_CHECK=$STATUS"
exit 0
