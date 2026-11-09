-- Slim Suite: chat filters, HUD controls, and other optional player tools.
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
--   * Move, resize and scale the UI: drag a green handle to move it; right-click for width, height and scale.
--     The action bar, XP bar, buffs, cast bar, party frames and kills/gold/cache tally can switch between horizontal and vertical layouts.
--     Bar 2 and Right bar are intentionally not included; Action Bar 1 can optionally show empty slots.
--     Optional anchoring latches nearby movable frames together. Positions and custom sizes are saved continuously across /reload.
--     The resize menu and tooltip can also be moved while settings are active. Native frames stay in their game layout until a UI replacement or edit is chosen.
--     The primary chat window, tab and input box move together from one Chat handle.
--   * The kills, gold and next-cache cost use the documented AZS_RUN values in a movable replacement for the tally.
--     Right-click its green handle to switch between a compact horizontal row and a vertical three-line layout.
--   * The run clock and next-boss countdown stay together in one movable replacement for the game's clock.
--   * Event announcements use the game's localized text, remain visible for 10 seconds, fade at both ends, and move
--     with their own handle. They are separate from the "Move to Begin" prompt.
--   * The stored-levels button is a movable replacement that opens the game's own choices through its documented API.
--   * Active boss, guardian and elite bars sit in the upper-left encounter area, separate from the centered run
--     clock. Horizontal cards grow from the left; right-click switches to narrow vertical bars. HP uses the
--     documented current/maximum values, refreshed on AZSUNITS updates.
--   * Hide the target frame: this game picks its own targets, so the frame can go.
--   * Plain action bar: the gryphons and the bar's art go, and only the six spell squares are left, with the bar
--     no wider than they are (and the two page arrows), so it leaves no empty space.
--   * Cooldown numbers: each spell square shows the seconds until its spell is ready again.
-- /slimsuite (or the gear by the minimap) opens the settings window: every one of these on or off.
-- Lua 5.0 / 1.12 interface: scripts read `this`, `event`, `arg1`, `arg2`; no # operator; only the 1.12 API.

local K = AZSKIT;
local NAME = "Slim Suite";

-- the stat bonus a level-up gives, in each of the game's languages (a piece of the line that has no number in it), as
-- the game itself writes "You have gained {damage}% damage, {health} maximum health and {regen} health per second."
-- SS.UnitKind(unit): what an enemy is, as one lowercase word ("final", "boss", "guardian", "elite", ...).
-- Pass a unit token ("target"), an id, or an entry from AZS_UNITS / AZS_GetBosses / AZS_GetGuardians. The game's
-- AZS_UnitKind (0.87) answers first; an entry's own kind field is the fallback. Use this everywhere instead of
-- reading .kind directly, so every feature classifies enemies the same way.
function SS.UnitKind(unit)
	local key = unit;
	if ( type(unit) == "table" ) then key = unit.id; end
	if ( key ~= nil and type(AZS_UnitKind) == "function" ) then
		local ok, kind = SS.Safe(AZS_UnitKind, key);
		if ( ok and type(kind) == "string" and kind ~= "" ) then return string.lower(kind); end
	end
	if ( type(unit) == "table" ) then
		if ( unit.final ) then return "final"; end
		if ( type(unit.kind) == "string" ) then return string.lower(unit.kind); end
	end
	return nil;
end
local UnitKind = SS.UnitKind;

function SS.DB()
	if ( type(SlimSuiteDB) ~= "table" ) then SlimSuiteDB = {}; end
	local d = SlimSuiteDB;
	if ( d.hideLevel == nil ) then d.hideLevel = true; end
 if ( d.hideNewSpells == nil ) then d.hideNewSpells = d.hideLevel; end
	if ( d.hideRP == nil ) then d.hideRP = false; end
	if ( d.hideRacialInfo == nil ) then d.hideRacialInfo = false; end
	if ( d.hideOpeningLine == nil ) then d.hideOpeningLine = false; end
	if ( d.hideLairLine == nil ) then d.hideLairLine = false; end
	if ( d.showGuardianFlag == nil ) then
		d.showGuardianFlag = true;
		if ( type(AZS_IsHudShown) == "function" ) then
			local ok, shown = SS.Safe(AZS_IsHudShown, "flag");
			if ( ok and shown ~= nil ) then d.showGuardianFlag = shown and true or false; end
		end
	end
	for _,key in ipairs({'replaceClock','replaceEncounters','replaceTally','replaceBanners'}) do if d[key]==nil then d[key]=false;end end
	if ( d.camera == nil ) then d.camera = true; end
	if ( d.plainBar == nil ) then d.plainBar = false; end
	if ( d.cooldowns == nil ) then d.cooldowns = false; end
	d.box, d.bloat, d.x, d.y, d.helloOnStart = nil, nil, nil, nil, nil;          -- the retired Say & Party box and "Remove bloat"
	if ( d.bossMarks == nil ) then d.bossMarks = true; end
	if ( d.deathMarks == nil ) then d.deathMarks = true; end
	if ( d.prePullMarks == nil ) then d.prePullMarks = false; end
	if ( d.encounterDebuffs == nil ) then d.encounterDebuffs = true; end
	-- Slim Suite stays under the game's level-up and new-item cards unless the player turns this on. An early
	-- test build had it on by default; this switches it off once for anyone who got that default.
	if ( (tonumber(d.onTopDefaultVersion) or 0) < 1 ) then d.onTopOfScreens = false; d.onTopDefaultVersion = 1; end
	if ( d.onTopOfScreens == nil ) then d.onTopOfScreens = false; end
	if ( d.replaceRevive == nil ) then d.replaceRevive = false; end
	if ( d.procMeter == nil ) then d.procMeter = false; end
	if ( d.combatTextBox == nil ) then d.combatTextBox = false; end
	if ( d.minimapCaches == nil ) then d.minimapCaches = false; end
	if ( d.minimapBosses == nil ) then d.minimapBosses = false; end
	if ( d.minimapLairs == nil ) then d.minimapLairs = false; end
	if ( d.zoneLine == nil ) then d.zoneLine = true; end
	if ( d.replaceLocalClock == nil ) then d.replaceLocalClock = false; end
	if ( d.clockDetached == nil ) then d.clockDetached = false; end
	if ( d.combineTarget == nil ) then d.combineTarget = false; end
	if ( d.gatherButtons == nil ) then d.gatherButtons = false; end
	if ( d.gatherSide == nil ) then d.gatherSide = "left"; end
	if ( d.newFrames == nil ) then d.newFrames = false; end
	if ( d.partyIncludesSelf == nil ) then d.partyIncludesSelf = false; end
	d.partyMeter = nil;                                     -- the party meter is now the damage meter's Party tab
	if ( d.floatingText == nil ) then d.floatingText = false; end
	if ( d.deathSound == nil ) then d.deathSound = false; end
	if ( d.hideTarget == nil ) then d.hideTarget = false; end
	if ( d.mirrorTarget == nil ) then d.mirrorTarget = false; end
	if ( d.mirrorSameScale == nil ) then d.mirrorSameScale = true; end
	if ( d.buffsOnTarget == nil ) then d.buffsOnTarget = false; end
	if ( d.buffsOnTargetSide ~= "above" ) then d.buffsOnTargetSide = "below"; end
	if ( d.buffsOnPlayer == nil ) then d.buffsOnPlayer = false; end
	if ( not d.buffsPlayerAboveDefault ) then d.buffsOnPlayerSide = "above"; d.buffsPlayerAboveDefault = true; end   -- buffs sit above by default
	if ( d.partyLocked == nil ) then d.partyLocked = false; end
	if ( d.partyCompact == nil ) then d.partyCompact = false; end
	if ( d.partyFaces == nil ) then d.partyFaces = true; end
	if ( d.targetDebuffs == nil ) then d.targetDebuffs = true; end
	if ( d.moveLevelButton == nil ) then d.moveLevelButton = false; end
	if ( d.moveMeter == nil ) then d.moveMeter = false; end
	if ( d.showRacialAbility == nil ) then d.showRacialAbility = false; end
	if ( type(d.places) ~= "table" ) then d.places = {}; end
	if ( type(d.sizes) ~= "table" ) then d.sizes = {}; end
	if ( type(d.scales) ~= "table" ) then d.scales = {}; end
	if ( type(d.muted) ~= "table" ) then d.muted = {}; end
	if ( type(d.padding) ~= "table" ) then d.padding = {}; end
	if ( type(d.orientations) ~= "table" ) then d.orientations = {}; end
	if ( d.buffGrowthDirection ~= "up" and d.buffGrowthDirection ~= "down" ) then d.buffGrowthDirection = "down"; end
	if ( d.buffCustomLayout == nil ) then d.buffCustomLayout = d.orientations.BuffFrame == "vertical"; end
	if ( type(d.sizeMenuPosition) ~= "table" ) then d.sizeMenuPosition = {}; end
	if ( type(d.lockPanelPosition) ~= "table" ) then d.lockPanelPosition = {}; end
	if ( type(d.gridDivisions) ~= "number" ) then d.gridDivisions = tonumber(d.gridSpacing) or 128; end
	if ( not d.gridHalved ) then d.gridDivisions = (d.gridDivisions or 128) / 2; d.gridHalved = true; end   -- grid sizes were halved in v1.02
	if ( d.gridDivisions ~= 16 and d.gridDivisions ~= 32 and d.gridDivisions ~= 64 and d.gridDivisions ~= 128 ) then d.gridDivisions = 64; end
	d.gridSpacing = nil;
	if ( d.showEditGrid == nil ) then d.showEditGrid = false; end
	if ( not d.gridOffDefault ) then d.showEditGrid = false; d.mirrorTarget = false; d.gridOffDefault = true; end
	if ( d.gridCenterVertical == nil ) then d.gridCenterVertical = true; end
	if ( d.gridCenterHorizontal == nil ) then d.gridCenterHorizontal = true; end
	d.startUnlocked = nil;                                  -- the retired "Open UI modifier at startup": the UI always starts locked
	if ( d.tallyVertical == nil ) then d.tallyVertical = false; end
	if ( d.tallyBossKills == nil ) then d.tallyBossKills = true; end
	if ( d.tallyBackground == nil ) then d.tallyBackground = true; end
	if ( d.showEmptyActionSlots == nil ) then d.showEmptyActionSlots = false; end
	if ( d.buildRowsAttached == nil ) then d.buildRowsAttached = true; end
	if ( d.replaceBuildRows == nil ) then d.replaceBuildRows = false; end
	if ( type(d.itemRowEquipped) ~= "table" ) then d.itemRowEquipped = {}; end
	if ( type(d.itemRowSeen) ~= "table" ) then d.itemRowSeen = {}; end
	if ( type(d.itemRowCounter) ~= "number" ) then d.itemRowCounter = 0; end
	if ( type(d.chatOffsets) ~= "table" ) then d.chatOffsets = {}; end
	if ( d.anchorSnap == nil ) then d.anchorSnap = false; end
	if ( type(d.words) ~= "table" ) then d.words = {}; end
	-- Older versions enabled several replacement controls as defaults. This one-time migration
	-- returns those defaults to the native game UI while keeping saved positions and sizes intact.
	if ( (tonumber(d.uiDefaultsVersion) or 0) < 1 ) then
		d.replaceClock, d.replaceEncounters, d.replaceTally, d.replaceBanners = false, false, false, false;
		d.moveLevelButton, d.moveMeter, d.replaceBuildRows = false, false, false;
		d.showRacialAbility, d.cooldowns = false, false;
		d.uiDefaultsVersion = 1;
	end
	return d;
end

-- Keep chat-only helpers in their own lexical scope. The WoW 1.12 Lua runtime allows at
-- most 200 active locals in the addon chunk; the UI and mover code below needs that budget.
local HookChat;
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

function SS.LearnLine(low)
	for _, g in ipairs({ "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S", "ERR_LEARN_RECIPE_S" }) do
		local own = SS.Prefix(getglobal(g));
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
	if ( not GetSpellBookItemInfo ) then return nil; end
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
		local roleplayKind = type(banner) == "table" and
			(banner.kind == "boss" or banner.kind == "finalboss" or banner.kind == "bossdown" or banner.kind == "guardian");
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
		if ( SS.Hidden(msg) ) then return; end
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
			if ( type(arg1) == "string" and e and string.find(e, "^CHAT_MSG_") and SS.Hidden(arg1, e) ) then return; end
			local previousEvent, previousPlayerGuard = CHAT_FILTER.activeEvent, CHAT_FILTER.allowPlayers;
			CHAT_FILTER.activeEvent = e;
			CHAT_FILTER.allowPlayers = CHAT_FILTER.playerEvents[e] and true or false;
			local ok, result = SS.Safe(orig, ev);
			CHAT_FILTER.activeEvent, CHAT_FILTER.allowPlayers = previousEvent, previousPlayerGuard;
			if ( not ok ) then error(result); end
			return result;
		end;
	end
end;
end -- scoped chat filter helpers

-- ---------------------------------------------------------------- the camera at its farthest: 50
-- The game's Max Camera Distance slider is cameraDistanceMaxFactor, a factor of cameraDistanceMax (15 yards): its
-- top, 3.33, is 50 yards. Slim Suite sets it to 50 yards when the game starts (and zooms out to it once); turned off
-- in /slimsuite, the game's own setting stays.
local MAX_CAMERA = 50;

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
	if ( zoomOut and CameraZoomOut ) then SS.Safe(CameraZoomOut, MAX_CAMERA); end
end

function SS.ApplyGuardianFlag()
	if ( type(AZS_SetHudShown) == "function" ) then
		SS.Safe(AZS_SetHudShown, "flag", SS.DB().showGuardianFlag and true or false);
	end
end

-- ---------------------------------------------------------------- the death sound
-- Boss, guardian and downed-friend markers live in SlimSuiteWorld.lua. They draw their own markers through the
-- game's world-anchor API and never change your target.
local DEATH_SOUND = "Interface\\AddOns\\SlimSuite\\Baby Crying.mp3";
function SS.PlayDeathSound()
	if ( not SS.DB().deathSound or not PlaySoundFile ) then return; end
	SS.Safe(PlaySoundFile, DEATH_SOUND);
end
SS.PlayDeathSound = SS.PlayDeathSound;
SS.DB = SS.DB;

local deathSoundFrame = CreateFrame("Frame");
deathSoundFrame:RegisterEvent("PLAYER_DEAD");
deathSoundFrame:SetScript("OnEvent", function() SS.PlayDeathSound(); end);


-- ---------------------------------------------------------------- moving the UI, and the target frame
-- Unlocked, each of these frames gets a handle over it (its name on a green panel): drag the handle and the frame
-- follows. The current lock state and every moved position are retained in SavedVariables across /reload.
local MOVABLE = { { "PlayerFrame", "Player" }, { "TargetFrame", "Target" }, { "PartyMemberFrame1", "Party" },
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
                  { "SlimSuiteCombatTextFrame", "Combat text (test)" },
                  { "SlimSuiteLocalClockFrame", "Local clock" },
                  { "SlimSuitePlayerCard", "Player (new style)" }, { "SlimSuiteTargetCard", "Target (new style)" } };
local handles = {};
local handleList = {};
local editOnly;
local setupActive;                                       -- the first-time setup is walking through the UI
local win;                                               -- the settings window (made the first time it opens)
function SS.IsEditing(name)
 return SS.DB().unlocked and (not editOnly or editOnly == name);
end
SS.IsEditing = SS.IsEditing;
local baseSizes = {};
local basePoints = {};
local mutedBaseAlphas = {};
local mutedBaseMouse = {};
-- Forward declarations are required because placement and the update ticker are
-- defined before the implementations later in this file.
local VisualInsets;
local RootBounds, SetRootPosition, RootFactor;
local ApplyFeatureMute;
local ApplyMovableOrientation;
local CaptureActionBarLayout;
local sizeMenu, sizeMenuText, sizeMenuWidth, sizeMenuHeight, sizeMenuScale, sizeMenuScaleInput, sizeMenuPadding;
local editGrid, editGridLines = nil, {};
local sizeTarget;
local lockPanel;
local ShowEditGrid;
local PlaceAll, ApplyActionSlotGrid;
local SetAnchorSnap;
local xpBarDetached = false;
local buffButtonOriginalPoints = {};
local buffLayoutApplying = false;
local actionSlotsGridApplied = false;
local tallyFrame;
local tallyNativeWasShown;
local tallyNativeOverridden = false;
local meterFrame;
local meterNativeWasShown;
local meterNativeOverridden = false;
local UpdateMeter;
local clockFrame;
local clockNativeWasShown;
local clockNativeOverridden = false;
local levelButton;
local levelNativeWasShown;
local levelNativeOverridden = false;
local bossFrame;
local bossNativeWasShown;
local bossNativeOverridden = false;
local bannerNativeWasShown;
local bannerNativeOverridden = false;
local announcementFrame;
local announcementStarted;
local announcementDuration = 10;
local announcementFade = 0.6;
local lastBannerId;
local encounterRows = {};
local actionBarOriginal;
local itemRow;
local itemRowButtons = {};
local spellRow;
local spellRowButtons = {};
local buildNativeWasShown;
local buildNativeOverridden = false;

-- The item deck reads the five real 1.12 jewelry equipment slots. The inventory API supplies
-- the currently worn icon and tooltip. API slot IDs are 1-based; ammo is slot 0.
local ITEM_EQUIP_SLOTS = { 2, 11, 12, 13, 14 };
function SS.ItemTextureKey(texture)
	if ( type(texture) ~= "string" ) then return nil; end
	return string.gsub(texture, "^Interface.Icons.", "");
end

-- The game's own build cluster (measured from its default UI): 28-pixel icons with a 1-pixel silver border,
-- spells in one row and the worn jewelry 8 pixels below it, both starting at the same left edge.
local BUILD = { ICON = 28, GAP = 4, ROW_GAP = 8 };

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
function SS.BuildRowDefaultPlace(name)
	local x, y = UIParent:GetWidth() * 0.275, UIParent:GetHeight() * 0.35;
	if ( name == "SlimSuiteItemRowFrame" ) then
		if ( SS.DB().buildRowsAttached ) then
			return { relative = "SlimSuiteSpellRowFrame", point = "TOPLEFT", relativePoint = "BOTTOMLEFT", dx = 0, dy = -BUILD.ROW_GAP };
		end
		return { x = x, y = y - 40, coordinateSpace = "uiParent" };
	end
	return { x = x, y = y, coordinateSpace = "uiParent" };
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
			                   knownName = SlimSuiteItemCatalog and SlimSuiteItemCatalog[SS.ItemTextureKey(texture)] or nil };
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
				if ( SS.IsEditing("SlimSuiteItemRowFrame") ) then button:Show(); else button:Hide(); end
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
			if ( GameTooltip.SetInventoryItem ) then GameTooltip:SetInventoryItem("player", this.slot);
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
		if ( iconLoaded or SS.IsEditing("SlimSuiteSpellRowFrame") ) then button:Show(); else button:Hide(); end
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
			if ( this.spellBookSlot and GameTooltip.SetSpellBookItem ) then GameTooltip:SetSpellBookItem(this.spellBookSlot, BOOKTYPE_SPELL or "spell");
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

function SS.SetNativeBuildHidden(on)
	if ( type(AZS_SetHudShown) ~= "function" ) then return; end
	if ( on ) then
		local shown = true;
		if ( type(AZS_IsHudShown) == "function" ) then
			local ok, value = SS.Safe(AZS_IsHudShown, "build");
			if ( ok and value ~= nil ) then
				if ( type(value) == "number" ) then shown = value ~= 0;
				elseif ( type(value) == "string" ) then shown = value ~= "0" and string.lower(value) ~= "false";
				else shown = value and true or false; end
			end
		end
		buildNativeWasShown = shown;
		if ( shown ) then
			SS.DB().buildNativeOriginal = shown;
			local ok = SS.Safe(AZS_SetHudShown, "build", false);
			buildNativeOverridden = ok and true or false;
		end
	elseif ( buildNativeOverridden or type(SS.DB().buildNativeOriginal) == "boolean" ) then
		local restore = SS.DB().buildNativeOriginal;
		if ( type(restore) ~= "boolean" ) then restore = buildNativeWasShown; end
		local ok = SS.Safe(AZS_SetHudShown, "build", restore);
		if ( ok ) then buildNativeOverridden = false; SS.DB().buildNativeOriginal = nil; end
	end
end

function SS.ApplyBuildRowReplacement()
	local enabled = SS.DB().replaceBuildRows;
	SS.SetNativeBuildHidden(enabled);
	if ( spellRow ) then if ( enabled ) then spellRow:Show(); else spellRow:Hide(); end end
	if ( itemRow ) then if ( enabled ) then itemRow:Show(); else itemRow:Hide(); end end
end
SS.ApplyBuildRowReplacement();

local itemRowEvents = CreateFrame("Frame");
itemRowEvents:RegisterEvent("UNIT_INVENTORY_CHANGED");
itemRowEvents:RegisterEvent("PLAYER_ENTERING_WORLD");
itemRowEvents:SetScript("OnEvent", function()
	if ( event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" ) then return; end
	SS.Safe(SS.RefreshItemRow);
end);
-- Some game gear changes are applied by the run rather than a bag click. Poll the five jewelry
-- equipment slots as a fallback so the item deck updates even if that transition omits the event.
SS.Every("itemRowPoll", 0.5, function() SS.Safe(SS.RefreshSpellRow); SS.Safe(SS.ApplyBuildRowReplacement); end);

local spellRowEvents = CreateFrame("Frame");
spellRowEvents:RegisterEvent("PLAYER_ENTERING_WORLD");
spellRowEvents:RegisterEvent("ACTIONBAR_SLOT_CHANGED");
spellRowEvents:RegisterEvent("ACTIONBAR_PAGE_CHANGED");
spellRowEvents:RegisterEvent("CHAT_MSG_ADDON");
spellRowEvents:SetScript("OnEvent", function()
	if ( event == "CHAT_MSG_ADDON" and arg1 ~= "AZSSPELLS" ) then return; end
	SS.Safe(SS.RefreshSpellRow);
	SS.Safe(SS.ApplyBuildRowReplacement);
end);

function SS.SetNativeTallyHidden(on)
	if ( type(AZS_SetHudShown) ~= "function" or tallyNativeWasShown ~= true ) then return; end
	if ( on ) then
		local shown = true;
		if ( type(AZS_IsHudShown) == "function" ) then
			local ok, value = SS.Safe(AZS_IsHudShown, "tally");
			if ( ok and value ~= nil ) then shown = value and true or false; end
		end
		if ( shown ) then
			SS.DB().tallyNativeOriginal = tallyNativeWasShown;
			SS.Safe(AZS_SetHudShown, "tally", false);
			tallyNativeOverridden = true;
		end
	elseif ( tallyNativeOverridden ) then
		SS.Safe(AZS_SetHudShown, "tally", tallyNativeWasShown);
		tallyNativeOverridden = false;
		SS.DB().tallyNativeOriginal = nil;
	end
end

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
local TALLY = { LABEL = { 0.69, 0.63, 0.47 }, VALUE = { 0.97, 0.82, 0.41 }, FONT_SIZE = 15, WORD_GAP = 6, PART_GAP = 16, LINE = 19 };

function SS.TallyValue(value)
	if ( type(value) ~= "number" ) then return "-"; end
	return tostring(math.floor(value));
end

function SS.TallyParts(run)
	local parts = { { "Kills", SS.TallyValue(run and run.kills) } };
	if ( SS.DB().tallyBossKills ) then
		local bosses, guardians;
		if ( run and SlimSuiteWorld and SlimSuiteWorld.RunKills ) then bosses, guardians = SlimSuiteWorld.RunKills(); end
		table.insert(parts, { "Bosses", SS.TallyValue(bosses) });
		table.insert(parts, { "Guardians", SS.TallyValue(guardians) });
	end
	table.insert(parts, { "Gold", SS.TallyValue(run and run.gold) });
	table.insert(parts, { "cache", SS.TallyValue(run and run.chest), true });   -- the game draws all of it in gold
	return parts;
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
	local x, widest, n = pad, 0, table.getn(parts);
	for i = 1, n do
		local label, value = SS.TallyString(tallyFrame.labels, i), SS.TallyString(tallyFrame.values, i, vertical and "RIGHT" or "LEFT");
		label:SetText(parts[i][1]); value:SetText(parts[i][2]);
		local c = parts[i][3] and TALLY.VALUE or TALLY.LABEL;
		label:SetTextColor(c[1], c[2], c[3]); value:SetTextColor(TALLY.VALUE[1], TALLY.VALUE[2], TALLY.VALUE[3]);
		widest = math.max(widest, (label:GetStringWidth() or 0) + TALLY.WORD_GAP + (value:GetStringWidth() or 0));
		label:Show(); value:Show();
	end
	for i = n + 1, table.getn(tallyFrame.labels) do tallyFrame.labels[i]:Hide(); tallyFrame.values[i]:Hide(); end
	local custom = SS.DB().sizes.SlimSuiteTallyFrame;
	local width, height;
	if ( vertical ) then
		width, height = widest + pad * 2, n * TALLY.LINE + 12;
	else
		for i = 1, n do x = x + (tallyFrame.labels[i]:GetStringWidth() or 0) + TALLY.WORD_GAP + (tallyFrame.values[i]:GetStringWidth() or 0) + TALLY.PART_GAP; end
		width, height = x - TALLY.PART_GAP + pad, 30;
	end
	-- a size set in the resize menu is kept as a minimum; the band always fits its text
	if ( type(custom) == "table" ) then width, height = math.max(width, custom.w or 0), math.max(height, custom.h or 0); end
	tallyFrame:SetWidth(width); tallyFrame:SetHeight(height);
	x = pad;
	for i = 1, n do
		local label, value = tallyFrame.labels[i], tallyFrame.values[i];
		label:ClearAllPoints(); value:ClearAllPoints();
		if ( vertical ) then
			local y = -6 - (i - 1) * TALLY.LINE;
			label:SetPoint("TOPLEFT", tallyFrame, "TOPLEFT", pad, y);
			value:SetPoint("TOPRIGHT", tallyFrame, "TOPRIGHT", -pad, y);
		else
			label:SetPoint("LEFT", tallyFrame, "LEFT", x, 0);
			x = x + (label:GetStringWidth() or 0) + TALLY.WORD_GAP;
			value:SetPoint("LEFT", tallyFrame, "LEFT", x, 0);
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
 if not SS.DB().replaceTally then if tallyFrame then tallyFrame:Hide();end;SS.SetNativeTallyHidden(false);return;end
	if ( not tallyFrame ) then return; end
	local phase = type(AZS_GetPhase) == "function" and AZS_GetPhase() or nil;
	local active = phase and phase ~= "ready";
	local run = type(AZS_RUN) == "table" and AZS_RUN or nil;
	if ( active and run ) then
		SS.DrawTally(SS.TallyParts(run));
		tallyFrame:Show();
		SS.SetNativeTallyHidden(true);
	elseif ( SS.IsEditing("SlimSuiteTallyFrame") ) then
		SS.DrawTally(SS.TallyParts(nil));
		tallyFrame:Show();
		SS.SetNativeTallyHidden(false);
	else
		tallyFrame:Hide();
		SS.SetNativeTallyHidden(false);
	end
end

function SS.CreateTallyFrame()
	tallyFrame = CreateFrame("Frame", "SlimSuiteTallyFrame", UIParent);
	tallyFrame:SetWidth(252);
	tallyFrame:SetHeight(28);
	tallyFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 12, 24);
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
	local savedOriginal = SS.DB().tallyNativeOriginal;
	if ( savedOriginal ~= nil ) then
		tallyNativeWasShown = savedOriginal and true or false;
		if ( type(AZS_SetHudShown) == "function" ) then SS.Safe(AZS_SetHudShown, "tally", tallyNativeWasShown); end
		SS.DB().tallyNativeOriginal = nil;
	else
		local shown;
		if ( type(AZS_IsHudShown) == "function" ) then
			local ok, value = SS.Safe(AZS_IsHudShown, "tally");
			if ( ok and value ~= nil ) then shown = value and true or false; end
		end
		if ( shown == nil and GetCVar ) then shown = GetCVar("hudTally") ~= "0"; end
		if ( shown == nil ) then shown = true; end
		tallyNativeWasShown = shown;
	end
	tallyFrame:Hide();
end

SS.CreateTallyFrame();

function SS.SetNativeMeterHidden(on)
	if ( type(AZS_SetHudShown) ~= "function" ) then return; end
	if ( on ) then
		local shown = true;
		if ( type(AZS_IsHudShown) == "function" ) then
			local ok, value = SS.Safe(AZS_IsHudShown, "meter");
			if ( ok and value ~= nil ) then shown = value and true or false; end
		end
		if ( shown ) then
			SS.DB().meterNativeOriginal = shown;
			local ok = SS.Safe(AZS_SetHudShown, "meter", false);
			meterNativeOverridden = ok and true or false;
		end
	elseif ( meterNativeOverridden ) then
		local restore = SS.DB().meterNativeOriginal;
		if ( type(restore) ~= "boolean" ) then restore = meterNativeWasShown; end
		local ok = SS.Safe(AZS_SetHudShown, "meter", restore);
		if ( ok ) then meterNativeOverridden = false; SS.DB().meterNativeOriginal = nil; end
	end
end

function SS.MeterNumber(value)
	if ( type(value) ~= "number" ) then return "0"; end
	if ( value >= 1000000 ) then return string.format("%.1fm", value / 1000000); end
	if ( value >= 10000 ) then return string.format("%.1fk", value / 1000); end
	return tostring(math.floor(value + 0.5));
end

function SS.CreateMeterFrame()
	meterFrame = CreateFrame("Frame", "SlimSuiteMeterFrame", UIParent);
	meterFrame:SetWidth(250); meterFrame:SetHeight(180);
	meterFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -8, 44);
	meterFrame:SetFrameStrata("HIGH");
	meterFrame:EnableMouse(false);
	SlimSuiteMeter.Attach(meterFrame);
	local savedOriginal = SS.DB().meterNativeOriginal;
	if ( savedOriginal ~= nil ) then
		meterNativeWasShown = savedOriginal and true or false;
		if ( type(AZS_SetHudShown) == "function" ) then SS.Safe(AZS_SetHudShown, "meter", meterNativeWasShown); end
		SS.DB().meterNativeOriginal = nil;
	else
		local shown;
		if ( type(AZS_IsHudShown) == "function" ) then
			local ok, value = SS.Safe(AZS_IsHudShown, "meter");
			if ( ok and value ~= nil ) then shown = value and true or false; end
		end
		if ( shown == nil and GetCVar ) then shown = GetCVar("hudMeter") ~= "0"; end
		if ( shown == nil ) then shown = true; end
		meterNativeWasShown = shown;
	end
	meterFrame:Hide();
end

SS.CreateMeterFrame();

