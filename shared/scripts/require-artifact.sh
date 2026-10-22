#!/usr/bin/env bash
# Fail the pipeline when an agent step finished without producing its Spec Kit artifact.
# Spec Kit marks a command step COMPLETED on exit code 0 even when the agent refused to work,
# so this guard is the only thing that stops a run from reporting a false success.
# usage: require-artifact.sh plan|tasks|snapshot|implement
# Exits 1 with a GUARD_FAIL line on failure; exits 0 otherwise.
#
# implement proves the current run finished its tasks, not just that some box was ticked:
#   - snapshot records the IDs already done and removes any stale report from an earlier run
#   - every task in tasks.md must be [X] (a blocked task keeps [ ] and fails the guard)
#   - every task newly done in this run needs an evidence line in the run report
#   - the report needs a TESTS line saying not-run | passed | failed | blocked
# A run that verified tasks without touching code passes; no code diff is required.
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
REPORT="$DIR/implement-report.md"
TASK_LINE='^[[:space:]]*- \[[ xX]\] T[0-9]+'

fail() {
  echo "GUARD_FAIL stage=$STAGE reason=$1"
  [[ -z "${2:-}" ]] || echo "  - $1: $2"
  echo "Agent không tạo đủ artifact cho bước $STAGE. Xem log phiên agent (Codex: ~/.codex/sessions/, Claude: ~/.claude/projects/)."
  exit 1
}

FEATURE_DIR="$(cat "$DIR/current-feature" 2>/dev/null || true)"
[[ -n "$FEATURE_DIR" && -d "$FEATURE_DIR" ]] || fail "no-feature-dir"

PLAN="$FEATURE_DIR/plan.md"
TASKS="$FEATURE_DIR/tasks.md"

# Own task IDs (one per line) of tasks.md checklist lines whose box matches $1 (bracket body, e.g. "xX")
task_ids() {
  sed -nE "s/^[[:space:]]*- \\[[$1]\\] (T[0-9]+).*/\\1/p" "$TASKS" 2>/dev/null | awk '!seen[$0]++'
}

# Report line for a task: "- T001: <evidence>"; prints the evidence text, empty when missing
report_entry() {
  sed -nE "s/^[[:space:]]*[-*][[:space:]]+$1:[[:space:]]*(.+)$/\1/p" "$REPORT" 2>/dev/null | head -1
}

join_ids() { paste -sd, - ; }

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
    # A report left by an earlier run must not satisfy this run
    rm -f "$REPORT"
    task_ids xX > "$BEFORE_FILE"
    echo "GUARD_OK stage=snapshot done=$(grep -c . "$BEFORE_FILE")"
    ;;
  implement)
    [[ -s "$TASKS" ]] || fail "missing-tasks" "$TASKS không có hoặc rỗng"
    [[ -f "$BEFORE_FILE" ]] || fail "no-snapshot" "thiếu $BEFORE_FILE; bước snapshot-tasks chưa chạy"

    PROBLEMS=()
    DETAILS=()
    problem() { PROBLEMS+=("$1"); DETAILS+=("$2"); }

    # 1. Every task must be done. A blocked task keeps [ ] so the run cannot pass silently.
    OPEN="$(task_ids " ")"
    if [[ -n "$OPEN" ]]; then
      detail="$(printf '%s\n' "$OPEN" | join_ids) còn [ ] trong $TASKS"
      if [[ -f "$REPORT" ]]; then
        blocked="$(grep -E 'BLOCKED' "$REPORT" | head -3 || true)"
        [[ -z "$blocked" ]] || detail="$detail; report ghi: $(printf '%s' "$blocked" | tr '\n' '|')"
      fi
      problem "tasks-incomplete" "$detail"
    fi

    # 2. The report of this run must exist
    if [[ ! -s "$REPORT" ]]; then
      problem "missing-report" "thiếu $REPORT; agent phải ghi report cuối bước implement"
    else
      # 3. Evidence for each task newly done in this run
      BEFORE_IDS="$(grep -oE 'T[0-9]+' "$BEFORE_FILE" || true)"
      NEW_IDS="$(comm -13 <(printf '%s\n' "$BEFORE_IDS" | sort -u) <(task_ids xX | sort -u))"
      NO_EVIDENCE=""
      for id in $NEW_IDS; do
        [[ -n "$(report_entry "$id")" ]] || NO_EVIDENCE="$NO_EVIDENCE $id"
      done
      [[ -z "$NO_EVIDENCE" ]] || problem "no-evidence" "task đã [X] nhưng $REPORT thiếu dòng '- <ID>: <bằng chứng>' cho:${NO_EVIDENCE}"

      # 4. Test status must be one of the four honest states
      if ! grep -qE '^[[:space:]]*TESTS:[[:space:]]*(not-run|passed|failed|blocked)\b' "$REPORT"; then
        problem "no-test-status" "$REPORT thiếu dòng 'TESTS: not-run|passed|failed|blocked - <lệnh/lý do>'"
      fi
    fi

    if (( ${#PROBLEMS[@]} > 0 )); then
      echo "GUARD_FAIL stage=implement reason=$(printf '%s\n' "${PROBLEMS[@]}" | join_ids)"
      for i in "${!PROBLEMS[@]}"; do echo "  - ${PROBLEMS[$i]}: ${DETAILS[$i]}"; done
      echo "Agent chưa hoàn tất bước implement. Xem log phiên agent (Codex: ~/.codex/sessions/, Claude: ~/.claude/projects/)."
      exit 1
    fi

    TESTS_LINE="$(grep -E '^[[:space:]]*TESTS:' "$REPORT" | head -1 | sed -E 's/^[[:space:]]+//')"
    echo "GUARD_OK stage=implement tasks=$(task_ids xX | grep -c .) new=$(printf '%s\n' "$NEW_IDS" | grep -c . || true) $TESTS_LINE"
    # Informational: a verification-only run legitimately changes no code
    CHANGED="$(git status --porcelain --untracked-files=all 2>/dev/null | awk -v fd="${FEATURE_DIR%/}/" \
      '{p=$NF} index(p, ".specify/") != 1 && index(p, fd) != 1 {print p; exit}' || true)"
    if [[ -z "$CHANGED" ]]; then
      echo "GHI CHÚ: git không thấy file nào đổi ngoài $FEATURE_DIR và .specify/. Hợp lệ nếu các task chỉ cần xác minh; code dir bị git-ignore cũng cho kết quả này."
    fi
    ;;
esac
exit 0
