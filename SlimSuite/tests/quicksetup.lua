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
-- presets: the five built-in designs are offered; your own come first and a broken one is skipped
check("five built-in designs offered", table.getn(SS.UsablePresets()) == 5)
local saved = SS.LayoutText(SS.LayoutSnapshot())
SS.PRESETS = { { "Test design", "For the test.", saved }, { "Broken", "Bad text.", "nonsense" } }
local list = SS.UsablePresets()
check("your preset first, broken skipped, still five", table.getn(list) == 5 and list[1][1] == "Test design")
SS.OpenQuickSetup(); Tick(1)
check("the preset question comes first", win.question:GetText() == "Would you like to use a pre-set design?")
d.enemyBossesOnly = false
check("applying your preset puts its layout back", SS.ApplyPreset(list[1]) and SS.DB().enemyBossesOnly == true)
SS.PRESETS = {}
local sl, sr, sb, st = SS.ScreenBounds()
for _, p in ipairs(SS.BUILTIN_PRESETS) do
	local errs = SS.errorCount or 0
	check(p[1] .. " applies", SS.ApplyPreset(p)); Tick(3)
	for _, at in ipairs(p[3].places) do local name = at[1]
		local pl = SS.DB().places[name]
		check(p[1] .. ": " .. name .. " placed on screen", pl and pl.x >= sl and pl.y >= sb and pl.x < sr and pl.y < st)
	end
	for k, v in pairs(p[3].keys) do check(p[1] .. ": " .. k, SS.DB()[k] == v) end
end
check("controller design is large and high contrast", SS.DB().accessibilityLargeText == true and SS.DB().scales.SlimSuitePlayerCard == 1.2)
print("errors: " .. #ERRORS); for _, e in ipairs(ERRORS) do print("  " .. e) end
if #ERRORS > 0 then bad = bad + 1 end
print("quick setup problems: " .. bad)
if bad > 0 then error("quick setup regressions") end
