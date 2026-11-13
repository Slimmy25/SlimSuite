-- Slim Suite: chat filters, HUD controls, and other optional player tools.
-- Reference layout map for native defaults and Slim Suite replacements:
--   1 Player frame; 2 target frame; 3 encounter/boss bars (up to four shown in the reference);
--   4 run timer with its next-boss countdown; 5 player buffs; 6 minimap; 7 local time;
--   8 damage meter; 9 stored level-up button; 10 kills/gold/cache tally;
--   11 action bar with its artwork; 12 XP bar; 13 build spells above worn items; 14 chat.
-- Additional native reference locations: event announcements ("Swarm surrounds you!") stay centered;
-- four party frames stack vertically below the player frame (the player is not part of that stack);
-- tooltips use the bottom-right corner. Replacement defaults should echo these locations only when
-- their matching replacement is enabled; otherwise the game's native UI remains in control.
--   * Optional chat filters independently hide level-up stat-bonus lines, newly learned spell lines, racial-buff
--     notices, selected opening/lair lines, and game-authored
--     NPC/boss dialogue and run-roleplay lines. /slimsuite hide <words> also hides matching non-player text. Player chat is never hidden.
--   * The camera goes as far out as the game allows, 50 yards (the Max Camera Distance setting at its top), and starts there. Turn it off in
--     /slimsuite to keep the game's own setting.
--   * Boss markers follow the live API spawn order: oldest active boss gets Skull, then Cross, Circle and Star.
--     Awake Guardians join after the real bosses; ordinary enemies are never marked by name guesses.
--   * In co-op, a friend who falls gets a marker over their head, blinking on and off 16 times. Each friend has their
--     own (Diamond, Triangle, Moon, Square), so several can be down at once. Those four are kept for this alone.
--   * Play the included sound once when you or a teammate dies (off until enabled).
--   * Move, resize and scale the UI: drag a green handle to move it; right-click it for that element's menu (its
--     settings, then its size and layout). The first time, a setup walks through the elements; after that "Toggle UI
--     Settings" opens Edit mode. The action bar, XP bar, buffs, party frames, build rows, encounter bars, run clock and
--     kills/gold/cache tally can switch between horizontal and vertical layouts.
--     Bar 2 and Right bar are intentionally not included; Action Bar 1 can optionally show empty slots.
--     Optional anchoring latches nearby movable frames together. Positions and custom sizes are saved continuously across /reload.
--     Native frames stay in their game layout until a UI replacement or edit is chosen. Layouts can be saved, loaded,
--     shared as text and kept per character (/slim layout).
--     The primary chat window, tab and input box move together from one Chat handle.
--   * The kills, gold and next-cache cost use the documented AZS_RUN values in a movable replacement for the tally.
--     Its menu switches between a compact horizontal row and a vertical layout.
--   * The run clock and next-boss countdown stay together in one movable replacement for the game's clock.
--   * Event announcements use the game's localized text, remain visible for 10 seconds, fade at both ends, and move
--     with their own handle. They are separate from the "Move to Begin" prompt.
--   * The stored-levels button is a movable replacement that opens the game's own choices through its documented API.
--   * Active boss, guardian and elite bars sit in the upper-left encounter area, separate from the centered run
--     clock. Horizontal cards grow from the left; its menu switches to narrow vertical bars. HP uses the
--     documented current/maximum values, refreshed on AZSUNITS updates.
--   * Hide the target frame: this game picks its own targets, so the frame can go.
--   * Plain action bar: the gryphons and the bar's art go, and only the six spell squares are left, with the bar
--     no wider than they are (and the two page arrows), so it leaves no empty space.
--   * Cooldown numbers: each spell square shows the seconds until its spell is ready again.
-- /slimsuite (or the gear by the minimap) opens the settings window: every one of these on or off. /slim help lists
-- the commands.
-- Lua 5.0 / 1.12 interface: scripts read `this`, `event`, `arg1`, `arg2`; no # operator; only the 1.12 API.
-- names shared by Slim Suite's own files and no one else (see SS.ENV in SlimSuiteCore.lua)
SS.PRIVATE = { ApplyActionSlotGrid = true, ApplyFeatureMute = true, ApplyMovableOrientation = true, BUFF_BUTTONS = true, BUILD = true, BuffButtons = true, BuildRaidPanel = true, CaptureActionBarLayout = true, DEATH_SOUND = true, DEMO_HITS = true, DEMO_METER = true, DemoBox = true, DemoRedraw = true, DemoTick = true, HookChat = true, ITEM_EQUIP_SLOTS = true, K = true, LEVEL_CLASS_ICON_COORDS = true, MAX_CAMERA = true, MOVABLE = true, NAME = true, PLAIN_HIDE = true, PlaceAll = true, RaidCursor = true, RaidTargets = true, RaidWithin = true, RootBounds = true, RootFactor = true, SU = true, SetAnchorSnap = true, SetRootPosition = true, ShowEditGrid = true, TALLY = true, TagLook = true, UnitKind = true, UpdateMeter = true, VisualInsets = true, actionBarOriginal = true, actionSlotsGridApplied = true, announcementDuration = true, announcementFade = true, announcementFrame = true, announcementStarted = true, bannerHandler = true, bannerHandlerRegistered = true, basePoints = true, baseSizes = true, bossFrame = true, buffButtonOriginalPoints = true, buffLayoutApplying = true, buffLayoutUpdater = true, buffSamples = true, cdText = true, clockFrame = true, deathSoundFrame = true, demoGlint = true, demoHidden = true, demoHitClock = true, demoHitIndex = true, demoPins = true, demoT = true, editGrid = true, editGridLines = true, editOnly = true, encounterRows = true, encounterUpdates = true, errMini = true, handleList = true, handles = true, itemRow = true, itemRowButtons = true, itemRowEvents = true, lastBannerId = true, levelButton = true, loader = true, lockPanel = true, meterFrame = true, mutedBaseAlphas = true, mutedBaseMouse = true, nativeHudShutdown = true, okMini = true, partyNativePoints = true, plainShow = true, raidOver = true, raidPanel = true, setupActive = true, sizeMenu = true, sizeMenuHeight = true, sizeMenuPadding = true, sizeMenuScale = true, sizeMenuScaleInput = true, sizeMenuText = true, sizeMenuWidth = true, sizeTarget = true, spellRow = true, spellRowButtons = true, spellRowEvents = true, tallyFrame = true, targetShow = true, tooltipOwnerOriginal = true, tooltipShowOriginal = true, win = true, xpBarDetached = true, xpStyle = true };
if ( setfenv ) then setfenv(1, SS.ENV); end   -- Slim Suite's files share one set of private names (SS.ENV, in SlimSuiteCore.lua)

K = AZSKIT;
NAME = "Slim Suite";

-- Inventory/world events can refresh rows before SlimSuiteSetup.lua is loaded.
-- Setup replaces this safe default with the live demo-state lookup later.
SS.Demoing = SS.Demoing or function() return false; end

-- the stat bonus a level-up gives, in each of the game's languages (a piece of the line that has no number in it), as
-- the game itself writes "You have gained {damage}% damage, {health} maximum health and {regen} health per second."
-- A setting that turns another off says so in the game's message line at the top of the screen (kept visible in the
-- setup too), so nothing changes without a word.
function SS.Notice(text)
	if ( UIErrorsFrame and UIErrorsFrame.AddMessage ) then UIErrorsFrame:AddMessage(text, 1, 0.6, 0.2, 1, 5); end
end
-- Shrinks a font string's font until its text fits the width (its normal size when it fits): used where the player can
-- make an element smaller than its text. The smallest size is minSize (7 by default).
function SS.FitText(fs, width, minSize)
	if ( not fs or not fs.GetFont or not fs.SetFont or not width ) then return; end
	if ( not fs.slimBase ) then
		local font, size, flags = fs:GetFont();
		if ( not font ) then return; end
		fs.slimBase = { font, size or 12, flags };
	end
	local b = fs.slimBase;
	local text = fs.GetText and fs:GetText() or "";
	if ( fs.slimFitText == text and fs.slimFitWidth == width and fs.slimFitMin == minSize ) then return; end   -- already fitted
	fs.slimFitText, fs.slimFitWidth, fs.slimFitMin = text, width, minSize;
	local size = b[2];
	fs:SetFont(b[1], size, b[3]);
	while ( size > (minSize or 7) and (fs:GetStringWidth() or 0) > width ) do
		size = size - 1;
		fs:SetFont(b[1], size, b[3]);
	end
end

-- a small warning box beside a control, for the right-click menu's own Mirror and Buffs boxes
function SS.ShowWarnTip(owner, text)
	local tip = getglobal("SlimSuiteWarnTip");
	if ( not tip ) then
		tip = CreateFrame("Frame", "SlimSuiteWarnTip", UIParent);
		tip:SetFrameStrata("TOOLTIP");
		tip:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
		tip:SetBackdropColor(0.1, 0.05, 0, 0.95); tip:SetBackdropBorderColor(1, 0.6, 0.2, 1);
		tip.text = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		tip.text:SetPoint("TOPLEFT", tip, "TOPLEFT", 8, -7); tip.text:SetWidth(200); tip.text:SetJustifyH("LEFT");
		tip.text:SetTextColor(1, 0.75, 0.4);
	end
	tip.text:SetText(text);
	tip:SetWidth(216); tip:SetHeight((tip.text:GetHeight() or 12) + 14);
	tip:ClearAllPoints(); tip:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", 4, 0);
	tip:Show();
