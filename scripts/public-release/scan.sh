#!/bin/bash
# The scans of plans/public-release, shared by sync-release, the hooks of the public clone and the
# CI of the public repo. Each hit prints as <file>:<line> <rule>, never the matched text.
#   scan.sh pii <dir>      PII off the allow list, then the secrets of gitleaks (needed, unless ALLOW_NO_GITLEAKS=1)
#   scan.sh names <dir>    the deny list of $DENY_LIST, default deny-list.txt here
#   scan.sh plant          each scan must catch a planted hit of each kind, or this fails (scans_catch?)
#   scan.sh release <dir> <base>   R56, in the scans job with pii: each file has an e2e test, and the PR
#                          adds a changelog whose E2E tests part names each test that covers a change
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
DENY_LIST=${DENY_LIST:-$HERE/deny-list.txt}

pii() {
  python3 -I "$HERE/scan.py" pii "$1" "${ALLOW_LIST:-$HERE/pii-allow.txt}" || return 1
  if command -v gitleaks >/dev/null; then
    gitleaks dir --no-banner --redact "$1" || return 1
  elif [ "${ALLOW_NO_GITLEAKS:-}" != 1 ]; then
    echo "gitleaks is not installed, so the secret scan cannot run. Install it, or set ALLOW_NO_GITLEAKS=1."
    return 1
  fi
}

# Each planted hit sits alone in a throwaway folder. $SCAN, a test hook, stands in for this script.
plant() {
  local W caught=0 n term
  W=$(mktemp -d); trap 'rm -rf "$W"' RETURN
  one() { # $1 the kind, $2 the scan mode, $3 the planted text. The message names the kind only.
    local d; d=$(mktemp -d "$W/p.XXXXXX")
    printf 'x %s x\n' "$3" > "$d/planted.txt"
    if bash "${SCAN:-$HERE/scan.sh}" "$2" "$d" >/dev/null 2>&1; then
      echo "the $2 scan missed a planted $1 (scan_broken)"; return 1
    fi
    caught=$((caught+1))
  }
  [ -s "$DENY_LIST" ] || { echo "no deny list to plant from: $DENY_LIST"; return 1; }
  while IFS=$'\t' read -r n term; do one "deny list term $n" names "$term" || return 1
  done < <(awk '{t=$0; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t)} t != "" && t !~ /^#/ {print NR "\t" t}' "$DENY_LIST")
  one email pii "canary.person@$(printf 'example.%s' org)" || return 1
  one phone pii "416-555-$(printf '%04d' 199)" || return 1
  for k in "account number" card "masked card" "card brand" sin "bare phone"; do
    one "$k" pii "$(python3 -I "$HERE/scan.py" sample "$k")" || return 1
  done
  if command -v gitleaks >/dev/null || [ "${ALLOW_NO_GITLEAKS:-}" != 1 ]; then
    one secret pii "token = $(python3 -c 'import secrets, string; print("ghp_" + "".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(36)))')" || return 1
  else
    echo "the secret check is skipped: no gitleaks, and ALLOW_NO_GITLEAKS=1"
  fi
  echo "planted hits caught: $caught"
}

# R56: a release PR holds its changelog and its e2e tests. <dir> is a git checkout, <base> the PR base.
release() {
  local d=$1 base=$2 rc=0 new f t W
  python3 -I "$HERE/scan.py" e2e "$d" || rc=1
  new=$(git -C "$d" diff --name-only --diff-filter=A "$base" HEAD -- 'changelogs/*.md') || { echo "release: cannot diff against $base"; return 1; }
  [ -n "$new" ] || { echo "changelogs/: the PR adds no changelog (no_changelog)"; return 1; }
  W=$(mktemp -d); trap 'rm -rf "$W"' RETURN
  git -C "$d" diff --name-only "$base" HEAD -- . ':!changelogs/' > "$W/changed"
  python3 -I "$HERE/scan.py" e2e-for "$d" "$W/changed" > "$W/want"
  for f in $new; do
    grep -qx '## E2E tests' "$d/$f" || { echo "$f: no E2E tests part (no_e2e)"; rc=1; continue; }
    while IFS= read -r t; do
      [ -z "$t" ] || grep -qxF -- "- $t" "$d/$f" || { echo "$f: the E2E tests part does not name $t (no_e2e)"; rc=1; }
    done < "$W/want"
  done
  return $rc
}

case "${1:-}" in
  pii)   pii "$2" ;;
  names) python3 -I "$HERE/scan.py" names "$2" "$DENY_LIST" ;;
  plant) plant ;;
  release) release "$2" "$3" ;;
  *)     sed -n '2,6p' "$0" >&2; exit 2 ;;
esac
