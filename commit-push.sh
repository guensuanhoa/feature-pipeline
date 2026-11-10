#!/usr/bin/env bash
# Commit with a GPG signature and push, so you never think about signing.
# Run it from a terminal: the passphrase prompt needs one (a git GUI has none, which is why
# its own signed commit fails with "Inappropriate ioctl for device").
#
# usage: ./commit-push.sh "feat(scope): message"        commit what is staged, then push
#        ./commit-push.sh -a "fix(scope): message"      stage tracked changes first (git commit -a)
#
# How it works: it unlocks the signing key once (gpg-agent then caches the passphrase for
# default-cache-ttl seconds), then runs a normal git commit and git push.
set -euo pipefail

ALL=()
if [[ "${1:-}" == "-a" ]]; then ALL=(-a); shift; fi
MSG="${1:-}"
[[ -n "$MSG" ]] || { echo "usage: ./commit-push.sh [-a] \"commit message\"" >&2; exit 1; }

cd "$(git rev-parse --show-toplevel)"

if (( ${#ALL[@]} == 0 )) && git diff --cached --quiet; then
  echo "Chưa có gì được stage. Chạy git add <file>, hoặc dùng -a cho file tracked đã sửa." >&2
  exit 1
fi

# Sign when the repo or global config asks for it
if [[ "$(git config --get commit.gpgsign || true)" == "true" ]]; then
  # gpg needs the terminal to ask for the passphrase
  [[ -t 0 ]] || { echo "Cần chạy trong terminal để nhập passphrase GPG." >&2; exit 1; }
  GPG_TTY="$(tty)"; export GPG_TTY
  echo "Mở khoá GPG key (nhập passphrase nếu được hỏi)..."
  echo "unlock" | gpg --clearsign >/dev/null
fi

git commit ${ALL[@]+"${ALL[@]}"} -m "$MSG"
git push