end
function SS.HideWarnTip() local tip = getglobal("SlimSuiteWarnTip"); if ( tip ) then tip:Hide(); end end
-- the newest choice wins: a setting that moves a frame takes it back from the game's own layout ("Movable?" on)
function SS.MakeMovable(frame, why)
	local d = SS.DB();
	if ( not (d.frameDefault and d.frameDefault[frame]) ) then return; end
	d.frameDefault[frame] = nil;
	local names = { PlayerFrame = "The player frame", TargetFrame = "The target frame", PartyMemberFrame1 = "The party frames", BuffFrame = "Your buffs" };
	SS.Notice((names[frame] or frame) .. " can be moved again: " .. why .. ".");
end

-- SS.UnitKind(unit): what an enemy is, as one lowercase word ("final", "boss", "guardian", "elite", ...).
-- Pass a unit token ("target"), an id, or an entry from AZS_UNITS / AZS_GetBosses / AZS_GetGuardians. The game's
-- AZS_UnitKind answers for unit names (it takes only those, per the addon docs); an id or an entry is classed by its
-- own kind field, else by AZS_UNITS. Use this everywhere instead of reading .kind directly.
-- a kind as one lowercase word; the final boss is "final" however the game writes it ("finalBoss", "final_boss")
function SS.KindWord(kind)
	local k = string.lower(kind);
	if ( k == "finalboss" or k == "final_boss" or k == "final boss" ) then return "final"; end
	return k;
end
function SS.UnitKind(unit)
	-- a unit name ("target", "mouseover"): the game's AZS_UnitKind, which takes only those
	if ( type(unit) == "string" ) then
		if ( type(AZS_UnitKind) == "function" ) then
			local ok, kind = SS.Safe(AZS_UnitKind, unit);
			if ( ok and type(kind) == "string" and kind ~= "" ) then return SS.KindWord(kind); end
		end
		return nil;
	end
	-- an AZS_UNITS id, or an entry from AZS_UNITS / AZS_GetBosses / AZS_GetGuardians: its own kind, else AZS_UNITS'
	local id = unit;
	if ( type(unit) == "table" ) then
		if ( unit.final ) then return "final"; end
		if ( type(unit.kind) == "string" and unit.kind ~= "" ) then return SS.KindWord(unit.kind); end
		id = unit.id;
	end
	if ( id ~= nil and type(AZS_UNITS) == "table" ) then
		for i = 1, table.getn(AZS_UNITS) do
			local u = AZS_UNITS[i];
			if ( type(u) == "table" and u.id == id and type(u.kind) == "string" ) then return SS.KindWord(u.kind); end
		end
	end
	return nil;
end
UnitKind = SS.UnitKind;

-- the class colours, by class token ("MAGE") or English class name ("Mage")
SS.CLASS_COLORS = { WARRIOR = { 0.78, 0.61, 0.43 }, MAGE = { 0.41, 0.8, 0.94 }, ROGUE = { 1, 0.96, 0.41 }, DRUID = { 1, 0.49, 0.04 },
	HUNTER = { 0.67, 0.83, 0.45 }, SHAMAN = { 0, 0.44, 0.87 }, PRIEST = { 1, 1, 1 }, WARLOCK = { 0.58, 0.51, 0.79 }, PALADIN = { 0.96, 0.55, 0.73 } };
-- colours used again and again by the unit frames (made once, not on every redraw)
SS.RGB = { white = { 1, 1, 1 }, enemy = { 0.9, 0.25, 0.25 }, friend = { 0.6, 0.9, 0.3 }, mana = { 0.2, 0.4, 1 }, rage = { 0.9, 0.15, 0.15 },
	energy = { 1, 0.9, 0.2 }, classicMana = { 0, 0, 1 }, classicRage = { 1, 0, 0 }, classicEnergy = { 1, 1, 0 }, health = { 0.2, 0.75, 0.2 },
	dead = { 0.4, 0.4, 0.4 } };
function SS.ClassColor(class)
	return SS.CLASS_COLORS[string.upper(tostring(class or ""))];
end

-- The saved settings. Their defaults and one-time migrations are applied once per saved table (SS.PrepareDB): when the
-- addon loads, and again when the game swaps in the player's saved settings, which it does after these files have run.
-- After that SS.DB() only hands the table back: it is asked for hundreds of times a second.
SS.DEFAULTS = {
	hideLevel = true, hideRP = false, hideRacialInfo = false, hideOpeningLine = false, hideLairLine = false,
	replaceClock = false, replaceEncounters = false, replaceTally = false, replaceBanners = false,
	camera = true, plainBar = false, cooldowns = false, bossMarks = true, deathMarks = true, prePullMarks = false,
	encounterDebuffs = true, onTopOfScreens = false, replaceRevive = false, procMeter = false, combatTextBox = false,
	minimapCaches = false, minimapBosses = false, minimapLairs = false, minimapTransparent = false, zoneLine = true, replaceLocalClock = false,
	clockDetached = false, combineTarget = false, gatherButtons = false, gatherSide = "left", minimapBar = false,
	partyIncludesSelf = false, floatingText = false, deathSound = false, hideTarget = false, mirrorTarget = false,
	mirrorSameScale = true, buffsOnTarget = false, buffsOnPlayer = false, partyLocked = false, partyLockAbove = false,
	partyFaces = true, cardPortraits = true, targetDebuffs = true, moveLevelButton = false, moveMeter = false,
	showRacialAbility = false, showEditGrid = false, gridCenterVertical = true, gridCenterHorizontal = true,
	tallyVertical = true, tallyBossKills = true, tallyBackground = true, showEmptyActionSlots = false,
	buildRowsAttached = true, replaceBuildRows = false, anchorSnap = false, raidRow = true, layoutPerCharacter = false,
};
SS.DEFAULT_TABLES = { "places", "sizes", "scales", "muted", "padding", "orientations", "lockPanelPosition",  "itemRowEquipped",
	"itemRowSeen", "chatOffsets", "words", "layouts", "enabledElements", "elementModes" };
