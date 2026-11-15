#!/usr/bin/env bash
# commit-page.sh <page>: commit one findings page alone in the KB, on main, and push it.
# Takes the same lock as kb-commit-nudge.sh, so the two never commit in the repo at once.
set -u
here=$(cd "$(dirname "$0")" && pwd)
page=$1
kb=$(git -C "${SESSION_RETRO_KB:-$HOME/second-brain/personal}" rev-parse --show-toplevel) || { echo "no KB repo"; exit 1; }
branch=$(git -C "$kb" symbolic-ref --short HEAD 2>/dev/null)
[[ $branch == main ]] || { echo "the KB is on ${branch:-a detached HEAD}, not main"; exit 1; }
python3 -I "$here/findings-page.py" check "$page" || exit 1
python3 -I "$here/../../kb/scripts/kb-check.py" file "$page" || { echo "kb-check.py refused the page"; exit 1; }

nudge=${KB_NUDGE_DIR:-${TMPDIR:-/tmp}/kb-commit-nudge}
mkdir -p "$nudge"
lock="$nudge/lock-$(printf '%s' "$kb" | cksum | cut -d' ' -f1)" got=""
for _ in $(seq 1 60); do mkdir "$lock" 2>/dev/null && { got=1; break; }; sleep 1; done
[[ -n $got ]] || { echo "the KB lock stayed busy for 60 seconds"; exit 1; }
trap 'rmdir "$lock"' EXIT

rel=${page#"$kb"/}
git -C "$kb" add -- "$rel" || exit 1
if ! git -C "$kb" diff --cached --quiet -- "$rel"; then
  git -C "$kb" commit -q -m "session-retro: findings of session $(basename "$rel" .staging.md)" -- "$rel" || exit 1
fi
# A failed rebase is undone, so the KB is never left half rebased.
if ! git -C "$kb" pull -q --rebase --autostash; then
  git -C "$kb" rebase --abort 2>/dev/null
  echo "committed, but the pull failed, so it is not pushed"; exit 1
fi
git -C "$kb" push -q || { echo "committed, but the push failed"; exit 1; }
