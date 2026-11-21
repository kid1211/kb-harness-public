# link-kb: a new KB is wired to the harness, and the harness itself is refused

## Covers

- `scripts/link-kb.sh`
- `templates/kb/`

## Setup

1. Make a temp folder `$T`.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test.

## Steps

1. Run `bash $T/h/scripts/link-kb.sh $T/kb`. Keep its exit code.
2. Run `ls -la $T/kb/.claude` and `ls -la $T/kb/.git/hooks`.
3. Run step 1 again.
4. Run `bash $T/h/scripts/link-kb.sh $T/h`. Keep its exit code.

## Expected

1. Step 1 exits 0, and `$T/kb` is a git repo.
2. In step 2, `CLAUDE.md`, `skills`, `hooks`, `settings.json`, `lib` and `agents` of `$T/kb/.claude` are links into `$T/h/.claude/`.
3. In step 2, `pre-commit`, `post-commit` and `pre-push` of `$T/kb/.git/hooks` are links into `$T/h/.claude/hooks/`.
4. `$T/kb/CLAUDE.md`, `$T/kb/.gitignore` and `$T/kb/.vscode/settings.json` exist, copied from `$T/h/templates/kb/`.
5. Step 3 exits 0. No file that step 1 created changed.
6. Step 4 exits 2, and its error says the folder is the harness itself.

## Cleanup

1. Delete `$T`.