function SS.PrepareDB(d)
	for key, value in pairs(SS.DEFAULTS) do if ( d[key] == nil ) then d[key] = value; end end
	for i = 1, table.getn(SS.DEFAULT_TABLES) do
		local key = SS.DEFAULT_TABLES[i];
		if ( type(d[key]) ~= "table" ) then d[key] = {}; end
	end
	if ( d.hideNewSpells == nil ) then d.hideNewSpells = d.hideLevel; end
	if ( d.showGuardianFlag == nil ) then
		d.showGuardianFlag = true;
		if ( type(AZS_IsHudShown) == "function" ) then
			local ok, shown = SS.Safe(AZS_IsHudShown, "flag");
			if ( ok and shown ~= nil ) then d.showGuardianFlag = SS.HudShown(shown); end
		end
	end
	-- retired settings
	d.box, d.bloat, d.x, d.y, d.helloOnStart = nil, nil, nil, nil, nil;          -- the Say & Party box and "Remove bloat"
	d.partyMeter = nil;                                     -- the party meter is now the damage meter's Party tab
	d.demoMode = nil;                                       -- Demo Mode is never saved
	d.startUnlocked = nil;                                  -- the UI always starts locked
	d.sizeMenuPosition, d.setupStep, d.setupDisabled = nil, nil, nil;   -- the old right-click menu's place; never used
	-- Slim Suite stays under the game's level-up and new-item cards unless the player turns this on. An early
	-- test build had it on by default; this switches it off once for anyone who got that default.
	if ( (tonumber(d.onTopDefaultVersion) or 0) < 1 ) then d.onTopOfScreens = false; d.onTopDefaultVersion = 1; end
	-- each unit frame's look: "classic" (the game's art) or "new" (Slim Suite's cards); the party: face plates or thin lines
	if ( d.playerLook ~= "classic" and d.playerLook ~= "new" ) then d.playerLook = d.newFrames and "new" or "classic"; end
	if ( d.targetLook ~= "classic" and d.targetLook ~= "new" ) then d.targetLook = d.newFrames and "new" or "classic"; end
	if ( d.partyLook ~= "classic" and d.partyLook ~= "thin" ) then d.partyLook = d.partyCompact and "thin" or "classic"; end
	d.newFrames, d.partyCompact = nil, nil;                -- replaced by the looks above
	-- your buffs belong to the player frame only; the target shows its own buffs and debuffs on its own side
	if ( d.buffsOnTarget ) then d.buffsOnTarget = false; end
	if ( d.buffsOnTargetSide ~= "above" ) then d.buffsOnTargetSide = "below"; end
	if ( d.targetAuraSide ~= "above" and d.targetAuraSide ~= "left" and d.targetAuraSide ~= "right" ) then d.targetAuraSide = "below"; end
	if ( d.buffsOnPlayerSide ~= "below" and d.buffsOnPlayerSide ~= "left" and d.buffsOnPlayerSide ~= "right" ) then d.buffsOnPlayerSide = "above"; end
	if ( not d.buffsPlayerAboveDefault ) then d.buffsOnPlayerSide = "above"; d.buffsPlayerAboveDefault = true; end   -- buffs sit above by default
	if ( d.buffGrowthDirection ~= "up" and d.buffGrowthDirection ~= "down" ) then d.buffGrowthDirection = "down"; end
	if ( d.buffCustomLayout == nil ) then d.buffCustomLayout = d.orientations.BuffFrame == "vertical"; end
	if ( type(d.itemRowCounter) ~= "number" ) then d.itemRowCounter = 0; end
	if ( type(d.gridDivisions) ~= "number" ) then d.gridDivisions = tonumber(d.gridSpacing) or 128; end
	if ( not d.gridHalved ) then d.gridDivisions = (d.gridDivisions or 128) / 2; d.gridHalved = true; end   -- grid sizes were halved in v1.02
	if ( d.gridDivisions ~= 16 and d.gridDivisions ~= 32 and d.gridDivisions ~= 64 and d.gridDivisions ~= 128 ) then d.gridDivisions = 64; end
	d.gridSpacing = nil;
	if ( not d.gridOffDefault ) then d.showEditGrid = false; d.mirrorTarget = false; d.gridOffDefault = true; end
	-- Mirror Target is now one setting that both combines the unit frames and mirrors their positions.
	if ( d.mirrorTarget or d.combineTarget ) then d.mirrorTarget, d.combineTarget = true, true; end
	d.mirrorSameScale = true;                                -- retained only for older saved profiles; size is implicit
	-- earlier versions let the classic player and target frames take a width and height that only changed their click area
	if ( not d.classicSizesCleared ) then
		d.sizes.PlayerFrame = nil; d.sizes.TargetFrame = nil;
		d.classicSizesCleared = true;
	end
	-- Older versions enabled several replacement controls as defaults. This one-time migration
	-- returns those defaults to the native game UI while keeping saved positions and sizes intact.
	if ( (tonumber(d.uiDefaultsVersion) or 0) < 1 ) then
		d.replaceClock, d.replaceEncounters, d.replaceTally, d.replaceBanners = false, false, false, false;
		d.moveLevelButton, d.moveMeter, d.replaceBuildRows = false, false, false;
		d.showRacialAbility, d.cooldowns = false, false;
		d.uiDefaultsVersion = 1;
	end
end
function SS.DB()
	local d = SlimSuiteDB;
	if ( d ~= SS.preparedDB or type(d) ~= "table" ) then
		if ( type(d) ~= "table" ) then d = {}; SlimSuiteDB = d; end
		SS.preparedDB = d;
		SS.PrepareDB(d);
	end
	return d;
end

-- Keep chat-only helpers in their own lexical scope. The WoW 1.12 Lua runtime allows at
-- most 200 active locals in the addon chunk; the UI and mover code below needs that budget.
HookChat = nil;
do
local STAT_WORDS = { "maximum health and", "maximale gesundheit und", "de salud máxima y", "de vida máxima e",
	"points de vie maximum et", "maksymalnego zdrowia i", "maximálního zdraví a", "до макс. здоров'я і",
	"к макс. здоровью и", "、最大体力+", "最大生命值和每秒", ", 최대 생명력 ", " azami can ve saniyede ",
	" viață maximă și " };
-- the game's "New spell" in its languages
local NEW_SPELL_WORDS = { "new spell", "neuer zauber", "hechizo nuevo", "novo feitiço", "nouveau sort", "nowe zaklęcie",
	"nové kouzlo", "vrajă nouă", "yeni büyü", "нове закляття", "новое заклинание", "新しい呪文",
	"新法术", "새 주문" };

-- the "you have learned a new spell" lines: the game's own texts in its language, the part
-- before the spell's name, and the English ways of saying it
local LEARN_WORDS = { "you have learned a new spell", "you have learned a new ability", "you have learned", "you learned",
	"you learn " };

function SS.Prefix(text)
	if ( type(text) ~= "string" ) then return nil; end
	local s = string.find(text, "%", 1, true);
	local head = s and string.sub(text, 1, s - 1) or text;
	head = string.lower(string.gsub(head, "^%s+", ""));
	if ( string.len(head) < 6 ) then return nil; end
	return head;
end

local LEARN_GLOBALS = { "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S", "ERR_LEARN_RECIPE_S" };
function SS.LearnLine(low)
	for i = 1, 3 do
		local own = SS.Prefix(getglobal(LEARN_GLOBALS[i]));
		if ( own and string.find(low, own, 1, true) ) then return true; end
	end
	for i = 1, table.getn(LEARN_WORDS) do
		if ( string.find(low, LEARN_WORDS[i], 1, true) ) then return true; end
	end
	return false;
end

-- ---------------------------------------------------------------- the level-up text out of the chat
function SS.Any(low, list)
	for i = 1, table.getn(list) do
		if ( string.find(low, list[i], 1, true) ) then return true; end
	end
	return false;
end

local CHAT_FILTER = { activeEvent = nil, allowPlayers = false };
local RACIAL_INFO_WORDS = { "racial buff", "racial bonus", "racial ability", "racial effect" };
local cachedRacialId, cachedRacialName;

function SS.RacialAbilityName()
	local spells = type(AZS_SPELLS) == "table" and AZS_SPELLS or {};
	local racial = spells[table.getn(spells)];
	local racialId = type(racial) == "table" and tonumber(racial.spell) or nil;
	if ( not racialId ) then cachedRacialId, cachedRacialName = nil, nil; return nil; end
	if ( cachedRacialId == racialId ) then return cachedRacialName; end
	cachedRacialId, cachedRacialName = racialId, nil;
	if ( not GetSpellBookItemInfo ) then
		-- no spellbook lookup by id on this client: the name the game gives in AZS_SPELLS, if it gives one
		local own = type(racial) == "table" and racial.name;
		if ( type(own) == "string" and own ~= "" ) then cachedRacialName = CHAT_FILTER.PlainText(own); end
		return cachedRacialName;
	end
	for slot = 1, 512 do
		local ok, kind, spellId = SS.Safe(GetSpellBookItemInfo, slot, BOOKTYPE_SPELL or "spell");
		if ( not ok or not kind ) then break; end
		if ( kind == "SPELL" and tonumber(spellId) == racialId and type(GetSpellName) == "function" ) then
			local nameOk, value = SS.Safe(GetSpellName, slot, BOOKTYPE_SPELL or "spell");
			if ( nameOk and type(value) == "string" ) then cachedRacialName = CHAT_FILTER.PlainText(value); end
			break;
		end
	end
	return cachedRacialName;
end

CHAT_FILTER.PlainText = function(msg)
	local text = string.lower(msg or "");
	text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "");
	text = string.gsub(text, "|r", "");
	text = string.gsub(text, "^%s+", "");
	text = string.gsub(text, "%s+$", "");
	return text;
end;

CHAT_FILTER.playerEvents = {
	CHAT_MSG_SAY=true, CHAT_MSG_YELL=true, CHAT_MSG_WHISPER=true, CHAT_MSG_PARTY=true,
	CHAT_MSG_PARTY_LEADER=true, CHAT_MSG_RAID=true, CHAT_MSG_RAID_LEADER=true,
	CHAT_MSG_RAID_WARNING=true, CHAT_MSG_GUILD=true, CHAT_MSG_OFFICER=true,
	CHAT_MSG_CHANNEL=true, CHAT_MSG_EMOTE=true, CHAT_MSG_TEXT_EMOTE=true,
	CHAT_MSG_BATTLEGROUND=true, CHAT_MSG_BATTLEGROUND_LEADER=true,
	CHAT_MSG_BN_WHISPER=true, CHAT_MSG_BN_CONVERSATION=true
};

CHAT_FILTER.IsRoleplay = function(msg, sourceEvent)
	if ( CHAT_FILTER.playerEvents[sourceEvent] ) then return false; end
	local text = CHAT_FILTER.PlainText(msg);
	if ( text == "" ) then return false; end
	-- The creator's banner API is the authoritative source for scripted run announcements.
	-- Match only actual banner text (or a banner phrase embedded in a chat line), never arbitrary NPC chatter.
	local banners = type(AZS_BANNERS) == "table" and AZS_BANNERS or {};
	for _, banner in ipairs(banners) do
		local kind = type(banner) == "table" and type(banner.kind) == "string" and SS.KindWord(banner.kind) or nil;
		local roleplayKind = kind == "boss" or kind == "final" or kind == "bossdown" or kind == "guardian";
		if ( roleplayKind and type(banner.text) == "string" ) then
			local bannerText = CHAT_FILTER.PlainText(banner.text);
			if ( bannerText ~= "" and string.find(text, bannerText, 1, true) ) then return true; end
		end
	end
	-- This common opening announcement can precede its first AZS_BANNERS snapshot.
	if ( string.find(text, "the burning legion", 1, true) and string.find(text, "survive the onslaught", 1, true) ) then return true; end
	-- These events are game-authored dialogue or narration, not player messages.
	return sourceEvent == "CHAT_MSG_MONSTER_SAY" or sourceEvent == "CHAT_MSG_MONSTER_YELL" or
		sourceEvent == "CHAT_MSG_MONSTER_EMOTE" or sourceEvent == "CHAT_MSG_RAID_BOSS_EMOTE" or
		sourceEvent == "CHAT_MSG_RAID_BOSS_WHISPER";
end;

