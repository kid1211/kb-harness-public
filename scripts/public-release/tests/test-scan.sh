#!/bin/bash
# Unit tests of the scans of plans/public-release, with a made-up deny list. They are public: the
# CI of the public repo runs them. No test file holds a real term or a literal email.
#   bash scripts/public-release/tests/test-scan.sh [-v]
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
V=${1:-}
PASS=0; FAIL=0
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
export DENY_LIST="$T/deny.txt"
printf '# a comment line\nzorblax\n\n测试词\n' > "$DENY_LIST"
ok()    { PASS=$((PASS+1)); [ -n "$V" ] && echo "ok   $1"; return 0; }
bad()   { FAIL=$((FAIL+1)); echo "FAIL $1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }
one()   { rm -rf "$T/d"; mkdir -p "$T/d"; printf '%s\n' "$2" > "$T/d/$1"; }
S="$HERE/scan.sh"

one a.md "the Zorblax tool";       bash "$S" names "$T/d" > "$T/out"; rc=$?
check "names: a term in any case stops" '[ $rc -ne 0 ] && grep -q "a.md:1" "$T/out"'
check "names: the hit names file:line, never the term" '! grep -qi zorblax "$T/out"'
one b.md "zorblax_x and zorblax2"; bash "$S" names "$T/d" > /dev/null; rc=$?
check "names: no ASCII letter touches the term, so _x and 2 still match" '[ $rc -ne 0 ]'
one c.md "zorblaxes everywhere";  bash "$S" names "$T/d" > /dev/null; rc=$?
check "names: a longer word does not match" '[ $rc -eq 0 ]'
one d.md "这是测试词的例子";        bash "$S" names "$T/d" > /dev/null; rc=$?
check "names: a CJK term matches inside a word" '[ $rc -ne 0 ]'
one e.md "Ｚｏｒｂｌａｘ";          bash "$S" names "$T/d" > /dev/null; rc=$?
check "names: a full-width term matches after the NFKC fold" '[ $rc -ne 0 ]'
one ok.md "clean"; mkdir -p "$T/d/zorblax"; echo x > "$T/d/zorblax/f.txt"
bash "$S" names "$T/d" > /dev/null; rc=$?
check "names: a term in a path stops" '[ $rc -ne 0 ]'

mail="someone.real@$(printf 'example.%s' net)"
one m.md "write to $mail"; ALLOW_NO_GITLEAKS=1 bash "$S" pii "$T/d" > "$T/out"; rc=$?
check "pii: an email off the allow list stops, and its text is not printed" '[ $rc -ne 0 ] && grep -q "m.md:1 email" "$T/out" && ! grep -q someone "$T/out"'
printf '%s\n' "$mail" > "$T/allow.txt"
ALLOW_LIST="$T/allow.txt" ALLOW_NO_GITLEAKS=1 bash "$S" pii "$T/d" > /dev/null; rc=$?
check "pii: an email on the allow list passes" '[ $rc -eq 0 ]'
one p.md "call 416 555 $(printf '%04d' 123)"; ALLOW_NO_GITLEAKS=1 bash "$S" pii "$T/d" > /dev/null; rc=$?
check "pii: a phone number stops" '[ $rc -ne 0 ]'

# R40: cards, masked cards, a brand word with digits, SIN numbers and bare phone numbers.
# No literal number sits in this file: each is built here, with its Luhn digit.
luhn() { python3 -I -c 'import sys
d=sys.argv[1]; t=0
for i,c in enumerate(reversed(d)):
    n=int(c)*(1 if i%2 else 2); t+=n-9 if n>9 else n
print(d+str((10-t%10)%10))' "$1"; }
rep() { printf "%${2}s" | tr ' ' "$1"; }
pii() { one "$1" "$2"; ALLOW_NO_GITLEAKS=1 bash "$S" pii "$T/d" > "$T/out"; }
visa=$(luhn "4$(rep 1 14)"); amex=$(luhn "37$(rep 8 12)"); sin=$(luhn "1$(rep 3 7)")
pii v.md "card ${visa:0:4} ${visa:4:4} ${visa:8:4} ${visa:12:4}"; rc=$?
check "card: a Visa number with spaces stops, named card" '[ $rc -ne 0 ] && grep -q "v.md:1 card" "$T/out"'
pii v.md "card ${visa:0:4}-${visa:4:4}-${visa:8:4}-${visa:12:4}"; rc=$?
check "card: a Visa number with dashes stops" '[ $rc -ne 0 ]'
pii a.md "card ${amex:0:4} ${amex:4:6} ${amex:10:5}"; rc=$?
check "card: an Amex number 4-6-5 stops" '[ $rc -ne 0 ] && grep -q "a.md:1 card" "$T/out"'
bad16="${visa:0:15}$(( (${visa:15:1} + 1) % 10 ))"
pii w.md "id ${bad16:0:4} ${bad16:4:4} ${bad16:8:4} ${bad16:12:4}"; rc=$?
check "card: 16 digits that fail the Luhn check pass" '[ $rc -eq 0 ]'
pii m.md "paid with $(rep '•' 4) $(rep 4 1)$(rep 2 3)"; rc=$?
check "masked card: four dots and the last 4 digits stop" '[ $rc -ne 0 ] && grep -q "m.md:1 masked card" "$T/out"'
pii m.md "paid with $(rep '*' 4)-$(rep 7 4)"; rc=$?
check "masked card: four stars, a dash and 4 digits stop" '[ $rc -ne 0 ]'
pii m.md "the year **$(rep 2 1)0$(rep 2 2)** in bold"; rc=$?
check "masked card: a bold 4-digit number in Markdown passes" '[ $rc -eq 0 ]'
pii b.md "Visa ending $(rep 5 4)"; rc=$?
check "card brand: Visa followed by digits stops" '[ $rc -ne 0 ] && grep -q "b.md:1 card brand" "$T/out"'
pii b.md "the Amex card $(rep 9 4) was used"; rc=$?
check "card brand: Amex, a word, then digits stops" '[ $rc -ne 0 ]'
pii b.md "Mastercard x$(rep 3 4)"; rc=$?
check "card brand: Mastercard x and digits stops" '[ $rc -ne 0 ]'
pii b.md "apply for a travel visa before the trip"; rc=$?
check "card brand: the word visa alone passes" '[ $rc -eq 0 ]'
pii s.md "sin ${sin:0:3} ${sin:3:3} ${sin:6:3}"; rc=$?
check "sin: 9 digits 3-3-3 that pass Luhn stop, named sin" '[ $rc -ne 0 ] && grep -q "s.md:1 sin" "$T/out"'
pii s.md "sin $sin"; rc=$?
check "sin: 9 bare digits that pass Luhn stop" '[ $rc -ne 0 ]'
badsin="${sin:0:8}$(( (${sin:8:1} + 1) % 10 ))"
pii s.md "id $badsin"; rc=$?
check "sin: 9 digits that fail Luhn pass" '[ $rc -eq 0 ]'
pii p.md "call $(rep 4 1)16$(rep 5 3)0$(rep 1 1)99"; rc=$?
check "phone: 10 digits with no separators stop" '[ $rc -ne 0 ] && grep -q "p.md:1 phone" "$T/out"'
pii p.md "at time 1$(rep 7 9)"; rc=$?
check "phone: 10 digits that start with 1, such as a timestamp, pass" '[ $rc -eq 0 ]'
pii p.md "the card number above"; rc=$?
check "pii: a line that only says card passes" '[ $rc -eq 0 ]'
# The published files of the scans hold no hit of their own rules.
rm -rf "$T/self"; mkdir -p "$T/self/tests"; cp "$HERE/scan.sh" "$HERE/scan.py" "$HERE/pii-allow.txt" "$T/self/"; cp "$0" "$T/self/tests/"
ALLOW_NO_GITLEAKS=1 bash "$S" pii "$T/self" > "$T/out"; rc=$?
check "pii: the published scan files pass their own scan" '[ $rc -eq 0 ]'
[ -n "$V" ] && cat "$T/out"

ALLOW_NO_GITLEAKS=1 bash "$S" plant > "$T/out"; rc=$?
n=10; command -v gitleaks > /dev/null && n=11
check "plant: the real scans catch each planted hit, the secret too when gitleaks is here" '[ $rc -eq 0 ] && grep -q "planted hits caught: $n" "$T/out"'
printf '#!/bin/bash\nexit 0\n' > "$T/blind.sh"
SCAN="$T/blind.sh" ALLOW_NO_GITLEAKS=1 bash "$S" plant > "$T/out"; rc=$?
check "plant: a scan that finds nothing fails, naming the kind, never the term" '[ $rc -ne 0 ] && grep -q "deny list term 2" "$T/out" && ! grep -qi zorblax "$T/out"'
printf '#!/bin/bash\nif [ "$1" = pii ] && grep -rq "@" "$2"; then exit 0; fi\nexec bash "%s" "$@"\n' "$S" > "$T/missmail.sh"
SCAN="$T/missmail.sh" ALLOW_NO_GITLEAKS=1 bash "$S" plant > "$T/out"; rc=$?
check "plant: a PII scan that misses the email fails" '[ $rc -ne 0 ] && grep -q "missed a planted email" "$T/out"'
mkdir -p "$T/bin"; printf '#!/bin/bash\nexit 0\n' > "$T/bin/gitleaks"; chmod +x "$T/bin/gitleaks"
PATH="$T/bin:$PATH" bash "$S" plant > "$T/out"; rc=$?
check "plant: a gitleaks that finds nothing fails" '[ $rc -ne 0 ] && grep -q "missed a planted secret" "$T/out"'
DENY_LIST="$T/none.txt" bash "$S" plant > "$T/out"; rc=$?
check "plant: no deny list fails" '[ $rc -ne 0 ] && grep -q "no deny list" "$T/out"'

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
