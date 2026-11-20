-- HUD Edit Mode: one tick box per element; click cycles Off -> On -> Default -> Off; Revert All sets Default.
local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SU = SS.ENV.SU
SS.SetupEnd(true); Tick(3,.1)
print("SU", SU ~= nil); SS.OpenHUDEdit(); print("hud", SlimSuiteHUDEditMode ~= nil)
check("window opens", SlimSuiteHUDEditMode:IsShown())
local boxes=0; local first
for _,name in ipairs(SS.SETUP_ORDER) do boxes=boxes+1 end
local count=0
for _,f in ipairs(SS.hudBoxes or {}) do count=count+1; first=first or f end
check("one tick box per setup element (got "..count.." for "..boxes..")", count==boxes)
-- cycle one element through its three states by clicking its box
local name=first.elementName
SU.SetMode(name,"default"); RunScript(first,"OnClick")
check("Default clicked goes to Off", SU.Mode(name)=="disabled")
RunScript(first,"OnClick"); check("Off clicked goes to On", SU.Mode(name)=="enabled" and first:GetChecked()~=nil)
RunScript(first,"OnClick"); check("On clicked goes to Default", SU.Mode(name)=="default" and first.defaultText:IsShown())
-- Revert All sets every element to Default
SU.SetMode(name,"enabled")
RunScript(SS.hudRevertAll,"OnClick")
local stillOn=0; for _,n in ipairs(SS.SETUP_ORDER) do if SU.Mode(n)~="default" then stillOn=stillOn+1 end end
check("Revert All Changes returns every element to Default", stillOn==0)
print("hud edit problems: "..bad)
assert(bad==0 and #ERRORS==0,"HUD edit regressions")