UpdateMeter = function()
	if ( not meterFrame ) then return; end
	local phase = type(AZS_GetPhase) == "function" and AZS_GetPhase() or nil;
	local active = phase and phase ~= "ready";
	local editing = SS.IsEditing("SlimSuiteMeterFrame") and SS.DB().moveMeter;
	if ( not SS.DB().moveMeter ) then
		meterFrame:Hide(); SS.SetNativeMeterHidden(false); return;
	end
	-- Shown before a run too, like the game's own meter (it reads "No damage yet." until the run starts).
	-- closed with its "x": hidden for the rest of this run (the game's meter stays hidden too)
	if ( not editing and SlimSuiteMeter.IsClosed and SlimSuiteMeter.IsClosed() ) then
		meterFrame:Hide(); SS.SetNativeMeterHidden(true); return;
	end
	SS.SetNativeMeterHidden(true);
	meterFrame:Show();
	SlimSuiteMeter.Draw(active, editing);
end

SS.Every("meterPoll", 0.35, function() SS.Safe(UpdateMeter); end);

function SS.SetNativeClockHidden(on)
	if ( type(AZS_SetHudShown) ~= "function" or clockNativeWasShown ~= true ) then return; end
	if ( on ) then
		local shown = true;
		if ( type(AZS_IsHudShown) == "function" ) then
			local ok, value = SS.Safe(AZS_IsHudShown, "clock");
			if ( ok and value ~= nil ) then shown = value and true or false; end
		end
		if ( shown ) then
			SS.DB().clockNativeOriginal = clockNativeWasShown;
			SS.Safe(AZS_SetHudShown, "clock", false);
			clockNativeOverridden = true;
		end
	elseif ( clockNativeOverridden ) then
		SS.Safe(AZS_SetHudShown, "clock", clockNativeWasShown);
		clockNativeOverridden = false;
		SS.DB().clockNativeOriginal = nil;
	end
end

function SS.SetNativeBossesHidden(on)
	if ( type(AZS_SetHudShown) ~= "function" or bossNativeWasShown ~= true ) then return; end
	if ( on ) then
		local shown = true;
		if ( type(AZS_IsHudShown) == "function" ) then
			local ok, value = SS.Safe(AZS_IsHudShown, "bosses");
			if ( ok and value ~= nil ) then shown = value and true or false; end
		end
		if ( shown ) then
			SS.DB().bossNativeOriginal = bossNativeWasShown;
			SS.Safe(AZS_SetHudShown, "bosses", false);
			bossNativeOverridden = true;
		end
	elseif ( bossNativeOverridden ) then
		SS.Safe(AZS_SetHudShown, "bosses", bossNativeWasShown);
		bossNativeOverridden = false;
		SS.DB().bossNativeOriginal = nil;
	end
end

function SS.SetNativeBannersHidden(on)
	if ( type(AZS_SetHudShown) ~= "function" or bannerNativeWasShown ~= true ) then return; end
	if ( on ) then
		local shown = true;
		if ( type(AZS_IsHudShown) == "function" ) then
			local ok, value = SS.Safe(AZS_IsHudShown, "banners");
			if ( ok and value ~= nil ) then shown = value and true or false; end
		end
		if ( shown ) then
			SS.DB().bannerNativeOriginal = bannerNativeWasShown;
			SS.Safe(AZS_SetHudShown, "banners", false);
			bannerNativeOverridden = true;
		end
	elseif ( bannerNativeOverridden ) then
		SS.Safe(AZS_SetHudShown, "banners", bannerNativeWasShown);
		bannerNativeOverridden = false;
		SS.DB().bannerNativeOriginal = nil;
	end
end

function SS.SetNativeLevelButtonHidden(on)
	if ( type(AZS_SetHudShown) ~= "function" or levelNativeWasShown ~= true ) then return; end
	if ( on ) then
		local shown = true;
		if ( type(AZS_IsHudShown) == "function" ) then
			local ok, value = SS.Safe(AZS_IsHudShown, "levels");
			if ( ok and value ~= nil ) then shown = value and true or false; end
		end
		if ( shown ) then
			SS.DB().levelNativeOriginal = levelNativeWasShown;
			SS.Safe(AZS_SetHudShown, "levels", false);
			levelNativeOverridden = true;
		end
	elseif ( levelNativeOverridden ) then
		SS.Safe(AZS_SetHudShown, "levels", levelNativeWasShown);
		levelNativeOverridden = false;
		SS.DB().levelNativeOriginal = nil;
	end
end

function SS.UpdateLevelButton()
	if ( not levelButton ) then return; end
	local canReplace = type(AZS_OpenStoredLevels) == "function";
	local replacing = SS.DB().moveLevelButton and canReplace;
	SS.SetNativeLevelButtonHidden(replacing);
	if ( levelButton.store ) then
		local phase = type(AZS_GetPhase) == "function" and AZS_GetPhase() or nil;
		local inRun = phase == "playing" or phase == "choosing" or phase == "paused";
		if ( replacing and type(AZS_SetStoringLevels) == "function" and (inRun or SS.IsEditing("SlimSuiteStoredLevelsButton")) ) then
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
	levelButton.level:SetText("LEVEL " .. (level and tostring(level) or ""));
	levelButton.count:SetText(count > 0 and tostring(count) or "");
	-- The game's stored-level count is the availability signal. Do not preview this button before a point is spendable.
	if ( count > 0 ) then levelButton:Show(); else levelButton:Hide(); end
end

-- AZS_SetHudShown stores native HUD visibility in the game's saved interface settings. Restore
-- every value this addon temporarily changed before a clean logout/reload, so disabling Slim Suite
-- in the AddOns screen cannot leave the game's own controls hidden on the next launch. The saved
-- originals are also kept until this point so a reload can restore them before this addon hides
-- the native controls again.
function SS.RestoreNativeHudOnLogout()
	if ( type(AZS_SetHudShown) ~= "function" ) then return; end
	local d = SS.DB();
	local restore = {
		{ "build", "buildNativeOriginal" },
		{ "revive", "reviveNativeOriginal" },
		{ "localClock", "localClockNativeOriginal" },
		{ "tally", "tallyNativeOriginal" },
		{ "meter", "meterNativeOriginal" },
		{ "clock", "clockNativeOriginal" },
		{ "bosses", "bossNativeOriginal" },
		{ "banners", "bannerNativeOriginal" },
		{ "levels", "levelNativeOriginal" }
	};
	for i = 1, table.getn(restore) do
		local part, key = restore[i][1], restore[i][2];
		if ( type(d[key]) == "boolean" ) then
			local ok = SS.Safe(AZS_SetHudShown, part, d[key]);
			if ( ok ) then d[key] = nil; end
		end
	end
end

-- The Create* functions below run while this file loads, before WoW has loaded SlimSuiteDB, so they
-- never see an original saved by a session that crashed. Once the saved settings are in, put back any
-- native HUD element that session left hidden and remember it as the original state.
function SS.RestoreNativeHudAfterLoad()
	if ( type(AZS_SetHudShown) ~= "function" ) then return; end
	local d = SS.DB();
	local keys = { "build", "buildNativeOriginal", "tally", "tallyNativeOriginal", "meter", "meterNativeOriginal",
		"clock", "clockNativeOriginal", "bosses", "bossNativeOriginal", "banners", "bannerNativeOriginal",
		"levels", "levelNativeOriginal", "revive", "reviveNativeOriginal", "localClock", "localClockNativeOriginal" };
	for i = 1, table.getn(keys), 2 do
		local part, key = keys[i], keys[i + 1];
		local original = d[key];
		if ( type(original) == "boolean" and SS.Safe(AZS_SetHudShown, part, original) ) then
			d[key] = nil;
			if ( part == "build" ) then buildNativeWasShown = original;
			elseif ( part == "tally" ) then tallyNativeWasShown = original;
			elseif ( part == "meter" ) then meterNativeWasShown = original;
			elseif ( part == "clock" ) then clockNativeWasShown = original;
			elseif ( part == "bosses" ) then bossNativeWasShown = original;
			elseif ( part == "banners" ) then bannerNativeWasShown = original;
			elseif ( part == "levels" ) then levelNativeWasShown = original;
			elseif ( SlimSuiteWorld and SlimSuiteWorld.SetNativeOriginal ) then SlimSuiteWorld.SetNativeOriginal(part, original); end
		end
	end
end
SS.RestoreNativeHudAfterLoad = SS.RestoreNativeHudAfterLoad;

local nativeHudShutdown = CreateFrame("Frame");
nativeHudShutdown:RegisterEvent("PLAYER_LOGOUT");
nativeHudShutdown:SetScript("OnEvent", SS.RestoreNativeHudOnLogout);

-- The native Level Up control uses the class symbol from WoW's character-create atlas.
-- Keep this 1.12 mapping local because CLASS_ICON_TCOORDS is not consistently global in
-- Vanilla clients/addon environments.
local LEVEL_CLASS_ICON_COORDS = {
	WARRIOR = { 0, 0.25, 0, 0.25 },
	MAGE = { 0.25, 0.5, 0, 0.25 },
	ROGUE = { 0.5, 0.75, 0, 0.25 },
	DRUID = { 0.75, 1, 0, 0.25 },
	HUNTER = { 0, 0.25, 0.25, 0.5 },
	SHAMAN = { 0.25, 0.5, 0.25, 0.5 },
	PRIEST = { 0.5, 0.75, 0.25, 0.5 },
	WARLOCK = { 0.75, 1, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 }
};

function SS.PlayerClassIconCoords()
	if ( type(UnitClass) ~= "function" ) then return nil; end
	local localized, english = UnitClass("player");
	local key = string.upper(tostring(english or localized or ""));
	return LEVEL_CLASS_ICON_COORDS[key];
end

function SS.CreateLevelButton()
	local savedOriginal = SS.DB().levelNativeOriginal;
	if ( savedOriginal ~= nil ) then
		levelNativeWasShown = savedOriginal and true or false;
		if ( type(AZS_SetHudShown) == "function" ) then SS.Safe(AZS_SetHudShown, "levels", levelNativeWasShown); end
		SS.DB().levelNativeOriginal = nil;
	else
		local shown;
		if ( type(AZS_IsHudShown) == "function" ) then
			local ok, value = SS.Safe(AZS_IsHudShown, "levels");
			if ( ok and value ~= nil ) then shown = value and true or false; end
		end
		if ( shown == nil and GetCVar ) then shown = GetCVar("hudLevels") ~= "0"; end
		if ( shown == nil ) then shown = true; end
		levelNativeWasShown = shown;
	end
	levelButton = CreateFrame("Button", "SlimSuiteStoredLevelsButton", UIParent);
	levelButton:SetWidth(184);
	levelButton:SetHeight(58);
	levelButton:SetFrameStrata("MEDIUM");
	levelButton:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	                         tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	levelButton:SetBackdropColor(0.13, 0.055, 0.025, 0.98);
	levelButton:SetBackdropBorderColor(0.82, 0.61, 0.24, 1);
	levelButton:EnableMouse(true);
	-- Keep a faint gold halo behind the button, like the game's own level-up control.
	-- This is a region of the button itself, so it follows saved position, scale, and hover growth.
	levelButton.glow = levelButton:CreateTexture(nil, "BACKGROUND");
	levelButton.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border");
	if ( levelButton.glow.SetBlendMode ) then levelButton.glow:SetBlendMode("ADD"); end
	levelButton.glow:SetVertexColor(1, 0.72, 0.22, 0.16);
	levelButton.glow:SetPoint("CENTER", levelButton, "CENTER", 0, 0);
	levelButton.glow:SetWidth(228);
	levelButton.glow:SetHeight(82);
	levelButton.glow:SetAlpha(0.16);
	levelButton.classIcon = levelButton:CreateTexture(nil, "ARTWORK");
	levelButton.classIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes");
	levelButton.classIcon:SetPoint("LEFT", levelButton, "LEFT", 10, 0);
	levelButton.classIcon:SetWidth(40);
	levelButton.classIcon:SetHeight(40);
	local classCoords = SS.PlayerClassIconCoords();
	if ( classCoords ) then
		levelButton.classIcon:SetTexCoord(classCoords[1], classCoords[2], classCoords[3], classCoords[4]);
	else
		levelButton.classIcon:Hide();
	end
	levelButton.level = levelButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	levelButton.level:SetPoint("TOPLEFT", levelButton, "TOPLEFT", 58, -10);
	levelButton.level:SetTextColor(1, 0.78, 0.22);
	levelButton.text = levelButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	levelButton.text:SetPoint("BOTTOMLEFT", levelButton, "BOTTOMLEFT", 58, 8);
	levelButton.text:SetText("LEVEL UP!");
	levelButton:SetScript("OnClick", function()
		if ( type(AZS_OpenStoredLevels) == "function" ) then SS.Safe(AZS_OpenStoredLevels); end
	end);
	levelButton.count = levelButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	levelButton.count:SetPoint("TOPRIGHT", levelButton.classIcon, "TOPRIGHT", 7, 7);
	levelButton.count:SetTextColor(1, 0.78, 0.18);
	local function LevelButtonBaseScale()
		return type(SS.DB().scales.SlimSuiteStoredLevelsButton) == "number" and SS.DB().scales.SlimSuiteStoredLevelsButton or 1;
	end
	local function CaptureLevelButtonPoints()
		local points = {};
		for i = 1, levelButton:GetNumPoints() do
			local point, relative, relativePoint, x, y = levelButton:GetPoint(i);
			points[i] = { point, relative, relativePoint, x, y };
		end
		return points;
	end
	local function RestoreLevelButtonPoints(points)
		levelButton:ClearAllPoints();
		for i = 1, table.getn(points or {}) do
			local p = points[i]; levelButton:SetPoint(p[1], p[2], p[3], p[4], p[5]);
		end
	end
	local function GrowLevelButtonInPlace()
		-- SetScale grows from the frame's anchor, which made the button appear to slide away
		-- from its resting location. Preserve its visual center while the hover scale changes.
		if ( not levelButton.hoverPoints ) then levelButton.hoverPoints = CaptureLevelButtonPoints(); end
		local left, right, bottom, top = RootBounds(levelButton);
		if ( not left or not right or not bottom or not top ) then return; end
		local centerX, centerY = (left + right) / 2, (bottom + top) / 2;
		levelButton:SetScale(LevelButtonBaseScale() * 1.06);
		local newLeft, newRight, newBottom, newTop = RootBounds(levelButton);
		if ( newLeft and newRight and newBottom and newTop ) then
			SetRootPosition(levelButton, centerX - (newRight - newLeft) / 2, centerY - (newTop - newBottom) / 2);
		end
	end
	local function RestoreLevelButtonAfterHover()
		levelButton:SetScale(LevelButtonBaseScale());
		if ( levelButton.hoverPoints ) then
			RestoreLevelButtonPoints(levelButton.hoverPoints);
			levelButton.hoverPoints = nil;
		end
	end
	levelButton:SetScript("OnEnter", function()
		GrowLevelButtonInPlace();
		levelButton.glow:SetAlpha(0.24);
	end);
	levelButton:SetScript("OnLeave", function()
		RestoreLevelButtonAfterHover();
		levelButton.glow:SetAlpha(0.16);
	end);
	levelButton:SetScript("OnHide", function()
		RestoreLevelButtonAfterHover();
		levelButton.glow:SetAlpha(0.16);
	end);
	if ( MainMenuBar ) then levelButton:SetPoint("BOTTOMLEFT", MainMenuBar, "TOPLEFT", 0, 6);
	else levelButton:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 32, 100); end
	levelButton:Hide();
	-- A tiny toggle to the right of the button: store level-ups or take them as they come (AZS_SetStoringLevels).
	-- It is its own frame, anchored to the button, so it stays visible while the button hides at 0 stored levels
	-- (otherwise storing could be switched off but never back on).
	local store = CreateFrame("CheckButton", "SlimSuiteStoreLevelsToggle", UIParent, "UICheckButtonTemplate");
	store:SetWidth(20); store:SetHeight(20);
	store:SetPoint("LEFT", levelButton, "RIGHT", 2, 0);
	store:SetFrameStrata("MEDIUM");
	store:SetScript("OnClick", function()
		if ( type(AZS_SetStoringLevels) == "function" ) then SS.Safe(AZS_SetStoringLevels, this:GetChecked() and true or false); end
		SS.Safe(SS.UpdateLevelButton);
	end);
	store:SetScript("OnEnter", function()
		if ( not GameTooltip ) then return; end
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
		GameTooltip:AddLine("Store level-ups", 1, 0.82, 0);
		GameTooltip:AddLine(this:GetChecked() and "On: level-ups wait here until you spend them." or "Off: level-up choices open as soon as you level.", 1, 1, 1, 1);
		GameTooltip:Show();
	end);
	store:SetScript("OnLeave", function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
	store:Hide();
	levelButton.store = store;
end

function SS.ClockText(seconds)
	if ( type(seconds) ~= "number" or seconds < 0 ) then return "--:--"; end
	seconds = math.floor(seconds);
	return string.format("%02d:%02d", math.floor(seconds / 60), math.mod(seconds, 60));
end

function SS.ApplyClockLayout()
	if ( not clockFrame or not clockFrame.time or not clockFrame.next ) then return; end
	local orientation = SS.DB().orientations.SlimSuiteClockFrame;
	if ( orientation ~= "horizontal" ) then orientation = "vertical"; end
	local padding = SS.FramePadding("SlimSuiteClockFrame");
	if ( orientation == "vertical" ) then
		clockFrame.time:ClearAllPoints();
		clockFrame.time:SetPoint("TOP", clockFrame, "TOP", 0, -padding);
		clockFrame.time:SetWidth(math.max(100, clockFrame:GetWidth() - (padding * 2)));
		clockFrame.time:SetJustifyH("CENTER");
		clockFrame.next:ClearAllPoints();
		clockFrame.next:SetPoint("TOP", clockFrame.time, "BOTTOM", 0, -(2 + padding));
		clockFrame.next:SetWidth(math.max(100, clockFrame:GetWidth() - (padding * 2)));
		clockFrame.next:SetJustifyH("CENTER");
	else
		clockFrame.time:ClearAllPoints();
		clockFrame.time:SetPoint("LEFT", clockFrame, "LEFT", 4 + padding, 0);
		clockFrame.time:SetWidth(math.max(60, (clockFrame:GetWidth() - (padding * 2)) * 0.34));
		clockFrame.time:SetJustifyH("RIGHT");
		clockFrame.next:ClearAllPoints();
		clockFrame.next:SetPoint("LEFT", clockFrame.time, "RIGHT", 8 + padding, 0);
		clockFrame.next:SetPoint("RIGHT", clockFrame, "RIGHT", -(4 + padding), 0);
		clockFrame.next:SetJustifyH("LEFT");
	end
end

function SS.CreateClockFrame()
	clockFrame = CreateFrame("Frame", "SlimSuiteClockFrame", UIParent);
	clockFrame:SetWidth(220);
	clockFrame:SetHeight(54);
	clockFrame:SetPoint("TOP", UIParent, "TOP", 0, -6);
	clockFrame:SetFrameStrata("MEDIUM");
	clockFrame:EnableMouse(false);
	clockFrame.time = clockFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	clockFrame.time:SetPoint("TOP", clockFrame, "TOP", 0, 0);
	clockFrame.time:SetWidth(220);
	clockFrame.time:SetJustifyH("CENTER");
	clockFrame.time:SetTextColor(1, 0.82, 0.28);
	clockFrame.next = clockFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	clockFrame.next:SetPoint("TOP", clockFrame.time, "BOTTOM", 0, -2);
	clockFrame.next:SetWidth(220);
	clockFrame.next:SetJustifyH("CENTER");
	clockFrame.next:SetTextColor(0.74, 0.72, 0.66);
	-- The zone line (AZS_ZONE): where you are and the run's Heroic affixes, just under the clock.
	clockFrame.zone = clockFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	clockFrame.zone:SetPoint("TOP", clockFrame, "BOTTOM", 0, -1);
	clockFrame.zone:SetTextColor(0.85, 0.75, 0.55);
	-- Both lines share one parent and one movement handle; they cannot be separated while repositioning.
	SS.ApplyClockLayout();
	local savedOriginal = SS.DB().clockNativeOriginal;
	if ( savedOriginal ~= nil ) then
		clockNativeWasShown = savedOriginal and true or false;
		if ( type(AZS_SetHudShown) == "function" ) then SS.Safe(AZS_SetHudShown, "clock", clockNativeWasShown); end
		SS.DB().clockNativeOriginal = nil;
	else
		local shown;
		if ( type(AZS_IsHudShown) == "function" ) then
			local ok, value = SS.Safe(AZS_IsHudShown, "clock");
			if ( ok and value ~= nil ) then shown = value and true or false; end
		end
		if ( shown == nil and GetCVar ) then shown = GetCVar("hudClock") ~= "0"; end
		if ( shown == nil ) then shown = true; end
		clockNativeWasShown = shown;
	end
	local savedBossOriginal = SS.DB().bossNativeOriginal;
	if ( savedBossOriginal ~= nil ) then
		bossNativeWasShown = savedBossOriginal and true or false;
		if ( type(AZS_SetHudShown) == "function" ) then SS.Safe(AZS_SetHudShown, "bosses", bossNativeWasShown); end
		SS.DB().bossNativeOriginal = nil;
	else
		local shown;
		if ( type(AZS_IsHudShown) == "function" ) then
			local ok, value = SS.Safe(AZS_IsHudShown, "bosses");
			if ( ok and value ~= nil ) then shown = value and true or false; end
		end
		if ( shown == nil and GetCVar ) then shown = GetCVar("hudBosses") ~= "0"; end
		if ( shown == nil ) then shown = true; end
		bossNativeWasShown = shown;
	end
	clockFrame:Hide();
end

function SS.BossPriority(unit)
	local kind = UnitKind(unit);
	if ( kind == "final" ) then return 1; end
	if ( kind == "boss" ) then return 2; end
	if ( kind == "guardian" ) then return 3; end
	if ( kind == "elite" ) then return 4; end
	return nil;
end

function SS.EncounterVertical()
	return SS.DB().orientations.SlimSuiteBossFrames == "vertical";
end

function SS.SetGameDefaultFont(fontString, size)
	-- Slim Suite uses WoW's standard 1.12 UI typeface throughout, including custom HUD labels.
	local defaultFont = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF";
	local ok, result = SS.Safe(fontString.SetFont, fontString, defaultFont, size);
	if ( not ok or result == false ) then SS.Safe(fontString.SetFont, fontString, "Fonts\\FRIZQT__.TTF", size); end
end

function SS.EncounterList()
	-- AZS_UNITS carries live hp/hpm for bosses, guardians and elites; the game updates it before the AZSUNITS event.
	local units = type(AZS_UNITS) == "table" and AZS_UNITS or {};
	local list = {};
	for i = 1, table.getn(units) do
		local unit = units[i];
		local priority = type(unit) == "table" and SS.BossPriority(unit) or nil;
		local awake = type(unit) == "table" and (UnitKind(unit) ~= "guardian" or unit.state == 1);
		if ( priority and awake and type(unit.id) == "number" and type(unit.name) == "string"
			and type(unit.hp) == "number" and type(unit.hpm) == "number" and unit.hp > 0 and unit.hpm > 0 ) then
			table.insert(list, { id = unit.id, name = unit.name, kind = UnitKind(unit), hp = unit.hp, hpm = unit.hpm, priority = priority, order = i });
		end
	end
	table.sort(list, function(a, b)
		if ( a.priority ~= b.priority ) then return a.priority < b.priority; end
		return a.order < b.order;
	end);
	return list;
end

function SS.ClampAbsoluteFrame(name, f)
	if ( not f or SS.DB().unlocked ) then return; end
	local saved = SS.DB().places[name];
	if ( type(saved) == "table" and saved.relative ) then return; end
	local minX, minY, maxOffsetX, maxOffsetY = VisualInsets(f);
	local maxX = UIParent:GetWidth() - maxOffsetX;
	local maxY = UIParent:GetHeight() - maxOffsetY;
	local x, right, y = RootBounds(f);
	if ( x == nil and type(saved) == "table" ) then x = saved.x; end
	if ( y == nil and type(saved) == "table" ) then y = saved.y; end
	if ( type(x) ~= "number" or type(y) ~= "number" ) then return; end
	local nx = math.max(-minX, math.min(maxX, x));
	local ny = math.max(-minY, math.min(maxY, y));
	if ( nx ~= x or ny ~= y ) then
		SetRootPosition(f, nx, ny);
	end
end

function SS.EncounterRow(index)
	if ( encounterRows[index] ) then return encounterRows[index]; end
	local row = CreateFrame("Button", nil, bossFrame);
	row:SetWidth(520);
	row:SetHeight(48);
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -2);
	row.name:SetWidth(176);
	row.name:SetHeight(22);
	row.name:SetJustifyH("LEFT");
	row.name:SetJustifyV("TOP");
	row.name:SetNonSpaceWrap(true);
	SS.SetGameDefaultFont(row.name, 10);
	row.name:SetTextColor(1, 0.22, 0.16);
	row.bar = CreateFrame("StatusBar", nil, row);
	row.bar:SetWidth(176);
	row.bar:SetHeight(8);
	row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -28);
	row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
	row.bar:SetStatusBarColor(0.9, 0.06, 0.025, 1);
	row.bar:SetMinMaxValues(0, 1);
	row.bar:SetValue(1);
	row.bar.background = row.bar:CreateTexture(nil, "BACKGROUND");
	row.bar.background:SetTexture("Interface\\TargetingFrame\\UI-StatusBar");
	row.bar.background:SetAllPoints(row.bar);
	row.bar.background:SetVertexColor(0.04, 0.015, 0.01, 0.9);
	row:EnableMouse(true);
	row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square");
	row:SetScript("OnClick", function()
		local unit = this.unit;
		if ( not unit or not unit.name or not TargetByName ) then return; end
		-- The encounter API exposes stable IDs for health tracking, but the client target API
		-- selects visible units by name. Ask it for this exact name and leave range/visibility
		-- rejection to the game; never retarget a different nearby enemy as a fallback.
		SS.Safe(TargetByName, unit.name, true);
	end);
	row:SetScript("OnEnter", function()
		if ( not this.unit or not GameTooltip ) then return; end
		if ( GameTooltip.SetClampedToScreen ) then GameTooltip:SetClampedToScreen(true); end
		local center = this:GetCenter();
		local onRight = center and center * RootFactor(this) > (UIParent:GetWidth() / 2);
		GameTooltip:SetOwner(this, onRight and "ANCHOR_LEFT" or "ANCHOR_RIGHT");
		GameTooltip:AddLine(this.unit.name .. "  [" .. (this.unit.kind == "guardian" and "Guardian" or (this.unit.kind == "elite" and "Elite" or "Boss")) .. "]");
		GameTooltip:AddLine("Health: " .. tostring(math.floor(this.unit.hp)) .. " / " .. tostring(math.floor(this.unit.hpm)), 1, 0.82, 0);
		GameTooltip:AddLine("Click to target", 0.75, 0.75, 0.75);
		GameTooltip:Show();
	end);
	row:SetScript("OnLeave", function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
	encounterRows[index] = row;
	return row;
end

function SS.UpdateEncounterRows(list)
	local count = table.getn(list);
	if ( count == 0 ) then return 0; end
	local vertical = SS.EncounterVertical();
	local padding = SS.FramePadding("SlimSuiteBossFrames");
	local gap = (vertical and 10 or 8) + padding;
	local configured = SS.DB().sizes.SlimSuiteBossFrames;
	-- Match the default boss target-frame scale shown in the reference: a readable, substantial
	-- nameplate and health bar rather than a tiny floating strip. Cards still distribute evenly
	-- when several enemies are active.
	local defaultCardWidth = vertical and 48 or 520;
	local minCardWidth = vertical and 34 or 520;
	local minimumFrameWidth = count * (vertical and 18 or minCardWidth) + ((count - 1) * gap) + (padding * 2);
	local frameWidth = type(configured) == "table" and configured.w or (count * defaultCardWidth + ((count - 1) * gap) + (padding * 2));
	frameWidth = math.max(minimumFrameWidth, frameWidth);
	local cardWidth = math.max(vertical and 18 or minCardWidth, (frameWidth - (padding * 2) - ((count - 1) * gap)) / count);
	frameWidth = count * cardWidth + ((count - 1) * gap) + (padding * 2);
	local frameHeight = type(configured) == "table" and configured.h or (vertical and 252 or (count * 48));
	local minimumHeight = vertical and math.max(60, 52 + (padding * 3)) or math.max(count * 42, 42 + (padding * 2));
	frameHeight = math.max(minimumHeight, frameHeight);
	bossFrame:SetWidth(frameWidth);
	bossFrame:SetHeight(frameHeight);
	local rowHeight = vertical and math.max(58, frameHeight - (padding * 2)) or math.max(42, (frameHeight - (padding * 2)) / count);
	for i = 1, table.getn(list) do
		local unit = list[i];
		local row = SS.EncounterRow(i);
		row.unit = unit;
		row:SetWidth(cardWidth);
		row:SetHeight(rowHeight);
		row.name:ClearAllPoints();
		row.bar:ClearAllPoints();
		row:ClearAllPoints();
		row:SetPoint("TOPLEFT", bossFrame, "TOPLEFT", vertical and (padding + ((i - 1) * (cardWidth + gap))) or padding, -(padding + (vertical and 0 or ((i - 1) * rowHeight))));
		row.name:SetText(unit.name);
		if ( vertical ) then
			SS.SetGameDefaultFont(row.name, 8.5);
			local barTopOffset = 34 + padding;
			-- Match the narrow, evenly spaced columns in the reference. Each boss name stays above its own bar.
			row.name:SetWidth(cardWidth);
			row.name:SetHeight(30);
			row.name:SetPoint("TOP", row, "TOP", 0, -(2 + padding));
			if ( row.bar.SetOrientation ) then SS.Safe(row.bar.SetOrientation, row.bar, "VERTICAL"); end
			row.bar:SetWidth(math.max(10, cardWidth - (padding * 2)));
			row.bar:SetHeight(math.max(18, rowHeight - barTopOffset - padding));
			row.bar:SetPoint("TOP", row, "TOP", 0, -barTopOffset);
		else
			SS.SetGameDefaultFont(row.name, 14);
			row.name:SetWidth(cardWidth - 8 - (padding * 2));
			row.name:SetHeight(22);
			row.name:SetJustifyH("CENTER");
			row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 4 + padding, -(2 + padding));
			if ( row.bar.SetOrientation ) then SS.Safe(row.bar.SetOrientation, row.bar, "HORIZONTAL"); end
			local width = math.max(20, cardWidth - 8 - (padding * 2));
			row.bar:SetWidth(unit.kind == "guardian" and math.max(20, width * 0.78) or width);
			row.bar:SetHeight(12);
			row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 4 + padding, -(24 + padding));
		end
		-- Keep the StatusBar range small and stable. Raw boss HP can be very large, and using it as
		-- the range can hide small health changes at the UI's numeric precision; show the live fraction.
		local health = math.max(0, math.min(1, unit.hp / unit.hpm));
		row.bar:SetMinMaxValues(0, 1);
		row.bar:SetValue(health);
		if ( SlimSuiteWorld and SlimSuiteWorld.DrawDebuffs ) then
			SS.Safe(SlimSuiteWorld.DrawDebuffs, row, unit, vertical, SS.DB().encounterDebuffs);
		end
		row:Show();
	end
	for i = table.getn(list) + 1, table.getn(encounterRows) do encounterRows[i]:Hide(); end
	return frameHeight;
end

-- AZS_ZONE (0.87; affixes added in 0.124): the zone, how long it lasts, and the run's Heroic affixes as lowercase
-- English words ("sanguine,explosive"). Shown as "Zone  -  Sanguine, Explosive".
function SS.ZoneText()
	local z = type(AZS_ZONE) == "table" and AZS_ZONE or nil;
	if ( not z ) then return nil; end
	local name = z.name or z.zone or z.title;
	local affixes = z.affixes;
	local list = {};
	if ( type(affixes) == "string" ) then
		for word in string.gfind(affixes, "[^,%s]+") do table.insert(list, word); end
	elseif ( type(affixes) == "table" ) then
		for i = 1, table.getn(affixes) do if ( type(affixes[i]) == "string" ) then table.insert(list, affixes[i]); end end
	end
	for i = 1, table.getn(list) do list[i] = string.upper(string.sub(list[i], 1, 1)) .. string.sub(list[i], 2); end
	local text = type(name) == "string" and name or "";
	if ( table.getn(list) > 0 ) then text = (text ~= "" and (text .. "  -  ") or "") .. table.concat(list, ", "); end
	if ( text == "" ) then return nil; end
	return text;
end

function SS.UpdateClock()
 if not SS.DB().replaceClock then if clockFrame then clockFrame:Hide();end;SS.SetNativeClockHidden(false);return;end
	if ( not clockFrame ) then return; end
	local phase = type(AZS_GetPhase) == "function" and AZS_GetPhase() or nil;
	local live = phase == "ready" or phase == "playing" or phase == "choosing" or phase == "paused";
	-- This movable replacement must not inherit the native clock's independent HUD visibility flag.
	local showClock = live;
	local preview = SS.IsEditing("SlimSuiteClockFrame") and not showClock;
	if ( showClock ) then
		local elapsed = type(AZS_GetRunTime) == "function" and AZS_GetRunTime() or nil;
		if ( phase == "ready" and type(elapsed) ~= "number" ) then elapsed = 0; end
		clockFrame.time:SetText(SS.ClockText(elapsed));
		local upcoming = {};
		if ( type(AZS_GetUpcomingBosses) == "function" ) then
			local ok, value = SS.Safe(AZS_GetUpcomingBosses);
			if ( ok and type(value) == "table" ) then upcoming = value; end
		end
		local left = type(upcoming[1]) == "table" and upcoming[1].left or nil;
		local run = type(AZS_RUN) == "table" and AZS_RUN or nil;
		if ( type(left) ~= "number" and run and type(run.nb) == "number" and run.nb >= 0 ) then left = run.nb; end
		if ( type(left) == "number" and left >= 0 ) then
			clockFrame.next:SetText("next boss in " .. ClockText(math.ceil(left)));
		else
			clockFrame.next:SetText("next boss in --:--");
		end
		SS.SetNativeClockHidden(true);
		clockFrame.time:Show();
		clockFrame.next:Show();
	else
		SS.SetNativeClockHidden(false);
		if ( preview ) then
			clockFrame.time:SetText("00:00");
			clockFrame.next:SetText("next boss in --:--");
			clockFrame.time:Show();
			clockFrame.next:Show();
		else
			clockFrame.time:Hide();
			clockFrame.next:Hide();
		end
	end
	if ( clockFrame.zone ) then
		local zone = SS.DB().zoneLine and (SS.ZoneText() or (preview and "Scholomance  -  Sanguine, Explosive")) or nil;
		if ( zone and (showClock or preview) ) then clockFrame.zone:SetText(zone); clockFrame.zone:Show(); else clockFrame.zone:Hide(); end
	end
	if ( showClock or preview ) then
		clockFrame:Show();
		SS.ClampAbsoluteFrame("SlimSuiteClockFrame", clockFrame);
	else clockFrame:Hide(); end
end

function SS.UpdateBossFrames()
 if not SS.DB().replaceEncounters then if bossFrame then bossFrame:Hide();end;SS.SetNativeBossesHidden(false);return;end
	if ( not bossFrame ) then return; end
	local phase = type(AZS_GetPhase) == "function" and AZS_GetPhase() or nil;
	local live = phase == "playing" or phase == "choosing" or phase == "paused";
	-- The replacement is driven by the documented AZS_UNITS data, independently of whether the
	-- player had the native boss frames enabled. Visibility of the original HUD must not gate ours.
	if ( live ) then
		local list = SS.EncounterList();
		local height = SS.UpdateEncounterRows(list);
		if ( height > 0 ) then
			bossFrame:SetHeight(height);
			SS.ClampAbsoluteFrame("SlimSuiteBossFrames", bossFrame);
			SS.SetNativeBossesHidden(true);
			bossFrame:Show();
		else
			SS.SetNativeBossesHidden(false);
			bossFrame:Hide();
		end
	elseif ( SS.IsEditing("SlimSuiteBossFrames") ) then
		for i = 1, table.getn(encounterRows) do encounterRows[i]:Hide(); end
		local vertical = SS.EncounterVertical();
		local configured = SS.DB().sizes.SlimSuiteBossFrames;
		bossFrame:SetWidth(type(configured) == "table" and configured.w or (vertical and 76 or 520));
		bossFrame:SetHeight(type(configured) == "table" and configured.h or (vertical and 252 or 48));
		SS.ClampAbsoluteFrame("SlimSuiteBossFrames", bossFrame);
		SS.SetNativeBossesHidden(false);
		bossFrame:Show();
	else
		for i = 1, table.getn(encounterRows) do encounterRows[i]:Hide(); end
		SS.SetNativeBossesHidden(false);
		bossFrame:Hide();
	end
end

local encounterUpdates = CreateFrame("Frame");
encounterUpdates:RegisterEvent("CHAT_MSG_ADDON");
encounterUpdates:SetScript("OnEvent", function()
	if ( arg1 == "AZSUNITS" ) then SS.Safe(SS.UpdateBossFrames); end
end);

SS.CreateClockFrame();
bossFrame = CreateFrame("Frame", "SlimSuiteBossFrames", UIParent);
bossFrame:SetWidth(520);
bossFrame:SetHeight(48);
-- Match the game's centered encounter nameplate, with the independent run clock above it.
bossFrame:SetPoint("TOP", UIParent, "TOP", 0, -76);
bossFrame:SetFrameStrata("MEDIUM");
bossFrame:EnableMouse(false);
bossFrame:Hide();

