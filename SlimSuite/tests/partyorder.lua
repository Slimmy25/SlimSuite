-- with yourself in the party you go first, in a run, the setup and Demo Mode alike: the top thin line, and the classic
-- plate placed right before the first member (above it in a column, left of it in a row)
local function upvalue(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i) if not n then return SS.ENV and SS.ENV[want] end if n == want then return v end i = i + 1 end end
SU = upvalue(SS.SetupHide, "SU")
local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("  MISMATCH " .. label) end end
local function plateBefore()
	local pts = SlimSuitePartySelfFrame and SlimSuitePartySelfFrame.points or {}
	local p = pts[1]
	return p and p[2] == PartyMemberFrame1 and (p[1] == "BOTTOM" or p[1] == "RIGHT")
end
local function round(mode)
	SS.SetLook("PartyMemberFrame1", "thin"); Tick(2)
	local line = SlimSuitePartyLines.lines[1]
	check(mode .. ": the first thin line is you", line.unit == "player" and line.shown)
	SS.SetLook("PartyMemberFrame1", "classic"); Tick(2)
	check(mode .. ": your plate shows", SlimSuitePartySelfFrame and SlimSuitePartySelfFrame.shown)
	check(mode .. ": your plate is before the first member", plateBefore())
	SU.SetPartyRow(true); Tick(2)
	check(mode .. ": in a row too", plateBefore())
	SU.SetPartyRow(false); Tick(2)
end
SS.SetPartySelf(true); Tick(2)
round("run")
SS.StartSetup(true); Tick(3)
if not SS.DB().partyIncludesSelf then SS.SetPartySelf(true); Tick(2) end
round("setup")
SS.StartDemoMode(); Tick(10); round("demo"); SS.StopDemoMode(); Tick(3)
SS.SetupEnd(true); Tick(3)
SS.SetPartySelf(false); Tick(2)
check("leaving hides your plate", not SlimSuitePartySelfFrame.shown)
print("party order problems: " .. bad)
print("errors: " .. #ERRORS); for _, e in ipairs(ERRORS) do print("  " .. e) end
