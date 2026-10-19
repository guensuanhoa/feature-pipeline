#!/usr/bin/env bash
# Dò lệnh build/lint/test của project một lần và ghi vào .specify/pipeline/commands.env.
# Nếu file đã tồn tại thì giữ nguyên, không ghi đè.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 0

DIR=".specify/pipeline"
FILE="$DIR/commands.env"
mkdir -p "$DIR"

if [[ -f "$FILE" ]]; then
  echo "COMMANDS_EXISTING: $FILE"
  exit 0
fi

BUILD=""
LINT=""
TEST=""

if [[ -f go.mod ]]; then
  BUILD="go build ./..."
  TEST="go test ./..."
  if command -v golangci-lint >/dev/null 2>&1; then
    LINT="golangci-lint run"
  fi
elif [[ -f package.json ]]; then
  PM="npm"
  [[ -f pnpm-lock.yaml ]] && PM="pnpm"
  [[ -f yarn.lock ]] && PM="yarn"
  grep -q '"test"[[:space:]]*:' package.json && TEST="$PM test"
  grep -q '"lint"[[:space:]]*:' package.json && LINT="$PM run lint"
  grep -q '"build"[[:space:]]*:' package.json && BUILD="$PM run build"
elif [[ -f gradlew ]]; then
  TEST="./gradlew test"
elif [[ -f pom.xml ]]; then
  TEST="mvn -q test"
elif [[ -f pyproject.toml || -f pytest.ini || -f setup.cfg ]]; then
  TEST="pytest -q"
fi

# Nếu project có Makefile với target test thì ưu tiên cách team đang dùng
if [[ -f Makefile ]] && grep -qE '^test:' Makefile; then
  TEST="make test"
fi

# List stack markers at the root and one level down. Commands above only cover the root, so a
# repo with code in subfolders (or several stacks) needs the user to fill commands by hand.
MARKERS=""
for m in go.mod package.json pom.xml gradlew pyproject.toml Cargo.toml Makefile project.godot; do
  for f in "$m" */"$m"; do
    [[ -f "$f" && "$f" != node_modules/* ]] && MARKERS="$MARKERS $f"
  done
done
for f in *.csproj */*.csproj; do
  [[ -f "$f" ]] && MARKERS="$MARKERS $f"
done
MARKERS="${MARKERS# }"
STACK_DIRS="$(for f in $MARKERS; do dirname "$f"; done | sort -u)"
STACK_DIR_COUNT="$(printf '%s\n' "$STACK_DIRS" | grep -c . || true)"

cat > "$FILE" <<EOF
# Detected stack markers: ${MARKERS:-none}
# Lệnh mà pipeline dùng để kiểm tra độc lập sau khi implement.
# Sửa lại nếu chưa đúng. Để trống ("") nếu project không có bước đó.
# Lưu ý: file này được thực thi bằng quyền của bạn, chỉ ghi lệnh bạn tin tưởng.
BUILD_CMD="$BUILD"
LINT_CMD="$LINT"
TEST_CMD="$TEST"
EOF

echo "COMMANDS_CREATED: $FILE"
echo "  BUILD_CMD=\"$BUILD\""
echo "  LINT_CMD=\"$LINT\""
echo "  TEST_CMD=\"$TEST\""
if [[ "$STACK_DIR_COUNT" -gt 1 ]] || [[ -n "$STACK_DIRS" && "$STACK_DIRS" != "." ]]; then
  echo "CẢNH BÁO: phát hiện stack ngoài root hoặc nhiều stack ($MARKERS)."
  echo "  Lệnh check chỉ phủ phần đã điền. Điền lệnh cho mọi stack trong $FILE trước khi approve."
fi
if [[ -z "$TEST" ]]; then
  echo "CẢNH BÁO: không tìm được lệnh test, hãy điền TEST_CMD thủ công trước khi approve."
fi
exit 0
