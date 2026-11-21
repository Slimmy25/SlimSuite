local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
local d=SS.DB(); local shown={}
AZS_SetHudShown=function(part,on) shown[part]=on end
AZS_IsHudShown=function(part) return shown[part]~=false end
SS.StartSetup(true)
for _,name in ipairs(SS.SETUP_ORDER) do SS.SU.SetMode(name,"enabled",name) end
d.floatingText=true; d.showAbsorbs=true; d.minimapSquare=true; d.minimapCaches=true
SS.GoBackToVanilla(); Tick(3)
check("editor and demo are off",not d.unlocked and not SS.demoRunning and not SS.setupActive)
check("vanilla selection persists without restarting onboarding",d.vanillaUI and d.setupDone and d.firstSetupDefaultsVersion==2)
for _,name in ipairs(SS.SETUP_ORDER) do check("native mode "..name,d.elementModes[name]=="default") end
for part in pairs(SS.NATIVE_KEYS) do check("native HUD shown "..part,shown[part]==true) end
check("stored level menu restored",shown.levels==true and not d.moveLevelButton and not SlimSuiteStoredLevelsButton:IsShown())
check("custom overlays off",not d.floatingText and not d.showAbsorbs and not d.minimapCaches and not d.modernEnemyFrames and not d.combatTextBox)
check("round native map restored",not d.minimapSquare and not d.minimapTransparent)
SS.ApplyElementModes(); Tick(3)
check("mode refresh cannot reactivate replacements",not d.replaceClock and not d.replaceTally and not d.moveMeter)
SS.StartSetup(true); Tick(2)
check("explicit editor reopen resumes custom HUD",not d.vanillaUI and d.elementModes.SlimSuiteStoredLevelsButton=="enabled" and d.elementModes.PlayerFrame=="enabled")
print("vanilla problems: "..bad)
for _,e in ipairs(ERRORS) do print(e) end
assert(bad==0 and #ERRORS==0,"vanilla regressions")
