#!/usr/bin/env bash
# Test, commit, push main, then tag and push the tag. Pushing the tag starts
# .github/workflows/release.yml, which builds the zips + catalog.json and publishes the Release.
#
# Inputs (both git-ignored, edit them before each release):
#   .release/tag             first non-comment line = the tag to create
#   .release/commit-message  commit message; lines starting with '#' are dropped
#
# Tag naming: vMAJOR.MINOR.PATCH, always with the leading "v" (the workflow only fires on v*.*.*).
#   PATCH  v0.2.2 -> v0.2.3   bug fix, wording or default change, no change to inputs or step order
#   MINOR  v0.2.3 -> v0.3.0   new workflow input, new step, new gate, behavior users must know about
#   MAJOR  v0.3.0 -> v1.0.0   breaking change: removed or renamed input, resume of old runs no longer works
# Latest tag: git tag --sort=-v:refname | head -1
#
# Commit message: Conventional Commits, no AI-tool wording in the subject.
#   <type>(<scope>): <what changed, imperative, <= 72 chars>
#   <blank line>
#   <body: why, and what behavior differs. Wrap at ~80 chars>
#   <blank line>
#   Co-Authored-By: <name> <noreply@anthropic.com>   (keep if an AI wrote part of the change)
#   types: feat fix chore docs refactor test | scope is usually feature-pipeline
#
# usage: bash release.sh              run everything
#        bash release.sh --dry-run    run tests and all checks, change nothing
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

BRANCH="main"
REMOTE="origin"
# Only these paths are committed; anything else in the working tree is left alone.
PATHS=(README.md build.sh release.sh claude codex shared tests .github .gitignore)
TAG_FILE=".release/tag"
MSG_FILE=".release/commit-message"

DRY_RUN=0
case "${1:-}" in
  "") ;;
  --dry-run) DRY_RUN=1 ;;
  *) echo "usage: bash release.sh [--dry-run]" >&2; exit 1 ;;
esac

die() { echo "Lỗi: $*" >&2; exit 1; }
run() { if (( DRY_RUN )); then echo "[dry-run] $*"; else "$@"; fi; }

[[ -f "$TAG_FILE" ]] || die "thiếu $TAG_FILE"
[[ -f "$MSG_FILE" ]] || die "thiếu $MSG_FILE"

TAG="$(grep -vE '^[[:space:]]*(#|$)' "$TAG_FILE" | head -1 | tr -d '[:space:]')"
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "tag '$TAG' sai định dạng, cần vX.Y.Z (xem comment đầu release.sh)"

MESSAGE="$(grep -vE '^[[:space:]]*#' "$MSG_FILE")"
[[ -n "${MESSAGE//[[:space:]]/}" ]] || die "$MSG_FILE rỗng (sau khi bỏ dòng comment)"

[[ "$(git branch --show-current)" == "$BRANCH" ]] || die "phải đứng ở nhánh $BRANCH"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "tag $TAG đã tồn tại ở local"
git ls-remote --exit-code --tags "$REMOTE" "refs/tags/$TAG" >/dev/null 2>&1 && die "tag $TAG đã tồn tại trên $REMOTE"

echo "Tag:     $TAG (trước đó: $(git tag --sort=-v:refname | head -1))"
echo "Message: $(printf '%s' "$MESSAGE" | head -1)"
echo

bash tests/run-tests.sh

git add -- "${PATHS[@]}" 2>/dev/null || true
if git diff --cached --quiet; then
  die "không có thay đổi nào để commit trong: ${PATHS[*]}"
fi
git --no-pager diff --cached --stat
echo

# --cleanup=strip also drops any '#' line that slipped into the message
run git commit --cleanup=strip -F "$MSG_FILE"
run git push "$REMOTE" "$BRANCH"
run git tag "$TAG"
run git push "$REMOTE" "$TAG"

if (( DRY_RUN )); then
  git reset -q -- "${PATHS[@]}" 2>/dev/null || true
  echo "Dry run xong: đã bỏ stage, chưa commit/push/tag."
else
  echo "Xong. Theo dõi release: gh run watch  (hoặc tab Actions trên GitHub)"
fi
