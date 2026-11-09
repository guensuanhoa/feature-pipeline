#!/usr/bin/env bash
# Fail fast when the Claude allowlist lacks the Spec Kit scripts the agent must run.
# Headless agents cannot answer a permission prompt, so a missing rule stalls the run
# at plan/tasks (after specify and clarify already spent time). Check before any agent step.
# Prints PERMISSIONS_OK, or PERMISSIONS_MISSING with the rules to add, and exits 1.
set -uo pipefail

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

if (( ${#MISSING[@]} == 0 )); then
  echo "PERMISSIONS_OK"
  exit 0
fi

echo "PERMISSIONS_MISSING"
echo "Agent chạy headless nên không thể xin quyền; thiếu rule sẽ làm pipeline kẹt ở plan/tasks."
echo "Thêm vào permissions.allow của .claude/settings.local.json:"
printf '  "%s",\n' "${MISSING[@]}"
echo "Mẫu đầy đủ: .specify/workflows/feature-pipeline/templates/settings.local.json.example"
exit 1
