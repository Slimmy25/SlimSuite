local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SS.SetupEnd(true)
local d=SS.DB(); local su=SS.ENV.SU
SetCVar("CombatDamage","1")
su.SetMode("SlimSuiteCombatTextFrame","enabled","Combat text"); SS.SetWorldCombatMode("off")
check("log-only mode suppresses real native damage",GetCVar("CombatDamage")=="0")
SS.SetWorldCombatMode("native")
check("native damage can be explicitly retained",GetCVar("CombatDamage")=="1")
SS.SetWorldCombatMode("iconsCrits")
check("primitive mode replaces log by default",SS.WorldTextMode()=="iconsCrits" and not SS.CombatLogVisible() and GetCVar("CombatDamage")=="0")
d.keepCombatLog=true; check("log can accompany primitive text",SS.CombatLogVisible()); d.keepCombatLog=false
SS.SetWorldCombatMode("bosses"); check("boss-only mode is selectable",SS.WorldTextMode()=="bosses")
-- Render actual projected events rather than testing just the setting value.
SS.SetWorldCombatMode("iconsCrits")
AZS_UNITS={{id=1,kind="boss",hp=100,hpm=100},{id=2,kind="normal",hp=100,hpm=100}}
AZS_ProjectCombatTextAnchors=function(ids)
 local entries={}; for _,id in ipairs(ids) do table.insert(entries,{anchorId=id,state="onScreen",x=100,y=100,playerDistance=10}) end
 return {entries=entries}
end
local function Emit(id,target,crit)
 for _,listener in ipairs(SlimSuiteMeter.listeners) do listener({kind="damage",amount=99,anchorId=id,anchorStatus="ready",targetUnitId=target,critical=crit,presentedAt=GetTime()}) end
end
Emit(101,2,false); Emit(102,1,true); Tick(1,.01)
local icons,crits=0,0
for _,f in ipairs({SlimSuiteFloatingText:GetChildren()}) do if f:IsShown() then if f.text:GetText()=="" then icons=icons+1 elseif f.text:GetText()=="99!" then crits=crits+1 end end end
check("all-enemy primitive mode renders icons and crits only",icons==1 and crits==1)
SS.SetWorldCombatMode("bosses"); Emit(103,2,false); Tick(1,.01)
local shown=0
for _,f in ipairs({SlimSuiteFloatingText:GetChildren()}) do if f:IsShown() then shown=shown+1 end end
check("switching to boss-only immediately removes ordinary-enemy hits",shown==1)
su.SetMode("SlimSuiteCombatTextFrame","default","Combat text"); SS.SyncNativeDamageNumbers()
check("leaving replacement restores original CVar",GetCVar("CombatDamage")=="1")
local link; local oldLink,oldLines=GameTooltip.SetHyperlink,GameTooltip.NumLines
GameTooltip.SetHyperlink=function(self,value) link=value end; GameTooltip.NumLines=function() return 3 end
check("build uses full native tooltip by exact spell ID",SS.ShowBuildSpellTooltip({spell={spell=123}}) and link=="spell:123")
GameTooltip.SetHyperlink,GameTooltip.NumLines=oldLink,oldLines
AZS_GetPhase=function() return "ready" end
AZS_SPELLS={{key="starter",spell=123,cd=0,cdmax=12},{key="racial",spell=456,cd=0,cdmax=90}}
d.showRacialAbility=true; SS.UpdateBuildCooldowns()
check("pregame spell shows actual interval without fake progress",SlimSuiteSpellButton1.slimBuildCooldown:GetText()=="12")
check("pregame racial uses the final racial entry",ActionButton12.slimBuildCooldown:GetText()=="90")
local api=SlimSuiteWorld.API
AZS_GetPlayerPosition=function() return {x=0,y=0,facing=0,spaceId="here"} end
AZS_CHESTS={{id=1,x=10,y=0,spaceId="here"},{id=2,x=10000,y=0,spaceId="here"}}
AZS_GetBosses=function() return {{id=-2,name="Marked Boss",hp=100,hpm=100}} end
AZS_GetWorldAnchors=function() return {entries={{anchorId=1,unitId=-2,kind="boss",state="alive",positionAvailable=true,x=15,y=0,spaceId="here"}}} end
AdvanceTime(1)
local pois=SlimSuiteWorld.PointsOfInterest("here",{minimapCaches=true,minimapBosses=true})
local boss; for _,p in ipairs(pois) do if p.category=="boss" then boss=p end end
check("known pregame positions show as unavailable",boss and boss.grey and boss.sub=="Not yet available")
check("boss pin carries its raid icon and name",boss and boss.raid==7 and boss.label=="Marked Boss")
d.minimapCaches=true; d.minimapBosses=false; d.minimapLairs=false; Minimap:Show()
Tick(2,.1)
local function VisibleCachePins()
 local count=0
 for _,pin in ipairs({Minimap:GetChildren()}) do if pin.tip=="Cache" and pin:IsShown() then count=count+1; check("visible pins never represent distant rim-clamped caches",pin.dist<300) end end
 return count
