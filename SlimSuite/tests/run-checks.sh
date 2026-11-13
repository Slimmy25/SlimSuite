#!/bin/sh
# Run every check before a change is pushed. Fails (exit 1) on any Lua error, balance, stale-name or load-order problem.
# Needs python3 and a Lua 5.3 or newer: luahbtex (LuaTeX) by default, or any other with LUA="lua5.3" sh tests/run-checks.sh
LUA="${LUA:-luahbtex --luaonly}"
cd "$(dirname "$0")/.." || exit 1
fail=0
run() { echo "== $1"; out=$(eval "$2" 2>&1); echo "$out" | tail -3; echo "$out" | grep -qE "attempt to|syntax error|problems: [1-9]|<-- BAD|TICK |MISMATCH|FAIL seed" && { echo "FAILED: $1"; fail=1; }; }
run "block balance"   "python3 tests/bal.py SlimSuite.lua SlimSuiteFrames.lua SlimSuiteEdit.lua SlimSuiteSetup.lua SlimSuiteCommands.lua"
run "stale names"     "python3 tests/stale.py SlimSuite.lua SlimSuiteFrames.lua SlimSuiteEdit.lua SlimSuiteSetup.lua SlimSuiteCommands.lua"
run "load order"      "python3 tests/order.py SlimSuite.lua SlimSuiteFrames.lua SlimSuiteEdit.lua SlimSuiteSetup.lua SlimSuiteCommands.lua"
run "shared kit"      "python3 tests/kitversion.py"
run "lua 5.0"         "python3 tests/lua50.py SlimSuiteCore.lua AZSKit.lua SlimSuiteErrors.lua SlimSuiteItems.lua SlimSuiteMeter.lua SlimSuite.lua SlimSuiteFrames.lua SlimSuiteEdit.lua SlimSuiteSetup.lua SlimSuiteCommands.lua SlimSuiteWorld.lua"
for s in cards movable square window menu fuzz setup selfparty choices target partyorder xpart marks api review; do
  run "harness: $s" "cd tests && SCENARIO=$s SEED=7 STEPS=300 $LUA run.lua"
done
[ $fail -eq 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit $fail
