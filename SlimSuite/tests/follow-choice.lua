local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SS.SetupEnd(true)
local d,su=SS.DB(),SS.ENV.SU
local bx,by=10,-5; local facing=0; local queries=0
AZS_GetPhase=function() return "playing" end
local position={x=0,y=0,facing=0,spaceId="s",mapId=1,runId="r"}
AZS_GetPlayerPosition=function() position.facing=facing; return position end
AZS_UNITS={{id=1,kind="boss",hp=100,hpm=100},{id=2,kind="guardian",hp=100,hpm=100,state=1}}
AZS_GetBosses=function() return {{id=1,name="Follower"}} end
AZS_GetGuardians=function() return {{id=2,name="Awake guardian",awake=true}} end
local function Anchors(query)
 if query.states then queries=queries+1 end
 return {catalogId=123,entries={
 {anchorId="boss",unitId=1,kind="boss",state="alive",name="Follower",positionAvailable=true,x=bx,y=by,spaceId="s",mapId=1,runId="r"},
 {anchorId="guardian",unitId=2,kind="guardian",state="alive",name="Awake guardian",positionAvailable=true,x=30,y=-30,spaceId="s",mapId=1,runId="r"}}}
end
AZS_GetWorldAnchors=Anchors
AdvanceTime(.016)
local flags={minimapBosses=true}
local first=SlimSuiteWorld.PointsOfInterest(position,flags); local count=queries
local again=SlimSuiteWorld.PointsOfInterest(position,flags)
check("two consumers share a single per-frame encounter query",queries==count and #first==2)
AZS_LAIRS={{index=1,id=2,name="Awake guardian",state="awake",x=30,y=-30,spaceId="s",mapId=1,runId="r"}}
local combined=SlimSuiteWorld.PointsOfInterest(position,{minimapBosses=true,minimapLairs=true})
local guardianCount=0; for _,point in ipairs(combined) do if point.unitId==2 then guardianCount=guardianCount+1 end end
check("moving guardian and its lair share one waypoint",guardianCount==1)
AZS_LAIRS=nil

by=5; AdvanceTime(.016)
local moved=SlimSuiteWorld.PointsOfInterest(position,flags); local boss
for _,point in ipairs(moved) do if point.unitId==1 then boss=point end end
check("unchanged catalog ID does not freeze a moving boss",boss and boss.y==5 and queries>count)
su.SetMode("SlimSuiteCompassFrame","enabled","Compass"); d.compassBosses=true; d.compassLairs=false; d.compassCaches=false
SS.UpdateCompass()
local function CompassX()
 for _,marker in ipairs(SlimSuiteCompassFrame.markers) do if marker:IsShown() and marker.title=="Follower" then return marker.points[1][4] end end
end
local oldX=CompassX(); by=-5; AdvanceTime(.016); SS.UpdateCompass(); local newX=CompassX()
check("stationary player sees a moving boss cross the compass",oldX and newX and oldX<0 and newX>0)
facing=.2; AdvanceTime(.016); SS.UpdateCompass()
check("player turning updates bearing in the same frame",CompassX()~=newX)
d.minimapBosses=true; d.minimapCaches=false; d.minimapLairs=false; d.showGuardianFlag=false; Minimap:Show()
Tick(1,.016)
local function PinX()
 for _,pin in ipairs({Minimap:GetChildren()}) do if pin:IsShown() and pin.tip=="Follower" then return pin.points[1][4] end end
end
local oldPin=PinX(); by=5; Tick(1,.016); local newPin=PinX()
check("boss location also moves immediately on the minimap",oldPin and newPin and oldPin>0 and newPin<0)
AZS_GetWorldAnchors=function() return nil,{code="NOT_READY"} end; AdvanceTime(.016)
check("unavailable coordinates never retain a stale chasing marker",#SlimSuiteWorld.PointsOfInterest(position,flags)==0)
AZS_GetWorldAnchors=Anchors
-- Disabled, muted, vertical, independently sized items are shown temporarily without editing the profile.
su.SetMode("SlimSuiteSpellRowFrame","default","Build")
d.buildRowsAttached=false; d.hideBuildItems=true; d.hideBuildSpells=true; d.matchBuildSizes=false
local item=SlimSuiteItemRowFrame
d.muted.SlimSuiteItemRowFrame=true; d.orientations.SlimSuiteItemRowFrame="vertical"
d.sizes.SlimSuiteItemRowFrame={w=24,h=160}; d.scales.SlimSuiteItemRowFrame=.6
d.places.SlimSuiteItemRowFrame={x=200,y=180,coordinateSpace="uiParent"}
SS.ENV.PlaceAll(); SS.RefreshItemRow(); SS.ApplyBuildRowReplacement(); SS.ENV.ApplyFeatureMute("SlimSuiteItemRowFrame")
local normalScale,normalWidth=item:GetScale(),d.sizes.SlimSuiteItemRowFrame.w
local snapshot=SS.LayoutText(SS.LayoutSnapshot())
AZS_GetPhase=function() return "choosing" end; d.cardEdgeHUD=true; d.unlocked=false
SS.UpdateChoiceHUD()
local x,y,icon,gap=SS.ChoiceFooterLayout()
check("hidden items are enabled only for the selection page",item:IsShown() and item:GetAlpha()==1)
check("selection items match native spell icon size",item:GetHeight()==icon and item:GetWidth()==5*icon+4*gap and item:GetScale()==1)
check("selection row sits under the native spell footer",item.points[1][1]=="BOTTOMLEFT" and item.points[1][4]==x and item.points[1][5]==y)
check("custom spells do not duplicate the native spell strip",not SlimSuiteSpellRowFrame:IsShown())
check("temporary selection layout does not modify saved preferences",SS.LayoutText(SS.LayoutSnapshot())==snapshot)
SS.RefreshItemRow(); SS.ApplyBuildRowReplacement(); SS.ENV.ApplyFeatureMute("SlimSuiteItemRowFrame")
check("normal renderer cannot hide the temporary items",item:IsShown() and item:GetAlpha()==1 and item:GetHeight()==icon)
AZS_GetPhase=function() return "playing" end; SS.UpdateChoiceHUD()
check("leaving selection restores disabled and hidden state",not item:IsShown() and item:GetAlpha()==0 and d.hideBuildItems and not d.buildRowsAttached)
check("normal scale, orientation and size survive",item:GetScale()==normalScale and d.orientations.SlimSuiteItemRowFrame=="vertical" and d.sizes.SlimSuiteItemRowFrame.w==normalWidth)
check("normal profile remains byte-for-byte unchanged",SS.LayoutText(SS.LayoutSnapshot())==snapshot)
for _,joined in ipairs({true,false}) do for _,hidden in ipairs({true,false}) do for _,mode in ipairs({"enabled","default","disabled"}) do
 su.SetMode("SlimSuiteSpellRowFrame",mode,"Build")
 d.buildRowsAttached=joined; d.hideBuildItems=hidden; d.muted.SlimSuiteItemRowFrame=nil
 SS.ENV.PlaceAll(); SS.RefreshItemRow(); SS.ApplyBuildRowReplacement()
 local normal=SS.LayoutText(SS.LayoutSnapshot())
 AZS_GetPhase=function() return "choosing" end; SS.UpdateChoiceHUD()
 check("all normal build modes get selection-only items",item:IsShown() and item:GetHeight()==icon)
 AZS_GetPhase=function() return "playing" end; SS.UpdateChoiceHUD()
 check("joined/split and hidden preferences restore",d.buildRowsAttached==joined and d.hideBuildItems==hidden and SS.LayoutText(SS.LayoutSnapshot())==normal)
 check("normal item visibility restores",item:IsShown()==(mode=="enabled" and not hidden))
end end end
print("follow/choice problems: "..bad)
for _,e in ipairs(ERRORS) do print(e) end
assert(bad==0 and #ERRORS==0,"follow/choice regressions")
