#!/usr/bin/env bash
#
# tests/run.sh — dependency-free test runner for the resolve-issues scripts.
# Exercises the pure (network-free) paths: select-issues.sh ordering and the
# codex-review-loop.sh classifier. Run: tests/run.sh
#
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIX="$ROOT/tests/fixtures"
SELECT="$ROOT/scripts/select-issues.sh"
CODEX="$ROOT/scripts/codex-review-loop.sh"

pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
no()   { fail=$((fail+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

# assert_eq <name> <expected> <actual>
assert_eq() { [ "$2" = "$3" ] && ok "$1" || no "$1" "expected [$2] got [$3]"; }

echo "select-issues.sh"
# priority order then newest-first: 30,29(rank0 tie -> higher number first),27,31,12,18
order="$(bash "$SELECT" --input "$FIX/issues-mixed.json" | jq -r '[.[].number] | join(",")')"
assert_eq "priority+recency ordering" "30,29,27,31,12,18" "$order"

ranks="$(bash "$SELECT" --input "$FIX/issues-mixed.json" | jq -r '[.[].priorityRank] | join(",")')"
assert_eq "priorityRank per issue"   "0,0,1,2,3,99"       "$ranks"

capped="$(bash "$SELECT" --input "$FIX/issues-mixed.json" --max 2 | jq -r '[.[].number] | join(",")')"
assert_eq "--max caps to top N"      "30,29"              "$capped"

allopen="$(bash "$SELECT" --input "$FIX/issues-mixed.json" | jq -r 'all(.[]; .state=="open")')"
assert_eq "only open issues"          "true"              "$allopen"

echo "codex-review-loop.sh classify"
clean="$(bash "$CODEX" classify --input "$FIX/codex-clean.json" | jq -r .status)"
assert_eq "clean pass detected"      "clean"             "$clean"

fstatus="$(bash "$CODEX" classify --input "$FIX/codex-findings.json" | jq -r .status)"
assert_eq "findings detected"        "findings"          "$fstatus"

fcount="$(bash "$CODEX" classify --input "$FIX/codex-findings.json" | jq -r '.findings | length')"
assert_eq "finding count (2 inline + 1 review)" "3"      "$fcount"

working="$(bash "$CODEX" classify --input "$FIX/codex-working.json" | jq -r .status)"
assert_eq "no new bot activity => working" "working"     "$working"

cw="$(bash "$CODEX" classify --input "$FIX/codex-clean-wins.json" | jq -r .status)"
assert_eq "clean signal wins over stale inline" "clean"  "$cw"

stdin_clean="$(bash "$CODEX" classify < "$FIX/codex-clean.json" | jq -r .status)"
assert_eq "classify reads stdin"     "clean"             "$stdin_clean"

echo
printf 'Total: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