function SS.CreateAnnouncementFrame()
	announcementFrame = CreateFrame("Frame", "SlimSuiteAnnouncementFrame", UIParent);
	local bannerWidth = math.max(280, math.min(920, UIParent:GetWidth() - 24));
	announcementFrame:SetWidth(bannerWidth);
	announcementFrame:SetHeight(60);
	announcementFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 112);
	announcementFrame:SetFrameStrata("HIGH");
	announcementFrame:EnableMouse(false);
	announcementFrame.text = announcementFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	announcementFrame.text:SetPoint("CENTER", announcementFrame, "CENTER", 0, 0);
	announcementFrame.text:SetWidth(bannerWidth - 20);
	announcementFrame.text:SetHeight(60);
	announcementFrame.text:SetJustifyH("CENTER");
	announcementFrame.text:SetJustifyV("MIDDLE");
	announcementFrame.text:SetNonSpaceWrap(true);
	SS.SetGameDefaultFont(announcementFrame.text, 22);
	announcementFrame.text:SetTextColor(0.96, 0.82, 0.52);
	local savedOriginal = SS.DB().bannerNativeOriginal;
	if ( savedOriginal ~= nil ) then
		bannerNativeWasShown = savedOriginal and true or false;
		if ( type(AZS_SetHudShown) == "function" ) then SS.Safe(AZS_SetHudShown, "banners", bannerNativeWasShown); end
		SS.DB().bannerNativeOriginal = nil;
	else
		local shown;
		if ( type(AZS_IsHudShown) == "function" ) then
			local ok, value = SS.Safe(AZS_IsHudShown, "banners");
			if ( ok and value ~= nil ) then shown = value and true or false; end
		end
		if ( shown == nil and GetCVar ) then shown = GetCVar("hudBanners") ~= "0"; end
		if ( shown == nil ) then shown = true; end
		bannerNativeWasShown = shown;
	end
	announcementFrame:Hide();
end

function SS.ShowAnnouncement(banner)
	if ( not SS.DB().replaceBanners ) then
		if ( announcementFrame ) then announcementFrame:Hide(); end
		SS.SetNativeBannersHidden(false);
		return;
	end
	if ( type(banner) ~= "table" ) then return; end
	if ( banner.id ~= nil and banner.id == lastBannerId ) then return; end
	local text = type(banner.text) == "string" and banner.text or "";
	if ( text == "" and type(AZS_BANNER) == "table" and type(AZS_BANNER.text) == "string" ) then
		text = AZS_BANNER.text;
	end
	if ( text == "" and type(banner.name) == "string" and banner.name ~= "" ) then text = banner.name; end
	if ( text == "" ) then return; end
	lastBannerId = banner.id;
	if ( bannerNativeWasShown ~= true and not SS.DB().unlocked ) then return; end
	announcementFrame.text:SetText(text);
	if ( banner.boss ) then announcementFrame.text:SetTextColor(1, 0.24, 0.13);
	else announcementFrame.text:SetTextColor(0.96, 0.82, 0.52); end
	announcementStarted = GetTime();
	announcementFrame:SetAlpha(0);
	announcementFrame:Show();
	SS.ClampAbsoluteFrame("SlimSuiteAnnouncementFrame", announcementFrame);
	SS.SetNativeBannersHidden(true);
end

function SS.UpdateAnnouncementFrame()
 if not SS.DB().replaceBanners then if announcementFrame then announcementFrame:Hide();end;SS.SetNativeBannersHidden(false);return;end
	if ( not announcementFrame ) then return; end
	local maxWidth = math.max(40, UIParent:GetWidth() - 24);
	if ( announcementFrame:GetWidth() > maxWidth ) then announcementFrame:SetWidth(maxWidth); end
	announcementFrame.text:SetWidth(math.max(40, announcementFrame:GetWidth() - 20));
	announcementFrame.text:SetHeight(announcementFrame:GetHeight());
	if ( announcementStarted ) then
		local elapsed = GetTime() - announcementStarted;
		if ( elapsed >= announcementDuration ) then
			announcementStarted = nil;
			announcementFrame:Hide();
			return;
		end
		local alpha = 1;
		if ( elapsed < announcementFade ) then alpha = elapsed / announcementFade;
		elseif ( elapsed > announcementDuration - announcementFade ) then
			alpha = (announcementDuration - elapsed) / announcementFade;
		end
		announcementFrame:SetAlpha(math.max(0, math.min(1, alpha)));
	elseif ( SS.IsEditing("SlimSuiteAnnouncementFrame") ) then
		announcementFrame.text:SetText("Hogger enters the battlefield!");
		announcementFrame.text:SetTextColor(1, 0.24, 0.13);
		announcementFrame:SetAlpha(1);
		announcementFrame:Show();
		SS.ClampAbsoluteFrame("SlimSuiteAnnouncementFrame", announcementFrame);
	else
		announcementFrame:Hide();
	end
end

SS.CreateAnnouncementFrame();
SS.Every("announcement", 0, function()
	if ( announcementStarted ) then SS.Safe(SS.UpdateAnnouncementFrame); end
end, announcementFrame);
local bannerHandler = function(banner) SS.Safe(SS.ShowAnnouncement, banner); end;
local bannerHandlerRegistered = false;
function SS.RegisterAnnouncementHandler()
	if ( bannerHandlerRegistered ) then return true; end
	if ( type(AZS_RegisterBannerHandler) ~= "function" ) then return false; end
	local ok = SS.Safe(AZS_RegisterBannerHandler, bannerHandler);
	if ( ok ) then
		bannerHandlerRegistered = true;
		if ( bannerNativeWasShown == true and SS.DB().replaceBanners ) then SS.SetNativeBannersHidden(true); end
	end
	return bannerHandlerRegistered;
end
SS.Safe(SS.RegisterAnnouncementHandler);
SS.CreateLevelButton();
SS.Safe(SS.UpdateLevelButton);
SS.Every("tally", 0.25, function()
		SS.Safe(SS.UpdateTally);
		SS.Safe(SS.UpdateClock);
		SS.Safe(SS.UpdateBossFrames);
		SS.Safe(SS.UpdateAnnouncementFrame);
		SS.Safe(SS.UpdateLevelButton);
		SS.Safe(ApplyActionSlotGrid);
		SS.Safe(SS.RefreshItemRow);
		local tooltipHandle = handles.GameTooltip;
		if ( tooltipHandle ) then
			if ( SS.IsEditing("GameTooltip") ) then tooltipHandle:Show();
			else tooltipHandle:Hide(); end
		end
		for i = 1, table.getn(MOVABLE) do
			local name = MOVABLE[i][1];
			if ( SS.DB().muted[name] ) then SS.Safe(ApplyFeatureMute, name); end
		end
end);

-- GetLeft/GetRight are in the queried frame's effective-scale units. All movement state
-- and comparisons below use UIParent units; SetPoint offsets must be converted back.
RootFactor = function(frame)
	return (frame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1);
end

RootBounds = function(frame)
	local l, r, b, t = frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop();
	if ( not l or not r or not b or not t ) then return nil; end
	local factor = RootFactor(frame);
	return l * factor, r * factor, b * factor, t * factor;
end

SetRootPosition = function(frame, x, y)
	local factor = RootFactor(frame);
	frame:ClearAllPoints();
	frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / factor, y / factor);
end

function SS.SavePlace(name, f)
	local p = SS.DB().places[name];
	if ( type(p) ~= "table" ) then p = {}; SS.DB().places[name] = p; end
	local left, right, bottom = RootBounds(f);
	p.x, p.y, p.coordinateSpace = left, bottom, "uiParent";
end
SS.SavePosition = function(name, f)
	SS.SavePlace(name, f);
	local p = SS.DB().places[name];
	if ( p ) then p.relative, p.point, p.relativePoint, p.dx, p.dy = nil, nil, nil, nil, nil; end
end

-- Resize, scale and snapped anchors can all push visible child controls past a screen edge.
-- Clamp the drawn bounds (not just the parent frame) and convert a clipped relative anchor to
-- a stable absolute location. Save the corrected place immediately so it survives /reload.
function SS.ClampToClient(name, frame)
	if ( not frame or not UIParent ) then return; end
	if ( name == "SlimSuiteItemRowFrame" and SS.DB().buildRowsAttached ) then return; end   -- the spell row is clamped for both
	local left, right, bottom = RootBounds(frame);
	if ( not left or not bottom ) then return; end
	local minX, minY, maxOffsetX, maxOffsetY = VisualInsets(frame);
	local maxX = UIParent:GetWidth() - maxOffsetX;
	local maxY = UIParent:GetHeight() - maxOffsetY;
	local x = math.max(-minX, math.min(maxX, left));
	local y = math.max(-minY, math.min(maxY, bottom));
	if ( math.abs(x - left) > 0.01 or math.abs(y - bottom) > 0.01 ) then
		SetRootPosition(frame, x, y);
		SS.SavePlace(name, frame);
		local p = SS.DB().places[name];
		p.relative, p.point, p.relativePoint, p.dx, p.dy = nil, nil, nil, nil, nil;
	end
end

function SS.ApplySize(name, f)
	local s = SS.DB().sizes[name];
	if ( name == "GameTooltip" and type(s) ~= "table" ) then
		s = { w = 260, h = 140 };
		SS.DB().sizes[name] = s;
	end
	if ( type(s) == "table" and s.w and s.h and s.w > 0 and s.h > 0 ) then
		f:SetWidth(s.w);
		f:SetHeight(s.h);
	end
	if ( name == "SlimSuiteClockFrame" ) then SS.ApplyClockLayout(); end
	if ( name == "MainMenuBar" and ApplyMovableOrientation ) then ApplyMovableOrientation(name); end
	if ( name == "SlimSuiteItemRowFrame" ) then SS.LayoutItemRow(); end
	if ( name == "SlimSuiteSpellRowFrame" ) then SS.LayoutSpellRow(); end
	local scale = SS.DB().scales[name];
	if ( type(scale) == "number" ) then
		if ( name == "PartyMemberFrame1" ) then
			for i = 1, 4 do local party = getglobal("PartyMemberFrame" .. i); if ( party and party.SetScale ) then party:SetScale(scale); end end
		elseif ( f.SetScale ) then f:SetScale(scale); end
	end
end

-- Include visible child frames in edge clamping. Some Blizzard bars draw their buttons a few
-- logical pixels outside the parent frame, so clamping only the parent's rectangle leaves a gap.
VisualInsets = function(frame)
	local baseLeft, baseRight, baseBottom = RootBounds(frame);
	if ( not baseLeft or not baseBottom ) then return 0, 0, 0, 0; end
	local uiScale = UIParent:GetEffectiveScale() or 1;
	local frameScale = frame:GetEffectiveScale() or uiScale;
	local factor = frameScale / uiScale;
	-- MainMenuExpBar's child textures retain their old horizontal extents after the native
	-- status bar is rotated. Its own bounds are the visible/movable bounds in either layout.
	if ( frame == MainMenuExpBar ) then
		return 0, 0, (frame:GetWidth() or 0) * factor, (frame:GetHeight() or 0) * factor;
	end
	if ( frame == MainMenuBar or frame == PartyMemberFrame1 or frame == BuffFrame ) then
		-- These Blizzard groups have unused parent padding or detached siblings. Clamp their
		-- actual visible controls as a group so scale cannot leave a gap or clip a companion.
		local minX, minY, maxX, maxY;
		local function Include(child)
			if ( not child or (child.IsShown and not child:IsShown()) ) then return; end
			local left, right, bottom, top = RootBounds(child);
			if ( left and right and bottom and top ) then
				local l, r, b, t = left - baseLeft, right - baseLeft, bottom - baseBottom, top - baseBottom;
				minX = minX and math.min(minX, l) or l; maxX = maxX and math.max(maxX, r) or r;
				minY = minY and math.min(minY, b) or b; maxY = maxY and math.max(maxY, t) or t;
			end
		end
		if ( frame == MainMenuBar ) then
			for i = 1, 6 do Include(getglobal("ActionButton" .. i)); end
			Include(ActionButton12);
			if ( ActionButton12 ) then Include(ActionButton12.slimRacialBorder); end
			Include(ActionBarUpButton); Include(ActionBarDownButton);
		elseif ( frame == BuffFrame ) then
			for i = 1, (MAX_PLAYER_BUFFS or 32) do Include(getglobal("BuffButton" .. i)); end
		else
			for i = 1, 4 do Include(getglobal("PartyMemberFrame" .. i)); end
		end
		if ( minX and minY and maxX and maxY ) then return minX, minY, maxX, maxY; end
	end
	local minX, minY = 0, 0;
	local maxX = (frame:GetWidth() or 0) * factor;
	local maxY = (frame:GetHeight() or 0) * factor;
	local function IncludeDescendants(parent, seen)
		if ( not parent or seen[parent] or not parent.GetChildren ) then return; end
		seen[parent] = true;
		local ok, children = SS.Safe(function() return { parent:GetChildren() }; end);
		if ( not ok or type(children) ~= "table" ) then return; end
		for i = 1, table.getn(children) do
			local child = children[i];
			if ( child and (not child.IsShown or child:IsShown()) ) then
				local got, left, right, bottom, top = pcall(function()
					return RootBounds(child);
				end);
				if ( got and left and right and bottom and top ) then
					minX = math.min(minX, left - baseLeft);
					maxX = math.max(maxX, right - baseLeft);
					minY = math.min(minY, bottom - baseBottom);
					maxY = math.max(maxY, top - baseBottom);
				end
				IncludeDescendants(child, seen);
			end
		end
	end
	IncludeDescendants(frame, {});
	if ( frame == spellRow and itemRow and SS.DB().buildRowsAttached and itemRow:IsShown() ) then
		local l, r, b, t = RootBounds(itemRow);
		if ( l and r and b and t ) then
			minX = math.min(minX, l - baseLeft); maxX = math.max(maxX, r - baseLeft);
			minY = math.min(minY, b - baseBottom); maxY = math.max(maxY, t - baseBottom);
		end
	end
	return minX, minY, maxX, maxY;
end;

function SS.CollectFeatureFrames(frame, list, seen, depth)
	if ( not frame or seen[frame] or depth > 4 ) then return; end
	seen[frame] = true;
	table.insert(list, frame);
	if ( not frame.GetChildren ) then return; end
	local ok, children = SS.Safe(function() return { frame:GetChildren() }; end);
	if ( not ok or type(children) ~= "table" ) then return; end
	for i = 1, table.getn(children) do SS.CollectFeatureFrames(children[i], list, seen, depth + 1); end
end

ApplyFeatureMute = function(name)
	local frame = getglobal(name);
	if ( not frame ) then return; end
	local list, seen = {}, {};
	SS.CollectFeatureFrames(frame, list, seen, 0);
	if ( name == "PartyMemberFrame1" ) then
		for i = 2, 4 do SS.CollectFeatureFrames(getglobal("PartyMemberFrame" .. i), list, seen, 0); end
	elseif ( name == "ChatFrame1" ) then
		SS.CollectFeatureFrames(getglobal("ChatFrame1Tab"), list, seen, 0);
		SS.CollectFeatureFrames(getglobal("ChatFrame1EditBox"), list, seen, 0);
	end
	local muted = SS.DB().muted[name] and true or false;
	for i = 1, table.getn(list) do
		local target = list[i];
		if ( target and target.GetAlpha and target.SetAlpha ) then
			if ( muted ) then
				if ( mutedBaseAlphas[target] == nil ) then
					local ok, alpha = SS.Safe(target.GetAlpha, target);
					mutedBaseAlphas[target] = ok and alpha or 1;
				end
				if ( mutedBaseMouse[target] == nil and target.IsMouseEnabled ) then
					local ok, enabled = SS.Safe(target.IsMouseEnabled, target);
					if ( ok ) then mutedBaseMouse[target] = enabled and true or false; end
				end
				SS.Safe(target.SetAlpha, target, 0);
				if ( target.EnableMouse and mutedBaseMouse[target] ~= nil ) then SS.Safe(target.EnableMouse, target, false); end
			else
				local alpha = mutedBaseAlphas[target];
				if ( alpha ~= nil ) then SS.Safe(target.SetAlpha, target, alpha); mutedBaseAlphas[target] = nil; end
				local enabled = mutedBaseMouse[target];
				if ( enabled ~= nil and target.EnableMouse ) then SS.Safe(target.EnableMouse, target, enabled); mutedBaseMouse[target] = nil; end
			end
		end
	end
	local handle = handles[name];
	if ( handle ) then
		if ( muted ) then
			handle:SetBackdropColor(0.22, 0.22, 0.24, 0.58);
			handle:SetBackdropBorderColor(0.6, 0.6, 0.62, 0.85);
			if ( handle.text and name ~= "GameTooltip" ) then handle.text:SetTextColor(0.72, 0.72, 0.74); end
		else
			handle:SetBackdropColor(0.1, 0.6, 0.1, 0.45);
			handle:SetBackdropBorderColor(0.3, 1, 0.3, 0.9);
			if ( handle.text and name ~= "GameTooltip" ) then handle.text:SetTextColor(1, 1, 1); end
		end
	end
end;

function SS.ToggleFeatureMute(name)
	SS.DB().muted[name] = not SS.DB().muted[name];
	ApplyFeatureMute(name);
	if ( sizeMenu and sizeMenu.muteButton ) then
		sizeMenu.muteButton:SetText(SS.DB().muted[name] and "Show feature" or "Hide feature");
	end
end

function SS.CurrentOrientation(name)
	local orientation = SS.DB().orientations[name];
	if ( orientation == "vertical" or orientation == "horizontal" ) then return orientation; end
	if ( name == "SlimSuiteClockFrame" ) then return "vertical"; end
	if ( name == "PartyMemberFrame1" ) then return "vertical"; end
	return "horizontal";
end

function SS.BuffGrowthDirection()
	return SS.DB().buffGrowthDirection == "up" and "up" or "down";
end

function SS.ApplyBuffOrientation()
	if ( not BuffFrame or buffLayoutApplying ) then return; end
	local orientation = SS.CurrentOrientation("BuffFrame");
	local limit = MAX_PLAYER_BUFFS or 32;
	local visible, iconW, iconH, durationW, durationH = {}, nil, nil, 0, 0;
	for i = 1, limit do
		local button = getglobal("BuffButton" .. i);
		if ( button ) then
			if ( not buffButtonOriginalPoints[i] and button.GetNumPoints ) then
				local points = {};
				for p = 1, button:GetNumPoints() do
					local a, relative, relativePoint, x, y = button:GetPoint(p);
					points[p] = { a, relative, relativePoint, x, y };
				end
				buffButtonOriginalPoints[i] = points;
			end
			if ( button:IsShown() ) then
				table.insert(visible, button);
				iconW = iconW or button:GetWidth(); iconH = iconH or button:GetHeight();
				local duration = getglobal("BuffButton" .. i .. "Duration");
				if ( duration and duration:IsShown() ) then
					local w = duration.GetStringWidth and duration:GetStringWidth() or 0;
					local h = duration.GetHeight and duration:GetHeight() or 0;
					durationW = math.max(durationW, w or 0);
					durationH = math.max(durationH, h or 0);
				end
			end
		end
	end
	if ( not iconW or not iconH or table.getn(visible) == 0 ) then return; end
	buffLayoutApplying = true;
	if ( orientation == "horizontal" and not SS.DB().buffCustomLayout ) then
		for i = 1, limit do
			local button = getglobal("BuffButton" .. i);
			local points = buffButtonOriginalPoints[i];
			if ( button and points and table.getn(points) > 0 ) then
				button:ClearAllPoints();
				for p = 1, table.getn(points) do
					local a = points[p];
					button:SetPoint(a[1], a[2], a[3], a[4], a[5]);
				end
			end
		end
		local base = baseSizes.BuffFrame;
		if ( base ) then BuffFrame:SetWidth(base.w); BuffFrame:SetHeight(base.h); end
		buffLayoutApplying = false;
		return;
	end
	-- The stock cooldown text sits below each icon. Reserve its own cell space so duration labels
	-- never collide with the next buff when the row is vertical or packed into multiple columns.
	-- Treat each icon and its cooldown text as one cell. The text's measured size is used
	-- instead of a fixed guessed gap, so long durations never collide with the next buff.
	local gap, count = 4 + SS.FramePadding("BuffFrame"), table.getn(visible);
	local cellW = math.max(iconW, durationW) + 4;
	local cellH = iconH + durationH + 4;
	local customSize = SS.DB().sizes.BuffFrame;
	local columns, rows;
	if ( orientation == "vertical" ) then
		local maxRows = count;
		if ( type(customSize) == "table" and customSize.h and customSize.h > 0 ) then
			maxRows = math.max(1, math.floor((customSize.h + gap) / (cellH + gap)));
		end
		rows = math.min(count, maxRows);
		columns = math.ceil(count / rows);
	else
		local base = baseSizes.BuffFrame;
		local maxWidth = type(customSize) == "table" and customSize.w or (base and base.w) or (iconW * 10);
		columns = math.max(1, math.min(count, math.floor((maxWidth + gap) / (cellW + gap))));
		rows = math.ceil(count / columns);
	end
	local direction = SS.BuffGrowthDirection();
	local verticalOffset = direction == "up" and 1 or -1;
	for i = 1, count do
		local column, row;
		if ( orientation == "vertical" ) then
			column = math.floor((i - 1) / rows);
			row = math.mod(i - 1, rows);
		else
			column = math.mod(i - 1, columns);
			row = math.floor((i - 1) / columns);
		end
		local button = visible[i];
		button:ClearAllPoints();
		-- Keep the first icon at the anchor. New rows/vertical icons extend in the selected direction.
		button:SetPoint("BOTTOMLEFT", BuffFrame, "BOTTOMLEFT",
			column * (cellW + gap) + (cellW - iconW) / 2,
			verticalOffset * row * (cellH + gap));
	end
	local requiredWidth = columns * (cellW + gap) - gap;
	local requiredHeight = rows * (cellH + gap) - gap;
	BuffFrame:SetWidth(math.max(type(customSize) == "table" and customSize.w or 0, requiredWidth));
	BuffFrame:SetHeight(math.max(type(customSize) == "table" and customSize.h or 0, requiredHeight));
	buffLayoutApplying = false;
end

ApplyActionSlotGrid = function()
	local on = SS.DB().showEmptyActionSlots and true or false;
	if ( on == actionSlotsGridApplied ) then return; end
	local action = on and ActionButton_ShowGrid or ActionButton_HideGrid;
	if ( type(action) ~= "function" ) then return; end -- retry later once the game action buttons are available
	local found = false;
	for i = 1, 6 do
		local button = getglobal("ActionButton" .. i);
		if ( button ) then SS.Safe(action, button); found = true; end
	end
	if ( found ) then actionSlotsGridApplied = on; end
end

CaptureActionBarLayout = function()
	if ( actionBarOriginal or not MainMenuBar ) then return; end
	local saved = SS.DB().actionBarHorizontalSize;
	local w, h = MainMenuBar:GetWidth(), MainMenuBar:GetHeight();
	if ( type(saved) == "table" and saved.w and saved.h ) then w, h = saved.w, saved.h;
	else SS.DB().actionBarHorizontalSize = { w = w, h = h }; end
	actionBarOriginal = { w = w, h = h, buttonSize = nil, buttons = {}, racial = nil, arrows = {} };
	for i = 1, 6 do
		local button = getglobal("ActionButton" .. i);
		if ( button and button.GetNumPoints ) then
			actionBarOriginal.buttonSize = actionBarOriginal.buttonSize or button:GetWidth();
			local points = {};
			for p = 1, button:GetNumPoints() do
				local point, relative, relativePoint, x, y = button:GetPoint(p);
				points[p] = { point, relative, relativePoint, x, y };
			end
			actionBarOriginal.buttons[i] = points;
		end
	end
	if ( ActionButton12 and ActionButton12.GetNumPoints ) then
		local points = {};
		for p = 1, ActionButton12:GetNumPoints() do
			local point, relative, relativePoint, x, y = ActionButton12:GetPoint(p);
			points[p] = { point, relative, relativePoint, x, y };
		end
		actionBarOriginal.racial = { w = ActionButton12:GetWidth(), h = ActionButton12:GetHeight(), points = points,
			shown = ActionButton12.IsShown and ActionButton12:IsShown() or false };
	end
	for _, name in ipairs({ "ActionBarUpButton", "ActionBarDownButton" }) do
		local arrow = getglobal(name);
		if ( arrow and arrow.GetNumPoints ) then
			local points = {};
			for p = 1, arrow:GetNumPoints() do
				local point, relative, relativePoint, x, y = arrow:GetPoint(p);
				points[p] = { point, relative, relativePoint, x, y };
			end
			actionBarOriginal.arrows[name] = { w = arrow:GetWidth(), h = arrow:GetHeight(), points = points };
		end
	end
	if ( AZS_RacialRim and AZS_RacialRim.GetNumPoints ) then
		local points = {};
		for p = 1, AZS_RacialRim:GetNumPoints() do
			local point, relative, relativePoint, x, y = AZS_RacialRim:GetPoint(p);
			points[p] = { point, relative, relativePoint, x, y };
		end
		actionBarOriginal.rim = points;
	end
end

function SS.RestoreRacialActionButtonLayout()
	local original = actionBarOriginal;
	if ( not original or not original.racial or not ActionButton12 ) then return; end
	ActionButton12:SetWidth(original.racial.w); ActionButton12:SetHeight(original.racial.h);
	ActionButton12:ClearAllPoints();
	for p = 1, table.getn(original.racial.points) do
		local a = original.racial.points[p]; ActionButton12:SetPoint(a[1], a[2], a[3], a[4], a[5]);
	end
	if ( original.racial.shown ) then ActionButton12:Show(); else ActionButton12:Hide(); end
	if ( ActionButton12.slimRacialBorder ) then ActionButton12.slimRacialBorder:Hide(); end
	if ( AZS_RacialRim and original.rim ) then
		AZS_RacialRim:ClearAllPoints();
		for p = 1, table.getn(original.rim) do local a = original.rim[p]; AZS_RacialRim:SetPoint(a[1], a[2], a[3], a[4], a[5]); end
	end
end

-- A clean look for the XP bar when it stands upright. The stock bar's segment art and its rested-XP marker
-- (ExhaustionTick, the diamond "end point") are drawn for a horizontal bar and look broken when rotated, so they are
-- hidden and the bar gets a dark background, a thin gold border and a smooth fill. Laid flat again, everything
-- the game drew comes back exactly as it was.
local xpStyle = { shows = {} };
function SS.StyleExpBar(on)
	local xp = MainMenuExpBar;
	if ( not xp ) then return; end
	for i = 0, 3 do
		local t = getglobal("MainMenuXPBarTexture" .. i);
		if ( t and t.SetAlpha ) then t:SetAlpha(on and 0 or 1); end
	end
	for _, n in ipairs({ "ExhaustionTick", "ExhaustionLevelFillBar" }) do
		local f = getglobal(n);
		if ( f and f.Hide ) then
			if ( not xpStyle.shows[n] ) then xpStyle.shows[n] = f.Show; end
			if ( on ) then f.Show = function() end; f:Hide();
			elseif ( f.Show ~= xpStyle.shows[n] ) then f.Show = xpStyle.shows[n]; f:Show(); end
		end
	end
	local fill = xp.GetStatusBarTexture and xp:GetStatusBarTexture();
	if ( fill and xpStyle.texture == nil and fill.GetTexture ) then xpStyle.texture = fill:GetTexture() or false; end
	if ( on ) then
		if ( not xpStyle.bg ) then
			xpStyle.bg = xp:CreateTexture(nil, "BACKGROUND");
			xpStyle.bg:SetAllPoints(xp);
			xpStyle.bg:SetTexture(0.04, 0.035, 0.05, 0.85);
			xpStyle.border = CreateFrame("Frame", nil, xp);
			xpStyle.border:SetPoint("TOPLEFT", xp, "TOPLEFT", -3, 3);
			xpStyle.border:SetPoint("BOTTOMRIGHT", xp, "BOTTOMRIGHT", 3, -3);
			xpStyle.border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 });
			xpStyle.border:SetBackdropBorderColor(0.75, 0.58, 0.25, 0.9);
			xpStyle.border:EnableMouse(false);
		end
		xpStyle.bg:Show(); xpStyle.border:Show();
		xpStyle.border:SetFrameLevel((xp:GetFrameLevel() or 1) + 2);
		if ( xp.SetStatusBarTexture ) then xp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); end
		-- keep the game's own XP text readable on the narrow bar
		for _, n in ipairs({ "MainMenuBarExpText", "MainMenuExpBarText" }) do
			local t = getglobal(n);
			if ( t and t.SetFont ) then
				local font, _, flags = t:GetFont();
				if ( font ) then t:SetFont(font, 10, "OUTLINE"); end
			end
		end
	elseif ( xpStyle.bg ) then
		xpStyle.bg:Hide(); xpStyle.border:Hide();
		if ( xpStyle.texture and xp.SetStatusBarTexture ) then xp:SetStatusBarTexture(xpStyle.texture); end
	end
	xpStyle.on = on;
end

ApplyMovableOrientation = function(name)
	local orientation = SS.CurrentOrientation(name);
	if ( name == "MainMenuBar" ) then
		local d = SS.DB();
		if ( not d.unlocked and not d.showRacialAbility and not d.plainBar and orientation ~= "vertical" and type(d.sizes.MainMenuBar) ~= "table" ) then return; end
        local first = getglobal("ActionButton1");
        if ( not first ) then return; end
        local vertical = orientation == "vertical";
        local saved = SS.DB().sizes.MainMenuBar;
        local showRacial = d.showRacialAbility and true or false;
        local buttonCount = showRacial and 7 or 6;
        local gap, racialGap = 2, showRacial and 4 or 0;
        local side = first:GetWidth() or 36;
        if ( type(saved) == "table" ) then
            side = math.max(12, math.min(vertical and saved.w or saved.h,
                ((vertical and saved.h or saved.w) - gap * (buttonCount - 1) - racialGap) / buttonCount));
        end
        for i = 1, buttonCount do
            local button = getglobal("ActionButton" .. (i == 7 and 12 or i));
            if ( button ) then
                button:SetWidth(side); button:SetHeight(side); button:ClearAllPoints();
                local offset = (i - 1) * (side + gap) + (showRacial and i == 7 and racialGap or 0);
                button:SetPoint("TOPLEFT", MainMenuBar, "TOPLEFT", vertical and 0 or offset, vertical and -offset or 0);
                if ( showRacial and i == 7 and AZS_RacialRim and AZS_RacialRim.SetAllPoints ) then AZS_RacialRim:ClearAllPoints(); AZS_RacialRim:SetAllPoints(button); end
                if ( showRacial and i == 7 and not button.slimRacialBorder ) then
                    local rim = CreateFrame("Frame", nil, button);
                    rim:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2);
                    rim:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2);
                    rim:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=8});
                    rim:SetBackdropBorderColor(1, 0.78, 0.18, 1); rim:EnableMouse(false);
                    button.slimRacialBorder = rim;
                end
                if ( showRacial and i == 7 ) then button:Show(); end
            end
        end
		if ( not showRacial ) then SS.RestoreRacialActionButtonLayout(); end
        MainMenuBar:SetWidth(vertical and side or side * buttonCount + gap * (buttonCount - 1) + racialGap);
        MainMenuBar:SetHeight(vertical and side * buttonCount + gap * (buttonCount - 1) + racialGap or side);
        if ( ActionBarUpButton ) then
            ActionBarUpButton:ClearAllPoints(); ActionBarUpButton:SetWidth(12); ActionBarUpButton:SetHeight(12);
            ActionBarUpButton:SetPoint("TOPRIGHT", first, "TOPLEFT", -2, 0);
        end
        if ( ActionBarDownButton ) then
            ActionBarDownButton:ClearAllPoints(); ActionBarDownButton:SetWidth(12); ActionBarDownButton:SetHeight(12);
            ActionBarDownButton:SetPoint("TOPRIGHT", first, "TOPLEFT", -2, -14);
        end
	elseif ( name == "MainMenuExpBar" ) then
		local d = SS.DB();
		if ( not d.unlocked and type(d.places.MainMenuExpBar) ~= "table" and type(d.sizes.MainMenuExpBar) ~= "table"
			and type(d.scales.MainMenuExpBar) ~= "number" and d.orientations.MainMenuExpBar == nil ) then return; end
		local xp = MainMenuExpBar;
		-- Some client builds keep rested-XP child textures anchored to the original horizontal
		-- extent after rotating the status bar. Clip children to the bar when this Frame API exists,
		-- so the movable handle and the rendered XP indicator share the same visible bounds.
		if ( xp and xp.SetClipsChildren ) then SS.Safe(xp.SetClipsChildren, xp, true); end
		if ( xp and xp.SetOrientation ) then SS.Safe(xp.SetOrientation, xp, string.upper(orientation)); end
		SS.Safe(SS.StyleExpBar, orientation == "vertical");
		local base = baseSizes.MainMenuExpBar;
		local saved = SS.DB().sizes.MainMenuExpBar;
		if ( xp and base and type(saved) ~= "table" ) then
			if ( orientation == "vertical" ) then xp:SetWidth(base.h); xp:SetHeight(base.w);
			else xp:SetWidth(base.w); xp:SetHeight(base.h); end
			SS.DB().sizes.MainMenuExpBar = { w = xp:GetWidth(), h = xp:GetHeight() };
		end
	elseif ( name == "BuffFrame" ) then
		SS.ApplyBuffOrientation();
	elseif ( name == "SlimSuiteBossFrames" ) then
		SS.UpdateBossFrames();
	elseif ( name == "PartyMemberFrame1" ) then
		local d = SS.DB();
		if ( not d.unlocked and d.orientations.PartyMemberFrame1 == nil
			and type(d.places.PartyMemberFrame1) ~= "table" and type(d.sizes.PartyMemberFrame1) ~= "table"
			and type(d.scales.PartyMemberFrame1) ~= "number" ) then return; end
		local root = PartyMemberFrame1;
		if ( not root ) then return; end
		for i = 2, 4 do
			local frame = getglobal("PartyMemberFrame" .. i);
			if ( frame ) then
				if ( frame.SetUserPlaced ) then SS.UserPlace(frame); end
				frame:ClearAllPoints();
				if ( orientation == "horizontal" ) then
					frame:SetPoint("LEFT", getglobal("PartyMemberFrame" .. (i - 1)), "RIGHT", 8, 0);
				else
					frame:SetPoint("TOP", getglobal("PartyMemberFrame" .. (i - 1)), "BOTTOM", 0, -4);
				end
				if ( frame.SetUserPlaced ) then SS.UserPlace(frame); end
			end
		end
		-- yourself, at the end of the party (anchored to the fourth member, so it moves with the party)
		local selfCard = getglobal("SlimSuitePartySelfCard");
		local last = getglobal("PartyMemberFrame4");
		if ( selfCard and last ) then
			selfCard:ClearAllPoints();
			selfCard:SetScale(getglobal("PartyMemberFrame1") and getglobal("PartyMemberFrame1"):GetScale() or 1);
			if ( orientation == "horizontal" ) then selfCard:SetPoint("LEFT", last, "RIGHT", 8, 0);
			else selfCard:SetPoint("TOP", last, "BOTTOM", 0, -4); end
		end
	end
