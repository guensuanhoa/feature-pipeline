#!/usr/bin/env bash
# Report (never fail) which sandbox Spec Kit's codex dispatch will most likely run with.
# Sources checked, strongest first: SPECKIT_INTEGRATION_CODEX_EXTRA_ARGS, sandbox_mode in the
# Codex config, then the project's trust_level (Codex runs trusted projects with workspace-write).
# A wrong guess is not fatal: the require-artifact guards stop the run if nothing gets written.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG="${CODEX_HOME:-$HOME/.codex}/config.toml"
EXTRA="${SPECKIT_INTEGRATION_CODEX_EXTRA_ARGS:-}"

ok() {
  echo "Codex sandbox: $1 (nguồn: $2)"
  [[ "$1" == "read-only" ]] && echo "CẢNH BÁO: sandbox read-only; specify/plan/tasks/implement không ghi được file."
  exit 0
}

case "$EXTRA" in
  *workspace-write*) ok "workspace-write" "SPECKIT_INTEGRATION_CODEX_EXTRA_ARGS" ;;
  *danger-full-access*) ok "danger-full-access" "SPECKIT_INTEGRATION_CODEX_EXTRA_ARGS" ;;
  *read-only*) ok "read-only" "SPECKIT_INTEGRATION_CODEX_EXTRA_ARGS" ;;
esac

if [[ -f "$CONFIG" ]]; then
  # Top-level sandbox_mode only: keys inside [tables] belong to profiles or other sections
  MODE="$(awk '/^[[:space:]]*\[/ {exit} /^[[:space:]]*sandbox_mode[[:space:]]*=/ {gsub(/.*=[[:space:]]*["\047]|["\047].*/, ""); print; exit}' "$CONFIG")"
  [[ -n "$MODE" ]] && ok "$MODE" "$CONFIG"

  TRUST="$(awk -v hdr="[projects.\"$ROOT\"]" '
    index($0, hdr) { inside = 1; next }
    inside && /^[[:space:]]*\[/ { exit }
    inside && /trust_level/ { gsub(/.*=[[:space:]]*["\047]|["\047].*/, ""); print; exit }
  ' "$CONFIG")"
  [[ "$TRUST" == "trusted" ]] && ok "workspace-write" "project trusted trong $CONFIG"
fi

echo "CẢNH BÁO: không xác định được sandbox của Codex; mặc định có thể là read-only."
echo "Nếu agent không ghi được file, guard sau plan/tasks/implement sẽ dừng pipeline."
echo "Muốn chắc chắn: export SPECKIT_INTEGRATION_CODEX_EXTRA_ARGS=\"--sandbox workspace-write\"."
exit 0
