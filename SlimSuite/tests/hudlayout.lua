-- HUD Edit Mode search filters the list; the Talents window shows only the trees with points.
local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SU = SS.ENV.SU
SS.SetupEnd(true); Tick(3,.1)
SS.OpenHUDEdit()
local all=table.getn(SS.HUDOrder())
local function visibleRows() local n=0 for _,r in pairs(SS.hudRows) do if r.frame:IsShown() then n=n+1 end end return n end
-- search: only rows whose label contains the text stay shown
local function typed(text)
 SlimSuiteHUDSearch:SetText(text); this=SlimSuiteHUDSearch
 SlimSuiteHUDSearch:GetScript("OnTextChanged")()
end
typed("player")
local matched, wrong = 0, 0
for name,r in pairs(SS.hudRows) do
 if r.frame:IsShown() then matched=matched+1; if not string.find(string.lower(SS.T((SS.ELEMENTS[name] and (SS.ELEMENTS[name].label or SS.ELEMENTS[name].title)) or name)),"player",1,true) then wrong=wrong+1 end end
end
check("search shows some rows", matched>0)
check("search shows only matching rows", wrong==0)
check("search hides the rest", matched<all)
typed("")
check("clearing the search shows every row", visibleRows()==all)
-- talents: three trees, only tree 2 has points, so only that tab shows
GetNumTalentTabs = function() return 3 end
GetTalentTabInfo = function(i) return "Tree"..i, "", (i==2) and 5 or 0 end
for i=1,3 do CreateFrame("Button", "TalentFrameTab"..i, UIParent) end
SU.SetMode("TalentFrame","enabled")
SS.ApplyTalentTrees()
check("one tree with points hides the tab row", not TalentFrameTab1:IsShown() and not TalentFrameTab2:IsShown() and not TalentFrameTab3:IsShown())
GetTalentTabInfo = function(i) return "Tree"..i, "", (i==1 or i==2) and 5 or 0 end
SS.ApplyTalentTrees()
check("two trees with points show two tabs", TalentFrameTab1:IsShown() and TalentFrameTab2:IsShown() and not TalentFrameTab3:IsShown())
GetTalentTabInfo = function(i) return "Tree"..i, "", (i==3) and 5 or 0 end
SS.ApplyTalentTrees()
check("a different single tree also hides the tab row", not TalentFrameTab1:IsShown() and not TalentFrameTab3:IsShown())
SU.SetMode("TalentFrame","default")
SS.ApplyTalentTrees()
check("Original shows every tab", TalentFrameTab1:IsShown() and TalentFrameTab2:IsShown() and TalentFrameTab3:IsShown())
print("hud layout problems: "..bad)
assert(bad==0 and #ERRORS==0,"HUD layout regressions")
