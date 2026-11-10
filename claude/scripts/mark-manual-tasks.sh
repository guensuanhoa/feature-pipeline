#!/usr/bin/env bash
# Find open tasks that touch secret files the user's privacy hook blocks for headless agents
# (.env*, *.pem, credentials files, ssh keys). Run before implement so the run does not die on them.
# usage: mark-manual-tasks.sh [--apply]
# Prints SENSITIVE_NONE, or SENSITIVE_TASKS with the matching task lines (exit 0 either way).
# With --apply, adds "[MANUAL]" after the task ID; guard-implement skips those and summary lists them.
set -uo pipefail

APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

FEATURE_DIR="$(cat .specify/pipeline/current-feature 2>/dev/null || true)"
TASKS="$FEATURE_DIR/tasks.md"
[[ -n "$FEATURE_DIR" && -s "$TASKS" ]] || { echo "SENSITIVE_NONE (không có tasks.md để quét)"; exit 0; }

# Same families as the privacy hook; example/sample/template copies are safe and stripped first
SAFE_COPY='[A-Za-z0-9_./-]*\.env[A-Za-z0-9_.-]*\.(example|sample|template)'
SENSITIVE='(^|[^A-Za-z0-9_])\.env([.][A-Za-z0-9_-]+)*|[A-Za-z0-9_/-]+\.pem|credentials[A-Za-z0-9_-]*\.(json|ya?ml|txt)|secrets?\.ya?ml|id_rsa|id_ed25519'
OPEN_TASK='^[[:space:]]*- \[ \] T[0-9]+ '

LINES=()
while IFS= read -r line; do
  [[ "$line" == *"[MANUAL]"* ]] && continue
  if sed -E "s/$SAFE_COPY//g" <<<"$line" | grep -qE "$SENSITIVE"; then
    LINES+=("$line")
  fi
done < <(grep -E "$OPEN_TASK" "$TASKS")

if (( ${#LINES[@]} == 0 )); then
  echo "SENSITIVE_NONE"
  exit 0
fi

if (( APPLY == 0 )); then
  echo "SENSITIVE_TASKS"
  echo "Các task sau đụng file nhạy cảm; agent headless bị privacy hook chặn ở các file này:"
  printf '  %s\n' "${LINES[@]}" | cut -c1-200
  exit 0
fi

tmp="$(mktemp)"
cp "$TASKS" "$tmp"
for line in "${LINES[@]}"; do
  id="$(sed -E 's/^[[:space:]]*- \[ \] (T[0-9]+) .*/\1/' <<<"$line")"
  sed -E "s/^([[:space:]]*- \[ \] $id) /\1 [MANUAL] /" "$tmp" > "$tmp.new" && mv "$tmp.new" "$tmp"
done
cat "$tmp" > "$TASKS"
rm -f "$tmp"
echo "SENSITIVE_MARKED: đã đánh dấu [MANUAL] cho ${#LINES[@]} task trong $TASKS; agent sẽ bỏ qua, bạn tự làm:"
printf '  %s\n' "${LINES[@]}" | cut -c1-200
