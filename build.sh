#!/usr/bin/env bash
# Assemble the two installable bundles from shared/ + <agent>/ into dist/.
# `specify workflow add` copies only the package dir, so shared files must be merged here.
# With VERSION set, also stamp that version into each bundle and write release assets
# (one zip per workflow + catalog.json) into dist/release/.
# usage: bash feature-pipeline/build.sh
#        VERSION=0.2.0 bash feature-pipeline/build.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

VERSION="${VERSION:-}"
REPO="${GITHUB_REPOSITORY:-guensuanhoa/feature-pipeline}"
RELEASE="$ROOT/dist/release"
CATALOG_ENTRIES=()

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

  [[ -n "$VERSION" ]] || continue

  # Spec Kit rejects a download whose workflow.yml version differs from the catalog.
  sed -E "s/^(  version: ).*/\1\"$VERSION\"/" "$out/workflow.yml" > "$out/workflow.yml.tmp"
  mv "$out/workflow.yml.tmp" "$out/workflow.yml"
  grep -q "^  version: \"$VERSION\"$" "$out/workflow.yml" || { echo "không ghi được version vào $out" >&2; exit 1; }

  # Spec Kit accepts an archive with workflow.yml inside exactly one top-level dir.
  mkdir -p "$RELEASE"
  zip_name="$id-$VERSION.zip"
  rm -f "$RELEASE/$zip_name"
  (cd "$ROOT/dist" && zip -qr "$RELEASE/$zip_name" "$id")

  name=$(sed -nE 's/^  name: "(.*)"$/\1/p' "$out/workflow.yml")
  description=$(sed -nE 's/^  description: "(.*)"$/\1/p' "$out/workflow.yml")
  CATALOG_ENTRIES+=("    \"$id\": {
      \"name\": \"$name\",
      \"version\": \"$VERSION\",
      \"description\": \"$description\",
      \"url\": \"https://github.com/$REPO/releases/download/v$VERSION/$zip_name\"
    }")
done

if [[ -z "$VERSION" ]]; then
  echo "Đã build vào $ROOT/dist. Cài bằng:"
  echo "  specify workflow add ./feature-pipeline/dist/feature-pipeline --dev"
  echo "  specify workflow add ./feature-pipeline/dist/feature-pipeline-codex --dev"
  exit 0
fi

{
  echo '{'
  echo '  "schema_version": "1.0",'
  echo '  "workflows": {'
  (IFS=$'\n'; printf '%s' "${CATALOG_ENTRIES[0]}"; printf ',\n%s' "${CATALOG_ENTRIES[@]:1}")
  echo
  echo '  }'
  echo '}'
} > "$RELEASE/catalog.json"

echo "Đã build release $VERSION vào $RELEASE"
