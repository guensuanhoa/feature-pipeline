#!/usr/bin/env bash
# Fail fast when the Claude allowlist lacks the Spec Kit scripts or file-write access the agent needs.
# Headless agents cannot answer a permission prompt, so a missing rule stalls the run
# (plan/tasks for scripts, implement for Edit/Write) after earlier steps already spent time.
# Check before any agent step.
# Prints PERMISSIONS_OK, or PERMISSIONS_MISSING with the rules to add (exit 0 either way: the
# workflow asks the user to approve). With --apply, merges the missing rules into this project's
# .claude/settings.local.json and prints PERMISSIONS_FIXED.
set -uo pipefail

APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

FILES=()
for f in .claude/settings.json .claude/settings.local.json "$HOME/.claude/settings.json"; do
  [[ -f "$f" ]] && FILES+=("$f")
done

# A blanket rule for the whole scripts dir covers every script below
WILDCARD='Bash\(\.?/?\.specify/scripts/bash/\*'
MISSING=()
for s in create-new-feature setup-plan check-prerequisites setup-tasks; do
  rule="Bash(.specify/scripts/bash/$s.sh:*)"
  if (( ${#FILES[@]} > 0 )) && grep -hqE "$WILDCARD|Bash\(\.?/?\.specify/scripts/bash/$s\.sh" "${FILES[@]}"; then
    continue
  fi
  MISSING+=("$rule")
done

# implement edits source files and tasks.md; a denied Edit/Write makes it stop with every task unticked
for tool in Edit Write; do
  if (( ${#FILES[@]} > 0 )) && grep -hqE "\"$tool\"|\"$tool\(|\"(acceptEdits|bypassPermissions)\"" "${FILES[@]}"; then
    continue
  fi
  MISSING+=("$tool")
done

if (( ${#MISSING[@]} == 0 )); then
  echo "PERMISSIONS_OK"
  exit 0
fi

if (( APPLY == 0 )); then
  echo "PERMISSIONS_MISSING"
  echo "Agent chạy headless nên không thể xin quyền; thiếu rule sẽ làm pipeline kẹt ở plan, tasks hoặc implement."
  echo "Rule còn thiếu trong permissions.allow của .claude/settings.local.json:"
  printf '  "%s",\n' "${MISSING[@]}"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "PERMISSIONS_FIX_FAILED: cần jq để tự sửa. Hãy thêm tay các rule sau vào .claude/settings.local.json:"
  printf '  "%s",\n' "${MISSING[@]}"
  exit 1
fi

TARGET=".claude/settings.local.json"
mkdir -p .claude
[[ -f "$TARGET" ]] || echo '{}' > "$TARGET"
tmp="$(mktemp)"
rules="$(printf '%s\n' "${MISSING[@]}" | jq -R . | jq -s .)"
if jq --argjson rules "$rules" '.permissions.allow = (((.permissions.allow // []) + $rules) | unique)' "$TARGET" > "$tmp"; then
  mv "$tmp" "$TARGET"
  echo "PERMISSIONS_FIXED: đã thêm ${#MISSING[@]} rule vào $TARGET"
  printf '  "%s",\n' "${MISSING[@]}"
else
  rm -f "$tmp"
  echo "PERMISSIONS_FIX_FAILED: $TARGET không phải JSON hợp lệ, hãy sửa tay."
  exit 1
fi