end

function SS.RestoreNativeActionBarLayout()
	local original = actionBarOriginal;
	if ( not original or not MainMenuBar ) then return; end
	MainMenuBar:SetWidth(original.w); MainMenuBar:SetHeight(original.h);
	for i = 1, 6 do
		local button = getglobal("ActionButton" .. i);
		local points = original.buttons[i];
		if ( button ) then
			if ( original.buttonSize ) then button:SetWidth(original.buttonSize); button:SetHeight(original.buttonSize); end
			if ( points and table.getn(points) > 0 ) then
				button:ClearAllPoints();
				for p = 1, table.getn(points) do local a = points[p]; button:SetPoint(a[1], a[2], a[3], a[4], a[5]); end
			end
		end
	end
	SS.RestoreRacialActionButtonLayout();
	for name, layout in pairs(original.arrows or {}) do
		local arrow = getglobal(name);
		if ( arrow ) then
			arrow:SetWidth(layout.w); arrow:SetHeight(layout.h); arrow:ClearAllPoints();
			for p = 1, table.getn(layout.points) do local a = layout.points[p]; arrow:SetPoint(a[1], a[2], a[3], a[4], a[5]); end
		end
	end
end

function SS.SetRacialAbility(on)
	local d = SS.DB();
	d.showRacialAbility = on and true or false;
	if ( on and CaptureActionBarLayout ) then SS.Safe(CaptureActionBarLayout); end
	if ( not d.showRacialAbility and not d.unlocked and not d.plainBar and d.orientations.MainMenuBar ~= "vertical"
		and type(d.sizes.MainMenuBar) ~= "table" ) then
		SS.Safe(SS.RestoreNativeActionBarLayout);
	else
		SS.Safe(ApplyMovableOrientation, "MainMenuBar");
	end
	PlaceAll();
end

-- True when the worn-jewelry row is joined under the spell row. Only the player separates them, with the
-- "Detach build rows" button; nothing else in Slim Suite may break that join.
function SS.BuildRowsJoined(name)
	return name == "SlimSuiteItemRowFrame" and SS.DB().buildRowsAttached and true or false;
end

function SS.Place(name, ignoreAnchor)
	local f = getglobal(name);
	local p = SS.DB().places[name];
	if ( not f ) then return; end
	if ( SS.DB().frameDefault and SS.DB().frameDefault[name] ) then return; end   -- "Default": the game's own placement
	if ( (name == "SlimSuiteSpellRowFrame" and type(p) ~= "table") or (name == "SlimSuiteItemRowFrame" and
		(type(p) ~= "table" or (SS.BuildRowsJoined(name) and p.relative ~= "SlimSuiteSpellRowFrame"))) ) then
		p = SS.BuildRowDefaultPlace(name);
		SS.DB().places[name] = p;
	end
	local w, h = f:GetWidth(), f:GetHeight();
	if ( w and h and w > 0 and h > 0 and not baseSizes[name] ) then baseSizes[name] = { w = w, h = h }; end
	if ( name ~= "GameTooltip" and not basePoints[name] and f.GetNumPoints ) then
		local points = {};
		for i = 1, f:GetNumPoints() do
			local point, relative, relativePoint, x, y = f:GetPoint(i);
			points[i] = { point, relative, relativePoint, x, y };
		end
		if ( table.getn(points) > 0 ) then basePoints[name] = points; end
	end
	if ( name == "MainMenuBar" and CaptureActionBarLayout ) then CaptureActionBarLayout(); end
	SS.ApplySize(name, f);
	if ( name == "PartyMemberFrame1" ) then
		local sc = SS.DB().partyCompact and 0.55 or (type(SS.DB().scales.PartyMemberFrame1) == "number" and SS.DB().scales.PartyMemberFrame1 or 1);
		for i = 1, 4 do local pf = getglobal("PartyMemberFrame" .. i); if ( pf and pf.SetScale ) then pf:SetScale(sc); end end
		for i = 1, 4 do
			local portrait = getglobal("PartyMemberFrame" .. i .. "Portrait");
			if ( portrait ) then if ( SS.DB().partyFaces == false ) then portrait:Hide(); else portrait:Show(); end end
		end
		local lockTo = (SS.DB().newFrames and getglobal("SlimSuitePlayerCard")) or PlayerFrame;
		if ( SS.DB().partyLocked and lockTo ) then
			f:ClearAllPoints(); f:SetPoint("TOPLEFT", lockTo, "BOTTOMLEFT", 0, -6);
			return;
		end
	end
	-- Our edge clamp uses visible child bounds; let it place an inset parent slightly outside the screen.
	if ( SS.DB().unlocked or type(p) == "table" ) then
		if ( f.SetClampedToScreen ) then f:SetClampedToScreen(false); end
		if ( (name == "BuffFrame" or name == "MainMenuBar") and f.SetUserPlaced ) then SS.UserPlace(f); end
	end
	if ( type(p) ~= "table" ) then return; end
	if ( p.coordinateSpace ~= "uiParent" ) then
		local factor = RootFactor(f);
		if ( p.x ) then p.x = p.x * factor; end
		if ( p.y ) then p.y = p.y * factor; end
		if ( p.dx ) then p.dx = p.dx * factor; end
		if ( p.dy ) then p.dy = p.dy * factor; end
		p.coordinateSpace = "uiParent";
	end
	local relative = not ignoreAnchor and p.relative and getglobal(p.relative) or nil;
	if ( relative and p.point and p.relativePoint ) then
		f:ClearAllPoints();
		local factor = RootFactor(f);
		f:SetPoint(p.point, relative, p.relativePoint, K.Num(p.dx) / factor, K.Num(p.dy) / factor);
	elseif ( p.x and p.y ) then
		-- Saved coordinates can come from a taller or wider display. Clamp absolute restores to this UIParent
		-- without rewriting the saved location, so a later return to the larger display restores the user's layout.
		local minX, minY, maxOffsetX, maxOffsetY = VisualInsets(f);
		local maxX = UIParent:GetWidth() - maxOffsetX;
		local maxY = UIParent:GetHeight() - maxOffsetY;
		local x = math.max(-minX, math.min(maxX, K.Num(p.x)));
		local y = math.max(-minY, math.min(maxY, K.Num(p.y)));
		SetRootPosition(f, x, y);
	end
end

PlaceAll = function()
	for i = 1, table.getn(MOVABLE) do SS.Safe(SS.Place, MOVABLE[i][1], true); end
	-- Reapply saved frame-to-frame anchors after every movable frame has its stored size and base position.
	for pass = 1, table.getn(MOVABLE) do
		for i = 1, table.getn(MOVABLE) do SS.Safe(SS.Place, MOVABLE[i][1], false); end
	end
	-- Relative snaps and scale changes must not leave a frame clipped or padded away from the edge.
	for i = 1, table.getn(MOVABLE) do
		local name = MOVABLE[i][1];
		local frame = getglobal(name);
		if ( frame ) then SS.Safe(SS.ClampToClient, name, frame); end
	end
	if ( SS.DB().mirrorTarget ) then SS.Safe(SS.MirrorTarget); end
	if ( SS.DB().buffsOnTarget or SS.DB().buffsOnPlayer ) then SS.Safe(SS.AttachBuffs); end
end

-- "Mirror target": the target frame stands where the player frame would be if the screen were folded at its center
-- line: same height, same scale, the same distance from the right edge as the player frame is from the left.
-- the player and target frames in use: the new-school cards when that design is on, the game's frames otherwise
-- With the new-school design on, the player and target elements are shown by the cards; the game's own frames stay
-- invisible underneath. Every handle, size, reset, hide and buff action goes to the frame the player can see.
function SS.Shown(name)
	if ( SS.DB().newFrames ) then
		if ( name == "PlayerFrame" ) then return "SlimSuitePlayerCard"; end
		if ( name == "TargetFrame" ) then return "SlimSuiteTargetCard"; end
	end
	return name;
end
function SS.Element(name)
	if ( name == "SlimSuitePlayerCard" ) then return "PlayerFrame"; end
	if ( name == "SlimSuiteTargetCard" ) then return "TargetFrame"; end
	return name;
end

function SS.Pair()
	if ( SS.DB().newFrames ) then return getglobal("SlimSuitePlayerCard"), getglobal("SlimSuiteTargetCard"); end
	return getglobal("PlayerFrame"), getglobal("TargetFrame");
end

function SS.MirrorTarget()
	local P, T = SS.Pair();
	if ( not SS.DB().mirrorTarget or not P or not T ) then return; end
	if ( SS.DB().mirrorSameScale ~= false ) then
		local scale = SS.DB().scales[P:GetName()];
		SS.DB().scales[T:GetName()] = scale;
		if ( T.SetScale ) then T:SetScale(type(scale) == "number" and scale or 1); end
	end
	local l, r, b, t = RootBounds(P);
	if ( not l or not t ) then return; end
	local factor = RootFactor(T);
	local tw, th = (T:GetWidth() or 0) * factor, (T:GetHeight() or 0) * factor;
	local x, y = UIParent:GetWidth() - l - tw, t - th;
	if ( T.SetUserPlaced ) then SS.UserPlace(T); end
	SetRootPosition(T, x, y);
	local p = SS.DB().places[T:GetName()];
	if ( type(p) ~= "table" ) then p = {}; SS.DB().places[T:GetName()] = p; end
	p.x, p.y, p.coordinateSpace = x, y, "uiParent";
	p.relative, p.point, p.relativePoint, p.dx, p.dy = nil, nil, nil, nil, nil;
end

-- the other direction: the player frame placed as the target frame's mirror image (while the target is dragged)
function SS.MirrorPlayer()
	local P, T = SS.Pair();
	if ( not SS.DB().mirrorTarget or not P or not T ) then return; end
	local l, r, b, t = RootBounds(T);
	if ( not l or not t ) then return; end
	local factor = RootFactor(P);
	local pw, ph = (P:GetWidth() or 0) * factor, (P:GetHeight() or 0) * factor;
	local x, y = UIParent:GetWidth() - l - pw, t - ph;
	if ( P.SetUserPlaced ) then SS.UserPlace(P); end
	SetRootPosition(P, x, y);
	local p = SS.DB().places[P:GetName()];
	if ( type(p) ~= "table" ) then p = {}; SS.DB().places[P:GetName()] = p; end
	p.x, p.y, p.coordinateSpace = x, y, "uiParent";
	p.relative, p.point, p.relativePoint, p.dx, p.dy = nil, nil, nil, nil, nil;
end

-- "Buffs on the target frame": the buff frame joins the target frame, above or below it, at the target's scale, and
-- loses its own handle while joined. It is shown in both frames' right-click menus and in the setup's steps.
function SS.AttachBuffs()
	local P, T = SS.Pair();
	local anchor = SS.DB().buffsOnTarget and T or (SS.DB().buffsOnPlayer and P) or nil;
	if ( not anchor or not BuffFrame ) then return; end
	local side = SS.DB().buffsOnTarget and SS.DB().buffsOnTargetSide or SS.DB().buffsOnPlayerSide;
	BuffFrame:ClearAllPoints();
	if ( side == "above" ) then BuffFrame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 6, 2);
	else BuffFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 6, -2); end
	if ( BuffFrame.SetScale ) then BuffFrame:SetScale(anchor:GetScale() or 1); end
end

-- fills the right-click menu's cross-reference rows for this element (the same settings the setup shows)
function SS.RefreshCrossRefs(name)
	if ( not sizeMenu or not sizeMenu.xref ) then return; end
	local rows = name and SS.CrossRefs(name) or {};
	for i = 1, table.getn(sizeMenu.xref) do
		local cb, e = sizeMenu.xref[i], rows[i];
		if ( e ) then
			cb.entry = e;
			cb:ClearAllPoints();
			cb:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", e[4] and 26 or 8, -312 - (i - 1) * 26);
			cb.label:SetText(e.short or e[1]);
			cb:SetChecked(e[2]() and 1 or nil);
			if ( e[4] and not e[4]() ) then cb:Disable(); cb.label:SetTextColor(0.45, 0.45, 0.45);
			else cb:Enable(); cb.label:SetTextColor(1, 1, 1); end
			cb:Show();
		else
			cb.entry = nil; cb:Hide();
		end
	end
	local n = table.getn(rows);
	if ( n > 0 ) then sizeMenu:SetHeight(math.max(sizeMenu:GetHeight() or 270, 340 + 26 * n)); end
end

function SS.RefreshBuffControls()
	if ( sizeMenu and sizeMenu.buffsOn ) then
		sizeMenu.buffsOn:SetChecked(SS.DB().buffsOnTarget and 1 or nil);
		sizeMenu.buffsSide:SetText(SS.DB().buffsOnTargetSide == "above" and "Buffs: above the target" or "Buffs: below the target");
		if ( SS.DB().buffsOnTarget ) then sizeMenu.buffsSide:Enable(); else sizeMenu.buffsSide:Disable(); end
	end
	if ( SS.DB().unlocked ) then SS.SetUnlocked(true, true); end        -- shows or hides the buff frame's own handle
end

function SS.SetBuffsOnTarget(on)
	SS.DB().buffsOnTarget = on and true or false;
	if ( on ) then SS.DB().buffsOnPlayer = false; end
	if ( on ) then
		SS.AttachBuffs();
	elseif ( BuffFrame ) then
		-- back on its own: its own scale, and its own place (or the game's, if it never had one)
		local scale = SS.DB().scales.BuffFrame;
		BuffFrame:SetScale(type(scale) == "number" and scale or 1);
		local points = basePoints.BuffFrame;
		if ( type(SS.DB().places.BuffFrame) ~= "table" and points ) then
			BuffFrame:ClearAllPoints();
			for i = 1, table.getn(points) do local p = points[i]; BuffFrame:SetPoint(p[1], p[2], p[3], p[4], p[5]); end
		end
		PlaceAll();
	end
	SS.RefreshBuffControls();
end

function SS.SetBuffsSide(side)
	SS.DB().buffsOnTargetSide = side == "above" and "above" or "below";
	SS.AttachBuffs();
	SS.RefreshBuffControls();
end

function SS.SetMirrorTarget(on)
	if ( on ) then SS.Safe(SS.ClaimTarget, "mirror"); end   -- the newest choice wins: mirroring takes the target's place
	SS.DB().mirrorTarget = on and true or false;
	if ( on ) then SS.Safe(SS.MirrorTarget); end
end

-- "Square minimap": the minimap's mask is swapped between the round and the square texture. Some clients
-- have no mask API at all, so this is checked and reported rather than assumed.
SlimSuiteMinimapMask = { round = "Textures\\MinimapMask", square = "Interface\\BUTTONS\\WHITE8X8" };
function SS.ApplyMinimapShape()
	if ( not Minimap or not Minimap.SetMaskTexture ) then return false; end
	local square = SS.DB().minimapSquare and true or false;
	local ok = SS.Safe(Minimap.SetMaskTexture, Minimap, square and SlimSuiteMinimapMask.square or SlimSuiteMinimapMask.round);
	if ( MinimapBorder ) then if ( square ) then MinimapBorder:Hide(); else MinimapBorder:Show(); end end
	return ok;
end

function SS.SetMinimapSquare(on)
	SS.DB().minimapSquare = on and true or false;
	if ( not SS.ApplyMinimapShape() ) then
		K.Print(NAME, "this client cannot change the minimap's shape.");
	end
end

-- "Same size scaling": the mirrored target copies the player frame's scale. Only meaningful while mirroring.
function SS.SetMirrorSameScale(on)
	SS.DB().mirrorSameScale = on and true or false;
	if ( SS.DB().mirrorTarget and SS.DB().mirrorSameScale ) then SS.Safe(SS.MirrorTarget); end
end

function SS.ApplyTallyLayout(resetSize)
	if ( not tallyFrame ) then return; end
	if ( resetSize ) then SS.DB().sizes.SlimSuiteTallyFrame = nil; end
	PlaceAll();
	SS.UpdateTally();
end

function SS.ToggleMovableOrientation(name)
	if ( name == "SlimSuiteItemRowFrame" or name == "SlimSuiteSpellRowFrame" ) then
		SS.DB().orientations[name] = SS.CurrentOrientation(name) == "vertical" and "horizontal" or "vertical";
		if ( name == "SlimSuiteItemRowFrame" ) then SS.LayoutItemRow(); else SS.LayoutSpellRow(); end
		SS.DB().sizes[name] = { w = getglobal(name):GetWidth(), h = getglobal(name):GetHeight() };
		PlaceAll();
		return;
	end
	if ( name == "SlimSuiteTallyFrame" ) then
		SS.DB().tallyVertical = not SS.DB().tallyVertical;
		SS.ApplyTallyLayout(true);
		return;
	end
	local nextOrientation = SS.CurrentOrientation(name) == "vertical" and "horizontal" or "vertical";
	SS.DB().orientations[name] = nextOrientation;
	if ( name == "SlimSuiteClockFrame" ) then
		local w, h = nextOrientation == "vertical" and 220 or 360, nextOrientation == "vertical" and 54 or 32;
		clockFrame:SetWidth(w); clockFrame:SetHeight(h);
		SS.DB().sizes[name] = { w = w, h = h };
		SS.ApplyClockLayout();
		PlaceAll();
		SS.UpdateClock();
		return;
	end
	if ( name == "BuffFrame" ) then SS.DB().buffCustomLayout = true; end
	if ( name == "SlimSuiteBossFrames" ) then SS.DB().sizes[name] = nil; end

	if ( name == "MainMenuExpBar" or name == "MainMenuBar" ) then
		local f = getglobal(name);
		if ( f ) then
			-- Rotate the current dimensions, including a user's custom length. Using only the
			-- Blizzard base size here discards resizing and leaves a horizontal footprint behind.
			local saved = SS.DB().sizes[name];
			local w = type(saved) == "table" and saved.w or f:GetWidth();
			local h = type(saved) == "table" and saved.h or f:GetHeight();
			w, h = h, w;
			f:SetWidth(w); f:SetHeight(h); SS.DB().sizes[name] = { w = w, h = h };
		end
	end
	ApplyMovableOrientation(name);
	PlaceAll();
end

function SS.ApplyMovablePadding(name)
	if ( name == "SlimSuiteClockFrame" ) then SS.ApplyClockLayout();
	elseif ( name == "SlimSuiteBossFrames" ) then SS.UpdateBossFrames();
	elseif ( name == "SlimSuiteTallyFrame" ) then SS.ApplyTallyLayout(false);
	elseif ( name == "SlimSuiteAnnouncementFrame" and announcementFrame and announcementFrame.text ) then
		local padding = SS.FramePadding(name);
		announcementFrame.text:ClearAllPoints();
		announcementFrame.text:SetPoint("TOPLEFT", announcementFrame, "TOPLEFT", padding + 10, -padding);
		announcementFrame.text:SetPoint("BOTTOMRIGHT", announcementFrame, "BOTTOMRIGHT", -(padding + 10), padding);
	elseif ( name == "BuffFrame" ) then
		SS.DB().buffCustomLayout = true;
		SS.Safe(SS.ApplyBuffOrientation);
	end
end


-- The main chat window is docked by default, with its tab and edit box as separate frames. Undock it for custom
-- placement, then anchor those two companions to the message frame so one green handle moves the whole chat window.
function SS.PrepareChatWindow()
	local chat = ChatFrame1;
	if ( not chat ) then return; end
	if ( chat.isDocked and FCF_UnDockFrame ) then
		SS.Safe(FCF_UnDockFrame, chat);
		if ( FCF_SetLocked ) then SS.Safe(FCF_SetLocked, chat, false); end
	end
	local chatLeft, chatBottom = chat:GetLeft(), chat:GetBottom();
	if ( not chatLeft or not chatBottom ) then return; end
	local parts = { { "ChatFrame1Tab", ChatFrame1Tab }, { "ChatFrame1EditBox", chat.editBox or getglobal("ChatFrame1EditBox") } };
	for i = 1, table.getn(parts) do
		local name, part = parts[i][1], parts[i][2];
		local offset = SS.DB().chatOffsets[name];
		if ( part and type(offset) ~= "table" ) then
			local left, bottom = part:GetLeft(), part:GetBottom();
			if ( left and bottom ) then
				offset = { x = left - chatLeft, y = bottom - chatBottom };
				SS.DB().chatOffsets[name] = offset;
			end
		end
		if ( part and type(offset) == "table" and type(offset.x) == "number" and type(offset.y) == "number" ) then
			part:ClearAllPoints();
			part:SetPoint("BOTTOMLEFT", chat, "BOTTOMLEFT", offset.x, offset.y);
		end
	end
end

-- The native XP bar is anchored to MainMenuBar. Reparent it while preserving its on-screen bounds so its
-- independent move handle can reposition it without moving or resizing the action buttons.
function SS.DetachExperienceBar()
	if ( xpBarDetached or not MainMenuExpBar or not UIParent ) then return; end
	local left, right, bottom = RootBounds(MainMenuExpBar);
	local width, height = MainMenuExpBar:GetWidth(), MainMenuExpBar:GetHeight();
	MainMenuExpBar:SetParent(UIParent);
	MainMenuExpBar:ClearAllPoints();
	if ( left and bottom ) then
		SetRootPosition(MainMenuExpBar, left, bottom);
	else
		MainMenuExpBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 8);
	end
	if ( width and width > 0 ) then MainMenuExpBar:SetWidth(width); end
	if ( height and height > 0 ) then MainMenuExpBar:SetHeight(height); end
	xpBarDetached = true;
end

function SS.ToggleBuildRowsAttached()
	if ( not itemRow or not spellRow or not MainMenuBar ) then return; end
	if ( SS.DB().buildRowsAttached ) then
		for _, name in ipairs({ "SlimSuiteSpellRowFrame", "SlimSuiteItemRowFrame" }) do
			local frame = getglobal(name);
			SS.SavePlace(name, frame);
			local p = SS.DB().places[name];
			if ( p ) then p.relative, p.point, p.relativePoint, p.dx, p.dy = nil, nil, nil, nil, nil; end
		end
		SS.DB().buildRowsAttached = false;
	else
		-- Keep the spell row where the player left it; attach only the jewelry row beneath it.
		SS.SavePlace("SlimSuiteSpellRowFrame", spellRow);
		local spellPlace = SS.DB().places.SlimSuiteSpellRowFrame;
		if ( spellPlace ) then spellPlace.relative, spellPlace.point, spellPlace.relativePoint, spellPlace.dx, spellPlace.dy = nil, nil, nil, nil, nil; end
		SS.DB().buildRowsAttached = true;
		SS.DB().places.SlimSuiteItemRowFrame = SS.BuildRowDefaultPlace("SlimSuiteItemRowFrame");
	end
	PlaceAll();
	if ( sizeMenu and sizeMenu.attachButton ) then
		sizeMenu.attachButton:SetText(SS.DB().buildRowsAttached and "Detach build rows" or "Attach build rows");
	end
end

