#!/usr/bin/env bash
# Open an interactive Claude session on the terminal so the user answers the open questions
# and Claude writes the answers back into the original requirement. Never edits spec or code.
# Always exits 0; the workflow stops at the next gate so the user reruns from scratch.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_FILE="$SCRIPT_DIR/../prompts/update-requirement.md"

MODEL="${1:-opus}"
case "$MODEL" in
  opus|sonnet|haiku) ;;
  *) echo "Model không hợp lệ: $MODEL"; exit 0 ;;
esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 0

QUESTIONS_FILE=".specify/pipeline/open-questions.md"

# The shell step captures stdout, so the interactive session must talk to the terminal directly.
if ! { : </dev/tty; } 2>/dev/null; then
  echo "Không có terminal để hỏi trực tiếp."
  echo "Tự trả lời các câu trong $QUESTIONS_FILE, bổ sung vào file yêu cầu gốc, rồi chạy lại pipeline từ đầu."
  exit 0
fi

if ! command -v claude >/dev/null 2>&1 || [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Thiếu claude CLI hoặc file prompt $PROMPT_FILE."
  echo "Tự trả lời các câu trong $QUESTIONS_FILE, bổ sung vào file yêu cầu gốc, rồi chạy lại pipeline từ đầu."
  exit 0
fi

echo "Mở phiên Claude ($MODEL) để trả lời câu hỏi. Trả lời xong, gõ /exit để quay lại pipeline." >/dev/tty
claude --model "$MODEL" "$(cat "$PROMPT_FILE")" </dev/tty >/dev/tty 2>&1
echo "claude exit code: $?"
exit 0
