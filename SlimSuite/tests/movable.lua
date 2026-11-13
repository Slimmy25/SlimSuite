local function upvalue(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i) if not n then return SS.ENV and SS.ENV[want] end if n == want then return v end i = i + 1 end end
SU = upvalue(SS.SetupHide, "SU")
SS.StartSetup(true); Tick(3)
Click(SU.barButtons.PlayerFrame); Tick(2)
local function row(label) for i = 1, #SU.checks do if SU.checks[i]:IsVisible() and SU.checks[i].label.text:find(label, 1, true) then return SU.checks[i] end end end
local m = row("Movable")
print("movable row", m and m.label.text, m and m.checked)
Click(m); Tick(3)
print("after untick: errors", #ERRORS); for _, e in ipairs(ERRORS) do print("  " .. e) end
ERRORS = {}
Click(m); Tick(3)
print("after retick: errors", #ERRORS); for _, e in ipairs(ERRORS) do print("  " .. e) end
