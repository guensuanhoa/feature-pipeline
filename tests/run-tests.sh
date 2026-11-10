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

T=specs/001-demo/tasks.md
R=.specify/pipeline/implement-report.md

check "snapshot" 0 "done=0" guard snapshot

# Task not done: guard blocks and names the open tasks
check "implement did nothing" 1 "tasks-incomplete" guard implement
check "implement did nothing names open tasks" 1 "T001,T002 còn [ ]" guard implement

# One of two tasks done: still blocked, even with a report
printf '# Tasks\n\n- [X] T001 First\n- [ ] T002 Second\n' > $T
printf -- '- T001: ran ./check ok\nTESTS: passed - go test ./...\n' > $R
check "partial progress still blocked" 1 "T002 còn [ ]" guard implement
printf -- '- T002: BLOCKED - db down\n' >> $R
check "blocked reason is shown" 1 "BLOCKED - db down" guard implement

# (a) Verification-only run: every task checked with evidence, no code change
printf '# Tasks\n\n- [X] T001 First\n- [X] T002 Second after T001\n' > $T
printf -- '- T001: confirmed handler already validates input (read api.go:40)\n- T002: N/A - no migration needed, schema unchanged\nTESTS: not-run - no runnable command for this change\n' > $R
check "verified without code change passes" 0 "GUARD_OK stage=implement tasks=2 new=2 TESTS: not-run" guard implement
check "no code change is only a note" 0 "GHI CHÚ" guard implement

# Report is required and must carry evidence and an honest test status
rm $R
check "missing report fails" 1 "missing-report" guard implement
printf -- '- T001: ok\nTESTS: passed - go test\n' > $R
check "task without evidence fails" 1 "no-evidence" guard implement
check "task without evidence names the task" 1 "cho: T002" guard implement
printf -- '- T001: ok\n- T002:\nTESTS: passed - go test\n' > $R
check "empty evidence fails" 1 "cho: T002" guard implement
printf -- '- T001: ok\n- T002: ok\nAll tests passed.\n' > $R
check "missing TESTS line fails" 1 "no-test-status" guard implement
printf -- '- T001: ok\n- T002: ok\nTESTS: green\n' > $R
check "unknown TESTS state fails" 1 "no-test-status" guard implement
for st in not-run passed failed blocked; do
  printf -- '- T001: ok\n- T002: ok\nTESTS: %s - x\n' "$st" > $R
  check "TESTS state $st accepted" 0 "TESTS: $st" guard implement
done

# Tasks ticked before this run need no new evidence, but the run still needs a report
printf -- 'TESTS: not-run - nothing to run\n' > $R
check "rerun with all tasks already done" 0 "tasks=2 new=0" bash -c 'cd "$1" && bash "$2" snapshot >/dev/null && printf "TESTS: not-run - nothing to run\n" > '"$R"' && bash "$2" implement' _ "$PWD" "$SCRIPTS/require-artifact.sh"
check "snapshot removes stale report" 1 "" bash -c 'cd "$1" && bash "$2" snapshot >/dev/null && test -f '"$R" _ "$PWD" "$SCRIPTS/require-artifact.sh"
check "stale report cannot satisfy next run" 1 "missing-report" guard implement

# Code changes outside the feature dir drop the note
printf '# Tasks\n\n- [ ] T001 First\n' > $T
guard snapshot >/dev/null
printf '# Tasks\n\n- [X] T001 First\n' > $T
printf -- '- T001: edited app\nTESTS: passed - make test\n' > $R
echo "code" > app.txt
check "implement with code change has no note" 0 "TESTS: passed" guard implement
if [[ "$(guard implement 2>&1)" == *"GHI CHÚ"* ]]; then FAIL=$((FAIL + 1)); echo "FAIL code change still prints note"; else PASS=$((PASS + 1)); echo "PASS code change prints no note"; fi

# Task IDs mentioned inside a description are not tasks
printf '# Tasks\n\n- [X] T001 Do it\n- [ ] T002 Run after T001\n' > $T
check "only own task ID counts" 1 "reason=tasks-incomplete" guard implement
check "description IDs are not listed as open" 1 "T002 còn" guard implement

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

# --- mark-manual-tasks.sh (claude variant) ---
MARK="$HERE/../claude/scripts/mark-manual-tasks.sh"
mark() { bash "$MARK" "$@"; }

