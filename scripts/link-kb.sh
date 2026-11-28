#!/usr/bin/env bash
# Wire a knowledge-base repo to this harness. See README.md.
#
#   scripts/link-kb.sh <kb-dir>
#
# - creates <kb-dir> and runs `git init` there if needed
# - links .claude/{CLAUDE.md,skills,hooks,settings.json,lib,agents} to this harness
# - copies starter files the KB owns (CLAUDE.md, .gitignore, .vscode/,
#   .claude/settings.local.json) only where they don't exist yet
# - links the KB's git pre-commit, post-commit and pre-push hooks to this harness
#
# Safe to re-run: links are refreshed, existing files are never overwritten.
# Links are absolute, so re-run it after moving either repo.

set -euo pipefail

HARNESS="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMPLATES="$HARNESS/templates/kb"

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <kb-dir>" >&2
  exit 2
fi

mkdir -p "$1"
KB="$(CDPATH="" cd "$1" && pwd -P)"
if [[ "$KB" == "$HARNESS" ]]; then
  echo "error: $KB is the harness itself" >&2
  exit 2
fi

if [[ ! -d "$KB/.git" ]]; then
  git -C "$KB" init -q -b main
  echo "git init   $KB"
fi

link() { # link <harness-path> <kb-path>
  local src="$1" dst="$2"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    echo "error: $dst exists and is not a symlink — move it aside, then re-run" >&2
    exit 1
  fi
  ln -sfn "$src" "$dst"
  echo "link       ${dst#"$KB"/} -> $src"
}

starter() { # starter <template-path> <kb-path>
  local src="$1" dst="$2"
  if [[ -e "$dst" ]]; then
    echo "keep       ${dst#"$KB"/} (exists)"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
  echo "create     ${dst#"$KB"/}"
}

mkdir -p "$KB/.claude"
for item in CLAUDE.md skills hooks settings.json lib agents; do
  link "$HARNESS/.claude/$item" "$KB/.claude/$item"
done

starter "$TEMPLATES/CLAUDE.md"            "$KB/CLAUDE.md"
starter "$TEMPLATES/gitignore"            "$KB/.gitignore"
starter "$TEMPLATES/vscode"               "$KB/.vscode"
starter "$TEMPLATES/settings.local.json"  "$KB/.claude/settings.local.json"

if ! grep -qxF '/.claude/' "$KB/.gitignore"; then
  printf '\n# links into the harness — versioned there, not here\n/.claude/\n' >> "$KB/.gitignore"
  echo "append     .gitignore: /.claude/"
fi

hooks_dir="$(git -C "$KB" rev-parse --absolute-git-dir)/hooks"
mkdir -p "$hooks_dir"
link "$HARNESS/.claude/hooks/pre-commit-checks/pre-commit.dispatcher" "$hooks_dir/pre-commit"
link "$HARNESS/.claude/hooks/post-commit.harness-dirty"               "$hooks_dir/post-commit"
link "$HARNESS/.claude/hooks/pre-push.block-main"                     "$hooks_dir/pre-push"

echo
echo "Done. Open Claude Code in $KB and run /context to confirm .claude/CLAUDE.md loaded."
