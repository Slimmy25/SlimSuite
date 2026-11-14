local function upvalue(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i) if not n then return SS.ENV and SS.ENV[want] end if n == want then return v end i = i + 1 end end
SU = upvalue(SS.SetupHide, "SU")
SS.StartSetup(true); Tick(3)
local b = SU.barButtons.PlayerFrame
local problems = 0
for i, mode in ipairs({ "enabled", "disabled", "default" }) do
	Click(b.states[i]); Tick(2)
	if SU.Mode("PlayerFrame") ~= mode then problems = problems + 1; print("mode button", mode, "did not apply") end
end
RunScript(b.nameHit, "OnMouseUp", "RightButton"); Tick(2)
if SU.focus ~= "PlayerFrame" then problems = problems + 1; print("right-clicking the name did not open its settings") end
print("mode/name problems:", problems, "errors:", #ERRORS)
for _, e in ipairs(ERRORS) do print("  " .. e) end
