-- the game's addon API, mocked: kill tally (3%), timer safety, SS.Safe arguments, item link names, the error log filter
local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("  MISMATCH " .. label) end end

-- kill tally: a boss at 3% or less counts once; a Guardian at 0 counts; one that leaves the list alive does not
AZS_GetPhase = function() return "playing" end
AZS_GetMeterContext = function() return { runId = "run1", uiSessionId = 1, epoch = 1 } end
AZS_RUN = { kills = 0 }
AZS_UNITS = { { id = 1, name = "Boss", kind = "boss", hp = 500, hpm = 1000 },
	{ id = 2, name = "Guard", kind = "guardian", hp = 100, hpm = 100 },
	{ id = 3, name = "Runner", kind = "guardian", hp = 90, hpm = 100 } }
Tick(3)
local b, g = SlimSuiteWorld.RunKills()
check("nothing killed yet", b == 0 and g == 0)
AZS_UNITS[1].hp = 30                                    -- 3%
AZS_UNITS[2].hp = 0
table.remove(AZS_UNITS, 3)                              -- left the list alive
Tick(3)
b, g = SlimSuiteWorld.RunKills()
check("boss at 3% counts as a kill", b == 1)
check("guardian at 0 counts, one that left alive does not", g == 1)
Tick(5)
b, g = SlimSuiteWorld.RunKills()
check("a kill counts only once", b == 1 and g == 1)
AZS_UNITS[1].hp = 40                                    -- 4%: still alive
AZS_UNITS[1].id = 9
Tick(3)
check("a boss at 4% is not a kill", (SlimSuiteWorld.RunKills()) == 1)

-- timer: a task that starts and stops others while the tasks run
local ran = {}
SS.Every("t_a", 0, function() ran.a = (ran.a or 0) + 1; SS.Stop("t_b"); if not ran.started then ran.started = true; SS.Every("t_c", 0, function() ran.c = (ran.c or 0) + 1 end) end end)
SS.Every("t_b", 0, function() ran.b = (ran.b or 0) + 1 end)
Tick(3)
SS.Stop("t_a"); SS.Stop("t_c")
check("stopped task does not run", not ran.b)
check("task started from a task runs", (ran.c or 0) >= 1)
Tick(2)
local a = ran.a
Tick(2)
check("stopped tasks stay stopped", ran.a == a)

-- SS.Safe passes nils in the middle through
local got
SS.Safe(function(x, y, z) got = { x, y, z } end, 1, nil, 3)
check("Safe keeps arguments after a nil", got and got[1] == 1 and got[2] == nil and got[3] == 3)

-- item links give their own name
check("item link name", SS.ItemLinkName("|cff1eff00|Hitem:1234:0:0:0|h[Ring of Tests]|h|r") == "Ring of Tests")

-- the error log keeps Slim Suite's errors and leaves other addons' alone
local before = table.getn(SS.ErrorLog())
local saved = SS.LogError
_ERRORMESSAGE("Interface\\AddOns\\Other\\Other.lua:1: boom")
check("other addons' errors are not logged", table.getn(SS.ErrorLog()) == before)
_ERRORMESSAGE("Interface\\AddOns\\SlimSuite\\SlimSuite.lua:1: boom")
check("Slim Suite's errors are logged", table.getn(SS.ErrorLog()) == before + 1)
SS.LogError = saved
for _, e in ipairs(ERRORS) do if string.find(e, "boom", 1, true) then ERRORS[_] = nil end end

-- the HUD: hidden parts are given back when Slim Suite lets go
local shown = {}
AZS_SetHudShown = function(part, on) shown[part] = on end
AZS_IsHudShown = function(part) return shown[part] ~= false end
SS.HideNative("localClock", true)
check("hiding a HUD part", shown.localClock == false)
SS.RestoreNatives()
check("restoring it", shown.localClock ~= false)

AZS_UNITS = nil; AZS_RUN = nil
print("api problems: " .. bad)
for _, e in pairs(ERRORS) do print("  " .. e) end
