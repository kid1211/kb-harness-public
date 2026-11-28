#!/usr/bin/env bash
# R11 of plans/worktree-end: the worktree-sync skill is gone, and no live file names it.
# Records of the past keep their text: alt- files, changelogs, the fixtures of spec, the e2e case of the removal,
# and plans/release-video/, whose worktree video changes in a round of its own.
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 1
fail=0
for d in .claude/skills/worktree-sync tests/e2e/worktree-sync; do
  [ -e "$d" ] && { echo "FAIL $d still exists"; fail=1; }
done
hits="$(git grep -l 'worktree-sync' -- . \
  ':!**/alt-*.md' ':!scripts/public-release/public/changelogs/' ':!tests/skills/spec/fixtures/' \
  ':!plans/release-video/' ':!tests/plans/release-video/' ':!plans/worktree-end/' \
  ':!tests/skills/worktree-end/test-no-worktree-sync.sh' ':!tests/e2e/worktree-end/no-worktree-sync.md')"
if [ -n "$hits" ]; then
  echo "FAIL these files name worktree-sync:"; printf '  %s\n' $hits; fail=1
fi
[ "$fail" = 0 ] && echo "ok   no worktree-sync left"
exit "$fail"
