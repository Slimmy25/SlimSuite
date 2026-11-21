local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SS.StartSetup(true)
local d=SS.DB(); local setup=SS.SU
local function Rect(f,l,r,b,t)
 f.GetLeft=function() return l end; f.GetRight=function() return r end
 f.GetBottom=function() return b end; f.GetTop=function() return t end
 f:SetWidth(r-l); f:SetHeight(t-b)
end
local owner=CreateFrame("Frame",nil,UIParent); Rect(owner,100,200,100,200)
local region=owner:CreateFontString(nil,"OVERLAY"); Rect(region,110,210,110,125)
SS.EnforceElementBounds(owner)
check("region crossing the right edge is invisible",region:GetAlpha()==0)
Rect(region,110,190,110,125); SS.EnforceElementBounds(owner)
check("suppressed content returns when it fits",region:GetAlpha()==1)
Rect(region,110,190,95,110); SS.EnforceElementBounds(owner)
check("region crossing the bottom is invisible",region:GetAlpha()==0)
SS.EnforceElementBounds(owner,true)
check("native restoration releases bounds suppression",region:GetAlpha()==1)
local text=owner:CreateFontString(nil,"OVERLAY"); text:SetText(string.rep("W",100))
SS.FitText(text,35,7,12)
check("minimum font size cannot leave overflowing glyphs",text:GetStringWidth()<=35)
SS.FitText(text,700,7,12)
check("truncated text is restored when enlarged",text:GetText()==string.rep("W",100))
setup.SetMode("SlimSuiteStatCounterFrame","enabled","Stats"); d.sizes.SlimSuiteStatCounterFrame=nil; SS.UpdateStats()
check("stats starts at the damage meter default size",SlimSuiteStatCounterFrame:GetWidth()==230 and SlimSuiteStatCounterFrame:GetHeight()==170)
AZS_GetPhase=function() return "ready" end; AZS_ZONE={run="containment-run"}; AZS_STATS={hp=100,dmg=1.2}; AZS_RUN={hp=100,hpm=100,sh=0}
d.statBaseline=nil; SS.statPreviousPhase=nil; SS.CaptureStatBaseline()
AZS_GetPhase=function() return "playing" end; AZS_STATS.dmg=1.7; AZS_RUN.hpm=125; d.statDisplayMode="split"
local entries=SS.StatEntries(); local byKey={}; for _,entry in ipairs(entries) do byKey[entry.key]=entry.value end
check("split totals include all changes since the baseline",byKey.dmg=="1.20 + 0.50" and byKey.hp=="100 + 25")
d.statHidden={dmg=true}; entries=SS.StatEntries(); local found=false; for _,entry in ipairs(entries) do if entry.key=="dmg" then found=true end end
check("each stat can be independently hidden",not found)
AZS_ZONE.run="late-run"; d.statHidden={}; entries=SS.StatEntries(); byKey={}; for _,entry in ipairs(entries) do byKey[entry.key]=entry.value end
check("mid-run enable never invents a baseline",byKey.dmg=="1.70")
local options={}
for _,group in ipairs({"core","combat","utility","details"}) do
 SS.statSettingsGroup=group
 for _,option in ipairs(SS.StatSettings()) do if not option.choice then options[option[1]]=true end end
end
for _,field in ipairs(SS.STAT_FIELDS) do check("every stat has a menu toggle: "..field[1],options[SS.T(field[2])]) end
check("HP, racial and buff details have menu toggles",options[SS.T("HP")] and options[SS.T("Racial")] and options[SS.T("Active buffs")])
local exported=SS.LayoutFromText(SS.LayoutText(SS.LayoutSnapshot()))
check("stat preferences survive profile export",exported and exported.statDisplayMode=="split")
d.tallyVertical=false; d.tallyContext=true; d.sizes.SlimSuiteTallyFrame={w=40,h=20}
SS.DrawTally(SS.TallyParts({kills=123456,gold=999999,chest=1234}))
local tally=SlimSuiteTallyFrame; local fitted=tally:GetWidth()
SS.PlaceAll()
check("subsequent placement cannot undo tally fit",tally:GetWidth()==fitted and d.sizes.SlimSuiteTallyFrame.w==fitted)
d.zoneLine=true; d.clockContextAbove=true; SS.ApplyClockLayout()
check("clock location has an inside top anchor",SS.clockFrame.zone.points[1][1]=="TOP" and SS.clockFrame.zone.points[1][2]==SS.clockFrame)
d.clockContextAbove=false; SS.ApplyClockLayout()
check("clock location can move below but remains inside",SS.clockFrame.zone.points[1][1]=="BOTTOM" and SS.clockFrame.zone.points[1][2]==SS.clockFrame)
-- Exercise every animation stage at small/large box sizes and inherited scales.
setup.SetMode("SlimSuiteCombatTextFrame","enabled","Combat text"); SS.SetupEnd(true)
local box=SlimSuiteCombatTextFrame
for _,width in ipairs({40,120,260}) do for _,height in ipairs({20,60,220}) do for _,age in ipairs({.1,1,2,4}) do
 box:SetWidth(width); box:SetHeight(height); box:SetScale(1.5)
 d.sizes.SlimSuiteCombatTextFrame={w=width,h=height}
 box.entries={{born=GetTime()-age,tier=0,emphasized=true,amount=123,name=string.rep("W",100),crit=true,icon="test"}}
 Tick(1,.05)
 local w,h=box:GetWidth(),box:GetHeight()
 for _,line in ipairs(box.lines) do if line:IsShown() and line:GetAlpha()>0 then
  local point=line.points[1]
  check("ordinary row stays inside box",point[4]>=0 and point[4]+line:GetWidth()<=w+.01 and -point[5]+line:GetHeight()<=h+.01)
 end end
end end end
print("containment problems: "..bad)
for _,e in ipairs(ERRORS) do print(e) end
assert(bad==0 and #ERRORS==0,"containment regressions")
