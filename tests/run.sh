#!/usr/bin/env bash
#
# tests/run.sh — dependency-free test runner for resolve-issues.
# Exercises select-issues.sh ordering (network-free via --input). The Codex review-loop
# mechanics live in the `codex-review` plugin (a dependency) and are tested there.
# Run: tests/run.sh
#
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIX="$ROOT/tests/fixtures"
SELECT="$ROOT/scripts/select-issues.sh"

pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
no()   { fail=$((fail+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || no "$1" "expected [$2] got [$3]"; }

echo "select-issues.sh"
order="$(bash "$SELECT" --input "$FIX/issues-mixed.json" | jq -r '[.[].number] | join(",")')"
assert_eq "priority+recency ordering" "30,29,27,31,12,18" "$order"

ranks="$(bash "$SELECT" --input "$FIX/issues-mixed.json" | jq -r '[.[].priorityRank] | join(",")')"
assert_eq "priorityRank per issue"   "0,0,1,2,3,99"       "$ranks"

capped="$(bash "$SELECT" --input "$FIX/issues-mixed.json" --max 2 | jq -r '[.[].number] | join(",")')"
assert_eq "--max caps to top N"      "30,29"              "$capped"

allopen="$(bash "$SELECT" --input "$FIX/issues-mixed.json" | jq -r 'all(.[]; .state=="open")')"
assert_eq "only open issues"          "true"              "$allopen"

echo
printf 'Total: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
