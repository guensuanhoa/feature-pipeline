#!/usr/bin/env bash
# Assemble the two installable bundles from shared/ + <agent>/ into dist/.
# `specify workflow add` copies only the package dir, so shared files must be merged here.
# usage: bash feature-pipeline/build.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

for pair in "claude:feature-pipeline" "codex:feature-pipeline-codex"; do
  agent=${pair%%:*}; id=${pair#*:}; out="$ROOT/dist/$id"

  # A path present in both shared/ and <agent>/ would silently overwrite; fail instead.
  dup=$(comm -12 <(cd shared && find . -type f | sort) <(cd "$agent" && find . -type f | sort))
  [[ -z "$dup" ]] || { echo "Trùng file giữa shared/ và $agent/: $dup" >&2; exit 1; }

  rm -rf "$out"; mkdir -p "$out"
  cp -R shared/. "$out/"
  cp -R "$agent"/. "$out/"
  chmod +x "$out"/scripts/*.sh
  grep -q "id: \"$id\"" "$out/workflow.yml" || { echo "workflow id sai trong $out" >&2; exit 1; }
done

echo "Đã build vào $ROOT/dist. Cài bằng:"
echo "  specify workflow add ./feature-pipeline/dist/feature-pipeline --dev"
echo "  specify workflow add ./feature-pipeline/dist/feature-pipeline-codex --dev"
