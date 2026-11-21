local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("  MISMATCH " .. label) end end
for k, fn in pairs(SlashCmdList or {}) do if string.find(k, "SLIM") then fn("perf 2") break end end
check("perf is measuring", SS.perf ~= nil)
Tick(25)
check("perf stops by itself", SS.perf == nil)
local found = false
for _, l in ipairs(SlimSuiteDB.actionLog or {}) do if string.find(l, "[perf]", 1, true) then found = true end end
check("the report is in the action log", found)
print("errors: " .. #ERRORS); print("perf problems: " .. bad)
if bad > 0 or #ERRORS > 0 then error("perf") end
