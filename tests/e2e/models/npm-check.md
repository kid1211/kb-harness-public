# models: npm run check typechecks and tests every model of a fresh clone

## Covers

- `scripts/check-models.sh`
- `package.json`

## Setup

1. Make a temp folder `$T`.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test.
3. In `$T/h`, run `npm ci`.

## Steps

1. In `$T/h`, run `npm run check`.

## Expected

1. Step 1 prints one `ok` line for each `.qnt` file that git tracks, with its module and test count.
2. The last line is `models: <n> ok, 0 failed`, and the exit code is 0.

## Cleanup

1. Delete `$T`.
