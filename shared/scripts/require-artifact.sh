#!/usr/bin/env bash
# Fail the pipeline when an agent step finished without producing its Spec Kit artifact.
# Spec Kit marks a command step COMPLETED on exit code 0 even when the agent refused to work,
# so this guard is the only thing that stops a run from reporting a false success.
# usage: require-artifact.sh plan|tasks|snapshot|implement
# Exits 1 with a GUARD_FAIL line on failure; exits 0 otherwise.
set -uo pipefail

STAGE="${1:-}"
case "$STAGE" in
  plan|tasks|snapshot|implement) ;;
  *) echo "usage: require-artifact.sh plan|tasks|snapshot|implement"; exit 1 ;;
esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || { echo "GUARD_FAIL stage=$STAGE reason=no-root"; exit 1; }

DIR=".specify/pipeline"
BEFORE_FILE="$DIR/tasks-done.before"
TASK_LINE='^[[:space:]]*- \[[ xX]\] T[0-9]+'
DONE_LINE='^[[:space:]]*- \[[xX]\] T[0-9]+'

fail() {
  echo "GUARD_FAIL stage=$STAGE reason=$1"
  echo "Agent không tạo đủ artifact cho bước $STAGE. Xem log phiên agent (Codex: ~/.codex/sessions/, Claude: ~/.claude/projects/)."
  exit 1
}

FEATURE_DIR="$(cat "$DIR/current-feature" 2>/dev/null || true)"
[[ -n "$FEATURE_DIR" && -d "$FEATURE_DIR" ]] || fail "no-feature-dir"

PLAN="$FEATURE_DIR/plan.md"
TASKS="$FEATURE_DIR/tasks.md"

count_done() {
  local n
  n="$(grep -cE "$DONE_LINE" "$TASKS" 2>/dev/null || true)"
  echo "${n:-0}"
}

case "$STAGE" in
  plan)
    [[ -s "$PLAN" ]] || fail "missing"
    # setup-plan copies the template verbatim; an untouched copy means the agent stopped early
    TEMPLATE=".specify/templates/plan-template.md"
    if [[ -f "$TEMPLATE" ]] && cmp -s "$PLAN" "$TEMPLATE"; then
      fail "template-only"
    fi
    echo "GUARD_OK stage=plan file=$PLAN"
    ;;
  tasks)
    [[ -s "$TASKS" ]] || fail "missing"
    grep -qE "$TASK_LINE" "$TASKS" || fail "no-tasks"
    echo "GUARD_OK stage=tasks file=$TASKS tasks=$(grep -cE "$TASK_LINE" "$TASKS")"
    ;;
  snapshot)
    mkdir -p "$DIR"
    count_done > "$BEFORE_FILE"
    echo "GUARD_OK stage=snapshot done=$(cat "$BEFORE_FILE")"
    ;;
  implement)
    [[ -s "$TASKS" ]] || fail "missing-tasks"
    BEFORE="$(cat "$BEFORE_FILE" 2>/dev/null || echo 0)"
    AFTER="$(count_done)"
    (( AFTER > BEFORE )) || fail "no-task-done"
    echo "GUARD_OK stage=implement done=$BEFORE->$AFTER"
    # Warn only: code dirs may be git-ignored, or the project may not use git at all
    CHANGED="$(git status --porcelain --untracked-files=all 2>/dev/null | awk -v fd="${FEATURE_DIR%/}/" \
      '{p=$NF} index(p, ".specify/") != 1 && index(p, fd) != 1 {print p; exit}' || true)"
    if [[ -z "$CHANGED" ]]; then
      echo "CẢNH BÁO: git không thấy file nào đổi ngoài $FEATURE_DIR và .specify/. Kiểm tra agent có sửa code thật không."
    fi
    ;;
esac
exit 0
