-- the new-school cards show the real player and target once they exist
local function upvalue(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i) if not n then return nil end if n == want then return v end i = i + 1 end end
SS.DB().newFrames = true
SS.ApplyNewFrames(); Tick(2)
local pc = getglobal("SlimSuitePlayerCard")
print("player card shown:", pc and pc:IsShown(), "name:", pc and pc.name and pc.name.text)
print("PlayerFrame alpha:", PlayerFrame.alpha)
SS.DB().partyIncludesSelf = true; SS.RefreshCard(pc)
print("player card with you in party (should be hidden):", pc.shown)
SS.DB().partyIncludesSelf = false; SS.DB().newFrames = false
print(table.concat(ERRORS, "\n"))