function SS.OpenSizeMenu(name, label)
	name = SS.Element(name);
	local f = getglobal(SS.Shown(name));
	if ( not f ) then return; end
	if ( not sizeMenu ) then
		sizeMenu = CreateFrame("Frame", nil, UIParent);
		sizeMenu:SetWidth(206);
		sizeMenu:SetHeight(270);
		sizeMenu:SetFrameStrata("DIALOG");
		sizeMenu:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		                      tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
		sizeMenu:SetBackdropColor(0.04, 0.035, 0.07, 0.97);
		sizeMenu:SetBackdropBorderColor(0.85, 0.65, 0.2, 1);
		sizeMenuText = sizeMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		sizeMenuText:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 12, -10);
		sizeMenu:SetMovable(true);
		if ( sizeMenu.SetClampedToScreen ) then sizeMenu:SetClampedToScreen(true); end
		sizeMenu.dragStrip = CreateFrame("Frame", nil, sizeMenu);
		sizeMenu.dragStrip:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 4, -3);
		sizeMenu.dragStrip:SetWidth(124); sizeMenu.dragStrip:SetHeight(20);
		sizeMenu.dragStrip:EnableMouse(true);
		sizeMenu.dragStrip:SetScript("OnMouseDown", function()
			if ( arg1 == "LeftButton" ) then sizeMenu:StartMoving(); sizeMenu.dragging = true; end
		end);
		sizeMenu.dragStrip:SetScript("OnMouseUp", function()
			if ( not sizeMenu.dragging ) then return; end
			sizeMenu:StopMovingOrSizing(); sizeMenu.dragging = nil;
			local left, bottom = sizeMenu:GetLeft(), sizeMenu:GetBottom();
			if ( left and bottom ) then SS.DB().sizeMenuPosition = { x = left, y = bottom }; end
		end);
		sizeMenuWidth = sizeMenu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		sizeMenuWidth:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 12, -34);
		sizeMenuHeight = sizeMenu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		sizeMenuHeight:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 12, -63);
		sizeMenuScale = sizeMenu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		sizeMenuScale:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 12, -92);
		sizeMenuScale:SetText("Scale %:");
		sizeMenuScaleInput = CreateFrame("EditBox", nil, sizeMenu);
		sizeMenuScaleInput:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 52, -89);
		sizeMenuScaleInput:SetWidth(46); sizeMenuScaleInput:SetHeight(20);
		sizeMenuScaleInput:SetAutoFocus(false); sizeMenuScaleInput:SetNumeric(true);
		sizeMenuScaleInput:SetJustifyH("CENTER"); sizeMenuScaleInput:SetMaxLetters(3);
		sizeMenuScaleInput:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } });
		sizeMenuScaleInput:SetBackdropColor(0.02, 0.02, 0.03, 0.95);
		sizeMenuScaleInput:SetBackdropBorderColor(0.55, 0.43, 0.2, 1);
		local function ResizeBy(axis, delta)
			if ( not sizeTarget ) then return; end
			local t = getglobal(sizeTarget);
			if ( not t ) then return; end
			local w, h = t:GetWidth(), t:GetHeight();
			local effective = t.GetEffectiveScale and t:GetEffectiveScale() or 1;
			local rootScale = UIParent:GetEffectiveScale() or 1;
			local scaleRatio = effective / rootScale;
			if ( scaleRatio <= 0 ) then scaleRatio = 1; end
			if ( axis == "w" ) then
				local minWidth = sizeTarget == "SlimSuiteClockFrame" and SS.CurrentOrientation(sizeTarget) == "horizontal" and 280 or 40;
				if ( sizeTarget == "SlimSuiteItemRowFrame" ) then minWidth = SS.CurrentOrientation(sizeTarget) == "vertical" and 36 or 76; end
				if ( sizeTarget == "SlimSuiteSpellRowFrame" ) then minWidth = SS.CurrentOrientation(sizeTarget) == "vertical" and 36 or 92; end
				if ( sizeTarget == "GameTooltip" ) then minWidth = 160; end
				if ( sizeTarget == "SlimSuiteMeterFrame" ) then minWidth = 300; end
				w = math.max(minWidth, math.min((UIParent:GetWidth() or 1920) / scaleRatio, w + delta));
			else
				local minHeight = sizeTarget == "SlimSuiteBossFrames" and SS.CurrentOrientation(sizeTarget) == "vertical" and 60
					or sizeTarget == "SlimSuiteClockFrame" and SS.CurrentOrientation(sizeTarget) == "vertical" and 40 or 24;
				if ( sizeTarget == "SlimSuiteBossFrames" ) then
					local pad = SS.FramePadding(sizeTarget);
					minHeight = SS.CurrentOrientation(sizeTarget) == "vertical" and math.max(60, 52 + (pad * 3)) or math.max(36, 36 + (pad * 4));
				elseif ( sizeTarget == "SlimSuiteClockFrame" and SS.CurrentOrientation(sizeTarget) == "vertical" ) then
					minHeight = 36 + (SS.FramePadding(sizeTarget) * 3);
				elseif ( sizeTarget == "SlimSuiteItemRowFrame" and SS.CurrentOrientation(sizeTarget) == "vertical" ) then
					minHeight = 60;
				elseif ( sizeTarget == "SlimSuiteSpellRowFrame" and SS.CurrentOrientation(sizeTarget) == "vertical" ) then
					minHeight = 92;
				elseif ( sizeTarget == "SlimSuiteMeterFrame" ) then
					minHeight = 148;
				elseif ( sizeTarget == "GameTooltip" ) then
					minHeight = 80;
				end
				h = math.max(minHeight, math.min((UIParent:GetHeight() or 1080) / scaleRatio, h + delta));
			end
			t:SetWidth(w); t:SetHeight(h);
			if ( sizeTarget == "MainMenuBar" ) then
				local vertical = SS.CurrentOrientation(sizeTarget) == "vertical";
				local side = (axis == "w") and (vertical and w or (w - 16) / 7) or (vertical and (h - 16) / 7 or h);
				side = math.max(12, math.min(side, (UIParent:GetWidth() / scaleRatio - (vertical and 0 or 16)) / (vertical and 1 or 7), (UIParent:GetHeight() / scaleRatio - (vertical and 16 or 0)) / (vertical and 7 or 1)));
				w, h = vertical and side or side * 7 + 16, vertical and side * 7 + 16 or side;
				t:SetWidth(w); t:SetHeight(h);
			end
			SS.DB().sizes[sizeTarget] = { w = w, h = h };
			if ( sizeTarget == "GameTooltip" ) then SS.DB().tooltipCustom = true; end
			if ( sizeTarget == "BuffFrame" ) then SS.Safe(SS.ApplyBuffOrientation); end
			if ( sizeTarget == "SlimSuiteClockFrame" ) then SS.ApplyClockLayout(); end
			PlaceAll();
			sizeMenuWidth:SetText("Width: " .. math.floor(w + 0.5));
			sizeMenuHeight:SetText("Height: " .. math.floor(h + 0.5));
		end
		local narrower = K.Button(sizeMenu, "-", 30, function() ResizeBy("w", -20); end);
		narrower:SetPoint("TOPRIGHT", sizeMenu, "TOPRIGHT", -72, -26);
		local wider = K.Button(sizeMenu, "+", 30, function() ResizeBy("w", 20); end);
		wider:SetPoint("TOPRIGHT", sizeMenu, "TOPRIGHT", -32, -26);
		local shorter = K.Button(sizeMenu, "-", 30, function() ResizeBy("h", -20); end);
		shorter:SetPoint("TOPRIGHT", sizeMenu, "TOPRIGHT", -72, -55);
		local taller = K.Button(sizeMenu, "+", 30, function() ResizeBy("h", 20); end);
		taller:SetPoint("TOPRIGHT", sizeMenu, "TOPRIGHT", -32, -55);
		local function SetScalePercent(percent)
			if ( not sizeTarget ) then return; end
			percent = math.max(1, math.min(200, math.floor(tonumber(percent) or 100)))
			SS.DB().scales[sizeTarget] = percent / 100;
			PlaceAll();
			sizeMenuScaleInput:SetText(tostring(percent));
		end
		sizeMenuScaleInput:SetScript("OnEnterPressed", function()
			this.cancelScaleEdit = true;
			SetScalePercent(this:GetText());
			this:ClearFocus();
		end);
		sizeMenuScaleInput:SetScript("OnEditFocusLost", function()
			if ( this.cancelScaleEdit ) then this.cancelScaleEdit = nil; return; end
			SetScalePercent(this:GetText());
		end);
		sizeMenuScaleInput:SetScript("OnEscapePressed", function()
			this.cancelScaleEdit = true;
			this:ClearFocus();
			local current = math.floor((SS.DB().scales[sizeTarget] or 1) * 100 + 0.5);
			this:SetText(tostring(current));
		end);
		local scaleDown = K.Button(sizeMenu, "-", 30, function()
			local scale = math.floor((SS.DB().scales[sizeTarget] or 1) * 100 + 0.5);
			SetScalePercent(scale - 5);
		end);
		scaleDown:SetPoint("TOPRIGHT", sizeMenu, "TOPRIGHT", -72, -84);
		local scaleUp = K.Button(sizeMenu, "+", 30, function()
			local scale = math.floor((SS.DB().scales[sizeTarget] or 1) * 100 + 0.5);
			SetScalePercent(scale + 5);
		end);
		scaleUp:SetPoint("TOPRIGHT", sizeMenu, "TOPRIGHT", -32, -84);
		-- Labels and their +/- buttons share the same adjustments for wheel and clicks.
		local function WheelPair(y, down, up)
			local zone = CreateFrame("Frame", nil, sizeMenu);
			zone:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 10, y);
			zone:SetWidth(90); zone:SetHeight(25); zone:EnableMouseWheel(true);
			local function Wheel()
				if ( not arg1 or arg1 == 0 ) then return; end
				local action = (arg1 > 0 and up or down):GetScript("OnClick");
				if ( action ) then action(); end
			end
			zone:SetScript("OnMouseWheel", Wheel);
			down:EnableMouseWheel(true); down:SetScript("OnMouseWheel", Wheel);
			up:EnableMouseWheel(true); up:SetScript("OnMouseWheel", Wheel);
			return zone;
		end
		WheelPair(-26, narrower, wider); WheelPair(-55, shorter, taller); WheelPair(-84, scaleDown, scaleUp);
		local layout = K.Button(sizeMenu, "Switch to vertical", 138, function()
			if ( not sizeTarget ) then return; end
			SS.ToggleMovableOrientation(sizeTarget);
			local t = getglobal(sizeTarget);
			if ( t ) then
				sizeMenuWidth:SetText("Width: " .. math.floor(t:GetWidth() + 0.5));
				sizeMenuHeight:SetText("Height: " .. math.floor(t:GetHeight() + 0.5));
			end
			local orientation = sizeTarget == "SlimSuiteTallyFrame" and (SS.DB().tallyVertical and "vertical" or "horizontal") or SS.CurrentOrientation(sizeTarget);
			sizeMenu.layoutButton:SetText(orientation == "vertical" and "Switch to horizontal" or "Switch to vertical");
		end);
		layout:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 10, -116);
		sizeMenu.layoutButton = layout;
		local growth;
		growth = K.Button(sizeMenu, "Grow down", 68, function()
			if ( sizeTarget ~= "BuffFrame" ) then return; end
			SS.DB().buffCustomLayout = true;
			SS.DB().buffGrowthDirection = SS.BuffGrowthDirection() == "up" and "down" or "up";
			growth:SetText("Grow " .. BuffGrowthDirection());
			SS.Safe(SS.ApplyBuffOrientation);
			PlaceAll();
		end);
		growth:SetPoint("TOPRIGHT", sizeMenu, "TOPRIGHT", -10, -116);
		growth:Hide();
		sizeMenu.growthButton = growth;
		sizeMenuPadding = sizeMenu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		sizeMenuPadding:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 12, -148);
		local padDown = K.Button(sizeMenu, "-", 30, function()
			if ( not sizeTarget ) then return; end
			SS.DB().padding[sizeTarget] = math.max(0, SS.FramePadding(sizeTarget) - 2);
			SS.ApplyMovablePadding(sizeTarget);
			sizeMenuPadding:SetText("Padding: " .. FramePadding(sizeTarget));
			local t = getglobal(sizeTarget);
			if ( t ) then sizeMenuWidth:SetText("Width: " .. math.floor(t:GetWidth() + 0.5)); sizeMenuHeight:SetText("Height: " .. math.floor(t:GetHeight() + 0.5)); end
		end);
		padDown:SetPoint("TOPRIGHT", sizeMenu, "TOPRIGHT", -72, -142);
		local padUp = K.Button(sizeMenu, "+", 30, function()
			if ( not sizeTarget ) then return; end
			SS.DB().padding[sizeTarget] = math.min(SS.FramePaddingLimit(sizeTarget), SS.FramePadding(sizeTarget) + 2);
			SS.ApplyMovablePadding(sizeTarget);
			sizeMenuPadding:SetText("Padding: " .. FramePadding(sizeTarget));
			local t = getglobal(sizeTarget);
			if ( t ) then sizeMenuWidth:SetText("Width: " .. math.floor(t:GetWidth() + 0.5)); sizeMenuHeight:SetText("Height: " .. math.floor(t:GetHeight() + 0.5)); end
		end);
		padUp:SetPoint("TOPRIGHT", sizeMenu, "TOPRIGHT", -32, -142);
		sizeMenu.padDown, sizeMenu.padUp = padDown, padUp;
		sizeMenu.paddingWheel = WheelPair(-142, padDown, padUp);
		local muteButton = K.Button(sizeMenu, "Hide feature", 112, function()
			if ( sizeTarget ) then SS.ToggleFeatureMute(sizeTarget); end
		end);
		muteButton:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 10, -178);
		sizeMenu.muteButton = muteButton;
		local attachButton = K.Button(sizeMenu, "Detach item row", 184, function() SS.ToggleBuildRowsAttached(); end);
		attachButton:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 10, -208);
		sizeMenu.attachButton = attachButton;
		-- the local clock's own options: its dark box, 12- or 24-hour time, and an hour's shift for daylight saving
		local function ClockLabels()
			local d = SS.DB();
			sizeMenu.clockBox:SetText(d.localClockBackground == false and "Show background" or "Remove background");
			local is24 = SlimSuiteWorld and SlimSuiteWorld.ClockIs24 and SlimSuiteWorld.ClockIs24();
			sizeMenu.clock24:SetText(is24 and "Switch to 12-hour" or "Switch to 24-hour");
			local dst = tonumber(d.localClockDST) or 0;
			sizeMenu.clockDst:SetText("Daylight saving: " .. (dst > 0 and "+1 hour" or (dst < 0 and "-1 hour" or "off")));
		end
		local function ClockChanged()
			if ( SlimSuiteWorld and SlimSuiteWorld.UpdateLocalClock ) then SlimSuiteWorld.UpdateLocalClock(); end
			ClockLabels();
		end
		sizeMenu.clockBox = K.Button(sizeMenu, "Remove background", 184, function()
			SS.DB().localClockBackground = SS.DB().localClockBackground == false; ClockChanged();
		end);
		sizeMenu.clockBox:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 10, -208);
		sizeMenu.clock24 = K.Button(sizeMenu, "Switch to 24-hour", 184, function()
			local is24 = SlimSuiteWorld and SlimSuiteWorld.ClockIs24 and SlimSuiteWorld.ClockIs24();
			SS.DB().localClock24 = not is24; ClockChanged();
		end);
		sizeMenu.clock24:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 10, -236);
		-- off -> +1 hour -> -1 hour -> off
		sizeMenu.clockDst = K.Button(sizeMenu, "Daylight saving: off", 184, function()
			local dst = tonumber(SS.DB().localClockDST) or 0;
			SS.DB().localClockDST = dst == 0 and 1 or (dst > 0 and -1 or 0); ClockChanged();
		end);
		sizeMenu.clockDst:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 10, -264);
		sizeMenu.ClockLabels = ClockLabels;
		-- the player frame's own option
		sizeMenu.mirror = CreateFrame("CheckButton", nil, sizeMenu, "UICheckButtonTemplate");
		sizeMenu.mirror:SetWidth(22); sizeMenu.mirror:SetHeight(22);
		sizeMenu.mirror:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 8, -207);
		sizeMenu.mirror.label = sizeMenu.mirror:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		sizeMenu.mirror.label:SetPoint("LEFT", sizeMenu.mirror, "RIGHT", 2, 1); sizeMenu.mirror.label:SetText("Mirror target");
		sizeMenu.mirror:SetScript("OnClick", function() SS.SetMirrorTarget(this:GetChecked() and true or false); end);
		sizeMenu.mirror:Hide();
		sizeMenu.xref = {};
		for i = 1, 10 do
			local cb = CreateFrame("CheckButton", nil, sizeMenu, "UICheckButtonTemplate");
			cb:SetWidth(22); cb:SetHeight(22);
			cb:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 8, -312 - (i - 1) * 26);
			cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
			cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 1); cb.label:SetWidth(160); cb.label:SetJustifyH("LEFT");
			cb:SetScript("OnClick", function()
				if ( this.entry and this.entry.set ) then this.entry.set(this:GetChecked() and true or false); end
				SS.RefreshCrossRefs(SlimSuiteSizeMenuName);
			end);
			cb:Hide();
			sizeMenu.xref[i] = cb;
		end
		-- indented under Mirror target; greyed out unless mirroring is on
		sizeMenu.mirrorScale = CreateFrame("CheckButton", nil, sizeMenu, "UICheckButtonTemplate");
		sizeMenu.mirrorScale:SetWidth(22); sizeMenu.mirrorScale:SetHeight(22);
		sizeMenu.mirrorScale:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 26, -229);
		sizeMenu.mirrorScale.label = sizeMenu.mirrorScale:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		sizeMenu.mirrorScale.label:SetPoint("LEFT", sizeMenu.mirrorScale, "RIGHT", 2, 1); sizeMenu.mirrorScale.label:SetText("Same size scaling");
		sizeMenu.mirrorScale:SetScript("OnClick", function() SS.SetMirrorSameScale(this:GetChecked() and true or false); end);
		sizeMenu.mirrorScale:Hide();
		-- the target frame's and the buff frame's shared option
		sizeMenu.buffsOn = CreateFrame("CheckButton", nil, sizeMenu, "UICheckButtonTemplate");
		sizeMenu.buffsOn:SetWidth(22); sizeMenu.buffsOn:SetHeight(22);
		sizeMenu.buffsOn.label = sizeMenu.buffsOn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		sizeMenu.buffsOn.label:SetPoint("LEFT", sizeMenu.buffsOn, "RIGHT", 2, 1); sizeMenu.buffsOn.label:SetText("Buffs on the target frame");
		sizeMenu.buffsOn:SetScript("OnClick", function() SS.SetBuffsOnTarget(this:GetChecked() and true or false); end);
		sizeMenu.buffsSide = K.Button(sizeMenu, "Buffs: below the target", 184, function()
			SS.SetBuffsSide(SS.DB().buffsOnTargetSide == "above" and "below" or "above");
		end);
		sizeMenu.buffsOn:Hide(); sizeMenu.buffsSide:Hide();
		local reset = K.Button(sizeMenu, "Reset", 62, function()
			if ( not SS.ResetElement(sizeTarget) ) then
				K.Print(NAME, "the original size is not available yet; try again after the frame appears.");
				return;
			end
			SS.OpenSizeMenu(sizeMenu.element or sizeTarget, sizeMenu.label);
		end);
		reset:SetPoint("BOTTOMLEFT", sizeMenu, "BOTTOMLEFT", 10, 8);
		local close = K.Button(sizeMenu, "Done", 62, function() sizeMenu:Hide(); end);
		close:SetPoint("BOTTOMRIGHT", sizeMenu, "BOTTOMRIGHT", -10, 8);
	end
	sizeTarget = SS.Shown(name);
	sizeMenu.element, sizeMenu.label = name, label;
	local w, h = f:GetWidth() or 0, f:GetHeight() or 0;
	sizeMenuText:SetText("Resize " .. (label or name));
	sizeMenuWidth:SetText("Width: " .. math.floor(w + 0.5));
	sizeMenuHeight:SetText("Height: " .. math.floor(h + 0.5));
	local scale = SS.DB().scales[sizeTarget] or 1;
	sizeMenuScaleInput:SetText(tostring(math.max(1, math.min(200, math.floor(scale * 100 + 0.5)))));
	if ( sizeMenu.layoutButton ) then
		local canOrient = name == "SlimSuiteTallyFrame" or name == "SlimSuiteClockFrame" or name == "SlimSuiteBossFrames" or name == "SlimSuiteSpellRowFrame" or name == "SlimSuiteItemRowFrame" or name == "MainMenuBar" or name == "MainMenuExpBar" or name == "BuffFrame" or name == "PartyMemberFrame1";
		if ( canOrient ) then
			sizeMenu.layoutButton:Show();
			sizeMenu.layoutButton:SetWidth(name == "BuffFrame" and 116 or 138);
			local orientation = name == "SlimSuiteTallyFrame" and (SS.DB().tallyVertical and "vertical" or "horizontal") or SS.CurrentOrientation(name);
			sizeMenu.layoutButton:SetText(orientation == "vertical" and "Switch to horizontal" or "Switch to vertical");
		else
			sizeMenu.layoutButton:Hide();
		end
		if ( sizeMenu.growthButton ) then
			if ( name == "BuffFrame" ) then
				sizeMenu.growthButton:Show();
				sizeMenu.growthButton:SetText("Grow " .. BuffGrowthDirection());
			else sizeMenu.growthButton:Hide(); end
		end
		if ( name == "SlimSuiteSpellRowFrame" ) then
			sizeMenu.attachButton:Show();
			sizeMenu.attachButton:SetText(SS.DB().buildRowsAttached and "Detach build rows" or "Attach build rows");
		else sizeMenu.attachButton:Hide(); end
		local canPad = name == "SlimSuiteClockFrame" or name == "SlimSuiteBossFrames" or name == "SlimSuiteTallyFrame" or name == "SlimSuiteAnnouncementFrame" or name == "BuffFrame";
		if ( canPad ) then
			sizeMenu.paddingWheel:Show();
			sizeMenuPadding:Show(); sizeMenu.padDown:Show(); sizeMenu.padUp:Show();
			sizeMenuPadding:SetText("Padding: " .. FramePadding(name));
		else
			sizeMenuPadding:Hide(); sizeMenu.padDown:Hide(); sizeMenu.padUp:Hide();
			sizeMenu.paddingWheel:Hide();
		end
		sizeMenu.muteButton:SetText(SS.DB().muted[sizeTarget] and "Show feature" or "Hide feature");
	end
	if ( sizeMenu.clockBox ) then
		if ( sizeMenu.mirror ) then
			if ( name == "PlayerFrame" or name == "TargetFrame" ) then
				sizeMenu.mirror:SetChecked(SS.DB().mirrorTarget and 1 or nil); sizeMenu.mirror:Show();
				sizeMenu.mirrorScale:SetChecked(SS.DB().mirrorSameScale ~= false and 1 or nil); sizeMenu.mirrorScale:Show();
				if ( SS.DB().mirrorTarget ) then
					sizeMenu.mirrorScale:Enable(); sizeMenu.mirrorScale.label:SetTextColor(1, 1, 1);
				else
					sizeMenu.mirrorScale:Disable(); sizeMenu.mirrorScale.label:SetTextColor(0.45, 0.45, 0.45);
				end
			else sizeMenu.mirror:Hide(); sizeMenu.mirrorScale:Hide(); end
		end
		if ( sizeMenu.buffsOn ) then
			local buffs = name == "TargetFrame" or name == "BuffFrame";
			sizeMenu.buffsOn:ClearAllPoints(); sizeMenu.buffsSide:ClearAllPoints();
			-- under Mirror target on the target frame's menu; first on the buff frame's
			local top = name == "TargetFrame" and -257 or -207;
			sizeMenu.buffsOn:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 8, top);
			sizeMenu.buffsSide:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 26, top - 26);
			if ( buffs ) then sizeMenu.buffsOn:Show(); sizeMenu.buffsSide:Show(); SS.RefreshBuffControls(); else sizeMenu.buffsOn:Hide(); sizeMenu.buffsSide:Hide(); end
		end
		local isClock = name == "SlimSuiteLocalClockFrame";
		for _, b in ipairs({ sizeMenu.clockBox, sizeMenu.clock24, sizeMenu.clockDst }) do if ( isClock ) then b:Show(); else b:Hide(); end end
		if ( isClock ) then sizeMenu.ClockLabels(); end
		sizeMenu:SetHeight(isClock and 326 or (name == "TargetFrame" and 326) or (name == "BuffFrame" and 300) or 270);
	end
	-- The menu opens smaller, right beside the element it is for (on its right, or its left when there is no room),
	-- top edges level. It can still be dragged anywhere while it is open.
	SlimSuiteSizeMenuName = name;
	SS.RefreshCrossRefs(name);
	local MENU_SCALE = 0.82;
	sizeMenu:SetScale(MENU_SCALE);
	sizeMenu:ClearAllPoints();
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight();
	local mw, mh = 206 * MENU_SCALE, (sizeMenu:GetHeight() or 270) * MENU_SCALE;
	local l, r, b, t = RootBounds(f);
	local x, y;
	if ( l and r and t ) then
		x = r + 8;
		if ( x + mw > sw ) then x = l - 8 - mw; end
		y = t - mh;
	else
		local scale = UIParent:GetEffectiveScale() or 1;
		x, y = GetCursorPosition(); x, y = x / scale + 8, y / scale + 8;
	end
	x = math.max(0, math.min(sw - mw, x));
	y = math.max(0, math.min(sh - mh, y));
	sizeMenu:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / MENU_SCALE, y / MENU_SCALE);
	sizeMenu:Show();
end

function SS.ShowLockPanel()
	if ( not lockPanel ) then
		lockPanel = CreateFrame("Frame", "SlimSuiteMovePanel", UIParent);
		lockPanel:SetWidth(374);
		lockPanel:SetHeight(198);
		lockPanel:SetFrameStrata("DIALOG");
		lockPanel:SetMovable(true);
		if ( lockPanel.SetClampedToScreen ) then lockPanel:SetClampedToScreen(true); end
		lockPanel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		                       tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
		lockPanel:SetBackdropColor(0.04, 0.035, 0.07, 0.97);
		lockPanel:SetBackdropBorderColor(0.85, 0.65, 0.2, 1);
		local header = CreateFrame("Frame", nil, lockPanel);
		header:SetPoint("TOPLEFT", lockPanel, "TOPLEFT", 4, -3);
		header:SetPoint("TOPRIGHT", lockPanel, "TOPRIGHT", -4, -3);
		header:SetHeight(22);
		header:EnableMouse(true);
		header:RegisterForDrag("LeftButton");
		local title = lockPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal");
		title:SetPoint("LEFT", header, "LEFT", 7, 0);
		title:SetText("Move UI settings — drag this header to move");
		header:SetScript("OnDragStart", function() lockPanel:StartMoving(); end);
		header:SetScript("OnDragStop", function()
			lockPanel:StopMovingOrSizing(); lockPanel.dragging = nil;
			local left, top = lockPanel:GetLeft(), lockPanel:GetTop();
			if ( left and top ) then SS.DB().lockPanelPosition = { x = left, y = UIParent:GetHeight() - top }; end
		end);
		local note = lockPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		note:SetPoint("TOPLEFT", lockPanel, "TOPLEFT", 10, -30);
		note:SetText("Drag to move. Right-click for size, scale, layout and hide options. Shift-left-click also hides/shows.");
		local gridCheck = CreateFrame("CheckButton", nil, lockPanel, "UICheckButtonTemplate");
		gridCheck:SetPoint("TOPLEFT", lockPanel, "TOPLEFT", 6, -52); gridCheck:SetWidth(22); gridCheck:SetHeight(22);
		gridCheck:SetScript("OnShow", function() this:SetChecked(SS.DB().showEditGrid and 1 or nil); end);
		gridCheck:SetScript("OnClick", function() SS.DB().showEditGrid = this:GetChecked() and true or false; if ( SS.DB().unlocked ) then ShowEditGrid(); end end);
		local gridLabel = lockPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		gridLabel:SetPoint("LEFT", gridCheck, "RIGHT", 0, 0); gridLabel:SetText("Grid");
		local gridSizes = {16, 32, 64, 128};
		lockPanel.gridButtons = {};
		for i = 1, table.getn(gridSizes) do
			local pixels = gridSizes[i];
			local button = K.Button(lockPanel, tostring(pixels), 48, function()
				SS.DB().gridDivisions = pixels;
				for j = 1, table.getn(lockPanel.gridButtons) do lockPanel.gridButtons[j]:UnlockHighlight(); end
				this:LockHighlight();
				if ( SS.DB().unlocked ) then ShowEditGrid(); end
			end);
			button:SetPoint("LEFT", gridLabel, "RIGHT", 5 + (i - 1) * 52, 0);
			table.insert(lockPanel.gridButtons, button);
		end
		local function AddGridLineToggle(x, key, labelText)
			local cb = CreateFrame("CheckButton", nil, lockPanel, "UICheckButtonTemplate");
			cb:SetPoint("TOPLEFT", lockPanel, "TOPLEFT", x, -82); cb:SetWidth(22); cb:SetHeight(22);
			cb:SetScript("OnShow", function() this:SetChecked(SS.DB()[key] and 1 or nil); end);
			cb:SetScript("OnClick", function() SS.DB()[key] = this:GetChecked() and true or false; if ( SS.DB().unlocked ) then ShowEditGrid(); end end);
			local label = lockPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
			label:SetPoint("LEFT", cb, "RIGHT", 0, 0); label:SetText(labelText);
		end
		AddGridLineToggle(8, "gridCenterVertical", "Vertical red center line");
		AddGridLineToggle(184, "gridCenterHorizontal", "Horizontal red center line");
		local snap = CreateFrame("CheckButton", nil, lockPanel, "UICheckButtonTemplate");
		snap:SetPoint("TOPLEFT", lockPanel, "TOPLEFT", 6, -111); snap:SetWidth(22); snap:SetHeight(22);
		snap:SetScript("OnShow", function() this:SetChecked(SS.DB().anchorSnap and 1 or nil); end);
		snap:SetScript("OnClick", function() SetAnchorSnap(this:GetChecked() and true or false); end);
		local snapLabel = lockPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		snapLabel:SetPoint("LEFT", snap, "RIGHT", 0, 0); snapLabel:SetText("Snap nearby frames together");
		local button = K.Button(lockPanel, "Done", 76, function() SS.SetUnlocked(false); end);
		button:SetPoint("BOTTOMRIGHT", lockPanel, "BOTTOMRIGHT", -8, 7);
		lockPanel.doneButton = button;
		local again = K.Button(lockPanel, "Run setup again", 130, function()
			editOnly = nil; lockPanel:Hide(); SS.StartSetup(true);
		end);
		again:SetPoint("BOTTOMLEFT", lockPanel, "BOTTOMLEFT", 8, 7);
		local choose = K.Button(lockPanel, "Choose element", 210, nil);
		choose:SetPoint("TOPLEFT", lockPanel, "TOPLEFT", 10, -141);
		local all;
		local choices = CreateFrame("Frame", nil, lockPanel);
		choices:SetFrameStrata("TOOLTIP"); choices:SetWidth(216);
		choices:SetHeight(table.getn(MOVABLE) * 23 + 8);
		choices:SetPoint("TOPLEFT", choose, "BOTTOMLEFT", 0, -2);
		if ( choices.SetClampedToScreen ) then choices:SetClampedToScreen(true); end
		choices:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12});
		choices:SetBackdropColor(0.04, 0.035, 0.07, 1);
		for i = 1, table.getn(MOVABLE) do
			local name, label = MOVABLE[i][1], MOVABLE[i][2];
			local row = K.Button(choices, label, 208, function()
				editOnly = name; choose:SetText(label .. " ▼"); all:UnlockHighlight(); choices:Hide();
				if ( sizeMenu ) then sizeMenu:Hide(); end
				SS.SetUnlocked(true, true);
			end);
			row:SetPoint("TOPLEFT", choices, "TOPLEFT", 4, -4 - (i - 1) * 23);
		end
		choices:Hide();
		choose:SetScript("OnClick", function() if ( choices:IsShown() ) then choices:Hide(); else choices:Show(); end end);
		all = K.Button(lockPanel, "ALL?", 62, function()
			editOnly = nil; choose:SetText("Choose element ▼"); all:LockHighlight(); choices:Hide();
			if ( sizeMenu ) then sizeMenu:Hide(); end
			SS.SetUnlocked(true, true);
		end);
		all:SetPoint("LEFT", choose, "RIGHT", 6, 0); all:LockHighlight();
	end
	local saved = SS.DB().lockPanelPosition;
	lockPanel:ClearAllPoints();
	if ( type(saved.x) == "number" and type(saved.y) == "number" ) then
		lockPanel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", saved.x, -saved.y);
	else
		lockPanel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 18, -78);
	end
	for i = 1, table.getn(lockPanel.gridButtons or {}) do
		local pixels = ({16, 32, 64, 128})[i];
		if ( tonumber(SS.DB().gridDivisions) == pixels ) then lockPanel.gridButtons[i]:LockHighlight();
		else lockPanel.gridButtons[i]:UnlockHighlight(); end
	end
	lockPanel:Show();
end

function SS.HideEditGrid()
	if ( editGrid ) then editGrid:Hide(); end
end

ShowEditGrid = function()
	SS.HideEditGrid();
	if ( not SS.DB().showEditGrid or not SS.DB().unlocked ) then return; end
	if ( not editGrid ) then
		editGrid = CreateFrame("Frame", "SlimSuiteEditGrid", UIParent);
		editGrid:SetAllPoints(UIParent);
		editGrid:SetFrameStrata("HIGH");
		editGrid:EnableMouse(false);
		editGrid:SetScript("OnSizeChanged", function()
			if ( SS.DB().showEditGrid and SS.DB().unlocked ) then ShowEditGrid(); end
		end);
	end
	local width, height = UIParent:GetWidth(), UIParent:GetHeight();
	local count, i = 1, 1;
	local function Line(x, y, w, h, color)
		local tex = editGridLines[count];
		if ( not tex ) then tex = editGrid:CreateTexture(nil, "OVERLAY"); editGridLines[count] = tex; end
		count = count + 1;
		tex:ClearAllPoints(); tex:SetPoint("TOPLEFT", editGrid, "TOPLEFT", x, -y); tex:SetWidth(w); tex:SetHeight(h);
		local c = color or { 0.95, 0.76, 0.3, 0.26 };
		tex:SetTexture(c[1], c[2], c[3], c[4]); tex:Show();
	end
	local divisions = tonumber(SS.DB().gridDivisions) or 64;
	-- The chosen count is exact on the shorter edge. The other axis gets the nearest
	-- matching count so cells stay square-like, and every edge is a full grid boundary.
	local shorter = math.min(width, height);
	local longerCount = math.max(divisions, math.floor((math.max(width, height) / shorter) * divisions + 0.5));
	local columns, rows = width <= height and divisions or longerCount, height <= width and divisions or longerCount;
	local edge = { 0.95, 0.76, 0.3, 0.34 };
	Line(0, 0, 1, height, edge); Line(math.max(0, width - 1), 0, 1, height, edge);
	Line(0, 0, width, 1, edge); Line(0, math.max(0, height - 1), width, 1, edge);
	for i = 1, columns - 1 do Line(math.floor(i * width / columns + 0.5), 0, 1, height); end
	for i = 1, rows - 1 do Line(0, math.floor(i * height / rows + 0.5), width, 1); end
	if ( SS.DB().gridCenterVertical ) then Line(math.floor(width / 2), 0, 2, height, { 1, 0.12, 0.12, 0.92 }); end
	if ( SS.DB().gridCenterHorizontal ) then Line(0, math.floor(height / 2), width, 2, { 1, 0.12, 0.12, 0.92 }); end
	for i = count, table.getn(editGridLines) do editGridLines[i]:Hide(); end
	editGrid:Show();
end

function SS.SnapPosition(name, f)
	local left, right, bottom, top = RootBounds(f);
	if ( not left or not right or not bottom or not top ) then SS.SavePlace(name, f); return; end
	local best, bestDistance;
	local threshold = 18;
	for i = 1, table.getn(MOVABLE) do
		local otherName = MOVABLE[i][1];
		local other = otherName ~= name and getglobal(otherName) or nil;
		if ( other ) then
			local ol, oright, ob, ot = RootBounds(other);
			if ( ol and oright and ob and ot ) then
				local overlapX = math.min(right, oright) - math.max(left, ol);
				local overlapY = math.min(top, ot) - math.max(bottom, ob);
				local candidates = {};
				if ( overlapX > 24 ) then
					table.insert(candidates, { math.abs(top - ob), "TOPLEFT", "BOTTOMLEFT", left - ol, top - ob });
					table.insert(candidates, { math.abs(bottom - ot), "BOTTOMLEFT", "TOPLEFT", left - ol, bottom - ot });
				end
				if ( overlapY > 24 ) then
					table.insert(candidates, { math.abs(left - oright), "BOTTOMLEFT", "BOTTOMRIGHT", left - oright, bottom - ob });
					table.insert(candidates, { math.abs(right - ol), "BOTTOMRIGHT", "BOTTOMLEFT", right - ol, bottom - ob });
				end
				for j = 1, table.getn(candidates) do
					local c = candidates[j];
					if ( c[1] <= threshold and (not bestDistance or c[1] < bestDistance) ) then
						bestDistance = c[1]; best = { relative = otherName, point = c[2], relativePoint = c[3], dx = c[4], dy = c[5] };
					end
				end
			end
		end
	end
	local p = { coordinateSpace = "uiParent" };
	if ( best ) then
		for k, v in pairs(best) do p[k] = v; end
	else
		p.x, p.y = left, bottom;
	end
	SS.DB().places[name] = p;
	PlaceAll();
end

function SS.FinishHandleMove(h, name)
	h:SetScript("OnUpdate", nil);   -- the drag step only runs while a drag is in progress
	name = h.mover or name;
	local t = getglobal(name);
	if ( not t or not h.dragging ) then return; end
	h.dragging = nil;
	if ( SS.DB().anchorSnap ) then SS.SnapPosition(name, t);
	else SS.SavePlace(name, t); SS.DB().places[name].relative = nil; SS.Place(name); end
end

function SS.BuffHandleBounds(frame)
	local left, right, bottom, top;
	local limit = MAX_PLAYER_BUFFS or 32;
	for i = 1, limit do
		local button = getglobal("BuffButton" .. i);
		if ( button and button:IsShown() ) then
			local l, r, b, t = RootBounds(button);
			if ( l and r and b and t ) then
				left = left and math.min(left, l) or l; right = right and math.max(right, r) or r;
				bottom = bottom and math.min(bottom, b) or b; top = top and math.max(top, t) or t;
			end
		end
	end
	if ( left and right and bottom and top ) then return left, bottom, right - left, top - bottom; end
	local l, r, b = RootBounds(frame);
	return l or 0, b or 0, 32, 32;
end

-- the frame a handle sits on: its outline follows the frame (the tooltip handle also keeps itself on top)
function SS.FollowHandle(h, name)
	local t = getglobal(name);
	if ( not t ) then return; end
	if ( name == "GameTooltip" and t:IsShown() ) then
		h:SetFrameStrata("TOOLTIP");
		if ( h:GetFrameLevel() <= t:GetFrameLevel() ) then h:SetFrameLevel(t:GetFrameLevel() + 1); end
	end
	h:ClearAllPoints();
	local l, r, b = RootBounds(t);
	if ( l and b ) then
		local x1, y1, x2, y2 = VisualInsets(t);
		h:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l + x1, b + y1);
		h:SetWidth(math.max(1, x2 - x1)); h:SetHeight(math.max(1, y2 - y1));
	end
end

-- one step of a drag: runs each frame only while the handle is being dragged
function SS.DragStep(h, name)
	local t = getglobal(name);
	if ( not t ) then return; end
	if ( IsMouseButtonDown and not IsMouseButtonDown("LeftButton") ) then
		SS.FinishHandleMove(h, name);
		return;
	end
	local scale = UIParent:GetEffectiveScale() or 1;
	local x, y = GetCursorPosition(); x, y = x / scale, y / scale;
	local deltaX, deltaY = x - h.dragStartX, y - h.dragStartY;
	local nextX, nextY = h.frameStartX + deltaX, h.frameStartY + deltaY;
	local moved = getglobal(h.mover or name) or t;
	local minX, minY, maxOffsetX, maxOffsetY = VisualInsets(moved);
	local maxX = UIParent:GetWidth() - maxOffsetX;
	local maxY = UIParent:GetHeight() - maxOffsetY;
	nextX = math.max(-minX, math.min(maxX, nextX));
	nextY = math.max(-minY, math.min(maxY, nextY));
	SetRootPosition(moved, nextX, nextY);
	SS.SavePlace(h.mover or name, moved);          -- keep the newest location even if /reload happens mid-session
	-- mirrored frames move together: drag either one and the other moves the opposite way
	if ( SS.DB().mirrorTarget ) then
		if ( (h.mover or name) == "PlayerFrame" ) then SS.MirrorTarget();
		elseif ( name == "TargetFrame" ) then SS.MirrorPlayer(); end
	end
	SS.FollowHandle(h, name);
end

function SS.Handle(name, label)
	local f = getglobal(name);
	if ( not f ) then return nil; end
	local h = handles[name];
	if ( not h ) then
		h = CreateFrame("Frame", nil, UIParent);
		h:SetFrameStrata("DIALOG");
		h:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		                tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
		if ( name == "GameTooltip" ) then
			h:SetBackdropColor(0, 0, 0, 0); -- keep tooltip text readable while its drag outline is active
			h:SetFrameStrata("TOOLTIP");
			if ( not RootBounds(f) ) then
				local size = SS.DB().sizes.GameTooltip;
				if ( type(size) ~= "table" ) then size = { w = 260, h = 140 }; SS.DB().sizes.GameTooltip = size; end
				f:SetWidth(size.w); f:SetHeight(size.h); f:ClearAllPoints();
				f:SetPoint("CENTER", UIParent, "CENTER", 0, 0); f:Hide();
			end
		else
			h:SetBackdropColor(0.1, 0.6, 0.1, 0.45);
		end
		h:SetBackdropBorderColor(0.3, 1, 0.3, 0.9);
		h:EnableMouse(true);
		h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal");
		h.text:SetPoint("CENTER", h, "CENTER", 0, 0);
		if ( name == "GameTooltip" ) then h.text:Hide(); else h.text:SetText(label); end
		local dragStep = function() SS.DragStep(this, name); end;
		h:SetScript("OnMouseDown", function()
			if ( arg1 == "RightButton" ) then
				SS.OpenSizeMenu(name, label);
				return;
			end
			if ( arg1 ~= "LeftButton" ) then return; end
			if ( IsShiftKeyDown and IsShiftKeyDown() ) then
				SS.ToggleFeatureMute(name);
				return;
			end
			-- The joined jewelry row moves with the spell row: dragging either handle moves the pair.
			this.mover = (name == "SlimSuiteItemRowFrame" and SS.DB().buildRowsAttached) and "SlimSuiteSpellRowFrame" or name;
			local t = getglobal(this.mover);
			if ( not t ) then return; end
			t:SetMovable(true);
			-- We clamp the visible child bounds ourselves below; native clamping would keep the
			-- parent inside the screen and leave a gap when its buttons extend beyond its edges.
			if ( t.SetClampedToScreen ) then t:SetClampedToScreen(false); end
			if ( (name == "BuffFrame" or name == "MainMenuBar" or name == "PartyMemberFrame1") and t.SetUserPlaced ) then SS.UserPlace(t); end
			local scale = UIParent:GetEffectiveScale() or 1;
			local x, y = GetCursorPosition(); x, y = x / scale, y / scale;
			this.dragStartX, this.dragStartY = x, y;
			local left, right, bottom = RootBounds(t);
			this.frameStartX, this.frameStartY = left or x, bottom or y;
			local saved = SS.DB().places[this.mover];
			if ( type(saved) == "table" ) then saved.relative, saved.point, saved.relativePoint, saved.dx, saved.dy = nil, nil, nil, nil, nil; end
			this.dragging = true;
			this:SetScript("OnUpdate", dragStep);
		end);
		h:SetScript("OnMouseUp", function()
			if ( arg1 ~= "LeftButton" ) then return; end
			SS.FinishHandleMove(this, name);
		end);
		h.handleName = name;
		table.insert(handleList, h);   -- the shared follower below keeps every shown handle on its frame
		handles[name] = h;
	end
	return h;
end

-- one shared follower keeps every shown handle on its frame (it replaces a separate OnUpdate per handle)
SS.Every("handleFollow", 0, function()
	for i = 1, table.getn(handleList) do
		local h = handleList[i];
		if ( h:IsShown() ) then SS.FollowHandle(h, h.handleName); end
	end
end);

