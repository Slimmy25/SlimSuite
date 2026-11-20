local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SS.SetupEnd(true)
if not SS.ENV.win then SS.WinBuild() end
SS.ENV.win:Show(); SS.OpenModulePage(nil)
check("category hub exists with the Elements page first",SlimSuiteModuleHub:IsShown() and #SS.MODULE_ORDER==7 and SS.MODULE_ORDER[1]=="elements")
check("diagnostic entry point removed",SS.ShowDiagnosticsWindow==nil and SlimSuiteDiagnosticsFrame==nil)
for _,id in ipairs(SS.MODULE_ORDER) do
 SS.SetModuleEnabled(id,true); SS.OpenModulePage(id)
 check("category settings page opens "..id,getglobal("SlimSuiteModule_"..id) and getglobal("SlimSuiteModule_"..id):IsShown() and SlimSuiteModuleHub:IsShown())
 local exists=false; for _,page in ipairs(SS.pages) do if page.module==id then exists=true end end
 check("category owns its settings "..id,exists)
end
local d=SS.DB(); d.hideLevel=true
local msg="You have gained +3% damage, +12 maximum health and +0.08 health per second."
check("chat module enabled filters configured spam",SS.Hidden(msg))
SS.SetModuleEnabled("chat",false)
check("chat Off releases chat without erasing preference",not SS.Hidden(msg) and d.hideLevel)
SS.SetModuleEnabled("chat",true); check("chat preference restored",SS.Hidden(msg))
SS.SetSoundSelection("boss","bossWhip"); local played=0
PlaySoundFile=function() played=played+1 end
SS.SetModuleEnabled("sounds",false); SS.PlayBossKillSound()
check("sound master Off silences selected effects",played==0 and SS.SoundSelection("boss")=="bossWhip")
SS.SetModuleEnabled("sounds",true); SS.PlayBossKillSound(); check("sound master restores chosen effect",played==1)
d.bossMarks=true; d.camera=true; d.modernEnemyFrames=true
SS.SetModuleEnabled("gameplay",false)
check("gameplay master stops visual extras",not d.bossMarks and not d.camera)
SS.SetModuleEnabled("gameplay",true)
check("gameplay settings resume",d.bossMarks and d.camera and d.modernEnemyFrames)
d.accessibilityContrast=true
SS.SetModuleEnabled("misc",false); check("Misc Off pauses accessibility",not d.accessibilityContrast)
SS.SetModuleEnabled("misc",true); check("Misc On restores accessibility",d.accessibilityContrast)
SS.StartSetup(true); SS.StartDemoMode(); SS.SetupEnd(true)
check("ending setup during Demo leaves no toolbar or samples",not SS.demoRunning and not SlimSuiteSetupBar:IsShown())
d.places.SlimSuiteMeterFrame={x=123,y=234,coordinateSpace="uiParent"}; d.muted.SlimSuiteMeterFrame=true
SS.ENV.PlaceAll(); local beforeTable=SS.LayoutSnapshot(); local before=SS.LayoutText(beforeTable)
SS.SetModuleEnabled("ui",false); Tick(3)
local allDefault=true
for _,id in ipairs(SS.SETUP_ORDER) do if d.elementModes[id]~="default" then allDefault=false end end
check("UI Off selects native HUD",allDefault and not d.replaceClock and not d.moveMeter)
for i=1,4 do check("UI Off hides nonexistent party member "..i,not getglobal("PartyMemberFrame"..i):IsShown()) end
check("paused UI exports retain the saved custom layout",SS.LayoutText(SS.LayoutSnapshot())==before)
SS.LayoutApply(beforeTable,false)
check("profile load cannot silently activate a paused UI module",not SS.ModuleEnabled("ui") and d.elementModes.SlimSuiteMeterFrame=="default")
SS.SetModuleEnabled("ui",true); Tick(3)
local afterTable=SS.LayoutSnapshot()
check("UI On restores exact saved layout",SS.LayoutText(afterTable)==before)
check("restored element mute preference is retained",d.muted.SlimSuiteMeterFrame==true)
local accessInMisc=false
for _,page in ipairs(SS.pages) do for _,row in ipairs(page.rows) do
 if row.cb and row.cb.label:GetText()==SS.T("High-contrast encounter bars") then accessInMisc=page.module=="misc" end
end end
check("accessibility belongs to Misc",accessInMisc)
print("module problems: "..bad)
for _,e in ipairs(ERRORS) do print(e) end
assert(bad==0 and #ERRORS==0,"module regressions")
-- Elements page: one row per setup element with On / Off / Original, wired to the same mode the setup uses.
SS.OpenModulePage("elements")
local elementRows, bad2 = 0, 0
local function upvalue(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i) if not n then return SS.ENV and SS.ENV[want] end if n == want then return v end i = i + 1 end end
SU = upvalue(SS.SetupHide, "SU")
for _, page in ipairs(SS.pages or {}) do
  if page.module == "elements" then
    for _, r in ipairs(page.rows) do
      if r.kind == "elementmode" then
        elementRows = elementRows + 1
        RunScript(r.buttons[1].b, "OnClick")
        if SU.Mode(r.name) ~= "enabled" then bad2 = bad2 + 1; print("On did not set", r.name) end
        RunScript(r.buttons[3].b, "OnClick")
        if SU.Mode(r.name) ~= "default" then bad2 = bad2 + 1; print("Original did not set", r.name) end
      end
    end
  end
end
check("elements page has a row per setup element", elementRows == table.getn(SS.SETUP_ORDER))
check("On and Original set each element's mode", bad2 == 0)
print("elements page problems: " .. bad2)
