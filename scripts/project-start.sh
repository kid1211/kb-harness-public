#!/bin/bash
# Start claude in the harness with each folder of one project added by --add-dir, so the
# harness hooks run and each folder's own skills load.
#
#   project-start.sh <project> [--worktree <name>] [claude args...]
#
# The folders come from the project map (scripts/project-map.py), one row per repo: Claude
# Code loads skills only from the top of an added folder. With --worktree, each code repo (a git repo whose role is not
# KB) is added as its worktree <repo>/.claude/worktrees/<name> on branch <name>, made if
# missing. Nothing is ever deleted.
# Plans: plans/global/components/multi-folder/components/project-start/,
# code-worktrees/.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
map="$root/scripts/project-map.py"
if [ $# -lt 1 ]; then
  echo "usage: project-start.sh <project>|--from <folder> [--worktree <name>] [claude args...]" >&2
  python3 -I "$map" list >&2
  exit 64
fi
# --from <folder>: the project of the folder on the map. A folder on no row starts nothing.
from=
if [ "$1" = --from ]; then
  case "$2" in ""|-) echo "no folder: '$2'" >&2; exit 64 ;; esac
  from=$(cd "$2" 2>/dev/null && pwd -P) || { echo "no folder: '$2'" >&2; exit 64; }
  shift 2
  err=$(python3 -I "$map" check "$from" 2>&1); rc=$?
  [ $rc -gt 1 ] && { echo "$err" >&2; exit $rc; }
  if [ $rc = 1 ]; then
    m=${PROJECT_MAP:-$(dirname "$(git -C "$root" rev-parse --path-format=absolute --git-common-dir)")/projects-mapping.md}
    echo "not on the map: $from" >&2
    python3 -I "$map" list >&2
    echo "Add a row for it to $m, with its project, then run this again." >&2
    exit 1
  fi
  set -- "$(python3 -I "$map" project "$from")" "$@"
fi
project=$1; shift
wt=
if [ "$1" = --worktree ]; then
  wt=$2; shift 2
  [ -n "$wt" ] && git check-ref-format --branch "$wt" >/dev/null 2>&1 || { echo "not a branch name: '$wt'" >&2; exit 64; }
fi
rows=$(python3 -I "$map" roles "$project") || { rc=$?; [ -n "$rows" ] && printf '%s\n' "$rows" >&2; exit $rc; }

# Each mapped folder, whole, with its role. Map each repo on its own row.
list=()
while IFS=$'\t' read -r f role; do
  [ -z "$f" ] && continue
  if [ ! -d "$f" ]; then echo "missing: $f" >&2; continue; fi
  list+=("$f"$'\t'"$role")
done <<< "$rows"

# --from: the git root of the folder is added too, with the role of the map row that holds it.
# Its CLAUDE.md and the map say which subfolder does what.
if [ -n "$from" ]; then
  top=$(git -C "$from" rev-parse --show-toplevel 2>/dev/null || echo "$from")
  # The role of the longest row that holds the folder, by real paths, so a KB repo whose row
  # is a subfolder gets no worktree.
  best=; role=
  while IFS=$'\t' read -r f r; do
    rf=$(cd "$f" 2>/dev/null && pwd -P) || continue
    case "$from/" in "$rf"/*) [ ${#rf} -gt ${#best} ] && { best=$rf; role=$r; } ;; esac
  done <<< "$rows"
  list+=("$top"$'\t'"$role")
fi

# The worktree of a code repo, made or reused, and kept out of the repo's git status.
worktree_of() {
  local repo=$1 dir="$1/.claude/worktrees/$wt" ex
  if [ ! -d "$dir" ]; then
    if git -C "$repo" rev-parse -q --verify "refs/heads/$wt" >/dev/null; then
      git -C "$repo" worktree add -q "$dir" "$wt" >&2
    else
      git -C "$repo" worktree add -q -b "$wt" "$dir" >&2
    fi || { echo "worktree add failed: $repo" >&2; return 1; }
  fi
  ex="$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
  grep -qx '.claude/worktrees/' "$ex" 2>/dev/null || { mkdir -p "$(dirname "$ex")"; echo '.claude/worktrees/' >> "$ex"; }
  printf '%s\n' "$dir"
}

args=(); seen=" "
for item in "${list[@]}"; do
  f=${item%%$'\t'*}; role=${item#*$'\t'}
  r=$(cd "$f" && pwd -P)
  [ "$r" = "$root" ] && continue
  # A folder in a code repo, the repo itself or a subfolder, goes by the same path in its worktree.
  top=$(git -C "$f" rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$wt" ] && [ -n "$top" ] && [ "$(tr '[:upper:]' '[:lower:]' <<< "$role")" != kb ]; then
    w=$(worktree_of "$top") || exit 1
    f="$w${r#"$top"}"
    [ -d "$f" ] || { echo "not in the worktree: $f" >&2; continue; }
    r=$(cd "$f" && pwd -P)
  fi
  case "$seen" in *" $r "*) continue ;; esac
  seen+="$r "
  args+=(--add-dir "$f")
  echo "added: $f" >&2
done
cd "$root" && exec claude "${args[@]}" "$@"
