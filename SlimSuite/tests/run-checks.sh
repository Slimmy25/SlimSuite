#!/bin/sh
# Run every check before a change is pushed. Fails (exit 1) on any Lua error, balance, stale-name or load-order problem.
# Needs: luahbtex (LuaTeX, --luaonly) and python3. Run from anywhere: sh tests/run-checks.sh
cd "$(dirname "$0")/.." || exit 1
fail=0
run() { echo "== $1"; out=$(eval "$2" 2>&1); echo "$out" | tail -3; echo "$out" | grep -qE "attempt to|syntax error|problems: [1-9]|<-- BAD|TICK |MISMATCH" && { echo "FAILED: $1"; fail=1; }; }
run "block balance"   "python3 tests/bal.py SlimSuite.lua"
run "stale names"     "python3 tests/stale.py SlimSuite.lua"
run "load order"      "python3 tests/order.py"
for s in cards movable square window menu fuzz setup selfparty choices target partyorder xpart marks; do
  run "harness: $s" "cd tests && SCENARIO=$s SEED=7 STEPS=300 luahbtex --luaonly run.lua"
done
[ $fail -eq 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit $fail
