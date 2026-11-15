local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SS.StartSetup(true)
local d=SS.DB(); local su=SS.ENV.SU
su.SetMode("MinimapCluster","enabled","Minimap")
su.SetMode("SlimSuiteLocalClockFrame","enabled","Local clock")
MinimapCluster.SetClipsChildren=function(self,v) self.clip=v end
Minimap.SetClipsChildren=function(self,v) self.clip=v end
local zoom=MinimapZoomIn or CreateFrame("Button","MinimapZoomIn",Minimap)
local tex=zoom:CreateTexture(nil,"ARTWORK"); tex:SetAlpha(0); tex.slimBoundsAlpha=.8
GameTimeFrame:Hide(); GameTimeFrame:SetAlpha(0)
MinimapToggleButton=MinimapToggleButton or CreateFrame("Button","MinimapToggleButton",MinimapCluster)
MinimapToggleButton:Hide(); MinimapToggleButton:SetAlpha(0)
SS.EnforceElementBounds(MinimapCluster)
check("native minimap and cluster are not clipped",Minimap.clip==false and MinimapCluster.clip==false)
SS.RestoreMinimapChrome()
check("previously suppressed zoom texture restores",tex:GetAlpha()==.8 and tex.slimBoundsAlpha==nil)
check("moon returns",GameTimeFrame:IsShown() and GameTimeFrame:GetAlpha()==1)
check("top-right control returns",MinimapToggleButton:IsShown() and MinimapToggleButton:GetAlpha()==1)
check("zoom draws above square border",zoom:GetFrameLevel()>Minimap:GetFrameLevel()+2)
d.clockDetached=false; d.scales.MinimapCluster=1.5; d.scales.SlimSuiteLocalClockFrame=.75
SS.SetMinimapSquare(true)
SS.ENV.PlaceAll(); SlimSuiteWorld.UpdateLocalClock()
local clock=SlimSuiteLocalClockFrame; local point=clock.points[1]
check("display templates cannot detach attached local clock",point[1]=="TOP" and point[2]==Minimap and point[3]=="BOTTOM")
local expected=-(5+2)*SS.EffectiveScale(Minimap)/SS.EffectiveScale(clock)
check("square clock gap follows effective scale",math.abs(point[5]-expected)<.001)
SS.ENV.PlaceAll(); check("repeated placement retains attachment",clock.points[1][2]==Minimap)
SS.SetClockDetached(true)
d.places.SlimSuiteLocalClockFrame={x=220,y=180,coordinateSpace="uiParent"}
SS.ENV.PlaceAll(); SlimSuiteWorld.UpdateLocalClock()
check("explicitly detached clocks stay independent",clock.points[1][2]~=Minimap)
SS.SetClockDetached(false); SS.SetMinimapSquare(false); SS.ENV.PlaceAll()
check("round clock also remains attached",clock.points[1][2]==Minimap and math.abs(clock.points[1][5]+2*SS.EffectiveScale(Minimap)/SS.EffectiveScale(clock))<.001)
print("minimap chrome problems: "..bad)
for _,e in ipairs(ERRORS) do print(e) end
assert(bad==0 and #ERRORS==0,"minimap chrome regressions")
