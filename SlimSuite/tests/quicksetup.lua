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
-- presets: none ship yet, so Quick setup starts with the questions; designs added later are offered (at most 5)
local shippedList = SS.UsablePresets()
check("two designs shipped: Console A then Console B", table.getn(shippedList) == 2 and shippedList[1][1] == "Console A" and shippedList[2][1] == "Console B" and shippedList[2].picture == "preset5")
check("Console B applies as exported, fitted to this screen", SS.ApplyPreset(shippedList[2]) and SS.DB().scales.MainMenuBar == 1.85 and SS.DB().orientations.SlimSuiteBossFrames == "vertical" and SS.DB().places.SlimSuiteTargetCard.x > 512); Tick(3)
check("Console B: minimap, run clock, luck, stats and build rows off; XP bar full width", SS.DB().elementModes.MinimapCluster == "disabled" and SS.DB().elementModes.SlimSuiteLuckFrame == "disabled" and SS.DB().elementModes.SlimSuiteClockFrame == "disabled" and SS.DB().elementModes.SlimSuiteStatCounterFrame == "disabled" and SS.DB().elementModes.SlimSuiteSpellRowFrame == "disabled" and SS.DB().xpFullWidth == true)
SS.OpenQuickSetup(); Tick(1)
check("the preset question comes first", win.question:GetText() == "Would you like to use a pre-set design?")
check("Console applies", SS.ApplyPreset(SS.UsablePresets()[1])); Tick(3)
local cd = SS.DB()
check("Console: big thin party lines", cd.partyLook == "thin" and cd.scales.SlimSuitePartyLines == 2.4)
check("Console: compass on, minimap off", SS.FeatureEnabled("SlimSuiteCompassFrame") and cd.elementModes.MinimapCluster == "disabled")
check("Console: up to five encounter bars pinned top-right", cd.encounterMax == 5 and cd.places.SlimSuiteBossFrames.point == "TOPRIGHT")
check("Console: player bottom-left, target bottom-right", cd.places.SlimSuitePlayerCard.point == "BOTTOMLEFT" and cd.places.SlimSuiteTargetCard.point == "BOTTOMRIGHT")
local shipped = SS.BUILTIN_PRESETS
local saved = SS.LayoutText(SS.LayoutSnapshot())
SS.PRESETS = { { "Test design", "For the test.", saved }, { "Broken", "Bad text.", "nonsense" } }
SS.BUILTIN_PRESETS = {}
for i = 1, 6 do table.insert(SS.BUILTIN_PRESETS, { "Spec " .. i, "A test spec.", { keys = { enemyBossesOnly = true },
	places = { { "SlimSuiteClockFrame", 0.5, 0.95 } } } }) end
local list = SS.UsablePresets()
check("exported design first, broken skipped, at most five", table.getn(list) == 5 and list[1][1] == "Test design")
SS.OpenQuickSetup(); Tick(1)
check("with designs the preset question comes first", win.question:GetText() == "Would you like to use a pre-set design?")
d.enemyBossesOnly = false
check("applying an exported design puts its layout back", SS.ApplyPreset(list[1]) and SS.DB().enemyBossesOnly == true)
d.enemyBossesOnly = false
check("applying a written-out design sets its options and places", SS.ApplyPreset(list[2]) and SS.DB().enemyBossesOnly == true and SS.DB().places.SlimSuiteClockFrame ~= nil)
SS.PRESETS = {}; SS.BUILTIN_PRESETS = shipped
-- the revive bar turns upright: its size swaps and it stays upright after the layout is drawn again
local rv = getglobal("SlimSuiteReviveFrame")
SS.DB().orientations.SlimSuiteReviveFrame = nil; SS.ApplyReviveOrientation()
local w0, h0 = rv:GetWidth(), rv:GetHeight()
SS.DB().orientations.SlimSuiteReviveFrame = "vertical"; SS.ApplyReviveOrientation(); if PlaceAll then PlaceAll() end; Tick(2)
check("revive bar turns upright", rv:GetHeight() > rv:GetWidth() and rv:GetWidth() == h0)
SS.DB().orientations.SlimSuiteReviveFrame = "horizontal"; SS.ApplyReviveOrientation(); Tick(2)
check("revive bar turns back", rv:GetWidth() == w0 and rv:GetHeight() == h0)
-- numbered slots: a design asking for slot 4 is fourth, loose ones fill the free places before it
SS.PRESETS = { { "Mine", "x", SS.LayoutText(SS.LayoutSnapshot()), slot = 5 } }
SS.BUILTIN_PRESETS = { { "Loose", "x", { places = {} } }, { "Four", "x", { places = {} }, slot = 4 } }
local l = SS.UsablePresets()
check("slots: loose first, then 4, then 5", table.getn(l) == 3 and l[1][1] == "Loose" and l[2][1] == "Four" and l[3][1] == "Mine" and l[2].picture == "preset4")
SS.PRESETS = {}; SS.BUILTIN_PRESETS = shipped
-- upright encounter cards with Most bars shown = 5: all five sample bosses fit where four default cards used to
SS.DB().orientations.SlimSuiteBossFrames = "vertical"; SS.DB().sizes.SlimSuiteBossFrames = nil; SS.DB().encounterMax = 5; SS.DB().replaceEncounters = true; SS.DB().elementModes.SlimSuiteBossFrames = "enabled"
SS.SetUnlocked(true, true); Tick(5)
local bf = getglobal("SlimSuiteBossFrames")
local pad = SS.FramePadding("SlimSuiteBossFrames")
local room = 4 * 48 + 3 * (10 + pad) + pad * 2
check("five upright cards fit in four cards' room (" .. tostring(bf:GetWidth()) .. " of " .. room .. ")", table.getn(SS.BOSS_SAMPLE) == 5 and bf:GetWidth() <= room + 1)
SS.DB().encounterMax = nil; SS.SetUnlocked(false, true); Tick(2)
-- sound previews play on the music channel, so pause stops them and a new preview replaces the old one
local played, stops = {}, 0
SetCVar("EnableMusic", "1"); SetCVar("MusicVolume", "0.5")
PlayMusic = function(path) table.insert(played, path) end
StopMusic = function() stops = stops + 1 end
local keys = {}; for k in pairs(SS.SOUND_FILES) do table.insert(keys, k) if table.getn(keys) == 2 then break end end
SS.PreviewSound(keys[1]); Tick(1)
check("a preview plays and can be stopped", table.getn(played) == 1 and SS.PreviewActive(keys[1]) and SS.CanStopPreview())
SS.PreviewSound(keys[2]); Tick(1)
check("a new preview stops the one before it", stops >= 1 and table.getn(played) == 2 and SS.PreviewActive(keys[2]) and not SS.PreviewActive(keys[1]))
SS.PreviewSound(keys[2]); Tick(1)
check("clicking the playing preview pauses it", not SS.PreviewActive())
PlayMusic, StopMusic = nil, nil
SetCVar("EnableMusic", "0")
check("with the game's music off, previews use the effects channel", not SS.PreviewOnMusic())
print("errors: " .. #ERRORS); for _, e in ipairs(ERRORS) do print("  " .. e) end
if #ERRORS > 0 then bad = bad + 1 end
print("quick setup problems: " .. bad)
if bad > 0 then error("quick setup regressions") end