end
check("only the genuine nearby cache is shown",VisibleCachePins()==1)
AZS_GetPlayerPosition=function() return {x=20000,y=0,facing=0,spaceId="here"} end
Tick(2,.1); check("walking away hides caches instead of dragging them along",VisibleCachePins()==0)
AZS_GetPlayerPosition=function() return {x=0,y=0,facing=0,spaceId="here"} end
Tick(2,.1); check("walking back restores the same cache",VisibleCachePins()==1)
SS.SetMinimapSquare(false); local _,_,_,_,baseY=Minimap:GetPoint(1)
SS.SetMinimapSquare(true); local _,_,_,_,squareY=Minimap:GetPoint(1)
SS.ApplyMinimapShape(); local _,_,_,_,againY=Minimap:GetPoint(1)
check("square map moves down once without accumulating offsets",squareY==baseY-6 and againY==squareY)
SS.SetMinimapSquare(false); local _,_,_,_,roundY=Minimap:GetPoint(1)
check("circle retains its exact native vertical anchor",roundY==baseY)
check("compass is optional and disabled initially",su.Mode("SlimSuiteCompassFrame")~="enabled")
check("forward marker is centered",math.abs(SS.CompassOffset(10,0,0,380))<.001)
check("west marker follows its real bearing",SS.CompassOffset(0,10,0,380)<0)
check("behind-camera points are not clamped to the compass rim",SS.CompassOffset(-10,0,0,380)==nil)
su.SetMode("SlimSuiteCompassFrame","enabled","Compass")
d.compassBosses=false; d.compassLairs=false; d.compassCaches=true; SS.UpdateCompass()
check("compass renders from real location data",SlimSuiteCompassFrame:IsShown())
d.compassStyle="free"; SS.UpdateCompass(); check("free marker style is supported",SlimSuiteCompassFrame:IsShown())
local nativeFlag=false
AZS_IsHudShown=function() return nativeFlag end; AZS_SetHudShown=function(part,on) if part=="flag" then nativeFlag=on end end
d.showGuardianFlag=true; d.guardianFlagNativeOriginal=nil; SS.ApplyGuardianFlag()
check("native flag restore preserves an original false",d.guardianFlagNativeOriginal==false)
SS.RestoreGuardianFlag(); check("releasing a hidden native flag does not enable it",nativeFlag==false)
nativeFlag=true; SS.ApplyGuardianFlag(); check("custom POIs suppress the native rim flag",nativeFlag==false)
SS.RestoreGuardianFlag(); check("native flag restores its original shown state",nativeFlag==true)
local onTop={}; AZS_SetOnTopOfScreens=function(f,on) onTop[f]=on end; AZS_IsOnTopOfScreens=function(f) return onTop[f] or false end
su.SetMode("SlimSuiteStatCounterFrame","enabled","Stats"); su.SetMode("SlimSuiteSpellRowFrame","enabled","Build")
SS.UpdateStats(); SS.ApplyBuildRowReplacement()
local before=SlimSuiteStatCounterFrame:GetPoint(1)
AZS_GetPhase=function() return "choosing" end; d.cardEdgeHUD=true; d.unlocked=false; SS.UpdateChoiceHUD()
check("stats docks on the card screen border",SlimSuiteStatCounterFrame.points[1][1]=="TOPRIGHT" and onTop[SlimSuiteStatCounterFrame])
check("build tooltip is lifted above cards too",onTop[GameTooltip])
AZS_GetPhase=function() return "playing" end; SS.UpdateChoiceHUD()
check("leaving card choices restores the original anchor",SlimSuiteStatCounterFrame.points[1][1]==before and not onTop[SlimSuiteStatCounterFrame])
print("navigation problems: "..bad)
for _,e in ipairs(ERRORS) do print(e) end
assert(bad==0 and #ERRORS==0,"navigation regressions")