-- unlocked: the handles show (the frames are shown too, so even an empty party frame can be placed)
function SS.SetUnlocked(on, quiet)
	-- The first time the mover is opened, the setup walks through the UI one element at a time instead.
	if ( on and not quiet and not setupActive and SS.StartSetup ) then
		SS.StartSetup();
		return;
	end
	if ( not on ) then
		if ( setupActive and SS.SetupHide ) then SS.SetupHide(); end   -- its step is kept for next time
		editOnly = nil;
	end
	SS.DB().unlocked = on and true or false;
	if ( on and GameTooltip ) then
		local size = SS.DB().sizes.GameTooltip;
		if ( type(size) ~= "table" ) then size = { w = 260, h = 140 }; SS.DB().sizes.GameTooltip = size; end
		GameTooltip:SetWidth(size.w); GameTooltip:SetHeight(size.h);
		if ( not RootBounds(GameTooltip) ) then
			GameTooltip:ClearAllPoints(); GameTooltip:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
		end
		local saved = SS.DB().places.GameTooltip;
		if ( type(saved) == "table" and saved.x and saved.y ) then SetRootPosition(GameTooltip, saved.x, saved.y); end
		GameTooltip:Hide();
	end
	if ( on ) then
		SS.Safe(SS.PrepareChatWindow);
		-- Reparent the stock XP bar only after the player explicitly opens the mover.
		SS.Safe(SS.DetachExperienceBar);
		SS.Safe(PlaceAll);
	end
	if ( not on and sizeMenu ) then sizeMenu:Hide(); end
	if ( on ) then
		-- Leave the settings/menu window before presenting the in-world mover and its Done control.
		if ( win ) then win:Hide(); end
		if ( setupActive ) then if ( lockPanel ) then lockPanel:Hide(); end
		else SS.ShowLockPanel(); end
	elseif ( lockPanel ) then
		lockPanel:Hide();
	end
	if ( on ) then ShowEditGrid(); else SS.HideEditGrid(); end
	for i = 1, table.getn(MOVABLE) do
		local name = MOVABLE[i][1];
		local isDefault = SS.DB().frameDefault and SS.DB().frameDefault[name];
		if ( on and not isDefault and (not editOnly or editOnly == name) and not (name == "BuffFrame" and (SS.DB().buffsOnTarget or SS.DB().buffsOnPlayer)) ) then
			local ok, h = SS.Safe(SS.Handle, name, MOVABLE[i][2]);
			if ( ok and h ) then h:Show(); end
		elseif ( handles[name] ) then
			handles[name]:Hide();
		end
		if ( SS.DB().muted[name] ) then SS.Safe(ApplyFeatureMute, name); end
	end
	SS.Safe(SS.UpdateLevelButton);
	SS.Safe(UpdateMeter);
	if ( not quiet ) then K.Print(NAME, on and "drag a handle to move it; right-click for size, scale, layout or hide. Shift-left-click hides/shows a feature. Use Lock UI when done." or "the UI is locked."); end
end

function SS.SetMeterReplacement(on)
	SS.DB().moveMeter = on and true or false;
	SS.Safe(UpdateMeter);
end

local tooltipOwnerOriginal;
local tooltipShowOriginal;
function SS.HookTooltipOwner()
	if ( not GameTooltip or tooltipOwnerOriginal or not GameTooltip.SetOwner ) then return; end
	tooltipOwnerOriginal = GameTooltip.SetOwner;
	GameTooltip.SetOwner = function(self, owner, anchor, x, y)
		tooltipOwnerOriginal(self, owner, anchor, x, y);
		if ( self.SetClampedToScreen ) then self:SetClampedToScreen(true); end
		-- Leave every tooltip at the game's own size until the player resizes it or moves it.
		if ( not SS.DB().tooltipCustom and not SS.DB().unlocked ) then return; end
		local size = SS.DB().sizes.GameTooltip;
		if ( type(size) ~= "table" ) then size = { w = 260, h = 140 }; SS.DB().sizes.GameTooltip = size; end
		self:SetWidth(size.w); self:SetHeight(size.h);
		local p = SS.DB().places.GameTooltip;
		if ( SS.DB().unlocked and type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" ) then
			SetRootPosition(self, p.x, p.y);
		end
	end;
	if ( GameTooltip.Show and not tooltipShowOriginal ) then
		tooltipShowOriginal = GameTooltip.Show;
		GameTooltip.Show = function(self)
			local size = (SS.DB().tooltipCustom or SS.DB().unlocked) and SS.DB().sizes.GameTooltip or nil;
			-- Set wrapping width before the game lays out its rows. Applying it only after Show
			-- leaves the old row heights in place and lets long text paint outside the tooltip.
			if ( type(size) == "table" and size.w ) then self:SetWidth(size.w); end
			tooltipShowOriginal(self);
			if ( type(size) == "table" and size.w and size.h ) then
				-- Some game tooltips contain more wrapped rows than the saved preferred height.
				-- Preserve their full measured height instead of letting the last row bleed out.
				local contentHeight = self:GetHeight() or 0;
				self:SetHeight(math.max(size.h, contentHeight));
			end
		end;
	end
end

SetAnchorSnap = function(on)
	SS.DB().anchorSnap = on and true or false;
	if ( not on ) then
		for i = 1, table.getn(MOVABLE) do
			local name = MOVABLE[i][1];
			local p = SS.DB().places[name];
			local f = getglobal(name);
			if ( type(p) == "table" and p.relative and f and not (name == "SlimSuiteItemRowFrame" and SS.DB().buildRowsAttached) ) then
				SS.SavePlace(name, f);
				p.relative, p.point, p.relativePoint, p.dx, p.dy = nil, nil, nil, nil, nil;
			end
		end
		PlaceAll();
	end
	K.Print(NAME, on and "nearby frames will latch together when you move them." or "frames will move independently now.");
end

function SS.ResetPlaces()
	for i = 1, table.getn(MOVABLE) do
		local name = MOVABLE[i][1];
		SS.DB().places[name] = nil;
		local frame = getglobal(name);
		local points = basePoints[name];
		if ( frame and points ) then
			frame:ClearAllPoints();
			for j = 1, table.getn(points) do
				local p = points[j]; frame:SetPoint(p[1], p[2], p[3], p[4], p[5]);
			end
		end
	end
	SS.DB().buildRowsAttached = true;
	SS.DB().places.SlimSuiteSpellRowFrame = SS.BuildRowDefaultPlace("SlimSuiteSpellRowFrame");
	SS.DB().places.SlimSuiteItemRowFrame = SS.BuildRowDefaultPlace("SlimSuiteItemRowFrame");
	PlaceAll();
	K.Print(NAME, "movable elements are back at their original locations.");
end

function SS.ResetElement(name)
	local frame = name and getglobal(name);
	if ( not frame ) then return false; end
	local d = SS.DB();
	d.places[name], d.sizes[name], d.scales[name], d.padding[name], d.orientations[name] = nil, nil, nil, nil, nil;
	if ( name == "SlimSuiteTallyFrame" ) then d.tallyVertical = false; end
	if ( name == "BuffFrame" ) then d.buffCustomLayout = false; d.buffGrowthDirection = "down"; end
	if ( name == "SlimSuiteSpellRowFrame" or name == "SlimSuiteItemRowFrame" ) then
		d.places[name] = SS.BuildRowDefaultPlace(name);
	end
	local points = basePoints[name];
	if ( points and name ~= "GameTooltip" ) then
		frame:ClearAllPoints();
		for i = 1, table.getn(points) do
			local p = points[i]; frame:SetPoint(p[1], p[2], p[3], p[4], p[5]);
		end
	end
	if ( name == "MainMenuBar" and actionBarOriginal and actionBarOriginal.buttonSize ) then
		for i = 1, 6 do
			local button = getglobal("ActionButton" .. i);
			if ( button ) then button:SetWidth(actionBarOriginal.buttonSize); button:SetHeight(actionBarOriginal.buttonSize); end
		end
	end
	local base = baseSizes[name];
	if ( base ) then frame:SetWidth(base.w); frame:SetHeight(base.h); end
	if ( name == "GameTooltip" ) then frame:SetWidth(260); frame:SetHeight(140); d.tooltipCustom = nil; end
	if ( name == "GameTooltip" ) then frame:Hide(); end
	SS.ApplySize(name, frame);
	if ( name == "SlimSuiteTallyFrame" ) then SS.ApplyTallyLayout(false); end
	if ( name == "SlimSuiteBossFrames" ) then SS.UpdateBossFrames(); end
	if ( name == "SlimSuiteAnnouncementFrame" ) then SS.ApplyMovablePadding(name); end
	if ( name == "BuffFrame" ) then SS.Safe(SS.ApplyBuffOrientation); end
	if ( name == "PartyMemberFrame1" or name == "MainMenuExpBar" or name == "MainMenuBar" ) then SS.Safe(ApplyMovableOrientation, name); end
	if ( d.muted[name] ) then d.muted[name] = nil; SS.Safe(ApplyFeatureMute, name); end
	PlaceAll();
	return true;
end

function SS.ResetUI()
	local d = SS.DB();
	d.places, d.sizes, d.scales, d.padding, d.orientations, d.muted = {}, {}, {}, {}, {}, {};
	d.tallyVertical, d.buffCustomLayout, d.buffGrowthDirection = false, false, "down";
	d.tooltipCustom = nil;
	d.buildRowsAttached = true;
	d.places.SlimSuiteSpellRowFrame = SS.BuildRowDefaultPlace("SlimSuiteSpellRowFrame");
	d.places.SlimSuiteItemRowFrame = SS.BuildRowDefaultPlace("SlimSuiteItemRowFrame");
	d.chatOffsets = {};
	for i = 1, table.getn(MOVABLE) do
		local name = MOVABLE[i][1];
		local frame, points, base = getglobal(name), basePoints[name], baseSizes[name];
		if ( frame and points and name ~= "GameTooltip" ) then
			frame:ClearAllPoints();
			for j = 1, table.getn(points) do
				local p = points[j]; frame:SetPoint(p[1], p[2], p[3], p[4], p[5]);
			end
		end
		if ( frame and base ) then frame:SetWidth(base.w); frame:SetHeight(base.h); end
		if ( frame and frame.SetScale ) then frame:SetScale(1); end
	end
	if ( actionBarOriginal and actionBarOriginal.buttonSize ) then
		for i = 1, 6 do
			local button = getglobal("ActionButton" .. i);
			if ( button ) then button:SetWidth(actionBarOriginal.buttonSize); button:SetHeight(actionBarOriginal.buttonSize); end
		end
	end
	if ( GameTooltip ) then GameTooltip:SetWidth(260); GameTooltip:SetHeight(140); GameTooltip:Hide(); end
	if ( type(SS.PrepareChatWindow) == "function" ) then SS.Safe(SS.PrepareChatWindow); end
	if ( type(SS.ApplyTallyLayout) == "function" ) then SS.Safe(SS.ApplyTallyLayout, false); end
	if ( type(SS.UpdateBossFrames) == "function" ) then SS.Safe(SS.UpdateBossFrames); end
	SS.Safe(SS.ApplyMovablePadding, "SlimSuiteAnnouncementFrame");
	if ( type(SS.ApplyBuffOrientation) == "function" ) then SS.Safe(SS.ApplyBuffOrientation); end
	for _, name in ipairs({ "MainMenuBar", "MainMenuExpBar", "PartyMemberFrame1" }) do SS.Safe(ApplyMovableOrientation, name); end
	for i = 1, table.getn(MOVABLE) do
		local name = MOVABLE[i][1];
		SS.Safe(ApplyFeatureMute, name);
	end
	PlaceAll();
	if ( sizeMenu ) then sizeMenu:Hide(); end
	K.Print(NAME, "all movable UI elements are back at their addon defaults.");
end

-- the target frame: hidden for good while the setting is on (this game targets for you)
local targetShow;
function SS.TargetFrameHidden(on)
	if ( not TargetFrame ) then return; end
	if ( not targetShow ) then targetShow = TargetFrame.Show; end
	if ( on ) then
		TargetFrame.Show = function() end;
		TargetFrame:Hide();
	else
		TargetFrame.Show = targetShow;
		if ( UnitExists("target") ) then TargetFrame:Show(); end
	end
end

-- the plain action bar: the gryphons at its ends and all of the bar's art (the game's slices, its own extra ones and
-- the racial's old rim) made see-through. Keep six spell squares and the native racial button;
-- hide only the character and talent micro buttons.
local PLAIN_HIDE = { "CharacterMicroButton", "TalentMicroButton" };
local plainShow = {};
function SS.BarArt(alpha)
	local names = { "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap", "AZS_RacialRim" };
	for i = 0, 3 do table.insert(names, "MainMenuBarTexture" .. i); end
	for i = 4, 12 do table.insert(names, "AZS_MainMenuBarTexture" .. i); end
	for i = 1, table.getn(names) do
		local t = getglobal(names[i]);
		if ( t and t.SetAlpha ) then t:SetAlpha(alpha); end
	end
	-- and every other texture straight on the bar's art frame (the end caps and slices sit there too)
	if ( MainMenuBarArtFrame and MainMenuBarArtFrame.GetRegions ) then
		local regions = { MainMenuBarArtFrame:GetRegions() };
		for i = 1, table.getn(regions) do
			local r = regions[i];
			if ( r and r.GetObjectType and r:GetObjectType() == "Texture" ) then r:SetAlpha(alpha); end
		end
	end
end

-- the bar's own width and its page arrows' places, kept to put back when the plain bar is turned off
local barWidth, arrowUp, arrowDown;
function SS.Narrow(on)
	if ( not MainMenuBar or not ActionButton1 or not ActionButton6 ) then return; end
	if ( not barWidth ) then
		barWidth = MainMenuBar:GetWidth();
		if ( ActionBarUpButton and ActionBarUpButton.GetPoint ) then arrowUp = { ActionBarUpButton:GetPoint(1) }; end
		if ( ActionBarDownButton and ActionBarDownButton.GetPoint ) then arrowDown = { ActionBarDownButton:GetPoint(1) }; end
	end
	if ( on ) then
		-- as wide as the six squares, plus room for the two page arrows on their right, as in the default bar
		local left = ActionButton1:GetLeft() and MainMenuBar:GetLeft() and (ActionButton1:GetLeft() - MainMenuBar:GetLeft()) or 8;
		local squares = ActionButton6:GetRight() and ActionButton1:GetLeft() and (ActionButton6:GetRight() - ActionButton1:GetLeft()) or 252;
		MainMenuBar:SetWidth(left + squares + 34);
		if ( ActionBarUpButton ) then
			ActionBarUpButton:ClearAllPoints();
			ActionBarUpButton:SetPoint("TOPLEFT", ActionButton6, "TOPRIGHT", 2, 6);
		end
		if ( ActionBarDownButton ) then
			ActionBarDownButton:ClearAllPoints();
			ActionBarDownButton:SetPoint("BOTTOMLEFT", ActionButton6, "BOTTOMRIGHT", 2, -6);
		end
	else
		MainMenuBar:SetWidth(barWidth);
		if ( ActionBarUpButton and arrowUp and arrowUp[1] ) then
			ActionBarUpButton:ClearAllPoints();
			ActionBarUpButton:SetPoint(arrowUp[1], arrowUp[2], arrowUp[3], arrowUp[4], arrowUp[5]);
		end
		if ( ActionBarDownButton and arrowDown and arrowDown[1] ) then
			ActionBarDownButton:ClearAllPoints();
			ActionBarDownButton:SetPoint(arrowDown[1], arrowDown[2], arrowDown[3], arrowDown[4], arrowDown[5]);
		end
	end
end

function SS.PlainBar(on)
	if ( not MainMenuBar ) then return; end
	SS.BarArt(on and 0 or 1);
	SS.Safe(ApplyMovableOrientation, "MainMenuBar");
	for i = 1, table.getn(PLAIN_HIDE) do
		local f = getglobal(PLAIN_HIDE[i]);
		if ( f ) then
			if ( not plainShow[f] ) then plainShow[f] = f.Show; end
			if ( on ) then
				f.Show = function() end;
				f:Hide();
			elseif ( f.Show ~= plainShow[f] ) then
				f.Show = plainShow[f];
				f:Show();
			end
		end
	end
end

-- the cooldown numbers: the seconds until each spell square's spell is ready again. The game's spells (AZS_SPELLS, the
-- racial last) map to ActionButton1 to 6, followed by the native racial ActionButton12.
local cdText = {};
SS.Every("cooldowns", 0.1, function()
	local on = SS.DB().cooldowns;
	local spells = type(AZS_SPELLS) == "table" and AZS_SPELLS or {};
	local n = table.getn(spells);
	for i = 1, 7 do
		local btn = getglobal("ActionButton" .. (i == 7 and 12 or i));
		if ( btn ) then
			local t = cdText[i];
			if ( not t ) then
				t = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge");
				t:SetPoint("CENTER", btn, "CENTER", 0, 0);
				t:SetTextColor(1, 0.82, 0);
				cdText[i] = t;
			end
			local sp = i == 7 and spells[n] or ((i < n) and spells[i] or nil);      -- (the last is the racial)
			local left = sp and tonumber(sp.cd) or 0;
			if ( on and left and left > 0.1 ) then
				t:SetText(left >= 10 and tostring(math.floor(left + 0.5)) or string.format("%.1f", left));
				t:Show();
			else t:Hide(); end
		end
	end
end);

-- ---------------------------------------------------------------- first-time setup of the movable UI
-- The first time "Toggle UI Settings" is turned on, Slim Suite walks the player through the interface one element
-- at a time: only that element's green handle shows, outlined in pulsing gold, with a short note and Back / Next.
-- It starts with the unit frame, then the party frames, then the action bar (with its two questions), then the
-- rest of the game's frames and every Slim Suite replacement that is turned on. Locking the UI part way through
-- picks the setup up at the same step next time; "Skip setup" or finishing it ends it for good, and the move
-- panel's "Run setup again" starts it over.
local SU = {};                                           -- the setup's panel, outline and steps

function SU.Steps()
	local d = SS.DB();
	local steps = {
		{ frame = "PlayerFrame", title = d.combineTarget and "Player + target" or "Unit frame",
		  text = "Your hero's frame: health, power and level. Drag the green handle to place it. Right-click the handle for size and scale." },
		{ frame = "PartyMemberFrame1", title = "Party frames",
		  text = "Your friends' frames in co-op. They show now even if you're alone, so you can place them. Right-click to stack them across or down." },
		{ frame = "MainMenuBar", title = "Action bar",
		  text = "Your spells. Drag to place it, right-click for size or to turn it upright." },
	};
	local rest = {
		{ "TargetFrame", "Target frame", "The enemy the game has picked for you.", function() return not d.hideTarget and not d.combineTarget; end },
		{ "MainMenuExpBar", "XP bar", "Your experience bar. It can stand upright too (right-click)." },
		{ "BuffFrame", "Buffs/Debuffs", "Your buffs and debuffs. Right-click to stack them in a column and choose which way they grow. Attached to the target frame, they move and scale with it instead." },
		{ "MinimapCluster", "Minimap", "The minimap, with its pins." },
		{ "ChatFrame1", "Chat", "The chat window, its tab and the box you type in move together." },
		{ "GameTooltip", "Tooltip", "Where tooltips appear while the UI is unlocked, and their size." },
		{ "SlimSuiteStoredLevelsButton", "Level Up", "The movable Level Up button and its store toggle.", function() return d.moveLevelButton; end },
		{ "SlimSuiteSpellRowFrame", "Build rows", "Your build spells, with your worn jewelry joined under them.", function() return d.replaceBuildRows; end },
		{ "SlimSuiteMeterFrame", "Damage meter", "The meter. Its corner grip resizes it any time.", function() return d.moveMeter; end },
		{ "SlimSuiteClockFrame", "Run clock", "Run time and the next boss.", function() return d.replaceClock; end },
		{ "SlimSuiteBossFrames", "Encounter bars", "Boss, Guardian and elite health bars.", function() return d.replaceEncounters; end },
		{ "SlimSuiteTallyFrame", "Kills / Gold / Cache", "Your run's tally.", function() return d.replaceTally; end },
		{ "SlimSuiteAnnouncementFrame", "Announcements", "Where event announcements appear.", function() return d.replaceBanners; end },
		{ "SlimSuiteReviveFrame", "Revive bar", "The bar shown while you bring a friend back.", function() return d.replaceRevive; end },
		{ "SlimSuiteLocalClockFrame", "Local clock", "Your real-world clock. Right-click for 12/24-hour and its background.", function() return d.replaceLocalClock and d.clockDetached; end },
		{ "SlimSuiteCombatTextFrame", "Combat text", "The combat text test box.", function() return d.combatTextBox; end },
	};
	for i = 1, table.getn(rest) do
		local r = rest[i];
		if ( getglobal(r[1]) and (not r[4] or r[4]()) ) then table.insert(steps, { frame = r[1], title = r[2], text = r[3] }); end
	end
	local kept = {};
	for i = 1, table.getn(steps) do
		if ( not (d.setupDisabled and d.setupDisabled[steps[i].frame]) ) then table.insert(kept, steps[i]); end
	end
	steps = kept;
	table.insert(steps, { title = "All set", text = "That's everything. Press Finish to lock the UI. You can move anything again with Toggle UI Settings, and run this setup again from the move panel." });
	return steps;
end

function SU.Check(parent)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate");
	cb:SetWidth(22); cb:SetHeight(22);
	cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0); cb.label:SetJustifyH("LEFT");
	cb.Refresh = function() if ( cb.get ) then cb:SetChecked(cb.get() and 1 or nil); end end;
	cb:SetScript("OnClick", function()
		if ( this.set ) then this.set(this:GetChecked() and true or false); end
		if ( SU.panel and SU.panel:IsShown() ) then for i = 1, table.getn(SU.checks) do SU.checks[i].Refresh(); end end
	end);
	cb:Hide();
	return cb;
end

-- the game's own frames that Slim Suite can move; each one's setup step asks "Movable? (Disables Default UI Element)"
SU.NATIVE = { PlayerFrame = true, TargetFrame = true, PartyMemberFrame1 = true, MinimapCluster = true,
                 BuffFrame = true, MainMenuBar = true, MainMenuExpBar = true, ChatFrame1 = true };

-- Default: put the frame back where the game places it and stop moving it; Movable: Slim Suite places it again
function SU.SetMovable(frame, movable)
	SS.DB().frameDefault = SS.DB().frameDefault or {};
	SS.DB().frameDefault[frame] = (not movable) or nil;
	if ( not movable ) then
		local f = getglobal(frame);
		local pts = basePoints[frame];
		if ( f and pts ) then
			f:ClearAllPoints();
			for i = 1, table.getn(pts) do local p = pts[i]; f:SetPoint(p[1], p[2], p[3], p[4], p[5]); end
			local s = baseSizes[frame];
			if ( s and f.SetWidth ) then f:SetWidth(s.w); f:SetHeight(s.h); end
		end
	end
	SS.DB().places[frame] = nil;
	if ( SS.DB().unlocked ) then SS.Safe(SS.SetUnlocked, true, true); end
end

-- the tick boxes each step offers: that element's own settings, the same ones as in the settings window
function SU.ChecksFor(frame)
	local d = SS.DB();
	-- Entries tagged xref = true refer to another element, so they also appear in that element's right-click menu.
	local function Mirror() return { "Mirror target", function() return SS.DB().mirrorTarget; end, function(v) SS.SetMirrorTarget(v); if ( v and not SS.DB().hideTarget ) then SU.SetOn("TargetFrame", true, SU.titles and SU.titles.TargetFrame or "Target frame"); SU.Focus(SU.focus); end end }; end
	local function MirrorScale() return { "Same size scaling (off: keep its own size)", function() return SS.DB().mirrorSameScale ~= false; end,
		function(v) SS.SetMirrorSameScale(v); end, function() return SS.DB().mirrorTarget; end }; end
	local function Combine() return { "Combine with the target frame (one button)", function() return SS.DB().combineTarget; end,
		function(v) SS.SetCombineTarget(v); end, short = "Combine with target", xref = true }; end
	local function NewSchool() return { "New-school player and target frames", function() return SS.DB().newFrames; end, function(v) SS.SetNewFrames(v); end, short = "New-school frames", xref = true }; end
	local function NewSchoolMirror() return { "...in the new-school design (off: original)", function() return SS.DB().newFrames; end,
		function(v) SS.SetNewFrames(v); end, function() return SS.DB().mirrorTarget; end, short = "New-school design", xref = true }; end
	local function BuffsOn() return { "Buffs on the target frame", function() return SS.DB().buffsOnTarget; end, function(v) SS.SetBuffsOnTarget(v); end }; end
	local function BuffsAbove() return { "...above the target (off: below it)", function() return SS.DB().buffsOnTargetSide == "above"; end,
		function(v) SS.SetBuffsSide(v and "above" or "below"); end }; end
	local function PlayerBuffs() return { "Buffs/Debuffs on the player frame", function() return SS.DB().buffsOnPlayer; end, function(v) SU.SetBuffsPlayer(v); end, short = "Buffs/Debuffs on player", xref = true }; end
	local function PlayerBuffsBelow() return { "Below the player frame (off: above it)", function() return SS.DB().buffsOnPlayerSide == "below"; end,
		function(v) SS.DB().buffsOnPlayerSide = v and "below" or "above"; SS.Safe(SS.AttachBuffs); end,
		function() return SS.DB().buffsOnPlayer; end, short = "Below the player frame", xref = true }; end
	local function LockParty() return { "Lock party frames to the player frame", function() return SS.DB().partyLocked; end,
		function(v) SU.SetPartyOption("partyLocked", v); end, short = "Lock to player frame", xref = true }; end
	local function SelfParty() return { "Add yourself to the party frames (turns the target frame off)", function() return SS.DB().partyIncludesSelf; end,
		function(v) SS.SetPartySelf(v); end, short = "Add yourself to party", xref = true }; end
	local function ShowClock() return { "Show the local clock", function() return SS.DB().replaceLocalClock; end,
		function(v) SS.SetLocalClockOn(v); end, short = "Show the local clock", xref = true }; end
	local function DetachClock() return { "Detach the clock from the minimap (its own button up top)", function() return SS.DB().clockDetached; end,
		function(v) SS.SetClockDetached(v); end, function() return SS.DB().replaceLocalClock; end, short = "Detach from minimap", xref = true }; end
	local function JoinRows() return { "Join the worn-jewelry row under the build spells", function() return SS.DB().buildRowsAttached; end,
		function(v) if ( (v and true or false) ~= (SS.DB().buildRowsAttached and true or false) ) then SS.ToggleBuildRowsAttached(); end end, short = "Join the jewelry row", xref = true }; end
	local list = {
		PlayerFrame = { Combine(), NewSchool(), Mirror(), MirrorScale(), NewSchoolMirror(), PlayerBuffs(), PlayerBuffsBelow(), LockParty(), SelfParty() },
		MainMenuBar = {
			{ "Hide the bar's artwork (only the spell squares stay)", function() return SS.DB().plainBar; end, function(v) SS.DB().plainBar = v; SS.Safe(SS.PlainBar, v); end },
			{ "Show all six buttons at all times, even empty ones", function() return SS.DB().showEmptyActionSlots; end, function(v) SS.DB().showEmptyActionSlots = v; SS.Safe(ApplyActionSlotGrid); end },
			{ "Add your racial as a 7th button", function() return SS.DB().showRacialAbility; end, function(v) SS.Safe(SS.SetRacialAbility, v); end },
			{ "Turn the action bar vertical", function() return SS.DB().orientations.MainMenuBar == "vertical"; end, function(v) SU.SetVertical("MainMenuBar", v); end } },
		TargetFrame = { Mirror(), MirrorScale(), { "Show debuffs and DoTs on the target", function() return SS.DB().targetDebuffs; end, function(v) SS.DB().targetDebuffs = v; end }, BuffsOn(), BuffsAbove(),
			Combine(), NewSchool(), NewSchoolMirror(), SelfParty() },
		BuffFrame = { BuffsOn(), BuffsAbove(), PlayerBuffs(), PlayerBuffsBelow() },
		MinimapCluster = { { "Square minimap (off: round)", function() return SS.DB().minimapSquare; end, function(v) SS.SetMinimapSquare(v); end },
			ShowClock(), DetachClock(),
			{ "Gather the minimap buttons together", function() return SS.DB().gatherButtons; end, function(v) SS.SetGather(v); end },
			{ "...above the minimap", function() return SS.DB().gatherButtons and SS.DB().gatherSide == "above"; end, function(v) if ( v ) then SS.SetGather(true, "above"); end end },
			{ "...below the minimap", function() return SS.DB().gatherButtons and SS.DB().gatherSide == "below"; end, function(v) if ( v ) then SS.SetGather(true, "below"); end end },
			{ "...left of the minimap", function() return SS.DB().gatherButtons and SS.DB().gatherSide == "left"; end, function(v) if ( v ) then SS.SetGather(true, "left"); end end },
			{ "...right of the minimap", function() return SS.DB().gatherButtons and SS.DB().gatherSide == "right"; end, function(v) if ( v ) then SS.SetGather(true, "right"); end end } },
		SlimSuiteClockFrame = { { "Show the zone and Heroic affixes under it", function() return SS.DB().zoneLine; end, function(v) SS.DB().zoneLine = v; end } },
		MainMenuExpBar = { { "Turn the XP bar vertical", function() return SS.DB().orientations.MainMenuExpBar == "vertical"; end,
			function(v) SU.SetVertical("MainMenuExpBar", v); end } },
		PartyMemberFrame1 = {
			LockParty(),
			{ "Show as thin lines, not face plates", function() return SS.DB().partyCompact; end, function(v) SU.SetPartyOption("partyCompact", v); end },
			{ "Show character faces", function() return SS.DB().partyFaces ~= false; end, function(v) SU.SetPartyOption("partyFaces", v); end },
			SelfParty(),
			{ "Horizontal (off: vertical)", function() return SS.DB().orientations.PartyMemberFrame1 == "horizontal"; end, function(v) SU.SetPartyRow(v); end } },
		SlimSuiteBossFrames = { { "Show debuffs on the bars", function() return SS.DB().encounterDebuffs; end, function(v) SS.DB().encounterDebuffs = v; end },
			{ "Vertical", function() return SS.DB().orientations.SlimSuiteBossFrames == "vertical"; end,
			function(v) SS.DB().orientations.SlimSuiteBossFrames = v and "vertical" or "horizontal"; SS.DB().sizes.SlimSuiteBossFrames = nil; SS.Safe(SS.UpdateBossFrames); SS.Safe(PlaceAll); SU.UpdateDemo(); end } },
		SlimSuiteTallyFrame = {
			{ "Show boss and Guardian kills", function() return SS.DB().tallyBossKills; end, function(v) SS.DB().tallyBossKills = v; end },
			{ "Dark band behind it", function() return SS.DB().tallyBackground; end, function(v) SS.DB().tallyBackground = v; end } },
		SlimSuiteLocalClockFrame = {
			{ "Dark background", function() return SS.DB().localClockBackground ~= false; end, function(v) SS.DB().localClockBackground = v; end },
			{ "24-hour time", function() return SlimSuiteWorld and SlimSuiteWorld.ClockIs24 and SlimSuiteWorld.ClockIs24(); end, function(v) SS.DB().localClock24 = v; end },
			ShowClock(), DetachClock() },
		SlimSuiteSpellRowFrame = { JoinRows() },
		SlimSuiteItemRowFrame = { JoinRows() },
	};
	local out = {};
	if ( frame and SU.NATIVE[frame] ) then
		table.insert(out, { "Movable? (Disables Default UI Element)", function() return not (SS.DB().frameDefault and SS.DB().frameDefault[frame]); end,
			function(v) SU.SetMovable(frame, v); end });
	end
	for _, c in ipairs(frame and list[frame] or {}) do table.insert(out, c); end
	return out;
end

-- the settings that refer to another element, for that element's right-click menu
function SS.CrossRefs(name)
	local out = {};
	local list = SU.ChecksFor(name);
	for i = 1, table.getn(list) do if ( list[i].xref ) then table.insert(out, list[i]); end end
	return out;
end

-- the game's own frames and every Slim Suite frame: hidden by alpha during setup, restored when it ends
function SU.Save(f)
	SU.saved = SU.saved or {};
	if ( SU.saved[f] == nil ) then SU.saved[f] = f:GetAlpha() or 1; end
end

-- hide every frame directly under UIParent except the setup's own panel, bar, glow and the handles
-- hide a frame for the setup: remembered if it was shown, so Exit or Complete can show it again
function SU.ForceHide(f)
	if ( not f or not f.SetAlpha ) then return; end
	SU.Save(f);
	SU.shownBefore = SU.shownBefore or {};
	if ( f.IsShown and f:IsShown() and SU.shownBefore[f] == nil ) then SU.shownBefore[f] = true; end
	if ( f.Hide ) then f:Hide(); end
	f:SetAlpha(0);
end

-- Slim Suite's own frames and the game's clock, which are not all children of UIParent
SU.FORCE_HIDE = { "SlimSuiteMeterFrame", "SlimSuiteTallyFrame", "SlimSuiteClockFrame", "SlimSuiteLocalClockFrame",
	"SlimSuiteBossFrames", "SlimSuiteAnnouncementFrame", "SlimSuiteReviveFrame", "SlimSuiteCombatTextFrame",
	"SlimSuiteSpellRowFrame", "SlimSuiteItemRowFrame", "SlimSuiteProcMeter", "SlimSuiteStoredLevelsButton",
	"SlimSuiteStoreLevelsToggle", "SlimSuiteWorldMarkers", "SlimSuiteFloatingText", "SlimSuiteMovePanel", "GameTimeFrame" };

-- the chat windows, their tabs and their input boxes stay visible and usable during setup, so you can always type
SU.KEEP_VISIBLE = {};
for i = 1, 7 do
	SU.KEEP_VISIBLE["ChatFrame" .. i] = true; SU.KEEP_VISIBLE["ChatFrame" .. i .. "Tab"] = true; SU.KEEP_VISIBLE["ChatFrame" .. i .. "EditBox"] = true;
end