function SS.Hidden(msg, sourceEvent)
	if ( type(msg) ~= "string" ) then return false; end
	if ( CHAT_FILTER.allowPlayers or CHAT_FILTER.playerEvents[sourceEvent or CHAT_FILTER.activeEvent] ) then return false; end
	if ( string.find(msg, "|Hplayer:", 1, true) ) then return false; end   -- a player's own words
	local d = SS.DB();
	if ( not (d.hideLevel or d.hideNewSpells or d.hideRP or d.hideRacialInfo or d.hideOpeningLine or d.hideLairLine or d.words[1]) ) then return false; end
	local low = CHAT_FILTER.PlainText(msg);
	if ( d.hideRacialInfo ) then
		local racialInfo = SS.Any(low, RACIAL_INFO_WORDS);
		-- The game's racial announcement usually uses the localized ability name, not the
		-- English words "racial buff". AZS_SPELLS documents the racial as its last entry.
		local racialName = not racialInfo and SS.RacialAbilityName() or nil;
		if ( racialName and racialName ~= "" and string.find(low, racialName, 1, true) ) then racialInfo = true; end
		if ( racialInfo ) then return true; end
	end
	if ( d.hideOpeningLine and string.find(low, "oogax q the troll shaman enters warsong gulch", 1, true) ) then return true; end
	if ( d.hideLairLine and string.find(low, "who dares to enter my lair", 1, true) ) then return true; end
	if ( d.hideRP and CHAT_FILTER.IsRoleplay(msg, sourceEvent or CHAT_FILTER.activeEvent) ) then return true; end
	if ( d.hideLevel ) then
		-- Hide only the stat-bonus line. Level notices and spell-learning lines have separate controls.
		if ( SS.Any(low, STAT_WORDS) or
			(string.find(low, "you have gained", 1, true) and string.find(low, "% damage", 1, true) and
			string.find(low, "health", 1, true)) ) then return true; end
	end
	if ( d.hideNewSpells and (SS.Any(low, NEW_SPELL_WORDS) or SS.LearnLine(low)) ) then return true; end
	for i = 1, table.getn(d.words) do
		if ( string.find(low, d.words[i], 1, true) ) then return true; end
	end
	return false;
end

-- every chat window's AddMessage (what the game and the addons print), and the chat's own event handler
local hooked = {};
function SS.HookFrame(cf)
	if ( not cf or hooked[cf] or not cf.AddMessage ) then return; end
	hooked[cf] = true;
	local orig = cf.AddMessage;
	cf.AddMessage = function(self, msg, r, g, b, id, hold)
		-- a line printed for a chat event was judged when the event came in (below): not read a second time
		if ( not CHAT_FILTER.activeEvent and SS.Hidden(msg) ) then return; end
		return orig(self, msg, r, g, b, id, hold);
	end;
end

HookChat = function()
	for i = 1, 7 do SS.Safe(SS.HookFrame, getglobal("ChatFrame" .. i)); end
	SS.Safe(SS.HookFrame, DEFAULT_CHAT_FRAME);
	if ( type(ChatFrame_OnEvent) == "function" and not hooked.event ) then
		hooked.event = true;
		local orig = ChatFrame_OnEvent;
		ChatFrame_OnEvent = function(ev)
			local e = ev or event;
			-- the combat log's lines (hundreds a second in a fight) are only read when the player has words of their own to hide
			local combat = e and (string.find(e, "^CHAT_MSG_COMBAT_") or string.find(e, "^CHAT_MSG_SPELL_"));
			if ( type(arg1) == "string" and e and string.find(e, "^CHAT_MSG_") and (not combat or SS.DB().words[1]) and SS.Hidden(arg1, e) ) then return; end
			local previousEvent, previousPlayerGuard = CHAT_FILTER.activeEvent, CHAT_FILTER.allowPlayers;
			CHAT_FILTER.activeEvent = e or "event";
			CHAT_FILTER.allowPlayers = CHAT_FILTER.playerEvents[e] and true or false;
			local ok, result = pcall(orig, ev);              -- an error is raised again below, so it is reported once
			CHAT_FILTER.activeEvent, CHAT_FILTER.allowPlayers = previousEvent, previousPlayerGuard;
			if ( not ok ) then error(result); end
			return result;
		end;
	end
end;
end -- scoped chat filter helpers

-- ---------------------------------------------------------------- the camera at its farthest: 50
-- The game's Max Camera Distance slider is cameraDistanceMaxFactor, a factor of cameraDistanceMax (15 yards): its
-- top, 3.33, is 50 yards. Slim Suite sets it to 50 yards when the game starts (and zooms out to it once a session); turned off
-- in /slimsuite, the game's own setting stays.
MAX_CAMERA = 50;

function SS.Camera(zoomOut)
	if ( not SetCVar ) then return; end
	local d = SS.DB();
	if ( not d.camera ) then
		if ( d.cameraOriginal ) then SS.Safe(SetCVar, "cameraDistanceMaxFactor", d.cameraOriginal); d.cameraOriginal = nil; end
		return;
	end
	if ( not d.cameraOriginal and GetCVar ) then
		local ok, v = SS.Safe(GetCVar, "cameraDistanceMaxFactor");
		if ( ok and v ) then d.cameraOriginal = v; end
	end
	local base = 15;
	if ( GetCVar ) then
		local ok, v = SS.Safe(GetCVar, "cameraDistanceMax");
		if ( ok and tonumber(v) and tonumber(v) > 0 ) then base = tonumber(v); end
	end
	SS.Safe(SetCVar, "cameraDistanceMaxFactor", string.format("%.4f", MAX_CAMERA / base));
	-- once a session: later loading screens keep whatever zoom the player has chosen since
	if ( zoomOut and CameraZoomOut and not SS.cameraZoomed ) then SS.cameraZoomed = true; SS.Safe(CameraZoomOut, MAX_CAMERA); end
end

function SS.ApplyGuardianFlag()
	if ( type(AZS_SetHudShown) == "function" ) then
		SS.Safe(AZS_SetHudShown, "flag", SS.DB().showGuardianFlag and true or false);
	end
end

-- ---------------------------------------------------------------- the death sound
-- Boss, guardian and downed-friend markers live in SlimSuiteWorld.lua. They draw their own markers through the
-- game's world-anchor API and never change your target.
DEATH_SOUND = "Interface\\AddOns\\SlimSuite\\Baby Crying.mp3";
function SS.PlayDeathSound()
	if ( not SS.DB().deathSound or not PlaySoundFile ) then return; end
	SS.Safe(PlaySoundFile, DEATH_SOUND);
end

deathSoundFrame = CreateFrame("Frame");
deathSoundFrame:RegisterEvent("PLAYER_DEAD");
deathSoundFrame:SetScript("OnEvent", function() SS.PlayDeathSound(); end);


-- ---------------------------------------------------------------- moving the UI, and the target frame
-- Unlocked, each of these frames gets a handle over it (its name on a green panel): drag the handle and the frame
-- follows. The current lock state and every moved position are retained in SavedVariables across /reload.
MOVABLE = { { "PlayerFrame", "Player" }, { "TargetFrame", "Target" }, { "PartyMemberFrame1", "Party" }, { "SlimSuitePartyLines", "Party" },
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
handles = {};
handleList = {};
editOnly = nil;
setupActive = nil;                                       -- the first-time setup is walking through the UI
win = nil;                                               -- the settings window (made the first time it opens)
-- True while an element is being placed: in the setup when its element is turned on there, or in Toggle UI Settings
-- (all elements, or the one chosen with "Choose element"). A new-school card counts as its element.
function SS.IsEditing(name)
	if ( setupActive ) then return (SS.SetupShows and SS.SetupShows(name)) and true or false; end
	if ( not SS.DB().unlocked ) then return false; end
	return (not editOnly or editOnly == name or (SS.Element and SS.Element(editOnly) == SS.Element(name))) and true or false;
end
-- True while an element shows sample data: while it is being placed (above) or in Demo Mode
function SS.Previewing(name)
	return (SS.Demoing and SS.Demoing(name) or SS.IsEditing(name)) and true or false;
end
baseSizes = {};
basePoints = {};
mutedBaseAlphas = {};
mutedBaseMouse = {};
-- Forward declarations are required because placement and the update ticker are
-- defined before the implementations later in this file.
VisualInsets = nil;
RootBounds, SetRootPosition, RootFactor = nil, nil, nil;
ApplyFeatureMute = nil;
ApplyMovableOrientation = nil;
CaptureActionBarLayout = nil;
sizeMenu, sizeMenuText, sizeMenuWidth, sizeMenuHeight, sizeMenuScale, sizeMenuScaleInput, sizeMenuPadding = nil, nil, nil, nil, nil, nil, nil;
editGrid, editGridLines = nil, {};
sizeTarget = nil;
lockPanel = nil;
ShowEditGrid = nil;
PlaceAll, ApplyActionSlotGrid = nil, nil;
SetAnchorSnap = nil;
xpBarDetached = false;
buffButtonOriginalPoints = {};
partyNativePoints = {};                            -- party frames 2-4 as the game anchors them
buffLayoutApplying = false;
actionSlotsGridApplied = false;
tallyFrame = nil;
meterFrame = nil;
UpdateMeter = nil;
clockFrame = nil;
levelButton = nil;
bossFrame = nil;
announcementFrame = nil;
announcementStarted = nil;
announcementDuration = 10;
announcementFade = 0.6;
lastBannerId = nil;
encounterRows = {};
actionBarOriginal = nil;
itemRow = nil;
itemRowButtons = {};
spellRow = nil;
spellRowButtons = {};

-- The item deck reads the five real 1.12 jewelry equipment slots. The inventory API supplies
-- the currently worn icon and tooltip. API slot IDs are 1-based; ammo is slot 0.
ITEM_EQUIP_SLOTS = { 2, 11, 12, 13, 14 };
-- Demo Mode's sample build: six spells and five pieces of jewelry (icons from the game's own jewelry list)
SS.DEMO_SPELLS = { "Spell_Fire_Fireball02", "Spell_Frost_FrostBolt02", "Spell_Holy_Smite", "Spell_Shadow_ShadowBolt", "Spell_Nature_StarFall", "Spell_Holy_Heal" };
SS.DEMO_JEWELRY = { "INV_Jewelry_Necklace_01", "INV_Jewelry_Ring_15", "INV_Jewelry_Ring_07", "INV_Jewelry_Talisman_01", "INV_Misc_Horn_01" };
function SS.ItemTextureKey(texture)
	if ( type(texture) ~= "string" ) then return nil; end
	return string.gsub(texture, "^Interface.Icons.", "");
end

