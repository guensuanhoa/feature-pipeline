#!/usr/bin/env bash
# Unit tests for the shared pipeline scripts. Each case runs in a throwaway git repo.
# usage: bash feature-pipeline/tests/run-tests.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/../shared/scripts"
FIXTURES="$HERE/fixtures"
PASS=0
FAIL=0

# Create a fresh repo with a feature dir registered the way locate-feature.sh does it
new_repo() {
  REPO="$(mktemp -d)"
  cd "$REPO" || exit 1
  git init -q
  mkdir -p .specify/pipeline .specify/templates specs/001-demo
  echo "specs/001-demo" > .specify/pipeline/current-feature
  printf '# Implementation Plan: [FEATURE]\n' > .specify/templates/plan-template.md
}

# check <name> <expected exit code> <expected output substring> <command...>
check() {
  local name="$1" want_rc="$2" want_out="$3"; shift 3
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [[ "$rc" == "$want_rc" && "$out" == *"$want_out"* ]]; then
    PASS=$((PASS + 1)); echo "PASS $name"
  else
    FAIL=$((FAIL + 1)); echo "FAIL $name (rc=$rc, want $want_rc; want output containing '$want_out')"
    printf '%s\n' "$out" | sed 's/^/    /'
  fi
}

guard() { bash "$SCRIPTS/require-artifact.sh" "$@"; }
accept() { bash "$SCRIPTS/accept-suggestions.sh"; }

# --- require-artifact.sh ---
new_repo
check "plan missing" 1 "reason=missing" guard plan
cp .specify/templates/plan-template.md specs/001-demo/plan.md
check "plan is untouched template" 1 "reason=template-only" guard plan
printf '# Implementation Plan: Demo\n\nReal content.\n' > specs/001-demo/plan.md
check "plan written" 0 "GUARD_OK stage=plan" guard plan

check "tasks missing" 1 "reason=missing" guard tasks
printf '# Tasks\n\n- [ ] Write something\n' > specs/001-demo/tasks.md
check "tasks without task ids" 1 "reason=no-tasks" guard tasks
printf '# Tasks\n\n- [ ] T001 First\n- [ ] T002 Second\n' > specs/001-demo/tasks.md
check "tasks written" 0 "tasks=2" guard tasks

check "snapshot" 0 "done=0" guard snapshot
check "implement did nothing" 1 "reason=no-task-done" guard implement
printf '# Tasks\n\n- [X] T001 First\n- [ ] T002 Second\n' > specs/001-demo/tasks.md
check "implement without code change warns" 0 "CẢNH BÁO" guard implement
echo "code" > app.txt
check "implement with code change" 0 "done=0->1" guard implement

rm .specify/pipeline/current-feature
check "no current feature" 1 "reason=no-feature-dir" guard plan
check "unknown stage" 1 "usage:" bash "$SCRIPTS/require-artifact.sh" bogus

# --- accept-suggestions.sh ---
new_repo
cp "$FIXTURES/spec-own-line-markers.md" specs/001-demo/spec.md
check "own-line markers accepted" 0 "ACCEPTED=2" accept
check "own-line markers removed" 1 "" grep -q "NEEDS CLARIFICATION" specs/001-demo/spec.md
check "decisions recorded under Clarifications" 0 "- Q: Show names? → A: no names" \
  awk '/^## Clarifications/{c=1} /^## User/{c=0} c' specs/001-demo/spec.md
check "existing session kept" 0 "### Session 2026-01-01" grep "### Session 2026-01-01" specs/001-demo/spec.md

new_repo
cp "$FIXTURES/spec-inline-marker.md" specs/001-demo/spec.md
check "inline marker accepted" 0 "ACCEPTED=1" accept
check "inline marker replaced by its answer" 0 "- Cache is optional. memory only" grep -F -- "- Cache is optional. memory only" specs/001-demo/spec.md
check "Clarifications created before first H2" 0 "## Clarifications" \
  awk '/^## /{print; exit}' specs/001-demo/spec.md

new_repo
cp "$FIXTURES/spec-no-suggestion.md" specs/001-demo/spec.md
check "marker without suggestion fails" 1 "REMAINING=1" accept
check "spec untouched on failure" 0 "" cmp -s "$FIXTURES/spec-no-suggestion.md" specs/001-demo/spec.md

# Markers the parser cannot accept must fail the step instead of passing silently
for bad in '- [NEEDS CLARIFICATION:method?]' '- [NEEDS CLARIFICATION: open bracket — gợi ý: x' '- [NEEDS CLARIFICATION: split
  across lines — gợi ý: x]'; do
  new_repo
  printf '# Spec\n\n## Requirements\n\n%s\n' "$bad" > specs/001-demo/spec.md
  cp specs/001-demo/spec.md before.md
  check "unparsable marker fails: $(printf %s "${bad:0:40}" | tr "\n" " ")" 1 "REMAINING=1" accept
  check "unparsable marker leaves spec untouched" 0 "" cmp -s before.md specs/001-demo/spec.md
done

new_repo
cp "$FIXTURES/spec-own-line-markers.md" specs/001-demo/spec.md
chmod 644 specs/001-demo/spec.md
echo "stale" > .specify/pipeline/open-questions.md
accept >/dev/null 2>&1
check "spec keeps file mode" 0 "-rw-r--r--" ls -l specs/001-demo/spec.md
check "stale open-questions removed" 1 "" test -f .specify/pipeline/open-questions.md

new_repo
printf '# Spec\n\n## Requirements\n\n- Done.\n' > specs/001-demo/spec.md
check "no markers is a no-op" 0 "ACCEPTED=0" accept

# --- detect-commands.sh ---
new_repo
mkdir -p api web
touch api/go.mod web/package.json
check "several stacks warn" 0 "CẢNH BÁO: phát hiện stack" bash "$SCRIPTS/detect-commands.sh"
check "markers listed in commands.env" 0 "api/go.mod web/package.json" grep "Detected stack markers" .specify/pipeline/commands.env

new_repo
touch go.mod
out="$(bash "$SCRIPTS/detect-commands.sh")"
if [[ "$out" != *"phát hiện stack"* && "$out" == *'BUILD_CMD="go build ./..."'* ]]; then
  PASS=$((PASS + 1)); echo "PASS single root stack does not warn"
else
  FAIL=$((FAIL + 1)); echo "FAIL single root stack does not warn"; printf '%s\n' "$out" | sed 's/^/    /'
fi

echo
echo "passed=$PASS failed=$FAIL"
[[ "$FAIL" == 0 ]]
