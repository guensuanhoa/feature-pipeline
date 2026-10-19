#!/usr/bin/env bash
# In tóm tắt cuối pipeline để bạn biết cần xem gì tiếp theo.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 0

DIR=".specify/pipeline"
FEATURE="$(cat "$DIR/current-feature" 2>/dev/null || echo "không rõ")"
STATUS="$(cat "$DIR/last-check.status" 2>/dev/null || echo "không rõ")"

echo "===== ${1:-Pipeline v0} hoàn tất ====="
echo "Feature:         $FEATURE"
echo "Kiểm tra cuối:   $STATUS"
echo "Nhánh hiện tại:  $(git branch --show-current 2>/dev/null || echo '?')"
echo
echo "Thay đổi so với commit gần nhất:"
git status --short 2>/dev/null | head -40
echo
echo "Tiếp theo: xem diff, tự tạo PR (v0 chưa tự tạo PR)."
echo "Log: $DIR/last-check.log, $DIR/fix.log, $DIR/fix-notes.md"
exit 0