-- The game's own build cluster (measured from its default UI): 28-pixel icons with a 1-pixel silver border,
-- spells in one row and the worn jewelry 8 pixels below it, both starting at the same left edge.
BUILD = { ICON = 28, GAP = 4, ROW_GAP = 8 };

function SS.LayoutItemRow()
	if ( not itemRow ) then return; end
	local gap = BUILD.GAP;
	if ( not SS.DB().sizes.SlimSuiteItemRowFrame ) then
		if ( SS.DB().orientations.SlimSuiteItemRowFrame == "vertical" ) then
			itemRow:SetWidth(BUILD.ICON); itemRow:SetHeight(5 * BUILD.ICON + 4 * gap);
		else itemRow:SetWidth(5 * BUILD.ICON + 4 * gap); itemRow:SetHeight(BUILD.ICON); end
	end
	local vertical = SS.DB().orientations.SlimSuiteItemRowFrame == "vertical";
	local width, height = itemRow:GetWidth() or BUILD.ICON, itemRow:GetHeight() or BUILD.ICON;
	local iconSize = vertical and math.max(12, math.min(width, (height - gap * 4) / 5))
		or math.max(12, math.min(height, (width - gap * 4) / 5));
	for i = 1, table.getn(itemRowButtons) do
		local button = itemRowButtons[i];
		button:ClearAllPoints();
		button:SetWidth(iconSize); button:SetHeight(iconSize);
		if ( vertical ) then button:SetPoint("TOPLEFT", itemRow, "TOPLEFT", 0, -((i - 1) * (iconSize + gap)));
		else button:SetPoint("TOPLEFT", itemRow, "TOPLEFT", (i - 1) * (iconSize + gap), 0); end
	end
end

function SS.LayoutSpellRow()
	if ( not spellRow ) then return; end
	local gap = BUILD.GAP;
	if ( not SS.DB().sizes.SlimSuiteSpellRowFrame ) then
		if ( SS.DB().orientations.SlimSuiteSpellRowFrame == "vertical" ) then
			spellRow:SetWidth(BUILD.ICON); spellRow:SetHeight(6 * BUILD.ICON + 5 * gap);
		else spellRow:SetWidth(6 * BUILD.ICON + 5 * gap); spellRow:SetHeight(BUILD.ICON); end
	end
	local vertical = SS.DB().orientations.SlimSuiteSpellRowFrame == "vertical";
	local width, height = spellRow:GetWidth() or BUILD.ICON, spellRow:GetHeight() or BUILD.ICON;
	local iconSize = vertical and math.max(12, math.min(width, (height - gap * 5) / 6))
		or math.max(12, math.min(height, (width - gap * 5) / 6));
	for i = 1, 6 do
		local button = spellRowButtons[i];
		if ( button ) then
			button:ClearAllPoints(); button:SetWidth(iconSize); button:SetHeight(iconSize);
			if ( vertical ) then button:SetPoint("TOPLEFT", spellRow, "TOPLEFT", 0, -((i - 1) * (iconSize + gap)));
			else button:SetPoint("TOPLEFT", spellRow, "TOPLEFT", (i - 1) * (iconSize + gap), 0); end
		end
	end
end

-- One build icon as the game draws it: the icon inset by one pixel inside a silver border that is lighter at the top,
-- a dark fill for an empty slot (shown only while placing the rows), and the standard hover highlight.
function SS.BuildIconLook(button)
	button.border = button:CreateTexture(nil, "BACKGROUND");
	button.border:SetAllPoints(button);
	button.border:SetTexture(1, 1, 1, 1);
	if ( button.border.SetGradient ) then button.border:SetGradient("VERTICAL", 0.26, 0.25, 0.27, 0.53, 0.52, 0.54);
	else button.border:SetVertexColor(0.42, 0.41, 0.43); end
	button.empty = button:CreateTexture(nil, "BORDER");
	button.empty:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1);
	button.empty:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1);
	button.empty:SetTexture(0, 0, 0, 0.6);
	button.icon = button:CreateTexture(nil, "ARTWORK");
	button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1);
	button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1);
	button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square");
end

-- Default replacement rows mirror the native build cluster: six spells in the upper row,
-- worn jewelry directly below. The spell row uses the screenshot-based lower-left-center anchor.
-- an item's own name, from its link ("|cff...|Hitem:...|h[Name]|h|r"): always right, even when two items share an icon
function SS.ItemLinkName(link)
	if ( type(link) ~= "string" ) then return nil; end
	local _, _, name = string.find(link, "%[(.-)%]");
	return name;
end

function SS.BuildRowDefaultPlace(name)
	local x, y = UIParent:GetWidth() * 0.275, UIParent:GetHeight() * 0.35;
	if ( name == "SlimSuiteItemRowFrame" ) then
		if ( SS.DB().buildRowsAttached ) then
			if ( SS.DB().orientations.SlimSuiteSpellRowFrame == "vertical" ) then   -- read directly: this runs while the file loads
				return { relative = "SlimSuiteSpellRowFrame", point = "TOPLEFT", relativePoint = "TOPRIGHT", dx = BUILD.ROW_GAP, dy = 0 };
			end
			return { relative = "SlimSuiteSpellRowFrame", point = "TOPLEFT", relativePoint = "BOTTOMLEFT", dx = 0, dy = -BUILD.ROW_GAP };
		end
		return { x = x, y = y - 40, coordinateSpace = "uiParent", displayDefault = true };
	end
	return { x = x, y = y, coordinateSpace = "uiParent", displayDefault = true };
end

function SS.RefreshItemRow()
	if ( not itemRow ) then return; end
	local d = SS.DB();
	local equipped, visible = {}, {};
	for i = 1, table.getn(ITEM_EQUIP_SLOTS) do
		local slot = ITEM_EQUIP_SLOTS[i];
		local texture = GetInventoryItemTexture and GetInventoryItemTexture("player", slot) or nil;
		local link = GetInventoryItemLink and GetInventoryItemLink("player", slot) or nil;
		if ( texture ) then
			local identity = link or tostring(texture);
			local previous = d.itemRowEquipped[slot];
			if ( type(previous) ~= "table" or previous.identity ~= identity ) then
				local order = d.itemRowSeen[identity];
				if ( type(order) ~= "number" ) then
					d.itemRowCounter = d.itemRowCounter + 1;
					order = d.itemRowCounter;
					d.itemRowSeen[identity] = order;
				end
				previous = { identity = identity, order = order };
				d.itemRowEquipped[slot] = previous;
			end
			equipped[slot] = { texture = texture, link = link, order = previous.order,
				knownName = SS.ItemLinkName(link) or (SlimSuiteItemCatalog and SlimSuiteItemCatalog[SS.ItemTextureKey(texture)]) or nil };
			table.insert(visible, { slot = slot, item = equipped[slot] });
		else
			d.itemRowEquipped[slot] = nil;
		end
	end
	table.sort(visible, function(a, b) return a.item.order < b.item.order; end);
	for i = 1, table.getn(itemRowButtons) do
		local button = itemRowButtons[i];
		local entry = visible[i];
		if ( button ) then
			if ( entry ) then
				button.slot = entry.slot;
				button.itemTexture = entry.item.texture;
				button.itemName = entry.item.knownName;
				button.icon:SetTexture(entry.item.texture);
				button.icon:Show();
				button:Show();
			else
				button.slot, button.itemTexture, button.itemName = nil, nil, nil;
				button.icon:SetTexture(nil);
				-- Like the game, an empty slot is not drawn. While the rows are being placed, empty slots show
				-- as dark squares so the row can still be found, moved and sized before anything is worn.
				if ( SS.Demoing("SlimSuiteItemRowFrame") and SS.DEMO_JEWELRY[i] ) then
					button.icon:SetTexture("Interface\\Icons\\" .. SS.DEMO_JEWELRY[i]); button.icon:Show(); button:Show();
				elseif ( SS.Previewing("SlimSuiteItemRowFrame") ) then button:Show(); else button:Hide(); end
			end
		end
	end
	SS.LayoutItemRow();
	if ( d.replaceBuildRows ) then itemRow:Show(); else itemRow:Hide(); end
	if ( SS.IsEditing("SlimSuiteItemRowFrame") and d.replaceBuildRows and handles.SlimSuiteItemRowFrame ) then handles.SlimSuiteItemRowFrame:Show(); end
end

