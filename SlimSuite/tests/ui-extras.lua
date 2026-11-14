local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SS.StartSetup(true)
local d=SS.DB(); local setup=SS.ENV.SU
setup.SetMode("SlimSuiteStatCounterFrame","enabled","Stats")
AZS_STATS={hp=100,dmg=1.5,crit=10}; AZS_RUN={hp=90,hpm=120,sh=25}; AZS_SPELLS={{key="racial_test",cd=3}}; AZS_BUFFS={{spell=123,left=8}}
local lines=SS.StatLines()
check("HP includes authoritative temporary max and shield",string.find(lines[1],"90 / 120",1,true) and string.find(lines[1],"25",1,true))
check("racial is reported",string.find(table.concat(lines,"|"),"racial_test",1,true))
AZS_STATS.dmg=2; AZS_RUN.hpm=150; SS.UpdateStats()
check("stats update from live totals without stacking gear twice",string.find(SS.StatLines()[3],"2",1,true))
check("stat counter is a real movable element",SS.ENV.handles.SlimSuiteStatCounterFrame~=nil)
check("no stored-level setting is created",not getglobal("SlimSuiteStoreLevelsToggle"))
d.xpHideBorder=true; SS.StyleExpBar(false)
check("XP copies hide when border is disabled",not SS.XpArtShown())
check("native XP artwork also hides",MainMenuXPBarTexture0:GetAlpha()==0)
d.xpHideBorder=false; SS.StyleExpBar(false)
d.buildRowsAttached=false; d.matchBuildSizes=true; d.sizes.SlimSuiteSpellRowFrame={w=260,h=40}
SS.MatchBuildRowSizes("SlimSuiteSpellRowFrame")
check("split rows can match icon dimensions",d.sizes.SlimSuiteItemRowFrame.h==40 and d.sizes.SlimSuiteItemRowFrame.w==216)
d.matchBuildSizes=false; d.hideBuildSpells=true; d.hideBuildItems=false
setup.SetMode("SlimSuiteSpellRowFrame","enabled","Build")
SS.ApplyBuildRowReplacement(); SS.RefreshSpellRow(); SS.RefreshItemRow()
check("split spells can be hidden independently",not SlimSuiteSpellRowFrame:IsShown() and SlimSuiteItemRowFrame:IsShown())
d.hideBuildSpells=false; d.hideBuildItems=true; SS.ApplyBuildRowReplacement(); SS.RefreshItemRow()
check("split items can be hidden independently",SlimSuiteSpellRowFrame:IsShown() and not SlimSuiteItemRowFrame:IsShown())
local handle=SS.Handle("MinimapCluster","Minimap"); local grip=handle.resizeGrip
check("native-art elements have a resize grip",grip~=nil)
local cursor=GetCursorPosition; GetCursorPosition=function() return 100,100 end
RunScript(grip,"OnMouseDown","LeftButton")
GetCursorPosition=function() return 200,50 end
RunScript(grip,"OnUpdate",.05); RunScript(grip,"OnMouseUp","LeftButton")
GetCursorPosition=cursor
check("held corner drag persists increased scale",(d.scales.MinimapCluster or 1)>1 and not grip.resizing)
print("UI extras problems: "..bad)
for _,e in ipairs(ERRORS) do print(e) end
assert(bad==0 and #ERRORS==0,"UI extras regressions")
