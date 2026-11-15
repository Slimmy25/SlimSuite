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
local box=SlimSuiteCombatTextFrame; box:SetHeight(220); box:SetWidth(260); box.entries={}; box.nextTier=0
local function Hit(i) SlimSuiteWorld.DemoHit(i,"Hit",nil,i==2,false) end
for i=1,4 do Hit(i) end
Tick(1,.05)
local rows={}; local oldX
for _,line in ipairs(box.lines) do if line:IsShown() then
 local p=line.points[1]; check("distinct rainfall row",not rows[p[5]]); rows[p[5]]=true
 if not oldX then oldX=p[4] end
end end
check("big hits use the same tier allocator",#box.entries==4)
Tick(2,.2)
check("rainfall travels right",box.lines[1].points[1][4]>oldX)
for i=5,30 do Hit(i) end
local tiers={}
for _,entry in ipairs(box.entries) do check("tier reuse retires old text",not tiers[entry.tier]); tiers[entry.tier]=true end
check("tier pool remains bounded",#box.entries<=math.floor((box:GetHeight()-12)/28))
Tick(1,15)
check("expired text disappears before later hits",#box.entries==0)
print("rainfall/demo problems: "..bad)
assert(bad==0 and #ERRORS==0,"rainfall/demo regressions")
