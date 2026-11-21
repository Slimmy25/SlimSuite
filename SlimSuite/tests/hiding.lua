-- Hide feature and the Disabled state hide every element, whether the UI is locked or being edited
local function upvalue(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i) if not n then return SS.ENV and SS.ENV[want] end if n == want then return v end i = i + 1 end end
SU = upvalue(SS.SetupHide, "SU")
local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("  MISMATCH " .. label) end end
for _, state in ipairs({ "locked", "editing" }) do
	SS.SetUnlocked(state == "editing", true); Tick(3)
	for _, m in ipairs(SS.MOVABLE) do
		local name = m[1]; local f = getglobal(name)
		if f and f.GetAlpha then
			SS.DB().muted[name] = nil; SS.ToggleFeatureMute(name); Tick(6)
			check("Hide feature hides " .. name .. " (" .. state .. ")", f:GetAlpha() == 0)
			SS.ToggleFeatureMute(name); Tick(2)
		end
		local shown = getglobal(SS.Shown(name)) or f
		if shown and shown.GetAlpha and SS.ELEMENTS[name] then
			SU.SetMode(name, "disabled", SS.ELEMENTS[name].title or name); Tick(6)
			check("Disabled hides " .. name .. " (" .. state .. ")", shown.shown == false or shown:GetAlpha() == 0)
			SU.SetMode(name, "default", SS.ELEMENTS[name].title or name); Tick(2)
		end
	end
end
print("errors: " .. #ERRORS)
print("hiding problems: " .. bad)
if bad > 0 or #ERRORS > 0 then error("hiding regressions") end
