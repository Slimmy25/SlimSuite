-- Shared element ownership metadata.
SS = SS or {};
function SS.FeatureEnabled(name)
	local d = SS.DB(); local mode = d.elementModes and d.elementModes[name];
	if ( mode == "enabled" or mode == "disabled" or mode == "default" ) then return mode == "enabled"; end
	local element = SS.ELEMENTS[name];
	return element and element.feature and d[element.feature] and true or false;
end
SS.ELEMENTS = {
	PlayerFrame = { native = true },
	TargetFrame = { native = true },
	PartyMemberFrame1 = { native = true },
	MinimapCluster = { native = true },
	BuffFrame = { native = true },
	MainMenuBar = { native = true },
	MainMenuExpBar = { native = true },
	ChatFrame1 = { native = true },
	SlimSuiteSpellRowFrame = { part = "build", originalKey = "buildNativeOriginal" },
	SlimSuiteTallyFrame = { part = "tally", originalKey = "tallyNativeOriginal" },
	SlimSuiteMeterFrame = { part = "meter", originalKey = "meterNativeOriginal" },
	SlimSuiteClockFrame = { part = "clock", originalKey = "clockNativeOriginal" },
	SlimSuiteBossFrames = { part = "bosses", originalKey = "bossNativeOriginal" },
	SlimSuiteAnnouncementFrame = { part = "banners", originalKey = "bannerNativeOriginal" },
	SlimSuiteStoredLevelsButton = { part = "levels", originalKey = "levelNativeOriginal" },
	SlimSuiteReviveFrame = { part = "revive", originalKey = "reviveNativeOriginal" },
	SlimSuiteLocalClockFrame = { part = "localClock", originalKey = "localClockNativeOriginal" },
	GameTooltip = {},
	SlimSuiteCombatTextFrame = {},
	SlimSuiteItemRowFrame = {},
	SlimSuiteMinimapBar = {},
	SlimSuitePartyLines = {},
	SlimSuitePlayerCard = {},
	SlimSuiteStatCounterFrame = {},
	SlimSuiteTargetCard = {},
};
SS.NATIVE_KEYS, SS.NATIVE_ELEMENTS, SS.NATIVE_FRAMES, SS.NATIVE_PARTS = {}, {}, {}, {};
for name, element in pairs(SS.ELEMENTS) do
	if ( element.native ) then SS.NATIVE_FRAMES[name] = true; end
	if ( element.part ) then
		SS.NATIVE_KEYS[element.part] = element.originalKey;
		SS.NATIVE_ELEMENTS[element.part] = name;
		SS.NATIVE_PARTS[name] = element.part;
	end
end

-- Ordered presentation, ownership, features and anchors live with the element definitions.
SS.MOVABLE = { { "PlayerFrame", "Player" }, { "TargetFrame", "Target" }, { "PartyMemberFrame1", "Party" }, { "SlimSuitePartyLines", "Party" },
	{ "MinimapCluster", "Minimap" }, { "BuffFrame", "Buffs" },
	{ "MainMenuBar", "Action bars" }, { "MainMenuExpBar", "XP bar" }, { "ChatFrame1", "Chat" },
	{ "SlimSuiteMeterFrame", "Damage meter" },
	{ "SlimSuiteStoredLevelsButton", "Level Up" },
	{ "SlimSuiteClockFrame", "Run clock / Next boss" },
	{ "SlimSuiteBossFrames", "Encounter bars" },
	{ "SlimSuiteAnnouncementFrame", "Event announcements" },
	{ "SlimSuiteSpellRowFrame", "Build spell row" },
	{ "SlimSuiteItemRowFrame", "Worn rings / trinkets" },
	{ "SlimSuiteTallyFrame", "Kills / Gold / Cache" }, { "GameTooltip", "Tooltip" },
	{ "SlimSuiteReviveFrame", "Revive bar" },
	{ "SlimSuiteLocalClockFrame", "Local clock" },
	{ "SlimSuitePlayerCard", "Player (new style)" }, { "SlimSuiteTargetCard", "Target (new style)" },
	{ "SlimSuiteMinimapBar", "Minimap buttons" }, { "SlimSuiteCombatTextFrame", "Combat text" } };
