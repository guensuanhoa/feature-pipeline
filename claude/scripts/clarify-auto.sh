#!/usr/bin/env bash
# One automatic clarify round: run /speckit-clarify headless (no human answers) and recount
# the NEEDS CLARIFICATION markers. Round 1 always runs, because specify often turns open
# product decisions into Assumptions without markers; later rounds skip when no marker is left.
# Always exits 0; last line is CLARIFY_STATUS=DONE or CLARIFY_STATUS=OPEN.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_FILE="$SCRIPT_DIR/../prompts/clarify-auto.md"

MODEL="${1:-sonnet}"
ROUND="${2:-?}"
case "$MODEL" in
  opus|sonnet|haiku) ;;
  *) echo "Model không hợp lệ: $MODEL"; echo "CLARIFY_STATUS=OPEN"; exit 0 ;;
esac
case "$ROUND" in
  [1-9]) ;;
  *) echo "Số vòng không hợp lệ: $ROUND"; echo "CLARIFY_STATUS=OPEN"; exit 0 ;;
esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || { echo "CLARIFY_STATUS=OPEN"; exit 0; }

DIR=".specify/pipeline"
LOG="$DIR/clarify.log"
QUESTIONS_FILE="$DIR/open-questions.md"
FEATURE_DIR="$(cat "$DIR/current-feature" 2>/dev/null || true)"
SPEC="$FEATURE_DIR/spec.md"

if [[ -z "$FEATURE_DIR" || ! -f "$SPEC" ]]; then
  echo "Không tìm thấy spec.md (xem bước locate-feature)."
  echo "CLARIFY_STATUS=OPEN"
  exit 0
fi

count_open() {
  local n
  n="$(grep -c "NEEDS CLARIFICATION" "$SPEC" 2>/dev/null || true)"
  echo "${n:-0}"
}

OPEN="$(count_open)"
if [[ "$OPEN" == "0" && "$ROUND" != "1" ]]; then
  echo "Vòng clarify $ROUND: spec không còn câu hỏi mở, bỏ qua."
  rm -f "$QUESTIONS_FILE"
  echo "CLARIFY_STATUS=DONE"
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "Không tìm thấy claude CLI trong PATH."
  echo "CLARIFY_STATUS=OPEN"
  exit 0
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Thiếu file prompt: $PROMPT_FILE"
  echo "CLARIFY_STATUS=OPEN"
  exit 0
fi

echo "Vòng clarify $ROUND: spec còn $OPEN câu hỏi mở, nhờ Claude ($MODEL) làm rõ. Log: $LOG"
{
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') round=$ROUND model=$MODEL ====="
  claude -p "/speckit-clarify $(cat "$PROMPT_FILE")" --model "$MODEL"
  echo "claude exit code: $?"
} >>"$LOG" 2>&1

OPEN="$(count_open)"
echo "OPEN_QUESTIONS=$OPEN"
if [[ "$OPEN" == "0" ]]; then
  rm -f "$QUESTIONS_FILE"
  echo "CLARIFY_STATUS=DONE"
  exit 0
fi

# Keep the remaining questions in one file so the user can judge them at the gate.
{
  echo "# Câu hỏi còn mở sau vòng clarify $ROUND"
  echo
  echo "Spec: \`$SPEC\`"
  echo
  grep -n "NEEDS CLARIFICATION" "$SPEC" | sed 's/^/- dòng /'
} >"$QUESTIONS_FILE"
echo "Danh sách câu hỏi còn mở: $QUESTIONS_FILE"
echo "CLARIFY_STATUS=OPEN"
exit 0