-- hide everything that is not the setup's own: the game's UI, Slim Suite's frames, the minimap and its buttons and pins
function SU.HideAll()
	local keep = { [SU.panel] = true, [SU.bar] = true, [SU.glow] = true };
	for name in pairs(SU.KEEP_VISIBLE) do local c = getglobal(name); if ( c ) then keep[c] = true; end end
	for _, h in pairs(handles) do keep[h] = true; end
	local kids = { UIParent:GetChildren() };
	for i = 1, table.getn(kids) do
		local f = kids[i];
		if ( f and not keep[f] ) then SU.ForceHide(f); end
	end
	for _, name in ipairs(SU.FORCE_HIDE) do SU.ForceHide(getglobal(name)); end
	for _, root in ipairs({ Minimap, MinimapCluster }) do
		if ( root and root.GetChildren ) then
			local mkids = { root:GetChildren() };
			for i = 1, table.getn(mkids) do SU.ForceHide(mkids[i]); end
		end
	end
	SU.ForceHide(Minimap); SU.ForceHide(MinimapCluster);
end

-- turn an element on or off: its frame (and the frames that move with it) and its handle
function SU.SetOn(frame, on, title)
	-- the newest choice wins: a target frame turned on or off by its own button takes precedence over the party/combine settings
	if ( frame == "TargetFrame" and on and not SU.restoring and SS.DB().partyIncludesSelf ) then SS.Safe(SS.ClaimTarget, "target"); end
	if ( frame == "TargetFrame" and not on and SS.DB().combineTarget and not SU.restoring and not SU.cascading ) then
		SS.DB().combineTarget = false; SS.Safe(SS.RebuildSetup);
	end
	SU.on = SU.on or {};
	SU.on[frame] = on and true or nil;
	SS.DB().enabledElements = SS.DB().enabledElements or {};
	SS.DB().enabledElements[frame] = on and true or nil;
	if ( frame == "PlayerFrame" and SS.DB().combineTarget and getglobal("TargetFrame") ) then
		SU.cascading = true;
		SU.SetOn("TargetFrame", on, SU.titles and SU.titles.TargetFrame or "Target frame");
		SU.cascading = false;
	end
	local names = { frame };
	for _, c in ipairs(SU.COMPANIONS[frame] or {}) do table.insert(names, c); end
	if ( frame == "TargetFrame" and SS.DB().buffsOnTarget ) then table.insert(names, "BuffFrame"); end
	if ( frame == "PlayerFrame" and SS.DB().buffsOnPlayer ) then table.insert(names, "BuffFrame"); end
	if ( frame == "MinimapCluster" ) then table.insert(names, "Minimap"); table.insert(names, "GameTimeFrame"); end
	for i = 1, table.getn(names) do
		if ( SS.DB().newFrames and names[i] == "PlayerFrame" ) then names[i] = "SlimSuitePlayerCard";
		elseif ( SS.DB().newFrames and names[i] == "TargetFrame" ) then names[i] = "SlimSuiteTargetCard"; end
	end
	for _, fname in ipairs(names) do
		local f = getglobal(fname);
		if ( f and f.SetAlpha ) then
			SU.Save(f);
			if ( on ) then
				if ( SU.shownBefore and SU.shownBefore[f] and f.Show ) then f:Show(); end
				if ( (fname == "SlimSuitePlayerCard" or fname == "SlimSuiteTargetCard") and f.Show ) then f:Show(); end
				f:SetAlpha(SU.saved[f]);
				if ( fname == "TargetFrame" and not SS.DB().hideTarget and f.Show ) then f:Show(); end
				local p = f:GetParent();                     -- a hidden parent would hide the element too
				while ( p and p ~= UIParent and p.SetAlpha ) do SU.Save(p); p:SetAlpha(SU.saved[p]); p = p:GetParent(); end
			elseif ( not SU.KEEP_VISIBLE[fname] ) then
				f:SetAlpha(0);
			end
		end
	end
	if ( frame == "TargetFrame" and not on and SS.DB().mirrorTarget ) then SS.SetMirrorTarget(false); end
	local hname = SS.Shown(frame);
	if ( hname ~= frame and handles[frame] ) then handles[frame]:Hide(); end    -- the hidden frame's handle never shows
	if ( on and not handles[hname] and title ) then SS.Safe(SS.Handle, hname, title); end
	if ( handles[hname] ) then if ( on ) then handles[hname]:Show(); else handles[hname]:Hide(); end end
	if ( not SU.batching ) then SU.RefreshBar(); SU.UpdateDemo(); end
end

-- the grid: the setting, the bar button and the panel's tick box all agree
function SU.SetGridSetting(on)
	SS.DB().showEditGrid = on and true or false;
	if ( on ) then SS.Safe(ShowEditGrid); end
	SU.SetOn("SlimSuiteEditGrid", on and true or false);
	if ( SU.grid ) then SU.grid.Refresh(); end
end

-- the action bar: vertical or horizontal, kept until changed
function SU.SetVertical(name, on)
	SS.DB().orientations[name] = on and "vertical" or "horizontal";
	SS.Safe(ApplyMovableOrientation, name);
	SS.Safe(PlaceAll);
	SU.UpdateDemo();
	if ( SU.checks ) then for i = 1, table.getn(SU.checks) do SU.checks[i].Refresh(); end end
end

-- the party demo: five sample members where the party frames stand, while the party element is on
SU.PARTY_SAMPLE = { { "Brann", "Priest", 82 }, { "Lyra", "Mage", 55 },
                       { "Tomas", "Hunter", 100 }, { "Velka", "Warrior", 30 } };
SU.CLASS_RGB = { Warrior = { 0.78, 0.61, 0.43 }, Priest = { 1, 1, 1 }, Mage = { 0.41, 0.8, 0.94 },
                    Hunter = { 0.67, 0.83, 0.45 }, Rogue = { 1, 0.96, 0.41 } };

-- the class icons (one sheet, a quarter of it per class) for the faces in the party demo
SU.CLASS_ICON = { Warrior = { 0, 0.25, 0, 0.25 }, Mage = { 0.25, 0.49, 0, 0.25 }, Rogue = { 0.49, 0.73, 0, 0.25 },
	Druid = { 0.73, 0.98, 0, 0.25 }, Hunter = { 0, 0.25, 0.25, 0.5 }, Priest = { 0.25, 0.49, 0.25, 0.5 },
	Paladin = { 0.49, 0.73, 0.25, 0.5 }, Shaman = { 0.73, 0.98, 0.25, 0.5 }, Warlock = { 0, 0.25, 0.5, 0.75 } };

-- the party demo: the four teammates as face plates or thin lines, in a column or a row (Party frames step)
function SU.BuildDemo()
	local compact = SS.DB().partyCompact and true or false;
	local across = SS.DB().orientations.PartyMemberFrame1 == "horizontal";
	local demo = CreateFrame("Frame", "SlimSuitePartyDemo", UIParent);
	local thick = compact and 16 or 36;
	local gap = compact and 3 or 4;
	local cardW = across and (compact and 100 or 112) or 180;
	local nameW = (compact and across) and 44 or 70;
	demo:SetFrameStrata("HIGH");
	if ( across ) then demo:SetWidth(4 * cardW + 3 * gap); demo:SetHeight(thick);
	else demo:SetWidth(cardW); demo:SetHeight(4 * (thick + gap) - gap); end
	demo.cards = {};
	for i = 1, 4 do
		local s = SU.PARTY_SAMPLE[i];
		local card = CreateFrame("Frame", nil, demo);
		card:SetWidth(cardW); card:SetHeight(thick);
		if ( across ) then card:SetPoint("TOPLEFT", demo, "TOPLEFT", (i - 1) * (cardW + gap), 0);
		else card:SetPoint("TOPLEFT", demo, "TOPLEFT", 0, -((i - 1) * (thick + gap))); end
		local rgb = SU.CLASS_RGB[s[2]] or { 1, 1, 1 };
		local hp = CreateFrame("StatusBar", nil, card);
		hp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
		hp:SetMinMaxValues(0, 100); hp:SetValue(s[3]);
		hp:SetStatusBarColor(0.2, 0.75, 0.2);
		local faces = SS.DB().partyFaces ~= false;
		local face = card:CreateTexture(nil, "ARTWORK");
		local coords = SU.CLASS_ICON[s[2]] or { 0, 1, 0, 1 };
		face:SetTexture("Interface\\WorldStateFrame\\ICONS-CLASSES");
		face:SetTexCoord(coords[1], coords[2], coords[3], coords[4]);
		if ( faces ) then face:Show(); else face:Hide(); end
		card.face = face;
		if ( compact ) then
			face:SetWidth(12); face:SetHeight(12); face:SetPoint("LEFT", card, "LEFT", 2, 0);
			card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
			card.name:SetPoint("LEFT", card, "LEFT", faces and 16 or 2, 0); card.name:SetWidth(nameW); card.name:SetJustifyH("LEFT");
			hp:SetPoint("LEFT", card, "LEFT", nameW + (faces and 20 or 6), 0); hp:SetPoint("RIGHT", card, "RIGHT", -2, 0); hp:SetHeight(6);
		else
			card:SetBackdrop(SU.CARD_BACKDROP);
			card:SetBackdropColor(0.05, 0.05, 0.05, 0.9);
			card:SetBackdropBorderColor(0.85, 0.65, 0.2, 1);
			face:SetWidth(26); face:SetHeight(26); face:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -4);
			card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal");
			card.name:SetPoint("TOPLEFT", card, "TOPLEFT", faces and 34 or 6, -4);
			card.class = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
			card.class:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -6); card.class:SetText(s[2]);
			hp:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 5, 5); hp:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -5, 5); hp:SetHeight(8);
		end
		card.name:SetText(s[1]); card.name:SetTextColor(rgb[1], rgb[2], rgb[3]);
		card.hp = hp;
		demo.cards[i] = card;
	end
	demo:Hide();
	return demo;
end

-- the party options in the Party frames step: locked to the player frame, thin lines, and a row
function SU.SetPartyOption(key, on)
	SS.DB()[key] = on and true or false;
	if ( SU.demo ) then SU.demo:Hide(); SU.demo = nil; end
	SS.Safe(PlaceAll);
	SU.UpdateDemo();
end

-- a row (horizontal) or a column (vertical) of party frames
function SU.SetPartyRow(on)
	SS.DB().orientations.PartyMemberFrame1 = on and "horizontal" or "vertical";
	-- Not wrapped in pcall: a failure here should reach the error log instead of silently doing nothing.
	ApplyMovableOrientation("PartyMemberFrame1");
	PlaceAll();
	ApplyMovableOrientation("PartyMemberFrame1");   -- placing can re-anchor the leader, so lay the others out again
	if ( SU.demo ) then SU.demo:Hide(); SU.demo = nil; end
	SU.UpdateDemo();
end

SU.CARD_BACKDROP = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                        tile = true, tileSize = 16, edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } };
SU.BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar";
SU.BOSS_SAMPLE = { { "Hogger", 60 }, { "Mr. Smite", 40 }, { "Edwin VanCleef", 85 } };   -- real Elwynn Forest bosses

-- The new-school player and target frames: cards in the party frames' look, showing name, health and power.
-- They are only shown while the design is on; the game's own frames are made transparent (not removed) meanwhile.
function SS.RefreshCard(f)
	if ( not f ) then return; end
	if ( f.slimParty and not SS.DB().partyIncludesSelf ) then f:Hide(); return; end
	if ( not f.slimParty and not SS.DB().newFrames ) then f:Hide(); return; end
	local unit = f.unit;
	if ( not UnitExists(unit) ) then
		if ( setupActive and unit == "target" ) then
			f.name:SetText("No target"); f.name:SetTextColor(0.6, 0.6, 0.6);
			f.hp:SetMinMaxValues(0, 1); f.hp:SetValue(1); f.hpText:SetText("");
			f.power:SetMinMaxValues(0, 1); f.power:SetValue(0);
			f:Show();
		elseif ( setupActive and unit == "player" ) then
			f.name:SetText(UnitName("player") or "You"); f.name:SetTextColor(1, 1, 1);
			f.hp:SetMinMaxValues(0, 1); f.hp:SetValue(1); f.hpText:SetText("");
			f.power:SetMinMaxValues(0, 1); f.power:SetValue(0);
			f:Show();
		else
			f:Hide();
		end
		return;
	end
	if ( f.slimParty and not SS.DB().partyIncludesSelf ) then f:Hide(); return; end
	if ( not f.slimParty and not SS.DB().newFrames ) then f:Hide(); return; end
	if ( unit == "target" and not f.slimParty and SS.DB().hideTarget ) then f:Hide(); return; end
	local rgb = { 1, 1, 1 };
	if ( UnitIsPlayer(unit) ) then
		local cls = UnitClass(unit);
		rgb = SU.CLASS_RGB[cls] or rgb;
	elseif ( UnitIsEnemy and UnitIsEnemy("player", unit) ) then
		rgb = { 0.9, 0.25, 0.25 };
	else
		rgb = { 0.6, 0.9, 0.3 };
	end
	f.name:SetText(UnitName(unit) or ""); f.name:SetTextColor(rgb[1], rgb[2], rgb[3]);
	local hp, hpMax = UnitHealth(unit) or 0, UnitHealthMax(unit) or 1;
	if ( hpMax < 1 ) then hpMax = 1; end
	f.hp:SetMinMaxValues(0, hpMax); f.hp:SetValue(hp); f.hpText:SetText(hp .. " / " .. hpMax);
	local pw, pwMax = UnitMana(unit) or 0, UnitManaMax(unit) or 1;
	if ( pwMax < 1 ) then pwMax = 1; end
	local kind = UnitPowerType(unit);
	local pc = { 0.2, 0.4, 1 };
	if ( kind == 1 ) then pc = { 0.9, 0.15, 0.15 }; elseif ( kind == 3 ) then pc = { 1, 0.9, 0.2 }; end
	f.power:SetStatusBarColor(pc[1], pc[2], pc[3]);
	f.power:SetMinMaxValues(0, pwMax); f.power:SetValue(pw);
	f:Show();
end

-- The target's buff and debuff tooltips ask the game for buff number "index" of the target. Hovering an icon with no
-- target, or one of Slim Suite's demo icons, gives no valid number, so the game shows an error. Only call the
-- game's own tooltip when that buff really exists.
function SS.GuardTargetTooltips()
	for kind, lookup in pairs({ TargetFrameBuff = UnitBuff, TargetFrameDebuff = UnitDebuff }) do
		for i = 1, 40 do
			local f = getglobal(kind .. i);
			if ( f and f.GetScript and not f.slimGuarded ) then
				local original = f:GetScript("OnEnter");
				if ( original ) then
					f.slimGuarded = true;
					f:SetScript("OnEnter", function()
						local id = this:GetID();
						if ( id and UnitExists("target") and lookup("target", id) ) then original(); end
					end);
				end
			end
		end
	end
end

function SS.MakeCards()
	if ( getglobal("SlimSuitePlayerCard") ) then return; end
	local function Make(name, unit)
		local f = CreateFrame("Button", name, UIParent);
		f:SetWidth(180); f:SetHeight(44); f:SetFrameStrata("MEDIUM");
		f:SetBackdrop(SU.CARD_BACKDROP);
		f:SetBackdropColor(0.05, 0.05, 0.05, 0.9);
		f:SetBackdropBorderColor(0.85, 0.65, 0.2, 1);
		f.unit = unit;
		f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal");
		f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -4);
		f.hp = CreateFrame("StatusBar", nil, f);
		f.hp:SetStatusBarTexture(SU.BAR_TEXTURE); f.hp:SetStatusBarColor(0.2, 0.75, 0.2);
		f.hp:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 5, 11); f.hp:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 11); f.hp:SetHeight(9);
		f.hpText = f.hp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		f.hpText:SetPoint("CENTER", f.hp, "CENTER", 0, 0);
		f.power = CreateFrame("StatusBar", nil, f);
		f.power:SetStatusBarTexture(SU.BAR_TEXTURE);
		f.power:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 5, 5); f.power:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 5); f.power:SetHeight(4);
		SS.cardFrames = SS.cardFrames or {};
		table.insert(SS.cardFrames, f);
		SS.Every("cards", 0.2, function()
			for i = 1, table.getn(SS.cardFrames) do
				local c = SS.cardFrames[i];
				if ( c:IsShown() ) then SS.RefreshCard(c); end
			end
		end);
		f:Hide();
		return f;
	end
	Make("SlimSuitePlayerCard", "player");
	Make("SlimSuiteTargetCard", "target");
	local self = Make("SlimSuitePartySelfCard", "player");
	self.slimParty = true;
end

-- the game's frames fade out and the cards show while the design is on (only outside the setup, which owns visibility)
function SS.ApplyNewFrames()
	local cp, ct = getglobal("SlimSuitePlayerCard"), getglobal("SlimSuiteTargetCard");
	if ( not cp or not ct ) then return; end
	local on = SS.DB().newFrames and true or false;
	if ( not setupActive ) then
		local P, T = getglobal("PlayerFrame"), getglobal("TargetFrame");
		if ( P and P.SetAlpha ) then P:SetAlpha(on and 0 or 1); end
		if ( T and T.SetAlpha ) then T:SetAlpha(on and 0 or 1); end
	end
	SS.RefreshCard(cp); SS.RefreshCard(ct);
end

-- a card with a name and a health bar; the caller places it
function SU.MakeCard(parent, w, h, name, pct)
	local card = CreateFrame("Frame", nil, parent);
	card:SetWidth(w); card:SetHeight(h);
	card:SetBackdrop(SU.CARD_BACKDROP);
	card:SetBackdropColor(0.05, 0.05, 0.05, 0.9);
	card:SetBackdropBorderColor(0.85, 0.65, 0.2, 1);
	card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	card.name:SetText(name);
	card.hp = CreateFrame("StatusBar", nil, card);
	card.hp:SetStatusBarTexture(SU.BAR_TEXTURE);
	card.hp:SetMinMaxValues(0, 100); card.hp:SetValue(pct);
	card.hp:SetStatusBarColor(0.8, 0.2, 0.15);
	return card;
end

-- the target demo: a real elite, Hogger, as the fake target
function SU.BuildTargetDemo()
	local demo = CreateFrame("Frame", "SlimSuiteTargetDemo", UIParent);
	demo:SetFrameStrata("DIALOG"); demo:SetWidth(200); demo:SetHeight(46);
	local card = SU.MakeCard(demo, 200, 46, "Hogger", 70);
	card:SetPoint("TOPLEFT", demo, "TOPLEFT", 0, 0); card:SetPoint("BOTTOMRIGHT", demo, "BOTTOMRIGHT", 0, 0);
	card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -4);
	card.level = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
	card.level:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -6); card.level:SetText("Elite");
	card.hp:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 5, 5); card.hp:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -5, 5);
	card.hp:SetHeight(10);
	demo.card = card;
	demo:Hide();
	return demo;
end

-- the boss demo: three real bosses, laid out the way the encounter bars are set (Vertical)
function SU.BuildBossDemo()
	local demo = CreateFrame("Frame", "SlimSuiteBossDemo", UIParent);
	demo:SetFrameStrata("DIALOG");
	demo.cards = {};
	for i = 1, 3 do demo.cards[i] = SU.MakeCard(demo, 100, 100, SU.BOSS_SAMPLE[i][1], SU.BOSS_SAMPLE[i][2]); end
	demo:Hide();
	return demo;
end

function SU.LayoutBossDemo(demo)
	local vertical = SS.DB().orientations.SlimSuiteBossFrames == "vertical";
	for i = 1, 3 do
		local card = demo.cards[i];
		card:ClearAllPoints(); card.name:ClearAllPoints(); card.hp:ClearAllPoints();
		if ( vertical ) then
			card:SetWidth(84); card:SetHeight(190);
			card:SetPoint("TOPLEFT", demo, "TOPLEFT", (i - 1) * 90, 0);
			card.name:SetWidth(80); card.name:SetPoint("TOP", card, "TOP", 0, -6);
			card.hp:SetPoint("BOTTOM", card, "BOTTOM", 0, 8); card.hp:SetWidth(18); card.hp:SetHeight(150);
			if ( card.hp.SetOrientation ) then SS.Safe(card.hp.SetOrientation, card.hp, "VERTICAL"); end
		else
			card:SetWidth(260); card:SetHeight(34);
			card:SetPoint("TOPLEFT", demo, "TOPLEFT", 0, -(i - 1) * 40);
			card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -4);
			card.hp:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 5, 5); card.hp:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -5, 5);
			card.hp:SetHeight(10);
			if ( card.hp.SetOrientation ) then SS.Safe(card.hp.SetOrientation, card.hp, "HORIZONTAL"); end
		end
	end
	demo:SetWidth(vertical and 264 or 260); demo:SetHeight(vertical and 200 or 116);
end

-- the real abilities each class uses: buffs on the player and the debuffs they bring
SU.CLASS_BUFF = { Priest = "Spell_Holy_WordFortitude", Mage = "Spell_Arcane_ArcaneIntellect",
                  Hunter = "Spell_Nature_RavenForm", Warrior = "Ability_Warrior_BattleShout" };
SU.CLASS_DEBUFF = { Priest = "Spell_Shadow_ShadowWordPain", Mage = "Spell_Frost_FrostBolt02",
                    Hunter = "Ability_Hunter_SniperShot", Warrior = "Ability_Warrior_Sunder" };

-- the buff demo: one buff per teammate on the top row, one debuff per teammate below
function SU.BuildBuffDemo()
	local demo = CreateFrame("Frame", "SlimSuiteBuffDemo", UIParent);
	demo:SetFrameStrata("HIGH"); demo:SetWidth(4 * 24 - 2); demo:SetHeight(48);
	demo.icons = {};
	for row = 1, 2 do
		for i = 1, 4 do
			local s = SU.PARTY_SAMPLE[i];
			local tex = (row == 1) and SU.CLASS_BUFF[s[2]] or SU.CLASS_DEBUFF[s[2]];
			local b = CreateFrame("Frame", nil, demo);
			b:SetWidth(22); b:SetHeight(22);
			b:SetPoint("TOPLEFT", demo, "TOPLEFT", (i - 1) * 24, -(row - 1) * 25);
			local icon = b:CreateTexture(nil, "ARTWORK");
			icon:SetAllPoints(b);
			icon:SetTexture("Interface\\Icons\\" .. (tex or "INV_Misc_QuestionMark"));
			if ( row == 2 ) then icon:SetVertexColor(1, 0.45, 0.45); end
			demo.icons[(row - 1) * 4 + i] = b;
		end
	end
	demo:Hide();
	return demo;
end

-- the demos stand where their elements are, while those elements are on; the real frames are hidden behind them
function SU.UpdateDemo()
	local on = SU.on or {};
	if ( on.PartyMemberFrame1 ) then
		if ( not SU.demo ) then SU.demo = SU.BuildDemo(); end
		SU.demo:ClearAllPoints();
		SU.demo:SetPoint("TOPLEFT", PartyMemberFrame1 or UIParent, "TOPLEFT", 0, 0);
		SU.demo:Show();
		for i = 1, 4 do local p = getglobal("PartyMemberFrame" .. i); if ( p and p.SetAlpha ) then SU.Save(p); p:SetAlpha(0); end end
	elseif ( SU.demo ) then
		SU.demo:Hide();
	end
	if ( on.TargetFrame and not SS.DB().hideTarget ) then
		if ( not SU.targetDemo ) then SU.targetDemo = SU.BuildTargetDemo(); end
		SU.targetDemo:ClearAllPoints();
		SU.targetDemo:SetPoint("TOPLEFT", TargetFrame or UIParent, "TOPLEFT", 0, 0);
		SU.targetDemo:Show();
		if ( TargetFrame ) then SU.Save(TargetFrame); TargetFrame:SetAlpha(0); end
	elseif ( SU.targetDemo ) then
		SU.targetDemo:Hide();
	end
	local buffFrame = getglobal("BuffFrame");
	if ( on.BuffFrame ) then
		if ( not SU.buffDemo ) then SU.buffDemo = SU.BuildBuffDemo(); end
		SU.buffDemo:ClearAllPoints();
		SU.buffDemo:SetPoint("TOPLEFT", buffFrame or UIParent, "TOPLEFT", 0, 0);
		SU.buffDemo:Show();
		if ( buffFrame and buffFrame.SetAlpha ) then SU.Save(buffFrame); buffFrame:SetAlpha(0); end
	elseif ( SU.buffDemo ) then
		SU.buffDemo:Hide();
	end
	local bossFrame = getglobal("SlimSuiteBossFrames");
	if ( on.SlimSuiteBossFrames ) then
		if ( not SU.bossDemo ) then SU.bossDemo = SU.BuildBossDemo(); end
		SU.LayoutBossDemo(SU.bossDemo);
		SU.bossDemo:ClearAllPoints();
		SU.bossDemo:SetPoint("TOPLEFT", bossFrame or UIParent, "TOPLEFT", 0, 0);
		SU.bossDemo:Show();
		if ( bossFrame and bossFrame.SetAlpha ) then SU.Save(bossFrame); bossFrame:SetAlpha(0); end
	elseif ( SU.bossDemo ) then
		SU.bossDemo:Hide();
	end
end

-- buffs can sit above or below the player frame too; the target and the player share the one buff bar
function SU.SetBuffsPlayer(on)
	SS.DB().buffsOnPlayer = on and true or false;
	if ( on ) then SS.DB().buffsOnTarget = false; end
	if ( on ) then SS.Safe(SS.AttachBuffs); else SS.Safe(PlaceAll); end
	SU.RefreshBar();
	if ( SU.focus ) then SU.Focus(SU.focus); end
end

function SU.RefreshBar()
	for frame, b in pairs(SU.barButtons or {}) do
		local on = SU.on and SU.on[frame];
		if ( on ) then b:LockHighlight(); else b:UnlockHighlight(); end
		if ( b.tag ) then if ( on ) then b.tag:Show(); else b.tag:Hide(); end end
		if ( frame == "BuffFrame" ) then
			local fs = b.GetFontString and b:GetFontString();
			local text = SS.DB().buffsOnPlayer and "DISABLED" or "Buffs/Debuffs";
			if ( fs ) then fs:SetText(text); elseif ( b.SetText ) then b:SetText(text); end
		end
	end
end

-- the panel shows one element's own questions, placed just below that element's handle
-- the size buttons: the chosen grid size is lit
function SU.RefreshGridButtons()
	local sizes = { 16, 32, 64, 128 };
	for i = 1, 4 do
		if ( SU.sizes and SU.sizes[i] ) then
			if ( tonumber(SS.DB().gridDivisions) == sizes[i] ) then SU.sizes[i]:LockHighlight(); else SU.sizes[i]:UnlockHighlight(); end
		end
	end
end

function SU.Focus(frame)
	SU.focus = frame;
	local e;
	for i = 1, table.getn(SU.elements or {}) do if ( SU.elements[i].frame == frame ) then e = SU.elements[i]; end end
	local checks = {};
	if ( e ) then
		SU.panel.title:SetText(e.title);
		SU.panel.text:SetText(e.text);
		checks = SU.ChecksFor(frame);
	else
		SU.panel.title:SetText("Setup");
		SU.panel.text:SetText("Click an element on the bar above to turn it on, then set its options here. Click it again to turn it off.");
	end
	local h = 58 + (SU.panel.text:GetHeight() or 28) + 40;
	for i = 1, 10 do
		local cb, c = SU.checks[i], checks[i];
		if ( c ) then
			cb.label:SetText(c[1]); cb.get, cb.set = c[2], c[3];
			cb:ClearAllPoints();
			-- a setting that only works with another one is indented under it
			local dx = c[4] and 20 or 0;
			cb.indentX = dx;
			if ( i == 1 ) then cb:SetPoint("TOPLEFT", SU.panel.text, "BOTTOMLEFT", -2 + dx, -4);
			else cb:SetPoint("TOPLEFT", SU.checks[i - 1], "BOTTOMLEFT", dx - (SU.checks[i - 1].indentX or 0), 0); end
			cb.Refresh(); cb:Show();
			if ( c[4] and not c[4]() ) then cb:Disable(); cb.label:SetTextColor(0.45, 0.45, 0.45);
			else cb:Enable(); cb.label:SetTextColor(1, 1, 1); end
			h = h + 24;
		else
			cb.get, cb.set = nil, nil; cb:Hide();
		end
	end
	SU.panel:SetHeight(h);
	if ( SU.grid ) then SU.grid.Refresh(); end
	SU.RefreshGridButtons();
	local handle = frame and handles[SS.Shown(frame)];
	SU.panel:ClearAllPoints();
	if ( handle and handle:IsShown() ) then SU.panel:SetPoint("TOP", handle, "BOTTOM", 0, -14);
	else SU.panel:SetPoint("TOP", UIParent, "TOP", 0, -110); end
	SU.panel:Show();
	SU.glow.handle = handle;
	if ( handle ) then
		SU.glow:ClearAllPoints();
		SU.glow:SetPoint("TOPLEFT", handle, "TOPLEFT", -6, 6);
		SU.glow:SetPoint("BOTTOMRIGHT", handle, "BOTTOMRIGHT", 6, -6);
		SU.glow:Show();
	else
		SU.glow:Hide();
	end
	SU.RefreshBar();
end

-- rebuilds the setup's top bar after an element was added or removed from it, keeping the open questions
function SU.Rebuild()
	if ( not setupActive ) then return; end
	local f = SU.focus;
	SU.Begin();
	for i = 1, table.getn(SU.elements or {}) do if ( f and SU.elements[i].frame == f ) then SU.Focus(f); end end
end

-- the new-school design for the player and target frames (the same switch as the sub-option under Mirror target)
function SS.RebuildSetup()
	if ( SU.Rebuild ) then SU.Rebuild(); end
end

function SS.SetNewFrames(on)
	SS.DB().newFrames = on and true or false;
	SS.Safe(SS.ApplyNewFrames);
	if ( setupActive and SU.on ) then
		for _, el in ipairs({ "PlayerFrame", "TargetFrame" }) do
			if ( SU.on[el] ) then
				local old = on and el or (el == "PlayerFrame" and "SlimSuitePlayerCard" or "SlimSuiteTargetCard");
				local of = getglobal(old);
				if ( of ) then SU.Save(of); of:SetAlpha(0); end
				if ( handles[old] ) then handles[old]:Hide(); end
				SU.SetOn(el, true, SU.titles and SU.titles[el]);
			end
		end
	end
	if ( SS.DB().mirrorTarget ) then SS.Safe(SS.MirrorTarget); end
	if ( setupActive and SU.focus ) then SU.Focus(SU.focus); end
end

-- Settings that cannot both be on: the one chosen last wins and the other is turned off (it can be turned back on).
--   "self"   you join the party frames: the target frame goes off, and mirroring with it
--   "mirror" mirroring starts: you leave the party frames and the target frame comes back
--   "target" the target frame is turned on from its button: you leave the party frames
function SS.ClaimTarget(by)
	if ( by == "self" ) then
		SS.DB().hideTarget = true; SS.Safe(SS.TargetFrameHidden, true);
		if ( SS.DB().mirrorTarget ) then SS.SetMirrorTarget(false); end
		if ( SU.on and SU.on.TargetFrame ) then SU.SetOn("TargetFrame", false, SU.titles and SU.titles.TargetFrame or "Target frame"); end
		return;
	end
	if ( SS.DB().partyIncludesSelf ) then
		SS.DB().partyIncludesSelf = false;
		SS.Safe(ApplyMovableOrientation, "PartyMemberFrame1");
	end
	if ( by ~= "self" and SS.DB().hideTarget ) then SS.DB().hideTarget = false; SS.Safe(SS.TargetFrameHidden, false); end
end

-- You in the party frames: your own card joins the end of the party column or row. It takes the target frame's
-- place, so the target frame is turned off and mirroring is turned off with it.
function SS.SetPartySelf(on)
	SS.DB().partyIncludesSelf = on and true or false;
	if ( on ) then SS.ClaimTarget("self"); end
	SS.Safe(ApplyMovableOrientation, "PartyMemberFrame1");
	if ( SU.demo ) then SU.demo:Hide(); SU.demo = nil; end
	SU.Rebuild();
	SU.UpdateDemo();
end

function SS.SetCombineTarget(on)
	SS.DB().combineTarget = on and true or false;
	SU.Rebuild();
end

function SS.SetLocalClockOn(on)
	SS.DB().replaceLocalClock = on and true or false;
	SS.Safe(SlimSuiteWorld.UpdateLocalClock);
	SU.Rebuild();
end

function SS.SetClockDetached(on)
	SS.DB().clockDetached = on and true or false;
	if ( SlimSuiteWorld and SlimSuiteWorld.SetClockDetached ) then SS.Safe(SlimSuiteWorld.SetClockDetached, SS.DB().clockDetached); end
	SU.Rebuild();
end

-- a bar button: first click turns the element on and opens its questions; clicking the open one turns it off
function SU.Click(frame)
	if ( frame == "SlimSuiteEditGrid" ) then SU.SetGridSetting(not (SU.on and SU.on[frame])); return; end
	local was = SU.on and SU.on[frame];
	SU.SetOn(frame, not was, SU.titles[frame]);
	if ( was ) then
		if ( SU.focus == frame ) then SU.Focus(nil); end
	else
		SU.Focus(frame);
	end
end

