# public-release: the scans of a fresh clone catch planted hits and pass a clean folder

## Covers

- `scripts/public-release/scan.sh`
- `scripts/public-release/scan.py`
- `scripts/public-release/pii-allow.txt`
- `scripts/public-release/deny-allow/`

## Setup

1. Make a temp folder `$T`.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test.
3. Write `$T/deny.txt` with the one line `term1`.
4. Make the folder `$T/s`. Write `hello term1` into `$T/s/b.md`, and `clean` into `$T/s/c.md`.
5. Make the folder `$T/c`. Write `clean` into `$T/c/c.md`.
6. Run each step below with `DENY_LIST=$T/deny.txt`. If `gitleaks` is not installed, also with `ALLOW_NO_GITLEAKS=1`.

## Steps

1. In `$T/h`, run `bash scripts/public-release/tests/test-scan.sh`.
2. Run `bash $T/h/scripts/public-release/scan.sh plant`.
3. Run `bash $T/h/scripts/public-release/scan.sh names $T/s`. Keep its exit code.
4. Run `bash $T/h/scripts/public-release/scan.sh pii $T/c` and `bash $T/h/scripts/public-release/scan.sh names $T/c`.
5. Run `python3 -I $T/h/scripts/public-release/scan.py e2e $T/h`.

## Expected

1. Step 1 exits 0 and ends with `<n> passed, 0 failed`.
2. Step 2 exits 0 and prints `planted hits caught: <n>`, with `<n>` at least 9.
3. Step 3 exits 1 and prints `b.md:1 name`. It never prints `term1`.
4. Both scans of step 4 exit 0.
5. For the public repo, step 5 exits 0 and prints nothing. For the private harness, it names files that do not go public.

## Cleanup

1. Delete `$T`.
