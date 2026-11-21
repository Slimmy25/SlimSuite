-- quick setup: walking the questions and applying the answers changes the settings once
local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("  MISMATCH " .. label) end end
SS.OpenQuickSetup(); Tick(1)
local win = getglobal("SlimSuiteQuickSetup")
check("the quick setup window opens", win and win.shown ~= false)
SS.ApplyQuickAnswers({ 2, 3, 1, 3, 2, 2 }); Tick(3)
local d = SS.DB()
check("RPG look applied", SS.PanelStyleKey() == "meter")
check("all enemies get plates", d.modernEnemyFrames == true and d.enemyBossesOnly == false)
check("group extras on", d.partyDistance == true and d.partyDimFar == true)
check("a few sounds", d.deathSound == true and d.lowHealthSound == false)
check("large text", d.accessibilityLargeText == true and d.accessibilityContrast == false)
d.enemyBossesOnly = true; Tick(3)
check("a setting changed afterwards stays changed", d.enemyBossesOnly == true)
SS.ApplyQuickAnswers({ 1, 1, 2, 1, 1, 1 }); Tick(3)
check("answers can be applied again", SS.PanelStyleKey() == "original" and d.modernEnemyFrames == false and d.deathSound == false)
-- presets: none filled in means no preset page; a filled one is offered and applies its layout
check("no presets: nothing offered", table.getn(SS.UsablePresets()) == 0)
local saved = SS.LayoutText(SS.LayoutSnapshot())
SS.PRESETS = { { "Test design", "For the test.", saved }, { "Broken", "Bad text.", "nonsense" } }
check("a filled preset is offered, a broken one skipped", table.getn(SS.UsablePresets()) == 1)
SS.OpenQuickSetup(); Tick(1)
check("the preset question comes first", win.question:GetText() == "Would you like to use a pre-set design?")
d.enemyBossesOnly = false
check("applying a preset puts its layout back", SS.ApplyPreset(SS.UsablePresets()[1]) and SS.DB().enemyBossesOnly == true)
SS.PRESETS = {}
print("quick setup problems: " .. bad)
if bad > 0 then error("quick setup regressions") end