function SS.CreateItemRow()
	if ( itemRow or not UIParent ) then return; end
	itemRow = CreateFrame("Frame", "SlimSuiteItemRowFrame", UIParent);
	itemRow:SetWidth(176); itemRow:SetHeight(36);
	local d = SS.DB();
	local oldItemPlace = d.places.SlimSuiteItemRowFrame;
	if ( d.buildRowsAttached and type(oldItemPlace) == "table" and oldItemPlace.relative == "MainMenuBar"
		and K.Num(oldItemPlace.dx) == 0 and K.Num(oldItemPlace.dy) == -4 ) then
		oldItemPlace.relative = "SlimSuiteSpellRowFrame";
	end
	if ( not d.places.SlimSuiteItemRowFrame ) then
		d.places.SlimSuiteItemRowFrame = SS.BuildRowDefaultPlace("SlimSuiteItemRowFrame");
	end
	itemRow:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 8, -130);
	itemRow:SetFrameStrata("MEDIUM");
	for i = 1, table.getn(ITEM_EQUIP_SLOTS) do
		local button = CreateFrame("Button", "SlimSuiteItemButton" .. i, itemRow);
		button:SetWidth(BUILD.ICON); button:SetHeight(BUILD.ICON);
		SS.BuildIconLook(button);
		button:EnableMouse(true);
		button:SetScript("OnEnter", function()
			if ( not this.slot or not GameTooltip ) then return; end
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
			if ( GameTooltip.SetInventoryItem ) then GameTooltip:SetInventoryItem("player", this.slot); GameTooltip:Show();
			elseif ( this.itemName ) then GameTooltip:AddLine(this.itemName); GameTooltip:Show(); end
		end);
		button:SetScript("OnLeave", function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
		itemRowButtons[i] = button;
	end
	SS.RefreshItemRow();
end
SS.CreateItemRow();

function SS.SpellTextureById(spellId)
	if ( type(spellId) ~= "number" or not GetSpellBookItemInfo or not GetSpellTexture ) then return nil; end
	-- AZS_SPELLS supplies canonical spell IDs. Resolve those against the real spellbook; never
	-- substitute an icon based only on a localized name or a guessed spell key.
	for i = 1, 512 do
		local kind, id = GetSpellBookItemInfo(i, BOOKTYPE_SPELL or "spell");
		if ( not kind ) then break; end
		if ( kind == "SPELL" and tonumber(id) == spellId ) then
			local ok, texture = SS.Safe(GetSpellTexture, i, BOOKTYPE_SPELL or "spell");
			if ( ok and texture ) then return texture, i; end
		end
	end
	return nil;
end

function SS.SourceHasSpellId(source, spellId)
	if ( type(source) ~= "table" or type(source.spellIds) ~= "table" or not spellId ) then return false; end
	for _, id in ipairs(source.spellIds) do if ( tonumber(id) == tonumber(spellId) ) then return true; end end
	return false;
end

function SS.RefreshSpellRow()
	if ( not spellRow ) then return; end
	local spells = type(AZS_SPELLS) == "table" and AZS_SPELLS or {};
	local learnedCount = math.max(0, table.getn(spells) - 1); -- racial spell is last
	-- The live loadout API carries exact selected ability icons, including talent-granted spells
	-- whose icons are not resolvable from the legacy spellbook scan.
	local loadout, loadoutContext;
	if ( type(AZS_GetMeterContext) == "function" and type(AZS_GetMeterLoadout) == "function" ) then
		local okContext; okContext, loadoutContext = SS.Safe(AZS_GetMeterContext);
		if ( okContext and type(loadoutContext) == "table" and loadoutContext.runId ) then
			local okLoadout, result = SS.Safe(AZS_GetMeterLoadout, { apiVersion = 1, runId = loadoutContext.runId });
			if ( okLoadout and type(result) == "table" ) then loadout = result; end
		end
	end
	local loadoutIcons = {};
	if ( loadout and type(loadout.abilities) == "table" ) then
		for _, ability in ipairs(loadout.abilities) do
			if ( type(ability) == "table" and ability.learned ~= false and ability.selected ~= false and
				type(ability.sourceKey) == "string" ) then
				local source = type(loadout.sources) == "table" and loadout.sources[ability.sourceKey] or nil;
				local icon = type(source) == "table" and source.icon or nil;
				local iconPath = type(icon) == "table" and icon.status == "ready" and icon.path or nil;
				if ( iconPath ) then
					-- Match the API descriptor to AZS_SPELLS by its stable ability key or exact
					-- spell ID. Do not infer slot numbering from undocumented slotId conventions.
					for i = 1, learnedCount do
						local spell = spells[i];
						if ( type(spell) == "table" and
							((source.abilityKey and spell.key == source.abilityKey) or SS.SourceHasSpellId(source, spell.spell)) ) then
							if ( not loadoutIcons[i] or (source.abilityKey and spell.key == source.abilityKey) ) then
								loadoutIcons[i] = { path = iconPath, name = source.name };
							end
						end
					end
				end
			end
		end
	end
	for i = 1, 6 do
		local button = spellRowButtons[i];
		local spell = spells[i];
		local loadoutIcon = loadoutIcons[i];
		local iconLoaded = false;
		button.sourceName = loadoutIcon and loadoutIcon.name or nil;
		local texture, spellBookSlot;
		if ( i <= learnedCount and type(spell) == "table" ) then
			texture, spellBookSlot = SS.SpellTextureById(tonumber(spell.spell));
		end
		button.spellBookSlot = spellBookSlot;
		if ( loadoutIcon ) then
			button.spell = spell;
			button.icon:SetTexture(loadoutIcon.path); button.icon:Show(); iconLoaded = true;
		end
		if ( not iconLoaded and i <= learnedCount and type(spell) == "table" ) then
			button.spell, button.spellBookSlot = spell, spellBookSlot;
			if ( texture ) then button.icon:SetTexture(texture); button.icon:Show(); iconLoaded = true; else button.icon:SetTexture(nil); button.icon:Hide(); end
		else
			if ( not iconLoaded ) then
				button.spell, button.spellBookSlot = nil, nil;
				button.icon:SetTexture(nil); button.icon:Hide();
			end
		end
		if ( not iconLoaded and SS.Demoing("SlimSuiteSpellRowFrame") and SS.DEMO_SPELLS[i] ) then
			button.icon:SetTexture("Interface\\Icons\\" .. SS.DEMO_SPELLS[i]); button.icon:Show(); iconLoaded = true;
		end
		if ( iconLoaded or SS.Previewing("SlimSuiteSpellRowFrame") ) then button:Show(); else button:Hide(); end
	end
	SS.LayoutSpellRow();
	if ( SS.DB().replaceBuildRows ) then spellRow:Show(); else spellRow:Hide(); end
	if ( SS.IsEditing("SlimSuiteSpellRowFrame") and SS.DB().replaceBuildRows and handles.SlimSuiteSpellRowFrame ) then handles.SlimSuiteSpellRowFrame:Show(); end
end

function SS.CreateSpellRow()
	if ( spellRow or not UIParent ) then return; end
	spellRow = CreateFrame("Frame", "SlimSuiteSpellRowFrame", UIParent);
	spellRow:SetWidth(212); spellRow:SetHeight(36); spellRow:SetFrameStrata("MEDIUM");
	local d = SS.DB();
	local oldSpellPlace = d.places.SlimSuiteSpellRowFrame;
	if ( type(oldSpellPlace) == "table" and oldSpellPlace.relative == "MainMenuBar"
		and oldSpellPlace.point == "TOPLEFT" and oldSpellPlace.relativePoint == "BOTTOMLEFT"
		and K.Num(oldSpellPlace.dx) == 0 and K.Num(oldSpellPlace.dy) == -4 ) then
		oldSpellPlace.relative, oldSpellPlace.point, oldSpellPlace.relativePoint = nil, nil, nil;
		oldSpellPlace.dx, oldSpellPlace.dy = nil, nil;
		oldSpellPlace.x, oldSpellPlace.y, oldSpellPlace.coordinateSpace = UIParent:GetWidth() * 0.275, UIParent:GetHeight() * 0.35, "uiParent";
	end
	if ( not d.places.SlimSuiteSpellRowFrame ) then
		d.places.SlimSuiteSpellRowFrame = SS.BuildRowDefaultPlace("SlimSuiteSpellRowFrame");
	end
	spellRow:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 8, 170);
	for i = 1, 6 do
		local button = CreateFrame("Button", "SlimSuiteSpellButton" .. i, spellRow);
		button:SetID(i);
		button:SetWidth(BUILD.ICON); button:SetHeight(BUILD.ICON);
		SS.BuildIconLook(button);
		button:EnableMouse(true);
		button:SetScript("OnEnter", function()
			if ( not this.spell or not GameTooltip ) then return; end
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
			-- a loadout icon has no spell-book slot of its own: look the spell up, so the tooltip is the same as the action bar's
			if ( not this.spellBookSlot and this.spell.spell ) then
				local _, slot = SS.SpellTextureById(tonumber(this.spell.spell));
				this.spellBookSlot = slot;
			end
			if ( this.spellBookSlot and GameTooltip.SetSpellBookItem ) then GameTooltip:SetSpellBookItem(this.spellBookSlot, BOOKTYPE_SPELL or "spell"); GameTooltip:Show();
			elseif ( this.spellBookSlot and GameTooltip.SetSpell ) then GameTooltip:SetSpell(this.spellBookSlot, BOOKTYPE_SPELL or "spell"); GameTooltip:Show();   -- the 1.12 call
			elseif ( this.spell.key or this.sourceName ) then
				GameTooltip:AddLine(tostring(this.sourceName or this.spell.key));
				if ( this.spell.rank ) then GameTooltip:AddLine("Rank " .. tostring(this.spell.rank), 1, 0.82, 0); end
				if ( this.spell.spell ) then GameTooltip:AddLine("Spell ID: " .. tostring(this.spell.spell), 0.7, 0.7, 0.7); end
				if ( type(this.spell.cdmax) == "number" and this.spell.cdmax > 0 ) then GameTooltip:AddLine("Cooldown: " .. tostring(this.spell.cdmax) .. " sec", 0.7, 0.7, 0.7); end
				GameTooltip:Show();
			end
		end);
		button:SetScript("OnLeave", function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
		spellRowButtons[i] = button;
	end
	SS.RefreshSpellRow();
end
SS.CreateSpellRow();

function SS.ApplyBuildRowReplacement()
	local enabled = SS.DB().replaceBuildRows;
	SS.HideNative("build", enabled);
	if ( spellRow ) then if ( enabled ) then spellRow:Show(); else spellRow:Hide(); end end
	if ( itemRow ) then if ( enabled ) then itemRow:Show(); else itemRow:Hide(); end end
end
SS.ApplyBuildRowReplacement();

itemRowEvents = CreateFrame("Frame");
itemRowEvents:RegisterEvent("UNIT_INVENTORY_CHANGED");
itemRowEvents:RegisterEvent("PLAYER_ENTERING_WORLD");
itemRowEvents:SetScript("OnEvent", function()
	if ( event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" ) then return; end
	SS.Safe(SS.RefreshItemRow);
end);
-- The AZSSPELLS addon message refreshes the build rows as spells change. This slow poll catches anything the
-- event misses, for both the spell row and the worn-jewelry row (SS.ApplyBuildRowReplacement).
SS.Every("itemRowPoll", 2, function() SS.Safe(SS.RefreshSpellRow); SS.Safe(SS.RefreshItemRow); SS.Safe(SS.ApplyBuildRowReplacement); end);

spellRowEvents = CreateFrame("Frame");
spellRowEvents:RegisterEvent("PLAYER_ENTERING_WORLD");
spellRowEvents:RegisterEvent("ACTIONBAR_SLOT_CHANGED");
spellRowEvents:RegisterEvent("ACTIONBAR_PAGE_CHANGED");
spellRowEvents:RegisterEvent("CHAT_MSG_ADDON");
spellRowEvents:SetScript("OnEvent", function()
	if ( event == "CHAT_MSG_ADDON" and arg1 ~= "AZSSPELLS" ) then return; end
	SS.Safe(SS.RefreshSpellRow);
	SS.Safe(SS.ApplyBuildRowReplacement);
end);

function SS.FramePaddingLimit(name)
	if ( name == "SlimSuiteClockFrame" ) then return 6; end
	if ( name == "SlimSuiteBossFrames" ) then return 8; end
	if ( name == "SlimSuiteTallyFrame" ) then return 8; end
	if ( name == "SlimSuiteAnnouncementFrame" ) then return 20; end
	if ( name == "BuffFrame" ) then return 16; end
	return 0;
end

function SS.FramePadding(name)
	local value = SS.DB().padding[name];
	return type(value) == "number" and math.max(0, math.min(SS.FramePaddingLimit(name), value)) or 0;
end

-- Kills / Gold / Cache in the game's own style (measured from its HUD): muted tan labels, gold numbers, a lowercase
-- gold "cache" for the next cache's cost, and a soft dark band behind that fades out at both ends. The band can be
-- turned off completely. Boss and Guardian kills sit next to Kills by default.
TALLY = { LABEL = { 0.69, 0.63, 0.47 }, VALUE = { 0.97, 0.82, 0.41 }, FONT_SIZE = 15, WORD_GAP = 6, PART_GAP = 16, LINE = 19 };

function SS.TallyValue(value)
	if ( type(value) ~= "number" ) then return "-"; end
	return tostring(math.floor(value));
end

SS.TALLY_SAMPLE = { kills = 1284, gold = 356, chest = 120, bosses = 2, guardians = 3 };
function SS.TallyParts(run, sample)
	if ( sample ) then run = SS.TALLY_SAMPLE; end
	local parts = { { "Kills", SS.TallyValue(run and run.kills) } };
	if ( SS.DB().tallyBossKills ) then
		local bosses, guardians;
		if ( sample ) then bosses, guardians = run.bosses, run.guardians;
		elseif ( run and SlimSuiteWorld and SlimSuiteWorld.RunKills ) then bosses, guardians = SlimSuiteWorld.RunKills(); end
		table.insert(parts, { "Bosses", SS.TallyValue(bosses) });
		table.insert(parts, { "Guardians", SS.TallyValue(guardians) });
	end
	table.insert(parts, { "Gold", SS.TallyValue(run and run.gold) });
	table.insert(parts, { "cache", SS.TallyValue(run and run.chest), true });   -- the game draws all of it in gold
	return parts;
end

-- The creator documents AZS_ZONE.zname and AZS_ZONE.diff (the zone's difficulty multiplier).
-- Keep the multiplier explicit; do not guess a Normal/Heroic label from an undocumented threshold.
function SS.TallyContext(sample)
	if ( sample ) then return "Elwynn Forest  |  Difficulty 1.00x"; end
	local zone = type(AZS_ZONE) == "table" and AZS_ZONE or nil;
	local name = zone and (zone.zname or zone.name or zone.zone or zone.title) or nil;
	if ( type(name) ~= "string" or name == "" ) then name = type(GetRealZoneText) == "function" and GetRealZoneText() or ""; end
	local diff = zone and tonumber(zone.diff) or nil;
	if ( type(name) ~= "string" or name == "" ) then return ""; end
	if ( diff ) then return name .. "  |  Difficulty " .. string.format("%.2fx", diff); end
	return name;
end

function SS.TallyString(list, i, justify)
	local fs = list[i];
	if ( not fs ) then
		fs = tallyFrame:CreateFontString(nil, "OVERLAY");
		fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", TALLY.FONT_SIZE);
		fs:SetShadowColor(0, 0, 0, 1); fs:SetShadowOffset(1, -1);
		list[i] = fs;
	end
	fs:SetJustifyH(justify or "LEFT");
	return fs;
end

function SS.DrawTally(parts)
	local vertical = SS.DB().tallyVertical and true or false;
	local pad = 10 + SS.FramePadding("SlimSuiteTallyFrame");
	local n = table.getn(parts);
	local custom = SS.DB().sizes.SlimSuiteTallyFrame;
	local fixed = type(custom) == "table" and custom.w and custom.h;
	local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF";
	local context = SS.TallyContext(SS.Demoing("SlimSuiteTallyFrame") or SS.IsEditing("SlimSuiteTallyFrame"));
	local sig = (vertical and "v" or "h") .. pad .. (SS.DB().tallyBackground and "b" or "") .. context .. (fixed and (custom.w .. "x" .. custom.h) or "");
	for i = 1, n do sig = sig .. "|" .. parts[i][1] .. parts[i][2]; end
	if ( tallyFrame.sig == sig ) then return; end           -- nothing it shows has changed
	tallyFrame.sig = sig;
	-- the text at a given size: the widest part (a column) and the whole row
	local function Measure(size)
		local widest, total = 0, 0;
		for i = 1, n do
			local label, value = SS.TallyString(tallyFrame.labels, i), SS.TallyString(tallyFrame.values, i, vertical and "RIGHT" or "LEFT");
			label:SetFont(font, size); value:SetFont(font, size);
			label:SetText(parts[i][1]); value:SetText(parts[i][2]);
			local c = parts[i][3] and TALLY.VALUE or TALLY.LABEL;
			label:SetTextColor(c[1], c[2], c[3]); value:SetTextColor(TALLY.VALUE[1], TALLY.VALUE[2], TALLY.VALUE[3]);
			local part = (label:GetStringWidth() or 0) + TALLY.WORD_GAP + (value:GetStringWidth() or 0);
			widest = math.max(widest, part);
			total = total + part + TALLY.PART_GAP;
			label:Show(); value:Show();
		end
		return widest, total - TALLY.PART_GAP;
	end
	local size, line = TALLY.FONT_SIZE, TALLY.LINE;
	local widest, total = Measure(size);
	-- a size set in the resize menu is the size: the band keeps it exactly, and the text shrinks to fit inside it
	if ( fixed ) then
		local need = vertical and widest or total;
		local fit = size;
		if ( need > 0 and need > custom.w - pad * 2 ) then fit = math.floor(size * (custom.w - pad * 2) / need); end
		if ( vertical ) then fit = math.min(fit, math.floor((custom.h - 28) / n) - 4); else fit = math.min(fit, math.floor(custom.h) - 34); end
		fit = math.max(7, fit);
		if ( fit ~= size ) then size = fit; widest, total = Measure(size); end
		line = math.min(TALLY.LINE, size + 4);
	end
	for i = n + 1, table.getn(tallyFrame.labels) do tallyFrame.labels[i]:Hide(); tallyFrame.values[i]:Hide(); end
	local width, height;
	if ( fixed ) then width, height = custom.w, custom.h;
	elseif ( vertical ) then width, height = widest + pad * 2, n * line + 28;
	else width, height = total + pad * 2, 50; end
	tallyFrame:SetWidth(width); tallyFrame:SetHeight(height);
	if ( not tallyFrame.context ) then
		tallyFrame.context = tallyFrame:CreateFontString(nil, "OVERLAY");
		tallyFrame.context:SetJustifyH("CENTER"); tallyFrame.context:SetJustifyV("MIDDLE");
		tallyFrame.context:SetShadowColor(0, 0, 0, 1); tallyFrame.context:SetShadowOffset(1, -1);
	end
	local contextSize = 10;
	tallyFrame.context:SetFont(font, contextSize); tallyFrame.context:SetText(context);
	local contextWidth = width - 10;
	if ( contextWidth > 0 and (tallyFrame.context:GetStringWidth() or 0) > contextWidth ) then
		contextSize = math.max(7, math.floor(contextSize * contextWidth / tallyFrame.context:GetStringWidth()));
		tallyFrame.context:SetFont(font, contextSize);
	end
	tallyFrame.context:ClearAllPoints(); tallyFrame.context:SetPoint("TOPLEFT", tallyFrame, "TOPLEFT", 3, -2);
	tallyFrame.context:SetPoint("TOPRIGHT", tallyFrame, "TOPRIGHT", -3, -2); tallyFrame.context:SetHeight(14);
	tallyFrame.context:SetTextColor(0.95, 0.78, 0.35);
	if ( context ~= "" ) then tallyFrame.context:Show(); else tallyFrame.context:Hide(); end
	local x = pad;
	for i = 1, n do
		local label, value = tallyFrame.labels[i], tallyFrame.values[i];
		label:ClearAllPoints(); value:ClearAllPoints();
		if ( vertical ) then
			local y = -18 - (i - 1) * line;
			label:SetPoint("TOPLEFT", tallyFrame, "TOPLEFT", pad, y);
			value:SetPoint("TOPRIGHT", tallyFrame, "TOPRIGHT", -pad, y);
		else
			label:SetPoint("LEFT", tallyFrame, "LEFT", x, -26);
			x = x + (label:GetStringWidth() or 0) + TALLY.WORD_GAP;
			value:SetPoint("LEFT", tallyFrame, "LEFT", x, -26);
			x = x + (value:GetStringWidth() or 0) + TALLY.PART_GAP;
		end
	end
	-- the band: flat in the middle, fading out over its last 14 pixels on each side; nothing at all when turned off
	local band = SS.DB().tallyBackground and true or false;
	local fade = math.min(14, width / 4);
	tallyFrame.bgLeft:SetWidth(fade); tallyFrame.bgRight:SetWidth(fade);
	for _, t in ipairs({ tallyFrame.bg, tallyFrame.bgLeft, tallyFrame.bgRight }) do if ( band ) then t:Show(); else t:Hide(); end end
end

function SS.UpdateTally()
	if not SS.DB().replaceTally then if tallyFrame then tallyFrame:Hide();end;SS.HideNative("tally", false);return;end
	if ( not tallyFrame ) then return; end
	local phase = type(AZS_GetPhase) == "function" and AZS_GetPhase() or nil;
	local active = phase and phase ~= "ready";
	local run = type(AZS_RUN) == "table" and AZS_RUN or nil;
	if ( active and run ) then
		SS.DrawTally(SS.TallyParts(run));
		tallyFrame:Show();
		SS.HideNative("tally", true);
	elseif ( SS.Previewing("SlimSuiteTallyFrame") ) then
		-- while it is placed (or in Demo Mode) it shows sample counts, so the element is there to see and move
		SS.DrawTally(SS.TallyParts(nil, true));
		tallyFrame:Show();
		SS.HideNative("tally", false);
	else
		-- before a run there is nothing to count
		tallyFrame:Hide();
		SS.HideNative("tally", false);
	end
end

function SS.CreateTallyFrame()
	tallyFrame = CreateFrame("Frame", "SlimSuiteTallyFrame", UIParent);
	tallyFrame:SetWidth(252);
	tallyFrame:SetHeight(28);
	-- Match the centered lower-HUD cluster: above the action bar, without inheriting its frame.
	tallyFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 145);
	tallyFrame:SetFrameStrata("HIGH");
	tallyFrame:EnableMouse(false);
	tallyFrame.labels, tallyFrame.values = {}, {};
	local BAND = 0.5;
	tallyFrame.bgLeft = tallyFrame:CreateTexture(nil, "BACKGROUND");
	tallyFrame.bgLeft:SetPoint("TOPLEFT", tallyFrame, "TOPLEFT", 0, 0); tallyFrame.bgLeft:SetPoint("BOTTOMLEFT", tallyFrame, "BOTTOMLEFT", 0, 0);
	tallyFrame.bgRight = tallyFrame:CreateTexture(nil, "BACKGROUND");
	tallyFrame.bgRight:SetPoint("TOPRIGHT", tallyFrame, "TOPRIGHT", 0, 0); tallyFrame.bgRight:SetPoint("BOTTOMRIGHT", tallyFrame, "BOTTOMRIGHT", 0, 0);
	tallyFrame.bg = tallyFrame:CreateTexture(nil, "BACKGROUND");
	tallyFrame.bg:SetPoint("TOPLEFT", tallyFrame.bgLeft, "TOPRIGHT", 0, 0); tallyFrame.bg:SetPoint("BOTTOMRIGHT", tallyFrame.bgRight, "BOTTOMLEFT", 0, 0);
	for _, t in ipairs({ tallyFrame.bg, tallyFrame.bgLeft, tallyFrame.bgRight }) do t:SetTexture(1, 1, 1, 1); t:SetVertexColor(0, 0, 0, BAND); end
	if ( tallyFrame.bgLeft.SetGradientAlpha ) then
		tallyFrame.bgLeft:SetGradientAlpha("HORIZONTAL", 0, 0, 0, 0, 0, 0, 0, BAND);
		tallyFrame.bgRight:SetGradientAlpha("HORIZONTAL", 0, 0, 0, BAND, 0, 0, 0, 0);
	end
	tallyFrame:Hide();
end

SS.CreateTallyFrame();

function SS.CreateMeterFrame()
	meterFrame = CreateFrame("Frame", "SlimSuiteMeterFrame", UIParent);
	meterFrame:SetWidth(250); meterFrame:SetHeight(180);
	meterFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -8, 44);
	meterFrame:SetFrameStrata("HIGH");
	meterFrame:EnableMouse(false);
	SlimSuiteMeter.Attach(meterFrame);
	meterFrame:Hide();
end

SS.CreateMeterFrame();

UpdateMeter = function()
	if ( not meterFrame ) then return; end
	local phase = type(AZS_GetPhase) == "function" and AZS_GetPhase() or nil;
	local active = phase and phase ~= "ready";
	local editing = SS.IsEditing("SlimSuiteMeterFrame") and SS.DB().moveMeter;
	if ( not SS.DB().moveMeter ) then
		meterFrame:Hide();
		if ( not setupActive ) then SS.HideNative("meter", false); end   -- the setup keeps the game's meter hidden
		return;
	end
	-- Shown before a run too, like the game's own meter (it reads "No damage yet." until the run starts).
	-- closed with its "x": hidden for the rest of this run (the game's meter stays hidden too)
	if ( not editing and SlimSuiteMeter.IsClosed and SlimSuiteMeter.IsClosed() ) then
		meterFrame:Hide(); SS.HideNative("meter", true); return;
	end
	SS.HideNative("meter", true);
	meterFrame:Show();
	SlimSuiteMeter.Draw(active, editing);
end

SS.Every("meterPoll", 0.35, function() SS.Safe(UpdateMeter); end);

function SS.UpdateLevelButton()
	if ( not levelButton ) then return; end
	local canReplace = type(AZS_OpenStoredLevels) == "function";
	local replacing = SS.DB().moveLevelButton and canReplace;
	SS.HideNative("levels", replacing);
	local storedCount = 0;
	if ( type(AZS_GetStoredLevels) == "function" ) then
		local okCount, value = SS.Safe(AZS_GetStoredLevels);
		if ( okCount and type(value) == "number" ) then storedCount = math.max(0, math.floor(value)); end
	end
	if ( levelButton.store ) then
		local phase = type(AZS_GetPhase) == "function" and AZS_GetPhase() or nil;
		local inRun = phase == "playing" or phase == "choosing" or phase == "paused";
		-- points to spend: a level-up choice is open, or levels are already stored; otherwise the toggle is off the screen
		local hasPoints = phase == "choosing" or storedCount > 0;
		if ( replacing and type(AZS_SetStoringLevels) == "function" and ((inRun and hasPoints) or SS.Previewing("SlimSuiteStoredLevelsButton")) ) then
			local ok, storing = false, nil;
			if ( type(AZS_IsStoringLevels) == "function" ) then ok, storing = SS.Safe(AZS_IsStoringLevels); end
			levelButton.store:SetChecked((ok and storing) and 1 or nil);
			levelButton.store:Show();
		else
			levelButton.store:Hide();
		end
	end
	if ( not replacing ) then levelButton:Hide(); return; end
	local count = 0;
	if ( type(AZS_GetStoredLevels) == "function" ) then
		local ok, value = SS.Safe(AZS_GetStoredLevels);
		if ( ok and type(value) == "number" ) then count = math.max(0, math.floor(value)); end
	end
	local level = type(UnitLevel) == "function" and UnitLevel("player") or nil;
	local preview = count == 0 and SS.Previewing("SlimSuiteStoredLevelsButton");
	levelButton.level:SetText("LEVEL " .. (level and tostring(level) or ""));
	levelButton.count:SetText((count > 0 and tostring(count)) or (preview and "2") or "");   -- a sample count while it is placed
	SS.Safe(SS.LayoutLevelButton);
	-- the game's stored-level count says when there is something to spend; it is also shown while being placed
	if ( count > 0 or preview ) then levelButton:Show(); else levelButton:Hide(); end
end

-- the button's contents follow its size: the class symbol, the level line and LEVEL UP! grow and shrink with it
function SS.LayoutLevelButton()
	local b = levelButton;
	if ( not b ) then return; end
	local w, h = b:GetWidth() or 184, b:GetHeight() or 58;
	if ( b.laidW == w and b.laidH == h ) then return; end
	b.laidW, b.laidH = w, h;
	local s = math.min(h / 58, w / 184);
	local icon = math.max(10, math.floor(40 * s));
	b.classIcon:SetWidth(icon); b.classIcon:SetHeight(icon);
	b.classIcon:ClearAllPoints(); b.classIcon:SetPoint("LEFT", b, "LEFT", math.floor(10 * s), 0);
	local left = math.floor(10 * s) + icon + math.floor(8 * s);
	local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF";
	b.level:ClearAllPoints(); b.level:SetPoint("TOPLEFT", b, "TOPLEFT", left, -math.floor(10 * s));
	b.level:SetFont(font, math.max(6, math.floor(10 * s)));
	b.text:ClearAllPoints(); b.text:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", left, math.floor(8 * s));
	b.text:SetFont(font, math.max(7, math.floor(16 * s)));
	b.count:SetFont(font, math.max(6, math.floor(10 * s)));
	b.glow:SetWidth(w * 1.24); b.glow:SetHeight(h * 1.41);
end
