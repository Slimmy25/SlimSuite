local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SS.StartSetup(true); local su,d=SS.ENV.SU,SS.DB()
local compass=SS.Handle("SlimSuiteCompassFrame","Compass")
SS.RefreshEditHandles()
check("compass has a setup handle even in older profiles",compass:IsShown())
for i,v in ipairs({8,16,32,64}) do RunScript(su.sizes[i],"OnClick"); check("grid button "..v,d.gridDivisions==v) end
su.SetMode("SlimSuiteMeterFrame","enabled","Damage meter")
SS.StartDemoMode()
check("demo starts",SS.demoRunning)
su.SetMode("SlimSuiteSpellRowFrame","enabled","Build")
SS.RefreshItemRow(); SS.RefreshSpellRow(); Tick(20,.05)
for _,entry in ipairs(SS.MOVABLE) do
 local h=SS.ENV.handles[entry[1]]
 check("no green demo handle after refresh "..entry[1],not h or not h:IsShown())
end
SS.StopDemoMode()
check("setup handles return after demo",compass:IsShown() and su.bar:IsShown())
su.SetMode("SlimSuiteCombatTextFrame","enabled","Combat text"); SS.SetupEnd(true)
local box=SlimSuiteCombatTextFrame; box:SetHeight(220); box:SetWidth(260); box.entries={}; box.nextCombatTier=0
local function Hit(i,crit) SlimSuiteWorld.DemoHit(i,crit and "Crit" or "Normal",nil,crit,false) end
Hit(1,false); Hit(2,true); Hit(3,false); Hit(4,true)
Tick(1,.05)
local function Find(text)
 for _,line in ipairs(box.lines) do if line:IsShown() and string.find(line.text:GetText() or "",text,1,true) then return line end end
end
local rows={}
for _,entry in ipairs(box.entries) do check("mixed streams reserve distinct rows",not rows[entry.tier]); rows[entry.tier]=true end
local crit,normal=Find("Crit"),Find("Normal")
local critY,critX,normalX=crit.points[1][5],crit.points[1][4],normal.points[1][4]
local alpha=crit:GetAlpha()
Tick(2,.2)
crit,normal=Find("Crit"),Find("Normal")
check("crits travel right and remain on their assigned row",crit.points[1][4]>critX and crit.points[1][5]==critY)
check("crits fade while moving",crit:GetAlpha()<alpha)
check("normal hits never drift right",normal.points[1][4]==normalX)
local before=box.nextCombatTier
Hit(5,false); Hit(6,false)
check("normal hits advance the same forward cursor",box.nextCombatTier==math.mod(before+2,math.floor((box:GetHeight()-12)/28)))
for i=7,30 do Hit(i,true) end
local tiers={}
for _,entry in ipairs(box.entries) do check("critical wrap retires the previous row",not tiers[entry.tier]); tiers[entry.tier]=true end
check("mixed pool remains inside available rows",#box.entries<=math.floor((box:GetHeight()-12)/28))
SlimSuiteWorld.DemoHit(77,"Visible ordinary",nil,false,false)
Tick(2,.05)
check("ordinary damage survives a highlight flood",Find("Visible ordinary")~=nil)
local featureCount=0
for _,entry in ipairs(box.entries) do if entry.featured then featureCount=featureCount+1 end end
check("highlights leave room for the normal log",featureCount<math.floor((box:GetHeight()-12)/28))
SS.ResetCombatLearning(); AZS_ZONE={run="weak-crit"}
for i=1,30 do SS.LearnCombatHighlight({amount=1000,sourceKey="strong",name="Strong"}) end
check("small rare crits are weak relative to player damage",not SS.LearnCombatHighlight({amount=100,crit=true,sourceKey="weak",name="Weak"}))
for _,listener in ipairs(SlimSuiteMeter.listeners) do listener({kind="damage",amount=100,critical=true,meterSourceKey="weak",meterSource="Weak crit"}) end
Tick(1,.05)
for _,line in ipairs(box.lines) do
 line.text.SetTextColor=function(self,r,g,b) self.testColor={r,g,b} end
 line.text.SetFont=function(self,font,size) self.testFontSize=size end
end
Tick(1,.05)
local weak=Find("Weak crit")
check("weak crit becomes an ordinary white line",weak and weak.text.testColor and weak.text.testColor[1]==1 and weak.text.testColor[2]==1 and weak.text.testColor[3]==1)
check("weak crit has normal size and no critical suffix",weak and weak.text.testFontSize==10 and not string.find(weak.text:GetText(),"!",1,true))
local weakX=weak and weak.points[1][4]; Tick(2,.1); weak=Find("Weak crit")
check("weak crit scrolls normally without drifting right",weak and weak.points[1][4]==weakX)
Tick(1,15)
check("expired text disappears before later hits",#box.entries==0)
-- Quiet periods and wrap-around must retain one forward-only next-row position.
box.entries={}; box.nextCombatTier=0
local capacity=math.floor((box:GetHeight()-12)/28)
for i=0,capacity*3+2 do
 SlimSuiteWorld.DemoHit(100+i,"Remembered",nil,math.mod(i,2)==1,false)
 check("line continues forward across idle gaps and wrap "..i,box.entries[1].tier==math.mod(i,capacity))
 local nextTier=box.nextCombatTier
 Tick(1,15)
 check("expiration preserves next insertion row "..i,#box.entries==0 and box.nextCombatTier==nextTier)
end
SlimSuiteWorld.DemoHit(101,"Fixed first",nil,false,false)
local fixed=box.entries[1]; local firstTier=fixed.tier
SlimSuiteWorld.DemoHit(102,"Fixed second",nil,false,false)
Tick(1,.05)
check("adding a later row never repacks an existing row",fixed.tier==firstTier)
local nextTier=box.nextCombatTier
box:SetHeight(100)
SlimSuiteWorld.DemoHit(103,"Resized continuation",nil,false,false)
check("resizing wraps retained cursor into new bounds",box.entries[1].tier==math.mod(nextTier,math.floor((box:GetHeight()-12)/28)))
print("rainfall/demo problems: "..bad)
assert(bad==0 and #ERRORS==0,"rainfall/demo regressions")