new_repo
T=specs/001-demo/tasks.md
printf '# Tasks\n\n- [ ] T001 Edit manifest.json\n- [ ] T002 [P] Add VAR to `.env` and `.env.qa`\n- [ ] T003 Copy to .env.example\n- [X] T004 Done earlier, touched .env.local\n- [ ] T005 Use item.key in src/a.ts\n- [ ] T006 Add deploy/server.pem\n' > "$T"
check "scan lists env task" 0 "SENSITIVE_TASKS" mark
check "scan shows T002" 0 "T002" mark
check "scan shows pem task" 0 "T006" mark
if [[ "$(mark)" == *"T001"* || "$(mark)" == *"T003"* || "$(mark)" == *"T004"* || "$(mark)" == *"T005"* ]]; then
  FAIL=$((FAIL + 1)); echo "FAIL scan ignores plain, example, done and code-identifier tasks"
else
  PASS=$((PASS + 1)); echo "PASS scan ignores plain, example, done and code-identifier tasks"
fi
check "apply marks tasks" 0 "SENSITIVE_MARKED" mark --apply
check "T002 marked manual" 0 "- [ ] T002 [MANUAL] [P] Add VAR" cat "$T"
check "T001 untouched" 0 "- [ ] T001 Edit manifest.json" cat "$T"
check "rescan after apply finds nothing" 0 "SENSITIVE_NONE" mark
printf '# Tasks\n\n- [ ] T001 Plain\n' > "$T"
check "clean tasks.md" 0 "SENSITIVE_NONE" mark

# Guard: manual tasks do not block implement, other open tasks still do
new_repo
guard snapshot >/dev/null
T=specs/001-demo/tasks.md
R=.specify/pipeline/implement-report.md
printf '# Tasks\n\n- [X] T001 Done\n- [ ] T002 [MANUAL] Add VAR to .env\n' > "$T"
printf -- '- T001: edited a.go\nTESTS: not-run - nothing\n' > "$R"
check "manual task does not fail guard" 0 "GUARD_OK stage=implement" guard implement
printf '# Tasks\n\n- [X] T001 Done\n- [ ] T002 [MANUAL] Add VAR to .env\n- [ ] T003 Other\n' > "$T"
check "non-manual open task still fails guard" 1 "T003 còn [ ]" guard implement

# --- check-permissions.sh (claude variant) ---
PERMS="$HERE/../claude/scripts/check-permissions.sh"
perms() { HOME="$REPO/home" bash "$PERMS" "$@"; }

new_repo
check "no settings file" 0 "PERMISSIONS_MISSING" perms
mkdir -p .claude
printf '{"permissions":{"allow":["Bash(.specify/scripts/bash/setup-plan.sh:*)"]}}\n' > .claude/settings.local.json
check "partial allowlist names setup-tasks" 0 'Bash(.specify/scripts/bash/setup-tasks.sh:*)' perms
check "partial allowlist skips setup-plan" 0 "PERMISSIONS_MISSING" perms
cp "$HERE/../claude/templates/settings.local.json.example" .claude/settings.local.json
check "template covers all scripts" 0 "PERMISSIONS_OK" perms
printf '{"permissions":{"allow":["Edit","Write","Bash(.specify/scripts/bash/*:*)"]}}\n' > .claude/settings.local.json
check "wildcard covers all scripts" 0 "PERMISSIONS_OK" perms
printf '{"permissions":{"allow":["Bash(.specify/scripts/bash/*:*)"]}}\n' > .claude/settings.local.json
check "scripts-only allowlist misses Edit" 0 '  "Edit",' perms
check "scripts-only allowlist misses Write" 0 '  "Write",' perms
printf '{"permissions":{"defaultMode":"acceptEdits","allow":["Bash(.specify/scripts/bash/*:*)"]}}\n' > .claude/settings.local.json
check "acceptEdits covers Edit and Write" 0 "PERMISSIONS_OK" perms

# --apply merges missing rules into the project's settings.local.json and keeps existing keys
printf '{"hooks":{"x":1},"permissions":{"allow":["Bash(ls:*)"]}}\n' > .claude/settings.local.json
check "apply adds missing rules" 0 "PERMISSIONS_FIXED" perms --apply
check "apply result is now OK" 0 "PERMISSIONS_OK" perms
check "apply keeps existing allow rule" 0 "Bash(ls:*)" jq -c '.permissions.allow' .claude/settings.local.json
check "apply keeps unrelated keys" 0 '{"x":1}' jq -c '.hooks' .claude/settings.local.json
rm .claude/settings.local.json
check "apply creates missing settings file" 0 "PERMISSIONS_FIXED" perms --apply
echo "{bad" > .claude/settings.local.json
check "apply on invalid JSON fails" 1 "PERMISSIONS_FIX_FAILED" perms --apply

echo
echo "passed=$PASS failed=$FAIL"
[[ "$FAIL" == 0 ]]