SS.ELEMENTS["PlayerFrame"].label = "Player";
SS.ELEMENTS["TargetFrame"].label = "Target";
SS.ELEMENTS["PartyMemberFrame1"].label = "Party";
SS.ELEMENTS["SlimSuitePartyLines"].label = "Party";
SS.ELEMENTS["MinimapCluster"].label = "Minimap";
SS.ELEMENTS["BuffFrame"].label = "Buffs";
SS.ELEMENTS["MainMenuBar"].label = "Action bars";
SS.ELEMENTS["MainMenuExpBar"].label = "XP bar";
SS.ELEMENTS["ChatFrame1"].label = "Chat";
SS.ELEMENTS["SlimSuiteMeterFrame"].label = "Damage meter";
SS.ELEMENTS["SlimSuiteStoredLevelsButton"].label = "Level Up";
SS.ELEMENTS["SlimSuiteClockFrame"].label = "Run clock / Next boss";
SS.ELEMENTS["SlimSuiteBossFrames"].label = "Encounter bars";
SS.ELEMENTS["SlimSuiteAnnouncementFrame"].label = "Event announcements";
SS.ELEMENTS["SlimSuiteSpellRowFrame"].label = "Build spell row";
SS.ELEMENTS["SlimSuiteItemRowFrame"].label = "Worn rings / trinkets";
SS.ELEMENTS["SlimSuiteTallyFrame"].label = "Kills / Gold / Cache";
SS.ELEMENTS["GameTooltip"].label = "Tooltip";
SS.ELEMENTS["SlimSuiteReviveFrame"].label = "Revive bar";
SS.ELEMENTS["SlimSuiteLocalClockFrame"].label = "Local clock";
SS.ELEMENTS["SlimSuitePlayerCard"].label = "Player (new style)";
SS.ELEMENTS["SlimSuiteTargetCard"].label = "Target (new style)";
SS.ELEMENTS["SlimSuiteMinimapBar"].label = "Minimap buttons";
SS.ELEMENTS["SlimSuiteCombatTextFrame"].label = "Combat text";
SS.SETUP_ORDER = { "PlayerFrame", "PartyMemberFrame1", "MainMenuBar", "TargetFrame", "MainMenuExpBar", "BuffFrame", "MinimapCluster", "ChatFrame1", "GameTooltip", "SlimSuiteStoredLevelsButton", "SlimSuiteSpellRowFrame", "SlimSuiteMeterFrame", "SlimSuiteClockFrame", "SlimSuiteBossFrames", "SlimSuiteTallyFrame", "SlimSuiteAnnouncementFrame", "SlimSuiteReviveFrame", "SlimSuiteLocalClockFrame", "SlimSuiteMinimapBar", "SlimSuiteCombatTextFrame", "SlimSuiteStatCounterFrame" };
SS.ELEMENTS["PlayerFrame"].title = "Unit frame"; SS.ELEMENTS["PlayerFrame"].text = "Your hero's frame: health, power and level. Drag the green handle to place it; its size and scale are below.";
SS.ELEMENTS["PartyMemberFrame1"].title = "Party frames"; SS.ELEMENTS["PartyMemberFrame1"].text = "Your friends' frames in co-op. They show now even if you're alone, so you can place them. Choose a column or a row, face plates or thin lines, and whether you join them.";
SS.ELEMENTS["MainMenuBar"].title = "Action bar"; SS.ELEMENTS["MainMenuBar"].text = "Your spells. Drag to place it; its size, and turning it upright, are below.";
SS.ELEMENTS["TargetFrame"].title = "Target frame"; SS.ELEMENTS["TargetFrame"].text = "The enemy the game has picked for you.";
SS.ELEMENTS["MainMenuExpBar"].title = "XP bar"; SS.ELEMENTS["MainMenuExpBar"].text = "Your experience bar. It can stand upright too (below).";
SS.ELEMENTS["BuffFrame"].title = "Buffs/Debuffs"; SS.ELEMENTS["BuffFrame"].text = "Your buffs and debuffs. Below, stack them in a column and choose which way they grow. Attached to the target frame, they move and scale with it instead.";
SS.ELEMENTS["MinimapCluster"].title = "Minimap"; SS.ELEMENTS["MinimapCluster"].text = "The minimap, with its pins.";
SS.ELEMENTS["ChatFrame1"].title = "Chat"; SS.ELEMENTS["ChatFrame1"].text = "The chat window, its tab and the box you type in move together.";
SS.ELEMENTS["GameTooltip"].title = "Tooltip"; SS.ELEMENTS["GameTooltip"].text = "Where tooltips appear, and how wide they are. Each one is as tall as its own text.";
SS.ELEMENTS["SlimSuiteStoredLevelsButton"].title = "Level Up"; SS.ELEMENTS["SlimSuiteStoredLevelsButton"].text = "The movable Level Up button and its store toggle.";
SS.ELEMENTS["SlimSuiteSpellRowFrame"].title = "Build rows"; SS.ELEMENTS["SlimSuiteSpellRowFrame"].text = "Your build spells, with your worn jewelry joined under them.";
SS.ELEMENTS["SlimSuiteMeterFrame"].title = "Damage meter"; SS.ELEMENTS["SlimSuiteMeterFrame"].text = "The meter. Its corner grip resizes it any time.";
SS.ELEMENTS["SlimSuiteClockFrame"].title = "Run clock"; SS.ELEMENTS["SlimSuiteClockFrame"].text = "Run time and the next boss.";
SS.ELEMENTS["SlimSuiteBossFrames"].title = "Encounter bars"; SS.ELEMENTS["SlimSuiteBossFrames"].text = "Boss, Guardian and elite health bars.";
SS.ELEMENTS["SlimSuiteTallyFrame"].title = "Kills / Gold / Cache"; SS.ELEMENTS["SlimSuiteTallyFrame"].text = "Your run's tally.";
SS.ELEMENTS["SlimSuiteAnnouncementFrame"].title = "Announcements"; SS.ELEMENTS["SlimSuiteAnnouncementFrame"].text = "Where event announcements appear.";
SS.ELEMENTS["SlimSuiteReviveFrame"].title = "Revive bar"; SS.ELEMENTS["SlimSuiteReviveFrame"].text = "The bar shown while you bring a friend back.";
SS.ELEMENTS["SlimSuiteLocalClockFrame"].title = "Local clock"; SS.ELEMENTS["SlimSuiteLocalClockFrame"].text = "Your real-world clock: 12/24-hour, its background and daylight saving are below.";
SS.ELEMENTS["SlimSuiteMinimapBar"].title = "Button row (optional)"; SS.ELEMENTS["SlimSuiteMinimapBar"].text = "Optional: takes every minimap button and the day/night moon off the map into one row you can drag anywhere. Off, the buttons stay on the map's ring.";
SS.ELEMENTS["SlimSuiteCombatTextFrame"].title = "Combat text"; SS.ELEMENTS["SlimSuiteCombatTextFrame"].text = "Your newest hits and heals, each with its spell icon. Crits stand out.";
SS.ELEMENTS["SlimSuiteStatCounterFrame"].title = "Stat counter [WIP]"; SS.ELEMENTS["SlimSuiteStatCounterFrame"].text = "A placeholder for a future run-stat counter. [WIP]";
SS.ELEMENTS["SlimSuiteStoredLevelsButton"].feature = "moveLevelButton";
SS.ELEMENTS["SlimSuiteSpellRowFrame"].feature = "replaceBuildRows";
SS.ELEMENTS["SlimSuiteClockFrame"].feature = "replaceClock";
SS.ELEMENTS["SlimSuiteBossFrames"].feature = "replaceEncounters";
SS.ELEMENTS["SlimSuiteTallyFrame"].feature = "replaceTally";
SS.ELEMENTS["SlimSuiteAnnouncementFrame"].feature = "replaceBanners";
SS.ELEMENTS["SlimSuiteReviveFrame"].feature = "replaceRevive";
SS.ELEMENTS["SlimSuiteCombatTextFrame"].feature = "combatTextBox";
SS.ELEMENTS["SlimSuiteLocalClockFrame"].feature = "replaceLocalClock";
SS.ELEMENTS["SlimSuiteMinimapBar"].feature = "minimapBar";
SS.ELEMENTS["SlimSuiteMeterFrame"].feature = "moveMeter";
SS.ELEMENTS["SlimSuitePlayerCard"].owner = "PlayerFrame";
SS.ELEMENTS["SlimSuiteTargetCard"].owner = "TargetFrame";
SS.ELEMENTS["SlimSuitePartyLines"].owner = "PartyMemberFrame1";
SS.ELEMENTS["SlimSuiteItemRowFrame"].owner = "SlimSuiteSpellRowFrame";
SS.ELEMENT_COMPANIONS = { ChatFrame1 = { "ChatFrame1Tab", "ChatFrame1EditBox" }, SlimSuiteSpellRowFrame = { "SlimSuiteItemRowFrame" }, PlayerFrame = { "SlimSuiteProcMeter" } };
SS.DISPLAY_ANCHORS = {
 PlayerFrame = { "TOPLEFT", .02, .98 }, TargetFrame = { "TOPLEFT", .165, .98 },
 PartyMemberFrame1 = { "TOPLEFT", .02, .87 },
 SlimSuitePlayerCard = { "TOPLEFT", .02, .98 }, SlimSuiteTargetCard = { "TOPLEFT", .165, .98 },
 SlimSuitePartyLines = { "TOPLEFT", .02, .87 },
 SlimSuiteBossFrames = { "TOP", .5, .92 }, SlimSuiteClockFrame = { "TOP", .5, .995 },
 BuffFrame = { "TOPRIGHT", .88, .985 }, MinimapCluster = { "TOPRIGHT", .995, .995 },
 SlimSuiteLocalClockFrame = { "TOPRIGHT", .965, .80 },
 SlimSuiteMeterFrame = { "BOTTOMLEFT", .70, 0 }, SlimSuiteStoredLevelsButton = { "CENTER", .5, .23 },
 SlimSuiteTallyFrame = { "BOTTOM", .5, .006 }, MainMenuBar = { "BOTTOM", .5, 0 },
 MainMenuExpBar = { "BOTTOM", .5, .049 }, SlimSuiteSpellRowFrame = { "TOPLEFT", .275, .38 },
 SlimSuiteItemRowFrame = { "TOPLEFT", .275, .34 }, ChatFrame1 = { "BOTTOMLEFT", .005, .17 },
 SlimSuiteAnnouncementFrame = { "CENTER", .5, .70 }, GameTooltip = { "BOTTOMRIGHT", .995, .005 }
};
for name, anchor in pairs(SS.DISPLAY_ANCHORS) do SS.ELEMENTS[name].anchor = anchor; end
