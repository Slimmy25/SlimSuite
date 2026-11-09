local function upvalue(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i) if not n then return nil end if n == want then return v end i = i + 1 end end
SU = upvalue(SS.SetupHide, "SU")
SS.StartSetup(true); Tick(3)
local b = SU.barButtons.BuffFrame
SS.DB().buffsOnPlayer = false; Click(b); Tick(2)
print("buff frame on, buffs not on player: tag", b.tag.text.text, "on", SU.on.BuffFrame)
SS.DB().buffsOnPlayer = true; SU.RefreshBar()
print("buffs on player: tag", b.tag.text.text, "label", b:GetFontString().text)
print(table.concat(ERRORS, "\n"))
