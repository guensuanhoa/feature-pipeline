#!/usr/bin/env bash
# Tìm thư mục feature vừa được specify tạo ra và đếm chỗ còn đánh dấu NEEDS CLARIFICATION.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 0

DIR=".specify/pipeline"
mkdir -p "$DIR"

FEATURE_DIR=""
BRANCH="$(git branch --show-current 2>/dev/null || true)"

# Ưu tiên feature_directory mà Spec Kit ghi trong .specify/feature.json
FROM_JSON=""
if [[ -f ".specify/feature.json" ]]; then
  FROM_JSON="$(sed -n 's/.*"feature_directory"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .specify/feature.json | head -1)"
  FROM_JSON="${FROM_JSON%/}"
fi

if [[ -n "$FROM_JSON" && -f "$FROM_JSON/spec.md" ]]; then
  FEATURE_DIR="$FROM_JSON"
# Kế đến: thư mục trùng tên nhánh hiện tại
elif [[ -n "$BRANCH" && -f "specs/$BRANCH/spec.md" ]]; then
  FEATURE_DIR="specs/$BRANCH"
else
  # Dự phòng: thư mục trong specs/ được sửa gần nhất
  LATEST="$(ls -td specs/*/ 2>/dev/null | head -1 || true)"
  LATEST="${LATEST%/}"
  if [[ -n "$LATEST" && -f "$LATEST/spec.md" ]]; then
    FEATURE_DIR="$LATEST"
  fi
fi

if [[ -z "$FEATURE_DIR" ]]; then
  echo "FEATURE_DIR=NOT_FOUND"
  echo "CẢNH BÁO: không tìm thấy spec.md trong specs/. Kiểm tra bước specify trước khi approve."
  exit 0
fi

echo "$FEATURE_DIR" > "$DIR/current-feature"
OPEN="$(grep -c "NEEDS CLARIFICATION" "$FEATURE_DIR/spec.md" 2>/dev/null || true)"
OPEN="${OPEN:-0}"

echo "FEATURE_DIR=$FEATURE_DIR"
echo "SPEC_FILE=$FEATURE_DIR/spec.md"
echo "OPEN_QUESTIONS=$OPEN"
if [[ "$OPEN" != "0" ]]; then
  echo "CẢNH BÁO: spec còn $OPEN chỗ NEEDS CLARIFICATION. Hãy xử lý trước khi approve."
fi
exit 0