-- the setup: everything hidden, one bar of elements, all off
function SU.Begin()
	if ( not SU.panel ) then SU.Build(); end
	editOnly = "SlimSuiteSetupNothing";                  -- no handles until an element is turned on
	SS.SetUnlocked(true, true);
	SU.on = {};
	SU.elements = {};
	local steps = SU.Steps();
	for i = 1, table.getn(steps) do if ( steps[i].frame and steps[i].frame ~= "SlimSuiteEditGrid" ) then table.insert(SU.elements, steps[i]); end end
	local hasMeter = false;
	for i = 1, table.getn(SU.elements) do if ( SU.elements[i].frame == "SlimSuiteMeterFrame" ) then hasMeter = true; end end
	if ( not hasMeter ) then table.insert(SU.elements, { frame = "SlimSuiteMeterFrame", title = "Damage meter", text = "The damage meter. Its corner grip resizes it any time." }); end
	SU.titles = {};
	for i = 1, table.getn(SU.elements) do SU.titles[SU.elements[i].frame] = SU.elements[i].title; end
	SU.HideAll();
	SS.Safe(SS.SetNativeMeterHidden, true);
	local saved = SS.DB().enabledElements or {};
	SU.restoring = true;
	SU.batching = true;      -- one bar and demo refresh at the end, not one per element
	-- one element failing to come back must not stop the rest of the setup from opening (the error is still shown)
	for i = 1, table.getn(SU.elements) do local f = SU.elements[i].frame; SS.Safe(SU.SetOn, f, saved[f] and true or false, SU.titles[f]); end
	SU.batching = false;
	SU.restoring = false;
	-- the bar: one button per element
	SU.barButtons = SU.barButtons or {};
	local wanted, x, row, widest = {}, 8, 0, 8;
	local maxW = (UIParent:GetWidth() or 1024) - 40;   -- the bar wraps onto a new row rather than running off the screen
	for i = 1, table.getn(SU.elements) do
		local e = SU.elements[i];
		local name = e.frame;
		wanted[name] = true;
		local b = SU.barButtons[name];
		if ( not b ) then
			b = K.Button(SU.bar, e.title, 80, function() SU.Click(name); end);
			SU.barButtons[name] = b;
			b.tag = CreateFrame("Frame", nil, SU.bar);
			b.tag:SetHeight(14);
			b.tag:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			                    tile = true, tileSize = 16, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } });
			b.tag:SetBackdropColor(0.1, 0.4, 0.1, 0.95);
			b.tag:SetBackdropBorderColor(0.4, 1, 0.4, 1);
			b.tag.text = b.tag:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
			b.tag.text:SetPoint("CENTER", b.tag, "CENTER", 0, 0); b.tag.text:SetText("Enabled");
			b.tag:Hide();
		end
		local w = math.max(70, string.len(e.title) * 7 + 20);
		b:SetWidth(w); b:SetHeight(22);
		b.tag:SetWidth(w); b.tag:ClearAllPoints(); b.tag:SetPoint("TOP", b, "BOTTOM", 0, -2);
		if ( x + w > maxW and x > 8 ) then row = row + 1; x = 8; end
		b:ClearAllPoints(); b:SetPoint("TOPLEFT", SU.bar, "TOPLEFT", x, -8 - row * 44); b:Show();
		if ( x + w + 4 > widest ) then widest = x + w + 4; end
		x = x + w + 4;
	end
	for name, b in pairs(SU.barButtons) do if ( not wanted[name] ) then b:Hide(); if ( b.tag ) then b.tag:Hide(); end end end
	SU.bar:SetWidth(math.min(widest + 4, maxW + 20));
	SU.bar:SetHeight((row + 1) * 44 + 14);
	SU.bar:Show();
	SU.Focus(nil);
	SU.RefreshBar();
	SU.UpdateDemo();
end

function SU.Build()
	SU.panel = CreateFrame("Frame", "SlimSuiteSetupPanel", UIParent);
	SU.panel:SetWidth(420); SU.panel:SetHeight(150);
	SU.panel:SetFrameStrata("DIALOG");
	SU.panel:SetMovable(true); SU.panel:EnableMouse(true);
	if ( SU.panel.SetClampedToScreen ) then SU.panel:SetClampedToScreen(true); end
	SU.panel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	                         tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	SU.panel:SetBackdropColor(0.04, 0.035, 0.07, 0.97);
	SU.panel:SetBackdropBorderColor(0.85, 0.65, 0.2, 1);
	SU.panel:RegisterForDrag("LeftButton");
	SU.panel:SetScript("OnDragStart", function() this:StartMoving(); end);
	SU.panel:SetScript("OnDragStop", function() this:StopMovingOrSizing(); end);
	SU.panel.title = SU.panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	SU.panel.title:SetPoint("TOPLEFT", SU.panel, "TOPLEFT", 12, -10);
	SU.panel.text = SU.panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	SU.panel.text:SetPoint("TOPLEFT", SU.panel, "TOPLEFT", 12, -58);
	SU.panel.text:SetWidth(396); SU.panel.text:SetJustifyH("LEFT"); SU.panel.text:SetJustifyV("TOP");
	-- the grid settings, top right: grid on/off and its size; the red centre lines; frames snapping together
	local function Tick(x, y, label, get, set)
		local cb = CreateFrame("CheckButton", nil, SU.panel, "UICheckButtonTemplate");
		cb:SetWidth(20); cb:SetHeight(20); cb:SetPoint("TOPRIGHT", SU.panel, "TOPRIGHT", x, y);
		cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		cb.label:SetPoint("LEFT", cb, "RIGHT", 0, 1); cb.label:SetText(label);
		cb.Refresh = function() cb:SetChecked(get() and 1 or nil); end;
		cb:SetScript("OnClick", function() set(this:GetChecked() and true or false); end);
		return cb;
	end
	-- the grid, top right of every setup panel: on or off, and its size
	SU.grid = Tick(-176, -7, "Grid", function() return SS.DB().showEditGrid; end, function(v) SU.SetGridSetting(v); end);
	SU.sizes = {};
	local sizes = { 16, 32, 64, 128 };
	for i = 1, 4 do
		local pixels = sizes[i];
		local b = K.Button(SU.panel, tostring(pixels), 34, function()
			SS.DB().gridDivisions = pixels; SU.SetGridSetting(SS.DB().showEditGrid and true or false); SU.RefreshGridButtons();
		end);
		b:SetHeight(18); b:SetPoint("TOPRIGHT", SU.panel, "TOPRIGHT", -8 - (4 - i) * 36, -8);
		SU.sizes[i] = b;
	end
	-- the element's own questions (up to five tick boxes)
	SU.checks = {};
	for i = 1, 10 do SU.checks[i] = SU.Check(SU.panel); end
	SU.panel.exit = K.Button(SU.panel, "Exit", 90, function() SS.SetupEnd(false); end);
	SU.panel.exit:SetPoint("BOTTOMLEFT", SU.panel, "BOTTOMLEFT", 10, 8);
	SU.panel.complete = K.Button(SU.panel, "Complete", 100, function() SS.SetupEnd(true); end);
	SU.panel.complete:SetPoint("BOTTOMRIGHT", SU.panel, "BOTTOMRIGHT", -10, 8);
	SU.panel:Hide();
	-- the bar across the top of the screen: one toggle per element
	SU.bar = CreateFrame("Frame", "SlimSuiteSetupBar", UIParent);
	SU.bar:SetFrameStrata("DIALOG");
	SU.bar:SetHeight(52);
	SU.bar:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	                     tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	SU.bar:SetBackdropColor(0.04, 0.035, 0.07, 0.97);
	SU.bar:SetBackdropBorderColor(0.85, 0.65, 0.2, 1);
	SU.bar:SetPoint("TOP", UIParent, "TOP", 0, -6);
	SU.bar:Hide();
	-- the gold outline around the element being set up
	SU.glow = CreateFrame("Frame", "SlimSuiteSetupGlow", UIParent);
	SU.glow:SetFrameStrata("DIALOG");
	SU.glow:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 });
	SU.glow:SetBackdropBorderColor(1, 0.82, 0.2, 1);
	SU.glow:EnableMouse(false);
	SS.Every("glow", 0, function()
		local h = SU.glow.handle;
		if ( not h or not h:IsShown() ) then SU.glow:SetAlpha(0); return; end
		SU.glow:SetAlpha(0.45 + 0.55 * math.abs(math.sin(GetTime() * 3)));
	end, SU.glow);
	SU.glow:Hide();
end

function SS.StartSetup(fromStart)
	setupActive = true;
	SU.Begin();
end

-- what each element brings along: the frames that move with it
SU.COMPANIONS = {
	PartyMemberFrame1 = { "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4" },
	ChatFrame1 = { "ChatFrame1Tab", "ChatFrame1EditBox" },
	SlimSuiteSpellRowFrame = { "SlimSuiteItemRowFrame" },
	MainMenuBar = { "SlimSuiteProcMeter" },
};

-- restore every frame's alpha as it was before the setup
function SU.Unreveal()
	for f, a in pairs(SU.saved or {}) do if ( f and f.SetAlpha ) then f:SetAlpha(a); end end
	for f in pairs(SU.shownBefore or {}) do if ( f and f.Show ) then f:Show(); end end
	SU.saved = nil; SU.shownBefore = nil;
	SS.Safe(SS.ApplyNewFrames);
end

function SS.SetupHide()
	setupActive = false;
	SU.Unreveal();
	if ( SU.panel ) then SU.panel:Hide(); end
	if ( SU.bar ) then SU.bar:Hide(); end
	if ( SU.demo ) then SU.demo:Hide(); end
	if ( SU.targetDemo ) then SU.targetDemo:Hide(); end
	if ( SU.bossDemo ) then SU.bossDemo:Hide(); end
	if ( SU.buffDemo ) then SU.buffDemo:Hide(); end
	SS.Safe(SS.SetNativeMeterHidden, false);
	if ( SS.DB().moveMeter ) then SS.Safe(SS.SetNativeMeterHidden, true); end
	if ( SU.glow ) then SU.glow:Hide(); SU.glow.handle = nil; end
end

-- Exit: the UI stays unlocked for moving. Complete: the UI is locked.
function SS.SetupEnd(finished)
	SS.DB().setupDone = true;
	SS.DB().setupStep = nil;
	SS.SetupHide();
	editOnly = nil;
	if ( finished ) then SS.SetUnlocked(false, true);
	else SS.SetUnlocked(true, true); end
end

-- ---------------------------------------------------------------- the settings window

function SS.Check(parent, label, y, get, set, indent)
	local cb, ok = K.Templated("CheckButton", nil, parent, "UICheckButtonTemplate");
	if ( not ok or not cb.SetChecked ) then
		cb = CreateFrame("CheckButton", nil, parent);
		cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up");
		cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down");
		cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight");
		cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check");
	end
	cb:SetWidth(26);
	cb:SetHeight(26);
	cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 26 + (indent or 0), y);
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	fs:SetPoint("LEFT", cb, "RIGHT", 4, 1);
	fs:SetWidth(350); fs:SetHeight(28); fs:SetJustifyH("LEFT"); fs:SetText(label);
	cb:SetScript("OnShow", function() this:SetChecked(get() and 1 or nil); end);
	cb:SetScript("OnClick", function()
		set(this:GetChecked() and true or false);
		K.Sound(this:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff");
	end);
	return cb;
end

function SS.WinBuild()
	win = K.Window("SlimSuiteFrame", "Slim Suite", 470, 560);
	local hero = K.Hero(win, 380);
	hero:SetWidth(430);
	hero:SetPoint("TOPLEFT", win, "TOPLEFT", 20, -30);
	K.Icon(hero.icon, "INV_Misc_Gear_02");
	hero.heading:SetText("Slim Suite");
	hero.line:SetText("A Swiss-army knife of useful tools and UI controls.");
	local tabUi = K.Button(win, "Modifying the User Interface", 210, nil);
	tabUi:SetPoint("TOPLEFT", win, "TOPLEFT", 20, -101);
	local tabOther = K.Button(win, "New/Unique, But Minor Features", 210, nil);
	tabOther:SetPoint("TOPLEFT", tabUi, "TOPRIGHT", 4, 0);
	local bodyTop = -132;
	local uiScroll, uiChild = K.Scroll("SlimSuiteUiScroll", win, 422);
	uiScroll:SetPoint("TOPLEFT", win, "TOPLEFT", 20, bodyTop);
	uiScroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -30, 48);
	local otherScroll, otherChild = K.Scroll("SlimSuiteOtherScroll", win, 422);
	otherScroll:SetPoint("TOPLEFT", win, "TOPLEFT", 20, bodyTop);
	otherScroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -30, 48);
	local addonsScroll, addonsChild = K.Scroll("SlimSuiteAddonsScroll", win, 422);
	addonsScroll:SetPoint("TOPLEFT", win, "TOPLEFT", 20, bodyTop);
	addonsScroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -30, 48);
	local function AddRows(parent, entries, startY)
		local y = startY;
		for i = 1, table.getn(entries) do
			local row = entries[i];
			local label, lead = row[1], 0;
			if ( string.find(label, "^%s") ) then lead = 22; label = string.gsub(label, "^%s+", ""); end
			SS.Check(parent, label, y, row[2], row[3], lead); y = y - 28;
		end
		parent:SetHeight(math.max(20, -y + 12));
	end
	local function CheckboxRows()
		local noteTitle = uiChild:CreateFontString(nil, "OVERLAY", "GameFontNormal");
		noteTitle:SetPoint("TOPLEFT", uiChild, "TOPLEFT", 10, -8); noteTitle:SetText("About UI replacements");
		local note = uiChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		note:SetPoint("TOPLEFT", noteTitle, "BOTTOMLEFT", 0, -3); note:SetWidth(390); note:SetHeight(38);
		note:SetJustifyH("LEFT"); note:SetJustifyV("TOP"); note:SetText("Most custom game UI is not available as reusable addon art or code. This section recreates it as faithfully as possible so it can be moved; a few implementation choices are unavoidable. <3");
		AddRows(uiChild, {
			{"Toggle UI Settings (drag, resize and scale)", function() return SS.DB().unlocked; end, function(v) SS.SetUnlocked(v); end},
			{"Hide the target frame", function() return SS.DB().hideTarget; end, function(v) SS.DB().hideTarget = v; SS.TargetFrameHidden(v); end},
			{"Show debuffs and DoTs on the target", function() return SS.DB().targetDebuffs; end, function(v) SS.DB().targetDebuffs = v; end},
			{"Buffs on the target frame", function() return SS.DB().buffsOnTarget; end, function(v) SS.SetBuffsOnTarget(v); end},
			{"Replace Default Level Up with Movable Version?", function() return SS.DB().moveLevelButton; end, function(v) SS.DB().moveLevelButton = v; SS.Safe(SS.UpdateLevelButton); end},
			{"Replace Default Build Rows with Movable Versions?", function() return SS.DB().replaceBuildRows; end, function(v) SS.DB().replaceBuildRows = v; SS.ApplyBuildRowReplacement(); end},
			{"Replace Default Damage Meter with Movable Version?", function() return SS.DB().moveMeter; end, function(v) SS.SetMeterReplacement(v); end},
			{"Replace Default Run Clock with Movable Version?", function() return SS.DB().replaceClock;end,function(v) SS.DB().replaceClock=v;SS.UpdateClock();end},
			{"   ...show the zone and Heroic affixes under it", function() return SS.DB().zoneLine;end,function(v) SS.DB().zoneLine=v;SS.UpdateClock();end},
			{"Replace Default Encounter Bars with Movable Versions?", function() return SS.DB().replaceEncounters;end,function(v) SS.DB().replaceEncounters=v;SS.UpdateBossFrames();end},
			{"Replace Default Kills / Gold / Cache with Movable Version?", function() return SS.DB().replaceTally;end,function(v) SS.DB().replaceTally=v;SS.UpdateTally();end},
			{"   ...show boss and Guardian kills next to Kills", function() return SS.DB().tallyBossKills;end,function(v) SS.DB().tallyBossKills=v;SS.UpdateTally();end},
			{"   ...dark band behind it", function() return SS.DB().tallyBackground;end,function(v) SS.DB().tallyBackground=v;SS.UpdateTally();end},
			{"Replace Default Announcements with Movable Version?", function() return SS.DB().replaceBanners;end,function(v) SS.DB().replaceBanners=v;SS.UpdateAnnouncementFrame();end},
			{"Replace Default Action Bar Art with Plain Version?", function() return SS.DB().plainBar; end, function(v) SS.DB().plainBar = v; SS.PlainBar(v); end},
			{"Add racial ability as a 7th Action Bar 1 button?", function() return SS.DB().showRacialAbility; end, function(v) SS.SetRacialAbility(v); end},
			{"Show empty slots in Action Bar 1", function() return SS.DB().showEmptyActionSlots; end, function(v) SS.DB().showEmptyActionSlots = v; ApplyActionSlotGrid(); end},
			{"Replace Default Revive Bar with Movable Version?", function() return SS.DB().replaceRevive; end, function(v) SS.DB().replaceRevive = v; end},
			{"Show debuffs on the movable encounter bars", function() return SS.DB().encounterDebuffs; end, function(v) SS.DB().encounterDebuffs = v; SS.Safe(SS.UpdateBossFrames); end},
			{"Class proc meter under the player frame", function() return SS.DB().procMeter; end, function(v) SS.DB().procMeter = v; end},
			{"Combat text test box (movable)", function() return SS.DB().combatTextBox; end, function(v) SS.DB().combatTextBox = v; end},
			{"Floating combat text over enemies (Slim Suite's own)", function() return SS.DB().floatingText; end, function(v) SS.DB().floatingText = v; end},
			{"Replace Default Local Clock with Movable Version?", function() return SS.DB().replaceLocalClock; end, function(v) SS.DB().replaceLocalClock = v; end},
			{"Show Slim Suite above the level-up and new-item cards", function() return SS.DB().onTopOfScreens; end, function(v) SS.DB().onTopOfScreens = v; if ( SlimSuiteWorld ) then SlimSuiteWorld.ApplyOnTop(); end end}
		}, -72);
		uiChild:SetHeight(818);
	end
	local function BuildOther()
		local purpose=otherChild:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
		purpose:SetPoint("TOPLEFT",otherChild,"TOPLEFT",10,-8);purpose:SetWidth(390);purpose:SetHeight(32);
		purpose:SetJustifyH("LEFT");purpose:SetJustifyV("TOP");purpose:SetText("The goal of clearing up chat is to see your friends' chat better in multiplayer.");
		local title=otherChild:CreateFontString(nil,"OVERLAY","GameFontNormal");title:SetPoint("TOPLEFT",otherChild,"TOPLEFT",10,-43);title:SetText("Chat mods");
		AddRows(otherChild, {
			{"No level-up stat bonuses in chat", function() return SS.DB().hideLevel;end,function(v) SS.DB().hideLevel=v;end},
			{"No new spell lines in chat", function() return SS.DB().hideNewSpells;end,function(v) SS.DB().hideNewSpells=v;end},
			{"Hide racial buff information in chat", function() return SS.DB().hideRacialInfo;end,function(v) SS.DB().hideRacialInfo=v;end},
			{"Hide the Oogax Q opening line", function() return SS.DB().hideOpeningLine;end,function(v) SS.DB().hideOpeningLine=v;end},
			{"Hide 'Who dares to enter my lair'", function() return SS.DB().hideLairLine;end,function(v) SS.DB().hideLairLine=v;end},
			{"Hide in-game roleplay lines from chat", function() return SS.DB().hideRP;end,function(v) SS.DB().hideRP=v;end},
			{"Camera as far out as it goes (50)", function() return SS.DB().camera; end, function(v) SS.DB().camera = v; SS.Camera(v); end},
			{"Mark pulled bosses and Guardians (Skull, X, Circle, Star)", function() return SS.DB().bossMarks; end, function(v) SS.DB().bossMarks = v; end},
			{"   ...and Guardians and lairs before they're pulled", function() return SS.DB().prePullMarks; end, function(v) SS.DB().prePullMarks = v; end},
			{"Show caches on the minimap", function() return SS.DB().minimapCaches; end, function(v) SS.DB().minimapCaches = v; end},
			{"Show bosses on the minimap", function() return SS.DB().minimapBosses; end, function(v) SS.DB().minimapBosses = v; end},
			{"Show lairs on the minimap, with their 3:00 refill timer", function() return SS.DB().minimapLairs; end, function(v) SS.DB().minimapLairs = v; end},
			{"Show the game's nearest Guardian lair flag on minimap", function() return SS.DB().showGuardianFlag; end, function(v) SS.DB().showGuardianFlag = v; SS.ApplyGuardianFlag(); end},
			{"Mark where a downed friend can be revived", function() return SS.DB().deathMarks; end, function(v) SS.DB().deathMarks = v; end},
			{"Play a sound when you or a teammate dies", function() return SS.DB().deathSound; end, function(v) SS.DB().deathSound = v; end},
			{"Cooldown numbers on the spell squares", function() return SS.DB().cooldowns; end, function(v) SS.DB().cooldowns = v; end},
			{"Square minimap (off: round)", function() return SS.DB().minimapSquare; end, function(v) SS.SetMinimapSquare(v); end},
			{"Gather the minimap buttons together", function() return SS.DB().gatherButtons; end, function(v) SS.SetGather(v); end},
			{"   ...above the minimap", function() return SS.DB().gatherButtons and SS.DB().gatherSide == "above"; end, function(v) if ( v ) then SS.SetGather(true, "above"); end end},
			{"   ...below the minimap", function() return SS.DB().gatherButtons and SS.DB().gatherSide == "below"; end, function(v) if ( v ) then SS.SetGather(true, "below"); end end},
			{"   ...left of the minimap", function() return SS.DB().gatherButtons and SS.DB().gatherSide == "left"; end, function(v) if ( v ) then SS.SetGather(true, "left"); end end},
			{"   ...right of the minimap", function() return SS.DB().gatherButtons and SS.DB().gatherSide == "right"; end, function(v) if ( v ) then SS.SetGather(true, "right"); end end},
			{"Minimap button", function() local m = SS.DB().minimap; return not (m and m.hide); end, function(v) if ( SS.Mini ) then local m = SS.DB().minimap; if ( (m and m.hide and true or false) == v ) then SS.Mini.Toggle(); end end end}
		}, -68);
	end
	local function BuildAddonManager()
		local title = addonsChild:CreateFontString(nil, "OVERLAY", "GameFontNormal");
		title:SetPoint("TOPLEFT", addonsChild, "TOPLEFT", 8, -8); title:SetText("Enabled game addons");
		local note = addonsChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6); note:SetText("Changes apply after reload. Uncheck to disable an addon.");
		local n = (GetNumAddOns and GetNumAddOns()) or 0;
		local y = -48;
		for index = 1, n do
			local name, addonTitle, addonNotes, enabled = GetAddOnInfo(index);
			local state = GetAddOnEnableState and GetAddOnEnableState(nil, index) or (enabled and 1 or 0);
			if ( name and string.sub(string.lower(name), 1, 9) ~= "blizzard_" and name ~= "SlimSuite" ) then
				local cb = CreateFrame("CheckButton", nil, addonsChild, "UICheckButtonTemplate");
				cb:SetPoint("TOPLEFT", addonsChild, "TOPLEFT", 6, y); cb:SetWidth(24); cb:SetHeight(24);
				cb:SetChecked((state or 0) > 0 and 1 or nil);
				cb:SetScript("OnClick", function()
					if ( this:GetChecked() ) then EnableAddOn(name); else DisableAddOn(name); end
				end);
				local label = addonsChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
				label:SetPoint("LEFT", cb, "RIGHT", 4, 0); label:SetWidth(372); label:SetJustifyH("LEFT"); label:SetText(addonTitle or name);
				y = y - 26;
			end
		end
		addonsChild:SetHeight(math.max(64, -y + 12));
		local reload = K.Button(win, "Reload for changes", 160, function() if ( ReloadUI ) then ReloadUI(); end end);
		reload:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 28, 17);
		win.reloadButton = reload;
		local errors = K.Button(win, "Error log", 120, function() SS.ShowErrors(); end);
		errors:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 198, 17);
	end
	CheckboxRows(); BuildOther(); BuildAddonManager();
	local tooltipTitle = uiChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	tooltipTitle:SetPoint("TOPLEFT", uiChild, "TOPLEFT", 10, -732);
	tooltipTitle:SetText("Tooltip size");
	local function AdjustTooltipSize(delta)
		local size = SS.DB().sizes.GameTooltip;
		if ( type(size) ~= "table" ) then size = { w = 260, h = 140 }; SS.DB().sizes.GameTooltip = size; end
		SS.DB().tooltipCustom = true;
		size.w = math.max(160, math.min(600, size.w + delta));
		size.h = math.max(80, math.min(500, size.h + delta));
		if ( GameTooltip ) then GameTooltip:SetWidth(size.w); GameTooltip:SetHeight(size.h); end
		PlaceAll();
	end
	local tooltipSmaller = K.Button(uiChild, "Smaller", 82, function() AdjustTooltipSize(-20); end);
	tooltipSmaller:SetPoint("TOPLEFT", uiChild, "TOPLEFT", 10, -750);
	local tooltipLarger = K.Button(uiChild, "Larger", 82, function() AdjustTooltipSize(20); end);
	tooltipLarger:SetPoint("LEFT", tooltipSmaller, "RIGHT", 6, 0);
	local reset = K.Button(uiChild, "Reset positions", 140, function() SS.ResetPlaces(); end);
	reset:SetPoint("TOPLEFT", uiChild, "TOPLEFT", 10, -784);
	local resetAll = K.Button(uiChild, "Reset all UI", 126, function() SS.ResetUI(); end);
	resetAll:SetPoint("LEFT", reset, "RIGHT", 8, 0);
	uiChild:SetHeight(818);
	local function SelectPage(which)
		uiScroll:Hide(); otherScroll:Hide(); addonsScroll:Hide();
		if ( win.reloadButton ) then win.reloadButton:Hide(); end
		if ( which == "ui" ) then uiScroll:Show(); tabUi:LockHighlight(); tabOther:UnlockHighlight();
		elseif ( which == "other" ) then otherScroll:Show(); tabUi:UnlockHighlight(); tabOther:LockHighlight();
		else addonsScroll:Show(); if ( win.reloadButton ) then win.reloadButton:Show(); end end
	end
	tabUi:SetScript("OnClick", function() SelectPage("ui"); end);
	tabOther:SetScript("OnClick", function() SelectPage("other"); end);
	local addonsTab = K.Button(otherChild, "Manage Addons", 132, function() SelectPage("addons"); end);
	addonsTab:SetPoint("TOPLEFT", otherChild, "TOPLEFT", 10, -556);
	otherChild:SetHeight(594);
	SelectPage("other");
end

function SS.Toggle()
	if ( not win ) then
		local ok, err = SS.Safe(SS.WinBuild);
		if ( not ok ) then K.Print(NAME, "|cffff4040the settings window could not be made:|r " .. tostring(err)); win = nil; return; end
	end
	if ( win:IsShown() ) then win:Hide(); else win:Show(); end
end

SLASH_SLIMSUITE1 = "/slimsuite";
SLASH_SLIMSUITE2 = "/slim";
SlashCmdList["SLIMSUITE"] = function(msg)
	msg = msg or "";
	local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.-)$");
	cmd = string.lower(cmd or "");
	rest = string.lower(rest or "");
	local d = SS.DB();
	if ( cmd == "hide" and rest ~= "" ) then
		table.insert(d.words, rest);
		K.Print(NAME, "chat lines with \"" .. rest .. "\" are hidden now.");
	elseif ( cmd == "unhide" and rest ~= "" ) then
		for i = table.getn(d.words), 1, -1 do if ( d.words[i] == rest ) then table.remove(d.words, i); end end
		K.Print(NAME, "chat lines with \"" .. rest .. "\" are shown again.");
	elseif ( cmd == "errors" ) then
		SS.ShowErrors();
	elseif ( cmd == "minimap" ) then
		local shown = SS.Mini and SS.Mini.Toggle();
		K.Print(NAME, shown and "the minimap button is back." or "the minimap button is hidden. /slimsuite minimap brings it back.");
	elseif ( cmd == "unlock" or cmd == "move" ) then
		SS.SetUnlocked(true);
	elseif ( cmd == "lock" ) then
		SS.SetUnlocked(false);
	else
		SS.Toggle();
	end
end

local loader = CreateFrame("Frame");
loader:RegisterEvent("VARIABLES_LOADED");
loader:RegisterEvent("PLAYER_ENTERING_WORLD");
loader:SetScript("OnEvent", function()
	SS.Safe(SS.RegisterAnnouncementHandler);
	local ok, err = SS.Safe(HookChat);
	if ( not ok ) then K.Print(NAME, "|cffff4040the chat could not be changed:|r " .. tostring(err)); end
	-- The editor state is a user choice, not a leftover from an earlier session. Clear legacy
	-- unlocked saves at load; only the explicit startup option may reopen the mover after login.
	if ( event == "VARIABLES_LOADED" ) then
		SS.DB().unlocked = false;
		SS.Safe(SS.RestoreNativeHudAfterLoad);
	end
	SS.Safe(SS.Camera, event == "PLAYER_ENTERING_WORLD");
	SS.Safe(SS.ApplyGuardianFlag);
	-- the frames back where they were put (the game places some of them again as it loads), and the target frame
	if ( SS.DB().unlocked or type(SS.DB().places.MainMenuExpBar) == "table"
		or type(SS.DB().sizes.MainMenuExpBar) == "table" or type(SS.DB().scales.MainMenuExpBar) == "number"
		or SS.DB().orientations.MainMenuExpBar ~= nil ) then SS.Safe(SS.DetachExperienceBar); end
	if ( type(SS.DB().places.ChatFrame1) == "table" ) then SS.Safe(SS.PrepareChatWindow); end
	SS.Safe(SS.ApplyTallyLayout, false);
	SS.Safe(PlaceAll);
	SS.Safe(SS.TargetFrameHidden, SS.DB().hideTarget);
	if ( SS.DB().plainBar ) then SS.Safe(SS.PlainBar, true); end
	SS.Safe(ApplyMovableOrientation, "MainMenuBar");
	SS.Safe(ApplyMovableOrientation, "MainMenuExpBar");
	SS.Safe(ApplyMovableOrientation, "BuffFrame");

	SS.Safe(ApplyMovableOrientation, "PartyMemberFrame1");
	SS.Safe(ApplyActionSlotGrid);
	SS.Safe(SS.HookTooltipOwner);
	SS.Safe(PlaceAll);
	SS.Safe(UpdateMeter);
	if ( event == "PLAYER_ENTERING_WORLD" ) then SS.Safe(SS.SetUnlocked, false, true); SS.Safe(SS.ApplyMinimapShape); SS.Safe(SS.LayoutGather); SS.Safe(SS.MakeCards); SS.Safe(SS.ApplyNewFrames); SS.Safe(SS.GuardTargetTooltips); SS.Safe(ApplyMovableOrientation, "PartyMemberFrame1"); end
end);
local buffLayoutUpdater = CreateFrame("Frame");
buffLayoutUpdater:RegisterEvent("UNIT_AURA");
buffLayoutUpdater:SetScript("OnEvent", function()
	if ( arg1 == "player" and (SS.CurrentOrientation("BuffFrame") == "vertical" or SS.DB().buffCustomLayout) ) then SS.Safe(SS.ApplyBuffOrientation); end
end);
SS.Safe(HookChat);                                          -- right away too, so lines printed while loading are caught

-- Gather the minimap buttons: Slim Suite's own button and the small named buttons other addons put on the minimap
-- are lined up in one column or row on the chosen side. Each one's old anchor is kept so it goes back on release.
function SS.GatherRelease(f)
	if ( f.slimOrig ) then
		local o = f.slimOrig;
		f.slimOrig = nil;
		f:ClearAllPoints();
		if ( o[2] ) then f:SetPoint(o[1], o[2], o[3], o[4], o[5]); else f:SetPoint("CENTER", UIParent, "CENTER"); end
	end
end

function SS.LayoutGather()
	if ( not Minimap ) then return; end
	local d = SS.DB();
	local ours = SS.Mini;
	local want, wantSet = {}, {};
	if ( d.gatherButtons ) then
		local ourShown = ours and not (d.minimap and d.minimap.hide);
		if ( ourShown ) then table.insert(want, ours); wantSet[ours] = true; end
		local kids = { Minimap:GetChildren() };
		for i = 1, table.getn(kids) do
			local f = kids[i];
			local name = f and f.GetName and f:GetName();
			if ( name and f ~= ours and f.IsShown and f:IsShown() and string.sub(name, 1, 7) ~= "Minimap"
				and string.sub(name, 1, 9) ~= "SlimSuite" and string.sub(name, 1, 10) ~= "MiniMapTra" ) then
				local w, h = f:GetWidth() or 0, f:GetHeight() or 0;
				if ( w > 0 and w <= 40 and h > 0 and h <= 40 ) then table.insert(want, f); wantSet[f] = true; end
			end
		end
	end
	-- release everything gathered last time that is not gathered now
	local old = SlimSuiteGatheredList or {};
	for i = 1, table.getn(old) do if ( not wantSet[old[i]] ) then SS.GatherRelease(old[i]); end end
	-- line the wanted ones up on the chosen side, centred on the minimap
	local side = d.gatherSide or "left";
	local n = table.getn(want);
	local W, H = Minimap:GetWidth() or 140, Minimap:GetHeight() or 140;
	local gap, edge = 36, 22;
	for i = 1, n do
		local f = want[i];
		if ( not f.slimOrig ) then
			local p, rel, rp, x, y = f:GetPoint(1);
			f.slimOrig = { p, rel, rp, x or 0, y or 0 };
		end
		local off = (i - 1 - (n - 1) / 2) * gap;
		local dx, dy = 0, 0;
		if ( side == "left" ) then dx, dy = -(W / 2 + edge), off;
		elseif ( side == "right" ) then dx, dy = W / 2 + edge, off;
		elseif ( side == "above" ) then dx, dy = off, H / 2 + edge;
		else dx, dy = off, -(H / 2 + edge); end
		f:ClearAllPoints();
		f:SetPoint("CENTER", Minimap, "CENTER", dx, dy);
	end
	if ( ours and not wantSet[ours] and ours.Place ) then SS.Safe(ours.Place); end   -- back to its own spot
	SlimSuiteGatheredList = want;
end

function SS.SetGather(on, side)
	SS.DB().gatherButtons = on and true or false;
	if ( side ) then SS.DB().gatherButtons = true; SS.DB().gatherSide = side; end
	SS.Safe(SS.LayoutGather);
end

-- the minimap button: a gear, at the left of the minimap (AZS Stats' is at the bottom, AZS Handbook's at the top
-- left)
local okMini, errMini = SS.Safe(function()
	SS.Mini = K.Minimap({ name = "SlimSuiteMinimapButton", icon = "INV_Misc_Gear_02", angle = 190, db = SS.DB,
		click = function() SS.Toggle(); end,
		tooltip = function(tt)
			tt:AddLine(NAME);
			tt:AddLine("Gameplay helpers and UI controls.", 1, 1, 1);
			tt:AddLine(" ");
			tt:AddLine("Click: the settings. /slimsuite minimap hides this button.", 0.6, 0.6, 0.6);
		end });
end);
if ( not okMini ) then K.Print(NAME, "|cffff4040the minimap button could not be made:|r " .. tostring(errMini)); end
