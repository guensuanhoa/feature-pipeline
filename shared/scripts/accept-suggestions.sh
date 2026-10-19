#!/usr/bin/env bash
# Run when the user answers "continue" at the open-questions gate: accept the suggested answer
# of every NEEDS CLARIFICATION marker, so later agents see a settled spec instead of stopping.
# Marker format is a contract with prompts/clarify-auto.md:
#   [NEEDS CLARIFICATION: <question> — gợi ý: <suggested answer>]
# Each marker is recorded as "- Q: ... → A: ..." under "## Clarifications". A marker on its own line
# is deleted; a marker inside a sentence is replaced by its answer so the sentence stays complete.
# Any "NEEDS CLARIFICATION" left afterwards (no suggestion, unparsable) fails the step, spec untouched.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

FEATURE_DIR="$(cat .specify/pipeline/current-feature 2>/dev/null || true)"
SPEC="$FEATURE_DIR/spec.md"
if [[ -z "$FEATURE_DIR" || ! -f "$SPEC" ]]; then
  echo "Không tìm thấy spec.md (xem bước locate-feature)."
  exit 1
fi

TMP="$(mktemp "${TMPDIR:-/tmp}/accept-suggestions.XXXXXX")"
trap 'rm -f "$TMP" "$TMP.err"' EXIT

# awk exit codes: 0 = rewritten, 10 = markers left that cannot be accepted, 11 = no marker at all
awk -v today="$(date +%F)" '
  BEGIN { open_tag = "[NEEDS CLARIFICATION: "; sep = " — gợi ý: "; n = 0; accepted = 0; remaining = 0 }

  # Return the index of the "]" that closes the "[" at position start (brackets may nest).
  function closing(str, start,    i, c, depth) {
    depth = 0
    for (i = start; i <= length(str); i++) {
      c = substr(str, i, 1)
      if (c == "[") depth++
      else if (c == "]" && --depth == 0) return i
    }
    return 0
  }

  {
    line = $0; out = ""; got = 0
    while ((s = index(line, open_tag)) > 0) {
      e = closing(line, s)
      if (e == 0) break
      body = substr(line, s + length(open_tag), e - s - length(open_tag))
      k = index(body, sep)
      if (k == 0) { out = out substr(line, 1, e); line = substr(line, e + 1); continue }
      q[++accepted] = substr(body, 1, k - 1)
      a[accepted] = substr(body, k + length(sep))
      out = out substr(line, 1, s - 1) a[accepted]
      line = substr(line, e + 1); got++
    }
    out = out line

    # Whatever still mentions the marker could not be accepted (no suggestion, or unparsable)
    rest = out
    while ((i = index(rest, "NEEDS CLARIFICATION")) > 0) { remaining++; rest = substr(rest, i + 1) }

    # A line that was exactly one accepted marker disappears; its answer lives in Clarifications
    t = $0; gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
    if (got == 1 && index(t, open_tag) == 1 && closing(t, 1) == length(t)) next
    buf[++n] = out
  }

  END {
    print "ACCEPTED=" accepted > "/dev/stderr"
    print "REMAINING=" remaining > "/dev/stderr"
    if (remaining > 0) exit 10
    if (accepted == 0) exit 11

    block = "### Session " today " (accepted at pipeline gate)\n"
    for (i = 1; i <= accepted; i++) block = block "\n- Q: " q[i] " → A: " a[i]
    block = block "\n"

    # Insert at the end of "## Clarifications", or create that section before the first "## "
    clar = 0; insert_at = 0; first_h2 = 0
    for (i = 1; i <= n; i++) {
      if (buf[i] == "## Clarifications") { clar = i; continue }
      if (buf[i] ~ /^## /) {
        if (clar) { insert_at = i; break }
        if (!first_h2) first_h2 = i
      }
    }
    if (clar && !insert_at) insert_at = n + 1
    if (!clar) { insert_at = first_h2 ? first_h2 : n + 1; block = "## Clarifications\n\n" block }

    for (i = 1; i <= n; i++) {
      if (i == insert_at) {
        if (i > 1 && buf[i - 1] != "") print ""
        print block
      }
      print buf[i]
    }
    if (insert_at == n + 1) { print ""; printf "%s", block }
  }
' "$SPEC" >"$TMP" 2>"$TMP.err"
RC=$?
cat "$TMP.err"

case "$RC" in
  0)
    # Write in place (not mv) so the spec keeps its file mode
    cat "$TMP" > "$SPEC"
    # The question list shown at the gate is answered now
    rm -f .specify/pipeline/open-questions.md
    echo "Đã ghi các gợi ý vào $SPEC (mục Clarifications)."
    ;;
  11) echo "Spec không có marker nào để chấp nhận." ;;
  10) echo "Còn marker không có gợi ý hoặc sai định dạng, không thể tự chấp nhận. Spec giữ nguyên: $SPEC"; exit 1 ;;
  *) echo "Lỗi khi xử lý $SPEC (awk exit $RC). Spec giữ nguyên."; exit 1 ;;
esac
exit 0
