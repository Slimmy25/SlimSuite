-- Slim Suite: the setup and the settings window.
if ( setfenv ) then setfenv(1, SS.ENV); end   -- Slim Suite's files share one set of private names (SS.ENV, in SlimSuiteCore.lua)

-- ---------------------------------------------------------------- first-time setup of the movable UI
-- The first time "Toggle UI Settings" is turned on, Slim Suite walks the player through the interface one element
-- at a time: only that element's green handle shows, outlined in pulsing gold, with a short note and Back / Next.
-- It starts with the unit frame, then the party frames, then the action bar (with its two questions), then the
-- rest of the game's frames and every Slim Suite replacement that is turned on. Locking the UI part way through
-- picks the setup up at the same step next time; "Skip setup" or finishing it ends it for good, and the move
-- panel's "Run setup again" starts it over.
SU = {};                                           -- the setup's panel, outline and steps
local statCounterPlaceholder = CreateFrame("Frame", "SlimSuiteStatCounterFrame", UIParent);
statCounterPlaceholder:SetWidth(150); statCounterPlaceholder:SetHeight(28);
statCounterPlaceholder:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
statCounterPlaceholder:SetBackdropColor(0.04, 0.035, 0.07, 0.9); statCounterPlaceholder:SetBackdropBorderColor(0.85, 0.65, 0.2, 1);
statCounterPlaceholder.label = statCounterPlaceholder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
statCounterPlaceholder.label:SetPoint("CENTER", statCounterPlaceholder, "CENTER"); statCounterPlaceholder.label:SetText("Stat counter [WIP]");
statCounterPlaceholder:Hide();

function SU.Steps()
	local d = SS.DB();
	local steps = {
		{ frame = "PlayerFrame", title = d.combineTarget and "Player + target" or "Unit frame",
			text = "Your hero's frame: health, power and level. Drag the green handle to place it; its size and scale are below." },
		{ frame = "PartyMemberFrame1", title = "Party frames",
			text = "Your friends' frames in co-op. They show now even if you're alone, so you can place them. Choose a column or a row, face plates or thin lines, and whether you join them." },
		{ frame = "MainMenuBar", title = "Action bar",
			text = "Your spells. Drag to place it; its size, and turning it upright, are below." },
	};
	local rest = {
		{ "TargetFrame", "Target frame", "The enemy the game has picked for you.", function() return not d.hideTarget and not d.combineTarget; end },
		{ "MainMenuExpBar", "XP bar", "Your experience bar. It can stand upright too (below)." },
		{ "BuffFrame", "Buffs/Debuffs", "Your buffs and debuffs. Below, stack them in a column and choose which way they grow. Attached to the target frame, they move and scale with it instead." },
		{ "MinimapCluster", "Minimap", "The minimap, with its pins." },
		{ "ChatFrame1", "Chat", "The chat window, its tab and the box you type in move together." },
		{ "GameTooltip", "Tooltip", "Where tooltips appear, and how wide they are. Each one is as tall as its own text." },
		{ "SlimSuiteStoredLevelsButton", "Level Up", "The movable Level Up button and its store toggle.", function() return d.moveLevelButton; end },
		{ "SlimSuiteSpellRowFrame", "Build rows", "Your build spells, with your worn jewelry joined under them.", function() return d.replaceBuildRows; end },
		{ "SlimSuiteMeterFrame", "Damage meter", "The meter. Its corner grip resizes it any time.", function() return d.moveMeter; end },
		{ "SlimSuiteClockFrame", "Run clock", "Run time and the next boss.", function() return d.replaceClock; end },
		{ "SlimSuiteBossFrames", "Encounter bars", "Boss, Guardian and elite health bars.", function() return d.replaceEncounters; end },
		{ "SlimSuiteTallyFrame", "Kills / Gold / Cache", "Your run's tally.", function() return d.replaceTally; end },
		{ "SlimSuiteAnnouncementFrame", "Announcements", "Where event announcements appear.", function() return d.replaceBanners; end },
		{ "SlimSuiteReviveFrame", "Revive bar", "The bar shown while you bring a friend back.", function() return d.replaceRevive; end },
		{ "SlimSuiteLocalClockFrame", "Local clock", "Your real-world clock: 12/24-hour, its background and daylight saving are below.", function() return d.replaceLocalClock and d.clockDetached; end },
		{ "SlimSuiteMinimapBar", "Button row (optional)", "Optional: takes every minimap button and the day/night moon off the map into one row you can drag anywhere. Off, the buttons stay on the map's ring.", function() return d.minimapBar; end },
		{ "SlimSuiteCombatTextFrame", "Combat text", "Your newest hits and heals, each with its spell icon. Crits stand out.", function() return d.combatTextBox; end },
		{ "SlimSuiteStatCounterFrame", "Stat counter [WIP]", "A placeholder for a future run-stat counter. [WIP]" },
	};
	for i = 1, table.getn(rest) do
		local r = rest[i];
		-- every element Slim Suite can change is listed, on or off; turning one on here turns on its feature too
		if ( getglobal(r[1]) ) then table.insert(steps, { frame = r[1], title = r[2], text = r[3] }); end
	end
	local kept = {};
	for i = 1, table.getn(steps) do
		if ( not (d.setupDisabled and d.setupDisabled[steps[i].frame]) ) then table.insert(kept, steps[i]); end
	end
	steps = kept;
	table.insert(steps, { title = "All set", text = "That's everything. Press Finish to lock the UI. You can move anything again with Toggle UI Settings. Done closes the list." });
	if ( SS.TranslateRecord ) then for i=1,table.getn(steps) do SS.TranslateRecord(steps[i]); end end
	return steps;
end

function SU.Check(parent)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate");
	cb:SetScript("OnEnter", function() if ( this.warnText ) then SS.ShowWarnTip(this, this.warnText); end end);
	cb:SetScript("OnLeave", function() SS.HideWarnTip(); end);
	cb:SetWidth(22); cb:SetHeight(22);
	cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0); cb.label:SetJustifyH("LEFT");
	-- what turning this on turns off, in orange under the label
	cb.warn = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	cb.warn:SetPoint("TOPLEFT", cb.label, "BOTTOMLEFT", 0, -1); cb.warn:SetJustifyH("LEFT");
	cb.warn:SetTextColor(1, 0.6, 0.2); cb.warn:Hide();
	cb.Refresh = function() if ( cb.get ) then cb:SetChecked(cb.get() and 1 or nil); end end;
	cb:SetScript("OnClick", function()
		SS.FlipToggle(this.get, this.set);
		SS.RefreshToggles();
	end);
	cb:Hide();
	SS.TrackToggle(cb);
	return cb;
end

-- What turning a setting on turns off (the newest choice always wins), shown in orange under the setting in the setup
-- and the right-click menus. "Movable?" warns about what unticking it turns off.
SU.WARN = {
	mirror = "Turns off: Join the party yourself. Combines both frames and mirrors their positions at the same size.",
	selfParty = "Turns off: your player frame (back when unticked) and Mirror Target. Your frame joins the party list.",
	combine = "Turns off: Join the party yourself. The player frame takes the target's look.",
	buffs = "One place at a time: choosing a frame takes them off the other one.",
	partyPlace = "Under or above the player frame takes you out of the party frames and makes the party movable.",
	buffsTarget = "Turns off: Buffs/Debuffs on the player frame.",
	buffsPlayer = "Turns off: Buffs on the target frame.",
	lockParty = "Makes the party frames movable.",
};
SS.WARN = SU.WARN;

-- A setting with several choices ({ label, get, set, choice = { { text, value }, ... } }) shows as one button with the
-- current choice; clicking it opens a small menu of all of them, the game's own dropdown menu at the cursor.
SS.choiceButtons = {};
function SS.ChoiceText(e)
	local v = e[2] and e[2]();
	for i = 1, table.getn(e.choice or {}) do if ( e.choice[i][2] == v ) then return SS.T and SS.T(e.choice[i][1]) or e.choice[i][1]; end end
	return "";
end
function SS.RefreshChoices()
	for i = 1, table.getn(SS.choiceButtons) do
		local b = SS.choiceButtons[i];
		if ( b.entry ) then b:SetText(SS.ChoiceText(b.entry) .. "  v"); end
	end
end
function SS.ChoiceButton(parent, width)
	local b = K.Button(parent, "", width, function() SS.OpenChoice(this.entry); end);
	table.insert(SS.choiceButtons, b);
	return b;
end
function SS.FillChoiceMenu()
	local menu = getglobal("SlimSuiteChoiceMenu");
	local e = menu and menu.entry;
	if ( not e ) then return; end
	local current = e[2]();
	for i = 1, table.getn(e.choice) do
		local opt = e.choice[i];
		local info = {};
		info.text = opt[1];
		info.checked = current == opt[2];
		info.func = function() e[3](opt[2]); SS.AfterChoice(); end;
		UIDropDownMenu_AddButton(info);
	end
end
function SS.OpenChoice(e)
	if ( not e or not ToggleDropDownMenu or not UIDropDownMenu_Initialize ) then return; end
	local menu = getglobal("SlimSuiteChoiceMenu");
	if ( not menu ) then
		menu = CreateFrame("Frame", "SlimSuiteChoiceMenu", UIParent, "UIDropDownMenuTemplate");
		menu:Hide();
		UIDropDownMenu_Initialize(menu, function() SS.Safe(SS.FillChoiceMenu); end, "MENU");
	end
	menu.entry = e;
	ToggleDropDownMenu(1, nil, menu, "cursor", 0, 0);
end
-- after a choice: every place that shows it is brought up to date
function SS.AfterChoice()
	SS.RefreshChoices();
	SS.RefreshToggles();
	if ( setupActive and SU.focus ) then SU.Focus(SU.focus); end
	if ( not setupActive and SS.MenuOpen() ) then SU.Focus(SU.focus); end
end
-- a tick-box row turned into a choice row (or back): the box itself is hidden and the choice button stands beside its
-- label ("right", the setup) or under it ("below", the narrow right-click menu)
function SS.RowKind(cb, e, where)
	local choice = e and e.choice ~= nil;
	for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetCheckedTexture", "GetDisabledCheckedTexture" }) do
		local t = cb[get] and cb[get](cb);
		if ( t and t.SetAlpha ) then t:SetAlpha(choice and 0 or 1); end
	end
	cb:EnableMouse(not choice);
	if ( choice ) then
		if ( not cb.choiceBtn ) then cb.choiceBtn = SS.ChoiceButton(cb, where == "below" and 176 or 200); end
		cb.choiceBtn.entry = e;
		cb.choiceBtn:ClearAllPoints();
		if ( where == "below" ) then cb.choiceBtn:SetPoint("TOPLEFT", cb.label, "BOTTOMLEFT", -2, -3);
		else cb.choiceBtn:SetPoint("LEFT", cb.label, "RIGHT", 8, 0); end
		cb.choiceBtn:SetText(SS.ChoiceText(e) .. "  v");
		cb.choiceBtn:Show();
	elseif ( cb.choiceBtn ) then
		cb.choiceBtn:Hide(); cb.choiceBtn.entry = nil;
	end
end                                       -- the same, for code above SU's declaration
SU.WARN_UNMOVABLE = {
	PlayerFrame = "Unticking turns off: Mirror Target.",
	TargetFrame = "Unticking turns off: Mirror Target.",
	PartyMemberFrame1 = "Unticking turns off: Lock to player frame.",
	BuffFrame = "Unticking turns off: buffs on the player or target frame.",
};

-- the game's own frames that Slim Suite can move; each one's setup step asks "Movable? (Disables Default UI Element)"
SU.NATIVE = { PlayerFrame = true, TargetFrame = true, PartyMemberFrame1 = true, MinimapCluster = true,
	BuffFrame = true, MainMenuBar = true, MainMenuExpBar = true, ChatFrame1 = true };

-- Default: put the frame back where the game places it and stop moving it; Movable: Slim Suite places it again
function SU.SetMovable(frame, movable)
	SS.DB().frameDefault = SS.DB().frameDefault or {};
	if ( not movable ) then
		local d = SS.DB();
		if ( (frame == "PlayerFrame" or frame == "TargetFrame") and d.mirrorTarget ) then
			SS.SetMirrorTarget(false); SS.Notice("Mirror Target turned off: that frame is back in the game's own layout.");
		elseif ( frame == "PartyMemberFrame1" and d.partyLocked ) then
			d.partyLocked = false; SS.Notice("Lock to player frame turned off: the party frames are back in the game's own layout.");
		elseif ( frame == "BuffFrame" and (d.buffsOnTarget or d.buffsOnPlayer) ) then
			d.buffsOnTarget, d.buffsOnPlayer = false, false;
			SS.Notice("Buffs taken off the unit frame: they are back in the game's own layout.");
		end
	end
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
		if ( f and f.SetScale ) then f:SetScale((SS.nativeScales and SS.nativeScales[frame]) or 1); end
		if ( frame == "PartyMemberFrame1" ) then
			for i = 2, 4 do
				local member, points = getglobal("PartyMemberFrame" .. i), partyNativePoints[i];
				if ( member ) then
					if ( points ) then
						member:ClearAllPoints();
						for p = 1, table.getn(points) do local a = points[p]; member:SetPoint(a[1], a[2], a[3], a[4], a[5]); end
					end
					member:SetScale((SS.nativeScales and SS.nativeScales["PartyMemberFrame" .. i]) or 1);
				end
			end
		end
		if ( frame == "ChatFrame1" ) then SS.Safe(SS.RestoreChatLayout, not SU.restoring); end
		if ( frame == "MainMenuExpBar" ) then SS.Safe(SS.RestoreExperienceBar); end
	end
	SS.DB().places[frame] = nil;
	if ( SS.DB().unlocked ) then SS.Safe(SS.SetUnlocked, true, true); end
end

-- the choices the frame settings offer (the setup, the right-click menus and the settings window share them)
SS.LOOK_CHOICES = { { "Classic", "classic" }, { "New-school", "new" } };
SS.PLAYER_LOOKS = { { "Classic", "classic" }, { "New-school", "new" }, { "Same as the party (you join it)", "party" },
	{ "Same as the target (combined)", "target" } };
function SS.PlayerLookChoice()
	local d = SS.DB();
	if ( d.partyIncludesSelf ) then return "party"; end
	if ( d.combineTarget ) then return "target"; end
	return d.playerLook == "new" and "new" or "classic";
end
-- picking the party's or the target's look joins that frame; picking a look of its own leaves it
function SS.SetPlayerLookChoice(v)
	local d = SS.DB();
	if ( v == "party" ) then if ( not d.partyIncludesSelf ) then SS.SetPartySelf(true); end return; end
	if ( v == "target" ) then if ( not d.combineTarget ) then SS.SetCombineTarget(true); end return; end
	if ( d.partyIncludesSelf ) then SS.SetPartySelf(false); end
	if ( d.combineTarget ) then SS.SetCombineTarget(false); end
	SS.SetLook("PlayerFrame", v);
end
SS.PARTY_LOOKS = { { "Face plates", "classic" }, { "Thin lines", "thin" } };
SS.PARTY_LAYOUTS = { { "Column", "vertical" }, { "Row", "horizontal" } };
SS.PARTY_PLACES = { { "Anywhere", "free" }, { "Under the player frame", "below" }, { "Above the player frame", "above" } };
-- your buffs: in their own place, or on one side of the player frame
SS.BUFF_PLACES = { { "In their own place", "own" }, { "Above the player frame", "player_above" }, { "Below the player frame", "player_below" },
	{ "Left of the player frame", "player_left" }, { "Right of the player frame", "player_right" } };
-- the target's own buffs and debuffs: on one side of the target frame
SS.TARGET_AURA_SIDES = { { "Above the target frame", "above" }, { "Below the target frame", "below" },
	{ "Left of the target frame", "left" }, { "Right of the target frame", "right" } };

-- the tick boxes each step offers: that element's own settings, the same ones as in the settings window
function SU.ChecksFor(frame)
	local d = SS.DB();
	-- Entries tagged xref = true refer to another element, so they also appear in that element's right-click menu.
	local W = SU.WARN;
	local function Mirror(disableWhenPlayerOff)
		local e = { "Mirror Target", warn = W.mirror, function() return SS.DB().mirrorTarget and SS.DB().combineTarget; end,
			function(v) SS.SetMirrorTarget(v); if ( v and setupActive and not SS.DB().hideTarget ) then SU.SetOn("TargetFrame", true, SU.titles and SU.titles.TargetFrame or "Target frame"); end if ( SS.MenuOpen() ) then SU.Focus(SU.focus); end end,
			short = "Mirror Target", xref = true };
		-- Keep the control visible in target settings, but make its dependency explicit when the player frame is off.
		if ( disableWhenPlayerOff ) then e[5] = function() return SU.on and SU.on.PlayerFrame and true or false; end; end
		return e;
	end
	-- the player's look: its own, or the same as the party (you join it) or as the target (combined with it)
	local function PlayerLook() return { "Player frame look", function() return SS.PlayerLookChoice(); end,
		function(v) SS.SetPlayerLookChoice(v); end, choice = SS.PLAYER_LOOKS, short = "Look" }; end
	local function TargetLook() return { "Target frame look", function() return SS.DB().targetLook == "new" and "new" or "classic"; end,
		function(v) SS.SetLook("TargetFrame", v); end, choice = SS.LOOK_CHOICES, short = "Look" }; end
	local function Portraits(el) return { "3D portrait on the new-school frame", function() return SS.DB().cardPortraits ~= false; end,
		function(v) SS.DB().cardPortraits = v and true or false; SS.Safe(SS.ApplyNewFrames); end, function() return SS.UsesCard(el); end, short = "3D portrait" }; end
	local function BuffsPlace() return { "Player buffs position", function() return SS.BuffsPlace(); end, function(v) SS.SetBuffsPlace(v); end,
		choice = SS.BUFF_PLACES, short = "Buffs and debuffs", xref = true, warn = W.buffs }; end
	local function TargetBuffsPlace() return { "Target buffs/debuffs position", function() return SS.DB().targetAuraSide or "below"; end,
		function(v) SS.SetTargetAuraSide(v); end, function() return SS.DB().targetDebuffs; end,
		choice = SS.TARGET_AURA_SIDES, short = "Target buffs/debuffs" }; end
	local function SelfParty() return { "Join the party frames yourself (you go first)", function() return SS.DB().partyIncludesSelf; end,
		function(v) SS.SetPartySelf(v); end, short = "Join the party yourself", xref = true, warn = W.selfParty }; end
	local function PartyPlace() return { "Party frames sit", function() return SS.PartyPosition(); end, function(v) SS.SetPartyPosition(v); end,
		choice = SS.PARTY_PLACES, short = "Party frames sit", xref = true, warn = W.partyPlace }; end
	local function ProcMeter() return { "Class proc meter under it", function() return SS.DB().procMeter; end,
		function(v) SS.DB().procMeter = v and true or false; end, short = "Class proc meter", xref = true }; end
	-- one of your own settings, shown under the party while you are in it (your frame is part of the party then)
	local function YouIn(e) e[4] = function() return SS.DB().partyIncludesSelf; end; return e; end
	local function HideTarget() return { "Hide the target frame", function() return SS.DB().hideTarget; end,
		function(v) SS.SetTargetHidden(v); end }; end
	local function ShowClock() return { "Show the local clock", function() return SS.DB().replaceLocalClock; end,
		function(v) SS.SetLocalClockOn(v); end, short = "Show the local clock", xref = true }; end
	local function DetachClock() return { "Detach the clock from the minimap (its own button up top)", function() return SS.DB().clockDetached; end,
		function(v) SS.SetClockDetached(v); end, function() return SS.DB().replaceLocalClock; end, short = "Detach from minimap", xref = true }; end
	local function ButtonPlace() return SS.MinimapButtonsEntry(); end
	local function VerticalRow(name) return { "Vertical (off: horizontal)", function() return SS.CurrentOrientation(name) == "vertical"; end,
		function(v) SS.SetBuildOrientation(name, v); end, short = "Vertical", xref = true }; end
	local function JoinRows() return { "Join the worn-jewelry row under the build spells", function() return SS.DB().buildRowsAttached; end,
		function(v) if ( (v and true or false) ~= (SS.DB().buildRowsAttached and true or false) ) then SS.ToggleBuildRowsAttached(); end end, short = "Join the jewelry row", xref = true }; end
	local list = {
		PlayerFrame = { PlayerLook(), Portraits("PlayerFrame"), Mirror(), BuffsPlace(), TargetBuffsPlace(), ProcMeter(), SelfParty(), PartyPlace() },
		MainMenuBar = {
			{ "Hide the bar's artwork (only the spell squares stay)", short = "Hide the bar's artwork", function() return SS.DB().plainBar; end, function(v) SS.DB().plainBar = v; SS.Safe(SS.PlainBar, v); end },
			{ "Show all six buttons at all times, even empty ones", short = "Show empty buttons", function() return SS.DB().showEmptyActionSlots; end, function(v) SS.DB().showEmptyActionSlots = v; SS.Safe(ApplyActionSlotGrid); end },
			{ "Add your racial as a 7th button", short = "Racial as a 7th button", function() return SS.DB().showRacialAbility; end, function(v) SS.Safe(SS.SetRacialAbility, v); end },
			{ "Turn the action bar vertical", function() return SS.DB().orientations.MainMenuBar == "vertical"; end, function(v) SU.SetVertical("MainMenuBar", v); end },
			{ "Cooldown numbers on the spell squares", short = "Cooldown numbers", function() return SS.DB().cooldowns; end, function(v) SS.DB().cooldowns = v and true or false; end } },
		TargetFrame = { TargetLook(), Portraits("TargetFrame"), HideTarget(), Mirror(true),
			{ "Show the target's buffs and debuffs", short = "Target's buffs and debuffs", function() return SS.DB().targetDebuffs; end, function(v) SS.DB().targetDebuffs = v; end },
			TargetBuffsPlace() },
		BuffFrame = { BuffsPlace() },
		MinimapCluster = { { "Square minimap (off: round)", function() return SS.DB().minimapSquare; end, function(v) SS.SetMinimapSquare(v); end },
			{ "Transparent minimap (round or square, no borders)", function() return SS.DB().minimapTransparent; end, function(v) SS.SetMinimapTransparent(v); end },
			ShowClock(), DetachClock(),
			ButtonPlace(),
			{ "Show caches on the minimap", short = "Caches", function() return SS.DB().minimapCaches; end, function(v) SS.DB().minimapCaches = v and true or false; end },
			{ "Show bosses on the minimap", short = "Bosses", function() return SS.DB().minimapBosses; end, function(v) SS.DB().minimapBosses = v and true or false; end },
			{ "Show lairs and their refill timer", short = "Lairs", function() return SS.DB().minimapLairs; end, function(v) SS.DB().minimapLairs = v and true or false; end },
			{ "The game's nearest Guardian lair flag", short = "Guardian lair flag", function() return SS.DB().showGuardianFlag; end, function(v) SS.DB().showGuardianFlag = v and true or false; SS.ApplyGuardianFlag(); end },
			{ "Slim Suite's gear button", short = "Gear button", function() local m = SS.DB().minimap; return not (type(m) == "table" and m.hide); end,
				function(v) if ( SS.Mini ) then local m = SS.DB().minimap; if ( (type(m) == "table" and m.hide and true or false) == (v and true or false) ) then SS.Mini.Toggle(); end end end } },
		SlimSuiteMinimapBar = { ButtonPlace() },
		SlimSuiteClockFrame = { { "Show the zone and Heroic affixes under it", short = "Zone and Heroic affixes", function() return SS.DB().zoneLine; end, function(v) SS.DB().zoneLine = v; end } },
		MainMenuExpBar = { { "Turn the XP bar vertical", function() return SS.DB().orientations.MainMenuExpBar == "vertical"; end,
			function(v) SU.SetVertical("MainMenuExpBar", v); SS.Safe(SS.LayoutXpSegments); end },
			{ "Split into 20 segments", function() return SS.DB().xpSegments ~= false; end,
			function(v) SS.DB().xpSegments = v and true or false; SS.Safe(SS.LayoutXpSegments); end, xref = true, short = "Split into 20 segments" } },
		PartyMemberFrame1 = {
			{ "Party layout", function() return SS.DB().orientations.PartyMemberFrame1 == "horizontal" and "horizontal" or "vertical"; end,
				function(v) SU.SetPartyRow(v == "horizontal"); end, choice = SS.PARTY_LAYOUTS, short = "Layout" },
			{ "Party look", function() return SS.Look("PartyMemberFrame1"); end, function(v) SS.SetLook("PartyMemberFrame1", v); end,
				choice = SS.PARTY_LOOKS, short = "Look" },
			{ "Show character faces", function() return SS.DB().partyFaces ~= false; end, function(v) SU.SetPartyOption("partyFaces", v); end },
			{ "Party members' buffs above them", function() return SS.DB().partyMemberBuffs ~= false; end, function(v) SS.DB().partyMemberBuffs = v and true or false; SS.Safe(SS.UpdateFriendBuffs); end, short = "Friends' buffs" },
			SelfParty(), YouIn(BuffsPlace()), YouIn(ProcMeter()), PartyPlace() },
		SlimSuiteBossFrames = { { "Show debuffs on the bars", function() return SS.DB().encounterDebuffs; end, function(v) SS.DB().encounterDebuffs = v; end },
			{ "Health bar thickness", function() return SS.DB().encounterBarThickness or "standard"; end,
			function(v) SS.DB().encounterBarThickness = v; SS.Safe(SS.UpdateBossFrames); end,
			choice = { { "Compact", "compact" }, { "Standard", "standard" }, { "Thick", "thick" } } },
			{ "Name alignment", function() return SS.DB().encounterNameAlign or "center"; end,
			function(v) SS.DB().encounterNameAlign = v; SS.Safe(SS.UpdateBossFrames); end,
			choice = { { "Left", "left" }, { "Center", "center" }, { "Right", "right" } } },
			{ "High-contrast bars", function() return SS.DB().accessibilityContrast; end,
			function(v) SS.DB().accessibilityContrast = v and true or false; SS.Safe(SS.UpdateBossFrames); end },
			{ "Larger encounter names", function() return SS.DB().accessibilityLargeText; end,
			function(v) SS.DB().accessibilityLargeText = v and true or false; SS.Safe(SS.UpdateBossFrames); end },
			{ "Vertical", function() return SS.DB().orientations.SlimSuiteBossFrames == "vertical"; end,
			function(v) SS.DB().orientations.SlimSuiteBossFrames = v and "vertical" or "horizontal"; SS.DB().sizes.SlimSuiteBossFrames = nil; SS.Safe(SS.UpdateBossFrames); SS.Safe(PlaceAll); SU.UpdateDemo(); end } },
		SlimSuiteTallyFrame = {
			{ "Show map name and difficulty", function() return SS.DB().tallyContext; end, function(v) SS.DB().tallyContext = v and true or false; SS.UpdateTally(); end },
			{ "Show boss and Guardian kills", function() return SS.DB().tallyBossKills; end, function(v) SS.DB().tallyBossKills = v; end },
			{ "Dark band behind it", function() return SS.DB().tallyBackground; end, function(v) SS.DB().tallyBackground = v; end } },
		SlimSuiteLocalClockFrame = {
			{ "Dark background", function() return SS.DB().localClockBackground ~= false; end, function(v) SS.DB().localClockBackground = v; end },
			{ "24-hour time", function() return SlimSuiteWorld and SlimSuiteWorld.ClockIs24 and SlimSuiteWorld.ClockIs24(); end, function(v) SS.DB().localClock24 = v; end },
			ShowClock(), DetachClock() },
		SlimSuiteSpellRowFrame = { VerticalRow("SlimSuiteSpellRowFrame"), JoinRows() },
		SlimSuiteItemRowFrame = { VerticalRow("SlimSuiteItemRowFrame"), JoinRows() },
		SlimSuiteCombatTextFrame = {
			{ "Show heals", function() return SS.DB().ctHeals ~= false; end, function(v) SS.DB().ctHeals = v and true or false; end },
			{ "Crits: bigger and longer", function() return SS.DB().ctCrits ~= false; end, function(v) SS.DB().ctCrits = v and true or false; end },
			{ "Spell icons", function() return SS.DB().ctIcons ~= false; end, function(v) SS.DB().ctIcons = v and true or false; end },
			{ "Lines stay twice as long", function() return SS.DB().ctLong ~= false; end, function(v) SS.DB().ctLong = v and true or false; end },
			{ "Crits and your biggest hits grow and fall away", short = "Big hits grow and fall", function() return SS.DB().ctPop ~= false; end, function(v) SS.DB().ctPop = v and true or false; end },
			{ "Reduce floating-text motion", function() return SS.DB().accessibilityReduceMotion; end, function(v) SS.DB().accessibilityReduceMotion = v and true or false; end } },
	};
	local out = {};
	-- "Movable?" belongs to the game's own frame: not offered while a card or the thin lines show the element
	if ( frame and SU.NATIVE[frame] and SS.Shown(frame) == frame ) then
		table.insert(out, { "Movable? (Disables Default UI Element)", short = "Movable? (off: default UI)", function() return not (SS.DB().frameDefault and SS.DB().frameDefault[frame]); end,
			function(v) SU.SetMovable(frame, v); end, warn = SU.WARN_UNMOVABLE[frame] });
	end
	for _, c in ipairs(frame and list[frame] or {}) do table.insert(out, c); end
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
	"SlimSuiteStoreLevelsToggle", "SlimSuiteWorldMarkers", "SlimSuiteFloatingText", "SlimSuiteMovePanel", "SlimSuiteStatCounterFrame", "GameTimeFrame" };

-- the chat windows, their tabs and their input boxes stay visible and usable during setup, so you can always type;
-- so do the game's error popup, menus and confirmation dialogs, and Slim Suite's own tools. Hidden, these came back
-- invisible but still catching clicks, which stopped any further changes.
SU.KEEP_VISIBLE = { ScriptErrors = true, SlimSuiteErrorFrame = true, SlimSuiteMouseProbe = true, ItemRefTooltip = true,
	UIErrorsFrame = true, SlimSuiteWarnTip = true, ChatFrameEditBox = true, ChatFrameMenuButton = true };
for i = 1, 3 do SU.KEEP_VISIBLE["DropDownList" .. i] = true; end
for i = 1, 4 do SU.KEEP_VISIBLE["StaticPopup" .. i] = true; end
for i = 1, 7 do
	SU.KEEP_VISIBLE["ChatFrame" .. i] = true; SU.KEEP_VISIBLE["ChatFrame" .. i .. "Tab"] = true; SU.KEEP_VISIBLE["ChatFrame" .. i .. "EditBox"] = true;
end

-- hide everything that is not the setup's own: the game's UI, Slim Suite's frames, the minimap and its buttons and pins
function SU.HideAll()
	local keep = { [SU.panel] = true, [SU.bar] = true, [SU.glow] = true };
	if ( SU.confirmDone ) then keep[SU.confirmDone] = true; end
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
SU.FEATURES = {
	SlimSuiteStatCounterFrame = function(v)
		if ( v and setupActive ) then statCounterPlaceholder:Show(); else statCounterPlaceholder:Hide(); end
	end,
	SlimSuiteStoredLevelsButton = function(v) SS.DB().moveLevelButton = v; SS.UpdateLevelButton(); end,
	SlimSuiteSpellRowFrame = function(v) SS.DB().replaceBuildRows = v; SS.ApplyBuildRowReplacement(); end,
	SlimSuiteClockFrame = function(v) SS.DB().replaceClock = v; SS.UpdateClock(); end,
	SlimSuiteBossFrames = function(v) SS.DB().replaceEncounters = v; SS.UpdateBossFrames(); end,
	SlimSuiteTallyFrame = function(v) SS.DB().replaceTally = v; SS.UpdateTally(); end,
	SlimSuiteAnnouncementFrame = function(v) SS.DB().replaceBanners = v; SS.UpdateAnnouncementFrame(); end,
	SlimSuiteReviveFrame = function(v) SS.DB().replaceRevive = v; end,
	SlimSuiteCombatTextFrame = function(v) SS.DB().combatTextBox = v; end,
	SlimSuiteLocalClockFrame = function(v)
		if ( v ) then SS.DB().replaceLocalClock = true;
		else SS.DB().replaceLocalClock = false; SS.DB().clockDetached = false; end
		SS.Safe(SlimSuiteWorld.UpdateLocalClock);
	end,
	SlimSuiteMinimapBar = function(v) SS.SetMinimapBar(v, true); end,
};

-- A setup element's Default state means the original Blizzard/Aethus element is active and Slim Suite's
-- replacement is inactive. These calls intentionally set game HUD visibility to shown, even if the player
-- previously hid that part in Interface settings: choosing Default explicitly asks for the game's design.
SU.NATIVE_PARTS = {
	SlimSuiteStoredLevelsButton = "levels", SlimSuiteSpellRowFrame = "build", SlimSuiteMeterFrame = "meter",
	SlimSuiteClockFrame = "clock", SlimSuiteBossFrames = "bosses", SlimSuiteTallyFrame = "tally",
	SlimSuiteAnnouncementFrame = "banners", SlimSuiteReviveFrame = "revive", SlimSuiteLocalClockFrame = "localClock",
};
function SU.RestoreNative(frame)
	local d = SS.DB();
	local part = SU.NATIVE_PARTS[frame];
	if ( part ) then
		SS.Safe(SS.HideNative, part, false);
		local key = SS.NATIVE_KEYS and SS.NATIVE_KEYS[part];
		if ( key ) then d[key] = nil; end
		if ( type(AZS_SetHudShown) == "function" ) then SS.Safe(AZS_SetHudShown, part, true); end
	end
	if ( frame == "PlayerFrame" ) then
		d.playerLook = "classic";
		if ( SS.DB().partyIncludesSelf ) then SS.SetPartySelf(false); end
		if ( SS.DB().mirrorTarget ) then SS.SetMirrorTarget(false); end
	elseif ( frame == "TargetFrame" ) then
		d.targetLook = "classic"; d.hideTarget = false;
		SS.Safe(SS.TargetFrameHidden, false);
	elseif ( frame == "PartyMemberFrame1" ) then d.partyLook = "classic";
	elseif ( frame == "BuffFrame" ) then
		d.buffsOnPlayer, d.buffsOnTarget, d.buffCustomLayout = false, false, false;
		d.buffGrowthDirection = "down";
		d.sizes.BuffFrame, d.orientations.BuffFrame, d.padding.BuffFrame = nil, nil, nil;
		SS.Safe(SS.ApplyBuffOrientation);
	elseif ( frame == "MinimapCluster" ) then
		d.minimapSquare, d.minimapTransparent, d.minimapBar, d.gatherButtons = false, false, false, false;
		SS.Safe(SS.SetMinimapBar, false, true); SS.Safe(SS.LayoutGather); SS.Safe(SS.LayoutMinimapBar);
	elseif ( frame == "MainMenuBar" ) then
		d.plainBar = false; SS.Safe(SS.PlainBar, false); SS.Safe(SS.RestoreNativeActionBarLayout);
	end
	if ( frame == "SlimSuiteStatCounterFrame" ) then return; end
	if ( frame == "TargetFrame" or frame == "PlayerFrame" or frame == "PartyMemberFrame1" ) then SS.Safe(SS.ApplyNewFrames); end
	if ( frame == "MinimapCluster" ) then SS.Safe(SS.ApplyMinimapShape); end
end

function SU.SetOn(frame, on, title)
	-- the newest choice wins: a target frame turned on or off by its own button takes precedence over the party/combine settings
	if ( frame == "PlayerFrame" and on and not SU.restoring and SS.DB().partyIncludesSelf ) then SS.Safe(SS.ClaimTarget, "player"); end
	if ( frame == "TargetFrame" and not on and SS.DB().combineTarget and not SU.restoring and not SU.cascading and not SU.defaulting ) then
		SS.Notice("Mirror Target turned off: the target frame is off.");
		SS.Safe(SS.SetMirrorTarget, false); SS.Safe(SS.RebuildSetup);
	end
	-- the damage meter element is the same switch as "Replace Default Damage Meter with Movable Version?"
	if ( frame == "SlimSuiteMeterFrame" and not SU.restoring ) then SS.DB().moveMeter = on and true or false; end
	-- the same goes for every replacement: its element in the list is its on/off switch
	local feature = SU.FEATURES[frame];
	if ( feature and not SU.restoring ) then SS.Safe(feature, on and true or false); end
	local nativePart = SU.NATIVE_PARTS[frame];
	if ( nativePart ) then SS.Safe(SS.HideNative, nativePart, on or SS.DB().elementModes[frame] == "disabled"); end
	-- the target frame element is the same switch as "Hide the target frame": off here is off in the game too
	if ( frame == "TargetFrame" and not SU.restoring and not SU.defaulting and (SS.DB().hideTarget and true or false) == (on and true or false) ) then
		SS.DB().hideTarget = not on;
		SS.Safe(SS.TargetFrameHidden, not on);
		SS.Safe(SS.ApplyNewFrames);
	end
	SU.on = SU.on or {};
	SU.on[frame] = on and true or nil;
	SS.DB().enabledElements = SS.DB().enabledElements or {};
	SS.DB().enabledElements[frame] = on and true or nil;
	if ( frame == "PlayerFrame" and SS.DB().combineTarget and getglobal("TargetFrame") ) then
		SU.cascading = true;
		SS.Safe(SU.SetOn, "TargetFrame", on, SU.titles and SU.titles.TargetFrame or "Target frame");
		SU.cascading = false;
	end
	local names = { frame };
	local companions = SU.CompanionsOf(frame);
	for i = 1, table.getn(companions) do table.insert(names, companions[i]); end
	if ( frame == "TargetFrame" and SS.DB().buffsOnTarget ) then table.insert(names, "BuffFrame"); end
	if ( frame == "PlayerFrame" and SS.DB().buffsOnPlayer ) then table.insert(names, "BuffFrame"); end
	if ( frame == "SlimSuiteMinimapBar" ) then
		for i = 1, table.getn(SlimSuiteMinimapBarList) do
			local n = SlimSuiteMinimapBarList[i].GetName and SlimSuiteMinimapBarList[i]:GetName();
			if ( n ) then table.insert(names, n); end
		end
	end
	if ( frame == "MinimapCluster" ) then
		table.insert(names, "Minimap");
		if ( GameTimeFrame and not GameTimeFrame.slimBarOrig ) then table.insert(names, "GameTimeFrame"); end   -- unless the moon is in the row
		-- the game's own minimap parts (its round border, zoom buttons, zone text), so the chosen shape can be seen;
		-- other addons' minimap buttons stay hidden
		for _, root in ipairs({ Minimap, MinimapCluster }) do
			if ( root and root.GetChildren ) then
				local kids = { root:GetChildren() };
				for i = 1, table.getn(kids) do
					local n = kids[i] and kids[i].GetName and kids[i]:GetName();
					if ( n and n ~= "Minimap" and not kids[i].slimBarOrig and (string.find(n, "^Minimap") or string.find(n, "^MiniMap")) ) then table.insert(names, n); end
				end
			end
		end
		-- the local clock hangs under the minimap unless it has been detached (then it is its own element)
		if ( SS.DB().replaceLocalClock and not SS.DB().clockDetached ) then table.insert(names, "SlimSuiteLocalClockFrame"); end
	end
	for i = 1, table.getn(names) do
		if ( names[i] == "PlayerFrame" or names[i] == "TargetFrame" or names[i] == "PartyMemberFrame1" ) then names[i] = SS.Shown(names[i]); end
	end
	for _, fname in ipairs(names) do
		local f = getglobal(fname);
		if ( f and f.SetAlpha ) then
			SU.Save(f);
			if ( on ) then
				if ( SU.shownBefore and SU.shownBefore[f] and f.Show ) then f:Show(); end
				if ( (fname == "SlimSuitePlayerCard" or fname == "SlimSuiteTargetCard" or fname == "SlimSuiteMinimapBar") and f.Show ) then f:Show(); end
				-- an element turned on is shown, even if it was invisible when the setup opened (e.g. the classic frames
				-- sat at alpha 0 under the new-school cards); a hidden feature is faded out again by its own setting
				local a = SU.saved[f];
				if ( type(a) ~= "number" or a <= 0 ) then a = 1; end
				f:SetAlpha(a);
				if ( fname == "TargetFrame" and not SS.DB().hideTarget and f.Show ) then f:Show(); end
				local p = f:GetParent();                     -- a hidden parent would hide the element too
				while ( p and p ~= UIParent and p.SetAlpha ) do SU.Save(p); p:SetAlpha(SU.saved[p]); p = p:GetParent(); end
			elseif ( not SU.defaulting and frame ~= "ChatFrame1" and not SU.KEEP_VISIBLE[fname] ) then
				f:SetAlpha(0);
			end
		end
	end
	-- Turning the target frame off ends the combined mirror; reopening setup only restores what is shown.
	if ( frame == "TargetFrame" and not on and SS.DB().mirrorTarget and not SU.restoring and not SU.defaulting ) then
		SS.SetMirrorTarget(false); SS.Notice("Mirror Target turned off: the target frame is off.");
	end
	local hname = SS.Shown(frame);
	if ( hname ~= frame and handles[frame] ) then handles[frame]:Hide(); end    -- the hidden frame's handle never shows
	if ( on and not handles[hname] and title ) then SS.Safe(SS.Handle, hname, title); end
	if ( handles[hname] ) then if ( on and SS.HandleAllowed(hname) ) then handles[hname]:Show(); else handles[hname]:Hide(); end end
	if ( frame == "MinimapCluster" and on ) then SS.Safe(SS.ApplyMinimapShape); end   -- round border or square edge
	if ( frame == "ChatFrame1" and on ) then SS.Safe(SS.PrepareChatWindow); end
	if ( frame == "PlayerFrame" or frame == "TargetFrame" ) then
		SS.Safe(SS.RefreshCard, getglobal(frame == "PlayerFrame" and "SlimSuitePlayerCard" or "SlimSuiteTargetCard"));
	end
	if ( not SU.batching ) then
		SU.RefreshBar(); SU.UpdateDemo();
		if ( frame == "PlayerFrame" and SU.focus == "TargetFrame" ) then SU.Focus("TargetFrame"); end
	end
end

-- the grid: the setting, the bar button and the panel's tick box all agree
function SU.SetGridSetting(on)
	SS.DB().showEditGrid = on and true or false;
	SS.Safe(ShowEditGrid);                                 -- shows it while editing, or takes it away
	if ( setupActive ) then SU.SetOn("SlimSuiteEditGrid", on and true or false); end
	if ( SU.grid ) then SU.grid.Refresh(); end
end

function SU.Mode(frame)
	local modes = SS.DB().elementModes or {};
	local mode = modes[frame];
	if ( mode == "enabled" or mode == "disabled" or mode == "default" ) then return mode; end
	if ( SS.DB().enabledElements and SS.DB().enabledElements[frame] ) then return "enabled"; end
	-- Preserve explicit settings from older versions, but availability alone must never activate a replacement.
	local d = SS.DB();
	local legacy = {
		SlimSuiteStoredLevelsButton = d.moveLevelButton,
		SlimSuiteSpellRowFrame = d.replaceBuildRows,
		SlimSuiteClockFrame = d.replaceClock,
		SlimSuiteBossFrames = d.replaceEncounters,
		SlimSuiteTallyFrame = d.replaceTally,
		SlimSuiteAnnouncementFrame = d.replaceBanners,
		SlimSuiteReviveFrame = d.replaceRevive,
		SlimSuiteCombatTextFrame = d.combatTextBox,
		SlimSuiteLocalClockFrame = d.replaceLocalClock,
		SlimSuiteMinimapBar = d.minimapBar,
	};
	if ( legacy[frame] ) then return "enabled"; end
	if ( frame == "SlimSuiteMeterFrame" and SS.DB().moveMeter ) then return "enabled"; end
	if ( (frame == "PlayerFrame" or frame == "TargetFrame") and SS.UsesCard(frame) ) then return "enabled"; end
	if ( frame == "PartyMemberFrame1" and SS.Look(frame) == "thin" ) then return "enabled"; end
	if ( frame == "TargetFrame" and SS.DB().hideTarget ) then return "disabled"; end
	return "default";
end

-- Detect an existing HUD setup so onboarding never resets a returning player's saved layout.
function SS.HasPriorUISetup(d)
	d = d or SS.DB();
	if ( d.setupDone or d.unlocked ) then return true; end
	if ( next(d.elementModes or {}) or next(d.enabledElements or {}) ) then return true; end
	if ( next(d.frameDefault or {}) or next(d.layouts or {}) or d.layoutPerCharacter ) then return true; end
	if ( next(d.sizes or {}) or next(d.scales or {}) or next(d.orientations or {}) ) then return true; end
	for frame in pairs(d.places or {}) do if ( frame ~= "SlimSuiteItemRowFrame" ) then return true; end end
	for _, key in ipairs({ "moveLevelButton", "moveMeter", "replaceBuildRows", "replaceClock", "replaceEncounters", "replaceTally", "replaceBanners", "replaceRevive", "replaceLocalClock", "minimapBar", "combatTextBox", "hideTarget", "partyIncludesSelf", "mirrorTarget", "combineTarget", "buffsOnPlayer", "minimapSquare", "minimapTransparent" }) do
		if ( d[key] ) then return true; end
	end
	return false;
end

-- Reapply explicit element choices after the game restores its native frames during login or setup exit.
function SS.ApplyElementModes()
	if ( setupActive ) then return; end
	local modes, steps, seen = SS.DB().elementModes or {}, SU.Steps(), {};
	for i = 1, table.getn(steps) do
		local frame = steps[i].frame;
		if ( frame and (modes[frame] == "enabled" or modes[frame] == "disabled") ) then
			seen[frame] = true;
			SS.Safe(SU.SetOn, frame, modes[frame] == "enabled", steps[i].title);
		end
	end
	if ( modes.SlimSuiteMeterFrame and not seen.SlimSuiteMeterFrame and (modes.SlimSuiteMeterFrame == "enabled" or modes.SlimSuiteMeterFrame == "disabled") ) then
		SS.Safe(SU.SetOn, "SlimSuiteMeterFrame", modes.SlimSuiteMeterFrame == "enabled", "Damage meter");
	end
	if ( not SS.DB().unlocked ) then SS.Safe(SS.SetUnlocked, false, true); end
end

function SU.SetMode(frame, mode, title)
	if ( mode ~= "enabled" and mode ~= "disabled" and mode ~= "default" ) then mode = "default"; end
	local d = SS.DB();
	d.elementModes = d.elementModes or {};
	d.elementModes[frame] = mode;
	if ( mode == "enabled" ) then
		SU.defaulting = false;
		if ( d.frameDefault ) then d.frameDefault[frame] = nil; end
		if ( not SU.restoring ) then d.muted[frame] = nil; d.muted[SS.Shown(frame)] = nil; end
		SU.SetOn(frame, true, title);
	elseif ( mode == "disabled" ) then
		SU.defaulting = false;
		SU.SetOn(frame, false, title);
	else
		-- Restore the game's native element without treating Default as an instruction to hide it.
		SU.defaulting = true;
		SU.SetOn(frame, false, title);
		SU.defaulting = false;
		if ( not SU.restoring ) then SS.Safe(SU.RestoreNative, frame); end
		if ( SU.NATIVE[frame] ) then SS.Safe(SU.SetMovable, frame, false); end
		if ( not SU.restoring ) then
			if ( frame == "TargetFrame" ) then
				d.hideTarget = false;
				if ( SS.UsesCard("TargetFrame") ) then SS.Safe(SS.SetLook, "TargetFrame", "classic"); end
				SS.Safe(SS.TargetFrameHidden, false); SS.Safe(SS.ApplyNewFrames);
			elseif ( frame == "PlayerFrame" and SS.UsesCard("PlayerFrame") ) then
				SS.Safe(SS.SetLook, "PlayerFrame", "classic");
			elseif ( frame == "PartyMemberFrame1" and SS.Look("PartyMemberFrame1") == "thin" ) then
				SS.Safe(SS.SetLook, "PartyMemberFrame1", "classic");
			elseif ( frame == "MinimapCluster" ) then
				d.minimapSquare, d.minimapTransparent = false, false;
			end
		end
		local names = { frame };
		local companions = SU.CompanionsOf(frame);
		for i = 1, table.getn(companions) do table.insert(names, companions[i]); end
		for i = 1, table.getn(names) do
			local name = names[i];
			if ( name == "PlayerFrame" or name == "TargetFrame" or name == "PartyMemberFrame1" ) then name = SS.Shown(name); end
			local f = type(name) == "table" and name or getglobal(name);
			if ( f and f.SetAlpha and not SU.FEATURES[frame] ) then
				f:SetAlpha(1);
				if ( f.Show and frame ~= "GameTooltip" ) then f:Show(); end
			end
		end
		if ( frame == "MinimapCluster" ) then SS.Safe(SS.ApplyMinimapShape); end
		if ( frame == "SlimSuiteMeterFrame" ) then SS.Safe(SS.HideNative, "meter", false); end
	end
	d.enabledElements = d.enabledElements or {};
	d.enabledElements[frame] = mode == "enabled" and true or nil;
	if ( not SU.batching ) then SU.RefreshBar(); SU.UpdateDemo(); SU.RefreshDemoButtons(); end
	-- Selecting Enabled in setup immediately selects that element and exposes its green move handle.
	if ( not SU.batching and setupActive and mode == "enabled" ) then SU.Focus(frame); end
	if ( frame == "ChatFrame1" ) then SS.Safe(SS.RefreshChatDock); end
	if ( not SU.batching ) then SS.RefreshToggles(); end
end

function SU.CycleMode(frame)
	local nextMode = { default = "enabled", enabled = "disabled", disabled = "default" };
	SU.SetMode(frame, nextMode[SU.Mode(frame)] or "default", SU.titles and SU.titles[frame]);
	if ( SU.Mode(frame) == "enabled" ) then SU.Focus(frame); elseif ( SU.focus == frame ) then SU.Focus(nil); end
end

function SS.Demoing(name)
	if ( not SS.demoRunning or not SS.demoElements ) then return false; end
	local element = SS.Element and SS.Element(name) or name;
	local selected = SS.demoElements[name] or SS.demoElements[element];
	-- The spell and worn-jewelry rows are one default build element and preview together.
	if ( name == "SlimSuiteItemRowFrame" or name == "SlimSuiteSpellRowFrame" ) then
		selected = SS.demoElements.SlimSuiteSpellRowFrame;
	end
	if ( not selected ) then return false; end
	return not SU or not SU.Mode or SU.Mode(element) == "enabled";
end

-- the action bar: vertical or horizontal, kept until changed
function SU.SetVertical(name, on)
	SS.DB().orientations[name] = on and "vertical" or "horizontal";
	SS.Safe(ApplyMovableOrientation, name);
	SS.Safe(PlaceAll);
	SU.UpdateDemo();
	if ( SU.checks ) then for i = 1, table.getn(SU.checks) do SU.checks[i].Refresh(); end end
end

-- How far the party block reaches down from the first party frame's top, in UIParent units: all four party frames,
-- shown or not (a hidden frame keeps its place), and the setup's sample cards while they are on screen.
function SS.PartyBlockDepth(first)
	if ( first and first == getglobal("SlimSuitePartyLines") ) then return (first:GetHeight() or 0) * RootFactor(first); end
	local depth = 0;
	local top = first and first:GetTop();
	if ( top ) then
		top = top * RootFactor(first);
		for i = 1, 4 do
			local p = getglobal("PartyMemberFrame" .. i);
			local b = p and p:GetBottom();
			if ( b ) then depth = math.max(depth, top - b * RootFactor(p)); end
		end
	end
	if ( depth <= 0 and first ) then depth = (first:GetHeight() or 0) * RootFactor(first); end
	return depth;
end

-- handles that are invisible until the mouse is over them (the frame under them is its own preview)
SS.QUIET_HANDLES = { PlayerFrame = true, TargetFrame = true, SlimSuitePlayerCard = true, SlimSuiteTargetCard = true,
	PartyMemberFrame1 = true, SlimSuitePartyLines = true };

-- The target preview in the setup: with no target, the target frame itself (classic or new-school) shows a sample
-- elite, so you see exactly what you are placing. A real target always shows as itself.
SU.SAMPLE_TARGET = { name = "Hogger", level = "??", hp = 70 };
-- the setup and Demo Mode both show the sample previews
SS.demoRunning = false;

function SU.PreviewTarget()
	if ( not SS.Previewing("TargetFrame") or SS.DB().hideTarget ) then return; end
	if ( UnitExists("target") ) then return; end
	local t = SU.SAMPLE_TARGET;
	if ( TargetFrame and not SS.UsesCard("TargetFrame") ) then
		TargetFrame:Show();
		local name, level = getglobal("TargetName"), getglobal("TargetLevelText");
		if ( name and name.SetText ) then name:SetText(t.name); end
		if ( level and level.SetText ) then level:SetText(t.level); end
		local hp, mana = getglobal("TargetFrameHealthBar"), getglobal("TargetFrameManaBar");
		if ( hp and hp.SetMinMaxValues ) then hp:SetMinMaxValues(0, 100); hp:SetValue(t.hp); hp:SetStatusBarColor(0, 1, 0); end
		if ( mana and mana.SetMinMaxValues ) then mana:SetMinMaxValues(0, 100); mana:SetValue(0); end
		local art = getglobal("TargetFrameTexture");
		if ( art and art.SetTexture ) then art:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Elite"); end
		local face = getglobal("TargetPortrait");
		if ( face and face.SetTexture ) then face:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark"); end
	end
end
-- the game redraws the target frame from the real target (or hides it with none) when the setup closes. The game's
-- TargetFrame_Update works on `this` (it reads this.name, this.portrait...), so it runs as the target frame itself: called
-- from a button or a timer, `this` would be that button and the game's code fails ("UnitFrame.lua:25 ... field `name'")
function SU.EndTargetPreview()
	if ( not TargetFrame ) then return; end
	if ( UnitExists("target") and not SS.DB().hideTarget ) then
		if ( TargetFrame_Update ) then SS.RunAs(TargetFrame, TargetFrame_Update); end
	else
		TargetFrame:Hide();
	end
end
-- The party preview in the setup: the game's own four party frames, each empty one filled with a sample teammate,
-- laid out as the party really is (a column or a row, thin lines, faces on or off). Real teammates show as themselves.
SU.MANA_COLOUR = { Warrior = { 1, 0, 0 } };                -- rage; everyone else here uses mana
function SU.PreviewParty()
	if ( not SS.Previewing("PartyMemberFrame1") ) then return; end
	for i = 1, 4 do
		local f = getglobal("PartyMemberFrame" .. i);
		local sample = SU.PARTY_SAMPLE[i];
		if ( f and sample and not UnitExists("party" .. i) ) then
			f.slimPreview = true;
			f:Show();
			local rgb = SS.ClassColor(sample[2]) or { 1, 1, 1 };
			local name = getglobal("PartyMemberFrame" .. i .. "Name");
			if ( name and name.SetText ) then name:SetText(sample[1]); name:SetTextColor(rgb[1], rgb[2], rgb[3]); end
			local hp = getglobal("PartyMemberFrame" .. i .. "HealthBar");
			if ( hp and hp.SetMinMaxValues ) then hp:SetMinMaxValues(0, 100); hp:SetValue(sample[3]); hp:SetStatusBarColor(0, 1, 0); end
			local mana = getglobal("PartyMemberFrame" .. i .. "ManaBar");
			if ( mana and mana.SetMinMaxValues ) then
				local c = SU.MANA_COLOUR[sample[2]] or { 0, 0, 1 };
				mana:SetMinMaxValues(0, 100); mana:SetValue(60); mana:SetStatusBarColor(c[1], c[2], c[3]);
			end
			local face = getglobal("PartyMemberFrame" .. i .. "Portrait");
			if ( face and face.SetTexture ) then
				local coords = SU.CLASS_ICON[sample[2]] or { 0, 1, 0, 1 };
				face:SetTexture("Interface\\WorldStateFrame\\ICONS-CLASSES");
				face:SetTexCoord(coords[1], coords[2], coords[3], coords[4]);
				if ( SS.DB().partyFaces == false ) then face:Hide(); else face:Show(); end
			end
		end
	end
end
-- the sample party and target go once nothing previews them any more (the setup, Toggle UI Settings and Demo Mode all
-- preview them)
function SS.EndPreviewsIfDone()
	if ( not SS.Previewing("PartyMemberFrame1") ) then SS.Safe(SU.EndPartyPreview); end
	if ( not SS.Previewing("TargetFrame") ) then SS.Safe(SU.EndTargetPreview); end
	SS.buffDirty = true;                                    -- the sample buffs come or go
	SS.Safe(SS.UpdateBossFrames);
	SS.Safe(SS.RefreshSpellRow); SS.Safe(SS.RefreshItemRow);
end

-- when the setup closes, a previewed frame with nobody in its place hides again, its face back to a plain portrait
function SU.EndPartyPreview()
	for i = 1, 4 do
		local f = getglobal("PartyMemberFrame" .. i);
		if ( f and f.slimPreview ) then
			f.slimPreview = nil;
			local face = getglobal("PartyMemberFrame" .. i .. "Portrait");
			if ( face and face.SetTexCoord ) then face:SetTexCoord(0, 1, 0, 1); end
			if ( UnitExists("party" .. i) ) then
				if ( face and SetPortraitTexture ) then SS.Safe(SetPortraitTexture, face, "party" .. i); end
			else
				f:Hide();
			end
		end
	end
end

-- clicking the ground or a party change during the setup makes the game hide the empty frames: show the samples again
SS.Every("targetPreview", 0.5, function() SU.PreviewTarget(); SU.PreviewParty(); end);

-- the sample party: four members, shown in the party's own frames (or lines) while it is previewed
SU.PARTY_SAMPLE = { { "Brann", "Priest", 82 }, { "Lyra", "Mage", 55 },
	{ "Tomas", "Hunter", 100 }, { "Velka", "Warrior", 30 } };

-- the class icons (one sheet, a quarter of it per class) for the faces in the party demo
SU.CLASS_ICON = { Warrior = { 0, 0.25, 0, 0.25 }, Mage = { 0.25, 0.49, 0, 0.25 }, Rogue = { 0.49, 0.73, 0, 0.25 },
	Druid = { 0.73, 0.98, 0, 0.25 }, Hunter = { 0, 0.25, 0.25, 0.5 }, Priest = { 0.25, 0.49, 0.25, 0.5 },
	Paladin = { 0.49, 0.73, 0.25, 0.5 }, Shaman = { 0.73, 0.98, 0.25, 0.5 }, Warlock = { 0, 0.25, 0.5, 0.75 } };


-- the party options in the Party frames step: locked to the player frame, thin lines, and a row
function SU.SetPartyOption(key, on)
	SS.DB()[key] = on and true or false;
	if ( key == "partyLocked" and on ) then SS.MakeMovable("PartyMemberFrame1", "Lock to player frame moves them"); end
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
	SU.UpdateDemo();
end

SU.CARD_BACKDROP = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } };
SU.BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar";
SS.BOSS_SAMPLE = { { "Hogger", 60 }, { "Mr. Smite", 40 }, { "Edwin VanCleef", 85 }, { "Cookie", 100 } };   -- real bosses of the first zones

-- The new-school player and target frames: cards in the party frames' look, showing name, health and power.
-- They are only shown while the design is on; the game's own frames are made transparent (not removed) meanwhile.
-- the 3D model of the unit on a new-school card; it is re-read only when the unit changes
function SS.UpdateCardModel(f, unit)
	local m = f.model;
	if ( not m or not m.SetUnit ) then return; end
	if ( SS.DB().cardPortraits == false or not unit or not UnitExists(unit) ) then
		m:Hide(); f.modelFor = nil; return;
	end
	local who = UnitName(unit);
	if ( f.modelFor ~= who or not m:IsShown() ) then
		m:Show(); m:ClearModel(); m:SetUnit(unit); m:SetCamera(0); f.modelFor = who;
	end
end

-- a card's contents follow its size: the portrait fills its height, the name and the bars take the rest
function SS.LayoutCard(f)
	local w, h = f:GetWidth() or 180, f:GetHeight() or 44;
	local portraits = SS.DB().cardPortraits ~= false;
	if ( f.laidW == w and f.laidH == h and f.laidP == portraits ) then return; end
	f.laidW, f.laidH, f.laidP = w, h, portraits;
	local pad = math.max(2, math.floor(h * 0.1));
	local face = portraits and math.max(8, h - pad * 2) or 0;
	f.model:SetWidth(math.max(1, face)); f.model:SetHeight(math.max(1, face));
	f.model:ClearAllPoints(); f.model:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -pad);
	local left = pad + face + (portraits and pad + 2 or 0);
	local powerH, hpH = math.max(2, math.floor(h * 0.09)), math.max(4, math.floor(h * 0.2));
	f.power:ClearAllPoints();
	f.power:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", left, pad); f.power:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -pad, pad);
	f.power:SetHeight(powerH);
	f.hp:ClearAllPoints();
	f.hp:SetPoint("BOTTOMLEFT", f.power, "TOPLEFT", 0, 2); f.hp:SetPoint("BOTTOMRIGHT", f.power, "TOPRIGHT", 0, 2);
	f.hp:SetHeight(hpH);
	f.name:ClearAllPoints();
	f.name:SetPoint("TOPLEFT", f, "TOPLEFT", left, -math.max(2, pad - 1)); f.name:SetPoint("RIGHT", f, "RIGHT", -pad, 0);
	local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF";
	f.name:SetFont(font, math.max(7, math.min(16, math.floor(h * 0.27))));
	f.hpText:SetFont(font, math.max(6, math.min(12, hpH)));
end

function SS.RefreshCard(f)
	if ( not f ) then return; end
	local el = f.unit == "target" and "TargetFrame" or "PlayerFrame";
	if ( not SS.UsesCard(el) or (el == "TargetFrame" and SS.DB().hideTarget) ) then f:Hide(); return; end
	-- Setup restoration can reveal the old frame without changing the selected look.
	-- Enforce exclusive ownership even when only the other unit's style changed.
	local native = getglobal(el);
	if ( native and native.SetAlpha ) then native:SetAlpha(0); end
	local mode = SS.DB().elementModes and SS.DB().elementModes[el];
	if ( mode == "disabled" or (setupActive and not SS.SetupShows(el)) ) then f:Hide(); return; end
	SS.Safe(SS.LayoutCard, f);
	local unit = f.unit;
	SS.Safe(SS.UpdateCardModel, f, unit);
	if ( not UnitExists(unit) ) then
		if ( unit == "target" and SS.Previewing("TargetFrame") ) then
			local t = SU.SAMPLE_TARGET;
			f.name:SetText(t.name); f.name:SetTextColor(0.9, 0.25, 0.25);
			f.hp:SetMinMaxValues(0, 100); f.hp:SetValue(t.hp); f.hpText:SetText("Elite"); f.hpWas = nil;
			f.power:SetMinMaxValues(0, 1); f.power:SetValue(0);
			f:Show();
		else
			f:Hide();
		end
		return;
	end
	local rgb = SS.RGB.white;
	if ( UnitIsPlayer(unit) ) then
		local _, token = UnitClass(unit);
		rgb = SS.ClassColor(token) or rgb;
	elseif ( UnitIsEnemy and UnitIsEnemy("player", unit) ) then
		rgb = SS.RGB.enemy;
	else
		rgb = SS.RGB.friend;
	end
	f.name:SetText(UnitName(unit) or ""); f.name:SetTextColor(rgb[1], rgb[2], rgb[3]);
	local hp, hpMax = UnitHealth(unit) or 0, UnitHealthMax(unit) or 1;
	if ( hpMax < 1 ) then hpMax = 1; end
	f.hp:SetMinMaxValues(0, hpMax); f.hp:SetValue(hp);
	SS.UpdateAbsorbMarker(f.hp, unit, hp, hpMax);
	if ( f.hpWas ~= hp or f.hpMaxWas ~= hpMax ) then f.hpWas, f.hpMaxWas = hp, hpMax; f.hpText:SetText(hp .. " / " .. hpMax); end
	local pw, pwMax = UnitMana(unit) or 0, UnitManaMax(unit) or 1;
	if ( pwMax < 1 ) then pwMax = 1; end
	local kind = UnitPowerType(unit);
	local pc = SS.RGB.mana;
	if ( kind == 1 ) then pc = SS.RGB.rage; elseif ( kind == 3 ) then pc = SS.RGB.energy; end
	f.power:SetStatusBarColor(pc[1], pc[2], pc[3]);
	f.power:SetMinMaxValues(0, pwMax); f.power:SetValue(pw);
	f:Show();
end

-- Use the game's run state for the local hero (the documented `sh` field). For other unit
-- tokens, show a value only if this client exposes a standard unit absorb query.
function SS.AbsorbAmount(unit)
	if ( unit == "player" and type(AZS_RUN) == "table" and tonumber(AZS_RUN.sh) ) then
		local phase = type(AZS_GetPhase) == "function" and AZS_GetPhase() or nil;
		if ( phase == "playing" or phase == "choosing" or phase == "paused" ) then return math.max(0, tonumber(AZS_RUN.sh)); end
	end
	if ( type(UnitGetTotalAbsorbs) == "function" ) then
		local ok, value = pcall(UnitGetTotalAbsorbs, unit);
		if ( ok and tonumber(value) ) then return math.max(0, tonumber(value)); end
	end
	return nil;
end
function SS.UpdateAbsorbMarker(bar, unit, health, maximum)
	if ( not bar or not unit ) then return; end
	if ( not SS.DB().showAbsorbs and not bar.slimAbsorb ) then return; end
	if ( not bar.slimAbsorb ) then
		bar.slimAbsorb = bar:CreateTexture(nil, "OVERLAY");
		bar.slimAbsorb:SetTexture("Interface\\TargetingFrame\\UI-StatusBar");
		bar.slimAbsorb:SetVertexColor(0.2, 1, 0.35, 0.9);
		bar.slimAbsorbText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		bar.slimAbsorbText:SetTextColor(0.55, 1, 0.55);
	end
	local value = SS.DB().showAbsorbs and SS.AbsorbAmount(unit) or nil;
	local width = bar:GetWidth() or 0;
	if ( not value or value <= 0 or not maximum or maximum <= 0 or width <= 0 ) then
		bar.slimAbsorb:Hide(); bar.slimAbsorbText:Hide(); return;
	end
	local start = width * math.min(1, math.max(0, health or 0) / maximum);
	local extent = math.min(width, math.max(2, width * value / maximum));
	-- Shields overlay the health bar, including at full health, without covering adjacent frames.
	start = math.min(start, width - extent);
	bar.slimAbsorb:ClearAllPoints();
	bar.slimAbsorb:SetPoint("LEFT", bar, "LEFT", start, 0);
	bar.slimAbsorb:SetWidth(extent); bar.slimAbsorb:SetHeight(bar:GetHeight() or 6);
	bar.slimAbsorb:Show();
	bar.slimAbsorbText:SetText("+" .. tostring(math.floor(value + 0.5)));
	bar.slimAbsorbText:ClearAllPoints(); bar.slimAbsorbText:SetPoint("LEFT", bar.slimAbsorb, "RIGHT", 2, 0);
	bar.slimAbsorbText:Show();
end
function SS.UpdateAbsorbMarkers()
	local player = getglobal("SlimSuitePlayerCard");
	if ( player and UnitExists("player") ) then SS.UpdateAbsorbMarker(player.hp, "player", UnitHealth("player") or 0, UnitHealthMax("player") or 1); end
	local nativePlayer = getglobal("PlayerFrameHealthBar");
	if ( nativePlayer and UnitExists("player") ) then SS.UpdateAbsorbMarker(nativePlayer, "player", UnitHealth("player") or 0, UnitHealthMax("player") or 1); end
	local selfFrame = getglobal("SlimSuitePartySelfFrame");
	if ( selfFrame and UnitExists("player") ) then SS.UpdateAbsorbMarker(selfFrame.hp, "player", UnitHealth("player") or 0, UnitHealthMax("player") or 1); end
	local lines = getglobal("SlimSuitePartyLines");
	if ( lines and lines.lines ) then
		for i = 1, 5 do local line = lines.lines[i]; if ( line and line.unit and UnitExists(line.unit) ) then SS.UpdateAbsorbMarker(line.bar, line.unit, UnitHealth(line.unit) or 0, UnitHealthMax(line.unit) or 1); end end
	end
	for i = 1, 4 do
		local unit = "party" .. i;
		local bar = getglobal("PartyMemberFrame" .. i .. "HealthBar");
		if ( bar and UnitExists(unit) ) then SS.UpdateAbsorbMarker(bar, unit, UnitHealth(unit) or 0, UnitHealthMax(unit) or 1); end
	end
end
SS.Every("absorbMarkers", 0.25, function() SS.Safe(SS.UpdateAbsorbMarkers); end);

-- The target's buff and debuff tooltips ask the game for buff number "index" of the target. Hovering an icon with no
-- target, or one of Slim Suite's demo icons, gives no valid number, so the game shows an error. Only call the
-- game's own tooltip when that buff really exists.
function SS.GuardTargetTooltips()
	for kind, lookup in pairs({ TargetFrameBuff = UnitBuff, TargetFrameDebuff = UnitDebuff }) do
		for i = 1, 40 do
			local f = getglobal(kind .. i);
			if ( f and f.GetScript and not f.slimGuarded ) then
				local original = f:GetScript("OnEnter");
				-- copies made inside the loop: in the game's Lua 5.0 a loop's own variables are shared by every pass, so a
				-- function made here must not read `i` or `lookup` themselves (it would see the loop's last values)
				local id, find = i, lookup;
				if ( original and find ) then
					f.slimGuarded = true;
					f:SetScript("OnEnter", function()
						if ( UnitExists("target") and find("target", id) ) then original(); end
					end);
				end
			end
		end
	end
end

-- where the cards start (TOPLEFT offsets from the screen's top-left), roughly over the game's own player and target frames
SS.CARD_START = {
	SlimSuitePlayerCard = { 24, -30 },
	SlimSuiteTargetCard = { 250, -30 },
};

-- the same right-click menu the game's own player and target frames open
function SS.CardMenu(f)
	if ( not ToggleDropDownMenu ) then return; end
	if ( f.unit == "target" and TargetFrameDropDown ) then ToggleDropDownMenu(1, nil, TargetFrameDropDown, f:GetName(), 120, 10);
	elseif ( f.unit == "player" and PlayerFrameDropDown ) then ToggleDropDownMenu(1, nil, PlayerFrameDropDown, f:GetName(), 106, 27); end
end

function SS.MakeCards()
	if ( getglobal("SlimSuitePlayerCard") ) then return; end
	local function Make(name, unit)
		local f = CreateFrame("Button", name, UIParent);
		f:SetWidth(unit == "player" and 160 or 180); f:SetHeight(44); f:SetFrameStrata("MEDIUM");
		f:SetBackdrop(SU.CARD_BACKDROP);
		f:SetBackdropColor(0.05, 0.05, 0.05, 0.9);
		f:SetBackdropBorderColor(0.85, 0.65, 0.2, 1);
		f.unit = unit;
		f:EnableMouse(true);
		f:RegisterForClicks("LeftButtonUp", "RightButtonUp");
		f:SetScript("OnClick", function()
			if ( arg1 == "RightButton" ) then SS.Safe(SS.CardMenu, this);
			else SS.Safe(TargetUnit, this.unit); end
		end);
		-- a starting place near the game's own frame (a frame with no anchor is never drawn); a saved place replaces it
		local start = SS.CARD_START[name];
		if ( start ) then f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", start[1], start[2]); end
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
		-- the 3D model on the left; the name and bars start to its right (SS.LayoutCard sizes them to the card)
		f.model = CreateFrame("PlayerModel", nil, f);
		SS.Safe(SS.LayoutCard, f);
		SS.cardFrames = SS.cardFrames or {};
		table.insert(SS.cardFrames, f);
		-- every card is checked, hidden ones too: the target card has to appear when a target is picked
		if ( not SS.cardsTask ) then SS.cardsTask = true; SS.Every("cards", 0.5, function()
			for i = 1, table.getn(SS.cardFrames) do SS.RefreshCard(SS.cardFrames[i]); end
		end); end
		f:Hide();
		return f;
	end
	Make("SlimSuitePlayerCard", "player");
	Make("SlimSuiteTargetCard", "target");
	SS.Safe(SS.Place, "SlimSuitePlayerCard");
	SS.Safe(SS.Place, "SlimSuiteTargetCard");
	-- the cards are made after the saved places were applied at load, so the mirror has to be applied to them now
	if ( SS.DB().mirrorTarget ) then SS.Safe(SS.MirrorTarget); end
end

-- each unit frame shows its look: the game's frame fades out under a new-school card (outside the setup, which owns
-- visibility), and the party shows face plates or thin lines
function SS.ApplyNewFrames()
	local cp, ct = getglobal("SlimSuitePlayerCard"), getglobal("SlimSuiteTargetCard");
	if ( not setupActive ) then
		local P, T = getglobal("PlayerFrame"), getglobal("TargetFrame");
		if ( P and P.SetAlpha ) then P:SetAlpha(SS.UsesCard("PlayerFrame") and 0 or 1); end
		if ( T and T.SetAlpha ) then T:SetAlpha(SS.UsesCard("TargetFrame") and 0 or 1); end
	end
	if ( cp ) then SS.RefreshCard(cp); end
	if ( ct ) then SS.RefreshCard(ct); end
	SS.Safe(SS.ApplyPartyLook);
end

-- a click on a unit Slim Suite draws: left targets it, right opens the game's own menu for it
function SS.UnitClick(btn)
	if ( not btn or not btn.unit ) then return; end
	if ( arg1 == "RightButton" ) then
		if ( not ToggleDropDownMenu ) then return; end
		local menu = btn.unit == "player" and PlayerFrameDropDown or (btn.slot and getglobal("PartyMemberFrame" .. btn.slot .. "DropDown"));
		if ( menu ) then ToggleDropDownMenu(1, nil, menu, btn:GetName(), 0, 0); end
	elseif ( TargetUnit ) then
		TargetUnit(btn.unit);
	end
end

-- The thin-line look: one slim bar per member (name on it, class colour, a small face if faces are on), stacked or in a
-- row, inside one movable block. The block's size is the player's: its width and height are shared out between its
-- places (four, or five with you), so each line follows it. You go first, before the members.
SS.PARTY_LINE = { W = 90, H = 9, GAP = 2, ROWGAP = 4 };
function SS.MakePartyLines()
	local c = getglobal("SlimSuitePartyLines");
	if ( c ) then return c; end
	c = CreateFrame("Frame", "SlimSuitePartyLines", UIParent);
	c:SetFrameStrata("LOW");
	c:SetWidth(SS.PARTY_LINE.W); c:SetHeight(4 * SS.PARTY_LINE.H + 3 * SS.PARTY_LINE.GAP);
	c:SetPoint("TOPLEFT", PartyMemberFrame1 or UIParent, "TOPLEFT", 0, 0);   -- where the party frames start, until moved
	c.lines = {};
	for i = 1, 5 do
		local l = CreateFrame("Button", "SlimSuitePartyLine" .. i, c);
		l:EnableMouse(true);
		if ( l.RegisterForClicks ) then l:RegisterForClicks("LeftButtonUp", "RightButtonUp"); end
		l.bg = l:CreateTexture(nil, "BACKGROUND"); l.bg:SetAllPoints(l); l.bg:SetTexture(0, 0, 0, 0.55);
		l.face = l:CreateTexture(nil, "ARTWORK");
		l.bar = CreateFrame("StatusBar", nil, l);
		l.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); l.bar:SetMinMaxValues(0, 1);
		l.name = l.bar:CreateFontString(nil, "OVERLAY");
		l.name:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 8);
		l.name:SetShadowColor(0, 0, 0, 1); l.name:SetShadowOffset(1, -1); l.name:SetJustifyH("LEFT");
		l.name:SetPoint("LEFT", l.bar, "LEFT", 2, 0); l.name:SetPoint("RIGHT", l.bar, "RIGHT", -2, 0);
		l:SetScript("OnClick", function() SS.Safe(SS.UnitClick, this); end);
		l:Hide();
		c.lines[i] = l;
	end
	c:Hide();
	return c;
end

function SS.UpdatePartyLines()
	local c = SS.MakePartyLines();
	if ( SS.Look("PartyMemberFrame1") ~= "thin" ) then c:Hide(); return; end
	local d = SS.DB();
	local preview = SS.Previewing("PartyMemberFrame1");
	-- you first (as the game lists you), then the members: the same in a run, the setup and Demo Mode
	local entries = {};
	if ( d.partyIncludesSelf ) then table.insert(entries, { unit = "player" }); end
	for i = 1, 4 do
		local unit = "party" .. i;
		if ( UnitExists(unit) ) then table.insert(entries, { unit = unit, slot = i });
		elseif ( preview and SU.PARTY_SAMPLE[i] ) then table.insert(entries, { sample = SU.PARTY_SAMPLE[i] }); end
	end
	local L = SS.PARTY_LINE;
	local slots = d.partyIncludesSelf and 5 or 4;
	local vertical = SS.CurrentOrientation("PartyMemberFrame1") ~= "horizontal";
	local gap = vertical and L.GAP or L.ROWGAP;
	local custom = d.sizes.SlimSuitePartyLines;
	local lw, lh = L.W, L.H;
	if ( type(custom) == "table" and custom.w and custom.h ) then
		if ( vertical ) then lw, lh = custom.w, (custom.h - gap * (slots - 1)) / slots;
		else lw, lh = (custom.w - gap * (slots - 1)) / slots, custom.h; end
	end
	lw, lh = math.max(20, lw), math.max(4, lh);
	c:SetWidth(vertical and lw or (slots * lw + (slots - 1) * gap));
	c:SetHeight(vertical and (slots * lh + (slots - 1) * gap) or lh);
	local faces = d.partyFaces ~= false;
	local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF";
	local size = math.max(6, math.min(12, math.floor(lh * 0.9)));
	for k = 1, 5 do
		local l, e = c.lines[k], entries[k];
		if ( e ) then
			l:SetWidth(lw); l:SetHeight(lh);
			l:ClearAllPoints();
			if ( vertical ) then l:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(k - 1) * (lh + gap));
			else l:SetPoint("TOPLEFT", c, "TOPLEFT", (k - 1) * (lw + gap), 0); end
			l.unit, l.slot = e.unit, e.slot;
			local name, class, hp, hpMax, dead;
			if ( e.sample ) then
				name, class, hp, hpMax = e.sample[1], e.sample[2], e.sample[3], 100;
			else
				name = UnitName(e.unit) or "";
				local _, token = UnitClass(e.unit); class = token;
				hp, hpMax = UnitHealth(e.unit) or 0, UnitHealthMax(e.unit) or 1;
				dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(e.unit);
			end
			if ( not hpMax or hpMax < 1 ) then hpMax = 1; end
			-- a small face at the left, as tall as the line
			local faceW = 0;
			if ( faces ) then
				faceW = lh;
				l.face:SetWidth(lh); l.face:SetHeight(lh); l.face:ClearAllPoints(); l.face:SetPoint("LEFT", l, "LEFT", 0, 0);
				local key = e.sample and ("s" .. name) or (e.unit .. ":" .. name);
				if ( l.faceFor ~= key ) then
					l.faceFor = key;
					if ( e.sample ) then
						local coords = SU.CLASS_ICON[class] or { 0, 1, 0, 1 };
						l.face:SetTexture("Interface\\WorldStateFrame\\ICONS-CLASSES");
						l.face:SetTexCoord(coords[1], coords[2], coords[3], coords[4]);
					else
						l.face:SetTexCoord(0, 1, 0, 1);
						if ( SetPortraitTexture ) then SetPortraitTexture(l.face, e.unit); end
					end
				end
				l.face:Show();
			else
				l.face:Hide();
			end
			l.bar:ClearAllPoints();
			l.bar:SetPoint("TOPLEFT", l, "TOPLEFT", faceW + 1, -1); l.bar:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", -1, 1);
			l.bar:SetMinMaxValues(0, hpMax); l.bar:SetValue(dead and 0 or hp);
			local rgb = SS.ClassColor(class) or SS.RGB.health;
			if ( dead ) then rgb = SS.RGB.dead; end
			l.bar:SetStatusBarColor(rgb[1] * 0.75, rgb[2] * 0.75, rgb[3] * 0.75);
			if ( l.fontSize ~= size ) then l.fontSize = size; l.name:SetFont(font, size); end
			l.name:SetText(name);
			l:Show();
		else
			l.unit, l.slot = nil, nil;
			l:Hide();
		end
	end
	c:Show();
end

-- Your own plate among the party in the classic look, made from the game's own party frame: the same art, portrait,
-- name and bars at the same size and places (copied from the first party frame), so it looks like everyone else.
function SS.MakeClassicSelf()
	local f = getglobal("SlimSuitePartySelfFrame");
	if ( f ) then return f; end
	local src = getglobal("PartyMemberFrame1");
	f = CreateFrame("Button", "SlimSuitePartySelfFrame", UIParent);
	f:SetWidth((src and src:GetWidth()) or 128); f:SetHeight((src and src:GetHeight()) or 53);
	f:SetFrameStrata((src and src.GetFrameStrata and src:GetFrameStrata()) or "LOW");
	f.unit = "player";
	f:EnableMouse(true);
	if ( f.RegisterForClicks ) then f:RegisterForClicks("LeftButtonUp", "RightButtonUp"); end
	f:SetScript("OnClick", function() SS.Safe(SS.UnitClick, this); end);
	local map = {};
	if ( src ) then map[src] = f; end
	-- one part copied from the game's frame: its size and its anchors (to the frame, or to a part already copied)
	local function Place(part, from, fallback)
		if ( from and from.GetNumPoints and (from:GetNumPoints() or 0) > 0 ) then
			map[from] = part;
			local w, h = from:GetWidth(), from:GetHeight();
			if ( w and w > 0 ) then part:SetWidth(w); end
			if ( h and h > 0 ) then part:SetHeight(h); end
			part:ClearAllPoints();
			for p = 1, from:GetNumPoints() do
				local a, rel, rp, x, y = from:GetPoint(p);
				part:SetPoint(a, (rel and map[rel]) or f, rp or a, x or 0, y or 0);
			end
			return;
		end
		part:SetWidth(fallback[1]); part:SetHeight(fallback[2]);
		part:ClearAllPoints(); part:SetPoint("TOPLEFT", f, "TOPLEFT", fallback[3], fallback[4]);
	end
	local function Src(part) return src and getglobal("PartyMemberFrame1" .. part) or nil; end
	f.portrait = f:CreateTexture(nil, "BACKGROUND");
	Place(f.portrait, Src("Portrait"), { 37, 37, 7, -6 });
	f.art = f:CreateTexture(nil, "BORDER");
	local art = Src("Texture");
	f.art:SetTexture((art and art.GetTexture and art:GetTexture()) or "Interface\\TargetingFrame\\UI-PartyFrame");
	Place(f.art, art, { 128, 64, 0, -2 });
	f.hp = CreateFrame("StatusBar", nil, f);
	Place(f.hp, Src("HealthBar"), { 70, 7, 47, -12 });
	f.hp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); f.hp:SetStatusBarColor(0, 1, 0);
	f.mp = CreateFrame("StatusBar", nil, f);
	Place(f.mp, Src("ManaBar"), { 70, 7, 47, -20 });
	f.mp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
	f.name = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall");
	Place(f.name, Src("Name"), { 70, 10, 47, -2 });
	f:Hide();
	return f;
end

-- You join the party first, as the game lists you, in the party's look: the classic plate here (just above the first
-- member in a column, just left of it in a row), a line in the thin look (SS.UpdatePartyLines draws that one). The
-- place never depends on who else is there, so a run, the setup and Demo Mode all show you in the same spot.
function SS.LayoutPartySelf(force)
	local d = SS.DB();
	local plate = getglobal("SlimSuitePartySelfFrame");
	if ( not d.partyIncludesSelf or SS.Look("PartyMemberFrame1") == "thin" ) then
		if ( plate ) then plate:Hide(); end
		return;
	end
	plate = plate or SS.MakeClassicSelf();
	local orientation = SS.CurrentOrientation("PartyMemberFrame1");
	local pf1 = getglobal("PartyMemberFrame1");
	local scale = pf1 and pf1:GetScale() or 1;
	local key = orientation .. scale;
	if ( force or plate.laid ~= key ) then
		plate.laid = key;
		plate:SetScale(scale);
		plate:ClearAllPoints();
		if ( not pf1 ) then plate:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -128);
		elseif ( orientation == "horizontal" ) then plate:SetPoint("RIGHT", pf1, "LEFT", -8, 0);
		else plate:SetPoint("BOTTOM", pf1, "TOP", 0, 4); end
	end
	plate:Show();
	SS.KeepPartySelfOnScreen(plate);
end

-- Your plate sits before the first member, so a party right at the screen's left edge (a row) or top edge (a column)
-- would push it off: the whole party then steps right or down just enough to show it. Dragging is held the same way.
-- Demo Mode's sample row is only for show, so there the step is not saved.
function SS.KeepPartySelfOnScreen(plate)
	local pf1 = getglobal("PartyMemberFrame1");
	if ( not pf1 or not UIParent ) then return; end
	local h = handles.PartyMemberFrame1;
	if ( h and h.dragging ) then return; end
	local left, right, bottom, top = RootBounds(plate);
	if ( not left or not top ) then return; end
	local dx = left < 0 and -left or 0;
	local dy = top > UIParent:GetHeight() and (UIParent:GetHeight() - top) or 0;
	if ( dx == 0 and dy == 0 ) then return; end
	local x, _, y = RootBounds(pf1);
	if ( not x or not y ) then return; end
	SetRootPosition(pf1, x + dx, y + dy);
	if ( not SS.demoRunning ) then SS.SavePosition("PartyMemberFrame1", pf1); end
end

function SS.UpdatePartySelf()
	local f = getglobal("SlimSuitePartySelfFrame");
	if ( not f or not f:IsShown() ) then return; end
	local who = UnitName("player");
	if ( f.portraitFor ~= who and SetPortraitTexture ) then SetPortraitTexture(f.portrait, "player"); f.portraitFor = who; end
	if ( SS.DB().partyFaces == false ) then f.portrait:Hide(); else f.portrait:Show(); end
	f.name:SetText(who or "");
	local hp, hpMax = UnitHealth("player") or 0, UnitHealthMax("player") or 1;
	if ( hpMax < 1 ) then hpMax = 1; end
	f.hp:SetMinMaxValues(0, hpMax); f.hp:SetValue(hp);
	local mp, mpMax = UnitMana("player") or 0, UnitManaMax("player") or 1;
	if ( mpMax < 1 ) then mpMax = 1; end
	local kind = UnitPowerType("player");
	local pc = SS.RGB.classicMana;
	if ( kind == 1 ) then pc = SS.RGB.classicRage; elseif ( kind == 3 ) then pc = SS.RGB.classicEnergy; end
	f.mp:SetStatusBarColor(pc[1], pc[2], pc[3]);
	f.mp:SetMinMaxValues(0, mpMax); f.mp:SetValue(mp);
end

-- the game's party frames step aside (invisible, not clickable) while the thin lines show the party
function SS.ApplyPartyLook()
	local thin = SS.Look("PartyMemberFrame1") == "thin";
	for i = 1, 4 do
		local f = getglobal("PartyMemberFrame" .. i);
		if ( f ) then
			if ( thin ) then
				if ( f:GetAlpha() ~= 0 ) then f:SetAlpha(0); end
				if ( not f.slimThin and f.EnableMouse ) then f:EnableMouse(false); end
				f.slimThin = true;
			elseif ( f.slimThin ) then
				f.slimThin = nil;
				if ( f.EnableMouse ) then f:EnableMouse(true); end
				local hidden = (setupActive and not SS.SetupShows("PartyMemberFrame1")) or SS.DB().muted.PartyMemberFrame1;
				f:SetAlpha(hidden and 0 or 1);
			end
		end
	end
	if ( not thin ) then local c = getglobal("SlimSuitePartyLines"); if ( c ) then c:Hide(); end end
end

SS.Safe(SS.MakePartyLines);                             -- made at load, so "above the level-up cards" can include it
SS.Every("partyLines", 0.5, function()
	SS.Safe(SS.ApplyPartyLook);
	SS.Safe(SS.UpdatePartyLines);
	SS.Safe(SS.LayoutPartySelf);
	SS.Safe(SS.UpdatePartySelf);
	-- your buffs follow your plate or line as it changes size or look
	local d = SS.DB();
	if ( d.partyIncludesSelf and d.buffsOnPlayer and not d.buffsOnTarget ) then
		local P = SS.PlayerAnchor();
		local key = P and (tostring(P) .. (P:GetHeight() or 0) .. (SS.EffectiveScale(P)) .. tostring(d.buffsOnPlayerSide)) or "";
		if ( key ~= SS.buffAttachKey ) then SS.buffAttachKey = key; SS.Safe(SS.AttachBuffs); end
	else
		SS.buffAttachKey = nil;
	end
end);

function SU.UpdateDemo()
	-- every preview is drawn on the element's own frame, with its own size, scale and layout
	if ( SS.Previewing("PartyMemberFrame1") ) then
		SU.PreviewParty();
		-- Preview construction can reset the first party frame's anchors on either side of the player.
		if ( SS.DB().partyLocked ) then SS.Safe(SS.Place, "PartyMemberFrame1"); end
	end
	if ( SS.Previewing("TargetFrame") and not SS.DB().hideTarget ) then SU.PreviewTarget(); end
	SS.buffDirty = true;                                    -- the sample buffs on the real buff frame
	SS.Safe(SS.UpdateBossFrames);                           -- the sample bosses on the real encounter bars
end

-- buffs can sit above or below the player frame too; the target and the player share the one buff bar
function SU.SetBuffsPlayer(on)
	if ( on and SS.DB().buffsOnTarget ) then SS.Notice("Buffs on the target frame turned off: your buffs are on the player frame now."); end
	SS.DB().buffsOnPlayer = on and true or false;
	if ( on ) then
		local batching = SU.batching; SU.batching = true;
		SU.SetMode("BuffFrame", "enabled", "Buffs/Debuffs");
		SU.batching = batching;
		SS.DB().buffCustomLayout = true;
		SS.Safe(SS.ApplyBuffOrientation);
	end
	if ( on ) then SS.DB().buffsOnTarget = false; SS.MakeMovable("BuffFrame", "they sit on the player frame"); end
	if ( on ) then SS.Safe(SS.AttachBuffs); else SS.Safe(PlaceAll); end
	SU.RefreshBar();
	if ( SU.focus ) then SU.Focus(SU.focus); end
end

-- where the buffs sit: "own", "player_above", "player_below", "target_above" or "target_below"
function SS.BuffsPlace()
	local d = SS.DB();
	if ( d.buffsOnPlayer ) then return "player_" .. (d.buffsOnPlayerSide or "above"); end
	return "own";
end
function SS.SetBuffsPlace(v)
	local d = SS.DB();
	local side = type(v) == "string" and string.sub(v, 1, 7) == "player_" and string.sub(v, 8) or nil;
	d.buffsOnTarget = false;
	if ( side ) then
		d.buffsOnPlayerSide = side;
		SU.SetBuffsPlayer(true);
	elseif ( d.buffsOnPlayer ) then
		SU.SetBuffsPlayer(false);
	end
	SS.Safe(SS.AttachBuffs);
	SU.RefreshBar();
	if ( SS.MenuOpen and SS.MenuOpen() ) then SU.Focus(SU.focus); end
end
-- the target's buffs and debuffs: which side of the target frame
function SS.SetTargetAuraSide(v)
	SS.DB().targetAuraSide = v;
	if ( SlimSuiteWorld and SlimSuiteWorld.UpdateTargetAuras ) then SlimSuiteWorld.UpdateTargetAuras(); end
end
-- mirroring the target to the player: offer to give the target's buffs the player's side, mirrored (left <-> right)
SS.MIRROR_SIDE = { above = "above", below = "below", left = "right", right = "left" };
function SS.OfferMirrorBuffs()
	local d = SS.DB();
	if ( not d.buffsOnPlayer ) then return; end
	local want = SS.MIRROR_SIDE[d.buffsOnPlayerSide or "above"] or "below";
	if ( d.targetDebuffs and d.targetAuraSide == want ) then return; end
	if ( not StaticPopupDialogs ) then return; end
	StaticPopupDialogs["SLIMSUITE_MIRROR_BUFFS"] = {
		text = "Mirror target: show the target's buffs and debuffs " .. want .. " the target frame, to match your player frame's buffs?",
		button1 = YES or "Yes", button2 = NO or "No", timeout = 0, whileDead = 1, hideOnEscape = 1,
		OnAccept = function() SS.DB().targetDebuffs = true; SS.SetTargetAuraSide(want); SS.RefreshToggles(); end };
	if ( StaticPopup_Show ) then StaticPopup_Show("SLIMSUITE_MIRROR_BUFFS"); end
end


-- hiding the target frame: the classic frame and the new-school card alike
function SS.SetTargetHidden(on)
	SS.DB().hideTarget = on and true or false;
	SS.TargetFrameHidden(on);
	SS.Safe(SS.ApplyNewFrames);
	if ( setupActive and SU.on and (SU.on.TargetFrame and true or false) == (on and true or false) ) then
		SS.Safe(SU.SetOn, "TargetFrame", not on, SU.titles and SU.titles.TargetFrame or "Target frame");
		SS.Safe(SU.RefreshBar);
	end
	if ( SS.DB().unlocked ) then SS.Safe(SS.SetUnlocked, true, true); end
end

-- Connected elements: an element that has been joined to another one is still on; its tag says "Connected" and
-- hovering the tag names the element it is joined to. Add any new joining here so the setup list shows it.
function SS.ConnectedTo(frame)
	local d = SS.DB();
	if ( frame == "PlayerFrame" and d.partyIncludesSelf ) then return "PartyMemberFrame1", "Party frames"; end
	if ( frame == "BuffFrame" and d.buffsOnPlayer ) then
		if ( d.partyIncludesSelf ) then return "PartyMemberFrame1", "Party frames (your plate)"; end
		return "PlayerFrame", "Player frame";
	end
	if ( frame == "TargetFrame" and d.combineTarget ) then return "PlayerFrame", "Player frame"; end
	return nil;
end
function SU.RefreshBar()
	for frame, b in pairs(SU.barButtons or {}) do
		local mode = SU.Mode(frame);
		local parentFrame, parentTitle = SS.ConnectedTo(frame);
		if ( b.nameHit ) then b.nameHit.parentTitle = parentTitle; end
		for i = 1, table.getn(b.states or {}) do
			local state = b.states[i];
			if ( state.modeValue == mode ) then state:LockHighlight(); else state:UnlockHighlight(); end
		end
		if ( parentTitle ) then
			if ( frame == "BuffFrame" ) then
				if ( b.label ) then b.label:SetText(SS.T("Buffs/Debuffs")); end
			end
		elseif ( frame == "BuffFrame" ) then
			if ( b.label ) then b.label:SetText(SS.T("Buffs/Debuffs")); end
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

-- The element's menu: the setup's panel for an element, the same in the setup and on a right-click while editing.
-- Its title and words, its settings, then its size & layout tools; Exit and Complete in the setup, Done otherwise.
function SS.OpenSizeMenu(name, label)
	name = SS.Element(name);
	if ( not getglobal(SS.Shown(name)) ) then return; end
	if ( not SU.panel ) then SU.Build(); end
	SU.menuLabel = label;
	SU.Focus(name);
end
function SS.MenuOpen()
	return SU.panel and SU.panel:IsShown() and SU.focus and true or false;
end
function SS.HideElementMenu()
	if ( not SU.panel ) then if ( sizeMenu ) then sizeMenu:Hide(); end return; end
	-- in the setup the panel stays: it is drawn again for its element (a Reset there leaves no empty space)
	if ( setupActive ) then
		if ( SU.panel:IsShown() and SU.focus ) then SU.Focus(SU.focus); elseif ( sizeMenu ) then sizeMenu:Hide(); end
		return;
	end
	if ( sizeMenu ) then sizeMenu:Hide(); end
	SU.panel:Hide();
	if ( SU.glow ) then SU.glow:Hide(); SU.glow.handle = nil; end
	SU.focus, SU.placedFor = nil, nil;
end

function SU.Focus(frame)
	SU.focus = frame;
	local e;
	for i = 1, table.getn(SU.elements or {}) do if ( SU.elements[i].frame == frame ) then e = SU.elements[i]; end end
	if ( not e and frame and not setupActive ) then
		local steps = SU.Steps();
		for i = 1, table.getn(steps) do if ( steps[i].frame == frame ) then e = steps[i]; end end
		e = e or { frame = frame, title = SU.menuLabel or frame, text = "" };
	end
	local checks, mode = {}, nil;
	if ( e ) then
		SU.panel.title:SetText(SS.T and SS.T(e.title) or e.title);
		mode = setupActive and frame and SU.Mode(frame) or nil;
		SU.panel.text:SetText(SS.T(e.text) .. (mode and mode ~= "enabled" and "\n" .. SS.T("Enable this element to show and move it before changing its settings.") or ""));
		-- a sub-setting shows only while the setting it depends on is on
		local all, shown = SU.ChecksFor(frame), {};
		for i = 1, table.getn(all) do if ( not all[i][4] or all[i][4]() ) then table.insert(shown, all[i]); end end
		checks = shown;
	else
		SU.panel.title:SetText(SS.T("Setup"));
		SU.panel.text:SetText(SS.T("All elements start disabled on a new install. Enable one to show and move it; Default restores the game's original element. Right-click its name for settings. Your Default profiles will appear beside this list."));
	end
	local h = 58 + (SU.panel.text:GetHeight() or 28) + 40;
	for i = 1, math.max(table.getn(checks), table.getn(SU.checks)) do
		if ( not SU.checks[i] ) then SU.checks[i] = SU.Check(SU.panel); end   -- as many rows as the element has settings
		local cb, c = SU.checks[i], checks[i];
		if ( c ) then
			cb.label:SetText(SS.T(c[1]) .. (c.warn and " |cffff9933(!)|r" or "")); cb.get, cb.set, cb.cond = c[2], c[3], c[4];
			cb.warnText = c.warn and SS.T(c.warn) or nil;
			SS.RowKind(cb, c, "right");
			cb:ClearAllPoints();
			-- a setting that only works with another one is indented under it
			local dx = (c[4] and not c.top) and 20 or 0;
			cb.indentX = dx;
			if ( i == 1 ) then cb:SetPoint("TOPLEFT", SU.panel.text, "BOTTOMLEFT", -2 + dx, -4);
			else cb:SetPoint("TOPLEFT", SU.checks[i - 1], "BOTTOMLEFT", dx - (SU.checks[i - 1].indentX or 0), -(SU.checks[i - 1].warnGap or 0)); end
			cb.warn:Hide(); cb.warnGap = 0;
			cb.Refresh(); cb:Show();
			if ( setupActive and mode ~= "enabled" ) then cb:Disable(); cb.label:SetTextColor(0.45, 0.45, 0.45);
			elseif ( c[5] and not c[5]() ) then cb:Disable(); cb.label:SetTextColor(0.45, 0.45, 0.45);
			else cb:Enable(); cb.label:SetTextColor(1, 1, 1); end
			h = h + 24 + cb.warnGap;
		else
			cb.get, cb.set, cb.cond = nil, nil, nil; cb:Hide();
		end
	end
	-- the size & layout tools, under the settings
	do
		local ok = frame and (not setupActive or SU.Mode(frame) == "enabled") and SS.PrepareSizeTools(frame, e and e.title);
		if ( ok and sizeMenu ) then
			sizeMenu:SetParent(SU.panel);
			sizeMenu:SetScale(1);
			sizeMenu:SetFrameLevel((SU.panel:GetFrameLevel() or 1) + 2);
			sizeMenu:ClearAllPoints();
			sizeMenu:SetPoint("TOPLEFT", SU.panel, "TOPLEFT", 2, -(h - 40));
			sizeMenu:Show();
			h = h + (sizeMenu:GetHeight() or 0);               -- Exit/Complete or Done stay under it
		elseif ( sizeMenu ) then
			sizeMenu:Hide();
		end
	end
	if ( SU.panel.done ) then
		SU.panel.exit:Hide(); SU.panel.complete:Hide(); SU.panel.done:Show();   -- the list's own Done ends Edit mode
	end
	SU.panel:SetHeight(h);
	if ( SU.grid ) then SU.grid.Refresh(); end
	SU.RefreshGridButtons();
	local handle = frame and handles[SS.Shown(frame)];
	-- placed when it opens for an element (it can be dragged after that and stays where it was put)
	if ( SU.placedFor ~= (frame or "") or not SU.panel:IsShown() ) then
		SU.placedFor = frame or "";
		SU.panel:ClearAllPoints();
		if ( handle and handle:IsShown() ) then SU.panel:SetPoint("TOP", handle, "BOTTOM", 0, -14);
		else SU.panel:SetPoint("TOP", UIParent, "TOP", 0, -110); end
		SS.Safe(SS.KeepMenuOnScreen);
	end
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
	if ( setupActive ) then SU.RefreshBar(); end
end

-- a menu under an element near the screen's bottom would run off it: it goes above the element then, or as high as fits
function SS.KeepMenuOnScreen()
	local p = SU.panel;
	local b, t = p:GetBottom(), p:GetTop();
	if ( not b or not t ) then return; end
	if ( b >= 0 ) then return; end
	local handle = SU.glow and SU.glow.handle;
	local h = t - b;
	p:ClearAllPoints();
	if ( handle and handle:GetTop() and handle:GetTop() + 14 + h <= UIParent:GetHeight() ) then
		p:SetPoint("BOTTOM", handle, "TOP", 0, 14);
	else
		p:SetPoint("TOP", UIParent, "TOP", 0, -10);
	end
end

-- rebuilds the setup's top bar after an element was added or removed from it, keeping the open questions
function SU.Rebuild()
	if ( not setupActive ) then return; end
	local f = SU.focus;
	SS.Safe(SU.Begin);
	SU.batching, SU.restoring, SU.cascading = false, false, false;   -- never left stuck by a failure part-way
	for i = 1, table.getn(SU.elements or {}) do if ( f and SU.elements[i].frame == f ) then SS.Safe(SU.Focus, f); end end
end

-- the new-school design for the player and target frames (the same switch as the sub-option under Mirror target)
function SS.RebuildSetup()
	if ( SU.Rebuild ) then SU.Rebuild(); end
end

-- A look change is one element changing its frame: the frame now shown takes the old one's place (centred on it; the
-- party by its top-left corner) and its hidden/shown state, so nothing set before is lost.
function SS.CarryPlace(el, fromName, toName)
	local from, to = getglobal(fromName), getglobal(toName);
	if ( not from or not to ) then return; end
	local l, r, b, t = RootBounds(from);
	if ( l and r and b and t ) then
		local factor = RootFactor(to);
		local w, h = (to:GetWidth() or 0) * factor, (to:GetHeight() or 0) * factor;
		SS.UserPlace(to);
		if ( el == "PartyMemberFrame1" ) then SetRootPosition(to, l, t - h);
		else SetRootPosition(to, (l + r) / 2 - w / 2, (b + t) / 2 - h / 2); end
		SS.Safe(SS.SavePosition, toName, to);
	end
	local muted = SS.DB().muted[fromName] and true or false;
	if ( (SS.DB().muted[toName] and true or false) ~= muted ) then
		SS.DB().muted[toName] = muted;
		SS.Safe(ApplyFeatureMute, toName);
	end
end

-- runs a change that can swap the frame showing the player, the target or the party, and brings everything along
function SS.ChangeLooks(change)
	local els = { "PlayerFrame", "TargetFrame", "PartyMemberFrame1" };
	local before = {};
	for i = 1, 3 do before[els[i]] = SS.Shown(els[i]); end
	change();
	for i = 1, 3 do
		local el = els[i];
		local old, new = before[el], SS.Shown(el);
		if ( old ~= new ) then
			SS.Safe(SS.CarryPlace, el, old, new);
			if ( setupActive and SU.on and SU.on[el] ) then
				local of = getglobal(old);
				if ( of ) then SU.Save(of); of:SetAlpha(0); end
				if ( handles[old] ) then handles[old]:Hide(); end
			end
		end
	end
	SS.Safe(SS.ApplyNewFrames);
	SS.Safe(SS.UpdatePartyLines);
	SS.Safe(SS.LayoutPartySelf, true);
	if ( setupActive and SU.on ) then
		for i = 1, 3 do if ( SU.on[els[i]] ) then SU.SetOn(els[i], true, SU.titles and SU.titles[els[i]]); end end
	end
	if ( SS.DB().mirrorTarget ) then SS.Safe(SS.MirrorTarget); end
	if ( SS.DB().unlocked ) then SS.Safe(SS.SetUnlocked, true, true); end
	SS.Safe(PlaceAll);
	if ( setupActive and SU.focus ) then SU.Focus(SU.focus); end
end

-- a frame's own look: the player ("classic" or "new"), the target ("classic" or "new"), the party ("classic" or "thin")
function SS.SetLook(el, look)
	SS.ChangeLooks(function()
		if ( el == "PlayerFrame" ) then SS.DB().playerLook = look == "new" and "new" or "classic";
		elseif ( el == "TargetFrame" ) then SS.DB().targetLook = look == "new" and "new" or "classic";
		elseif ( el == "PartyMemberFrame1" ) then SS.DB().partyLook = look == "thin" and "thin" or "classic"; end
	end);
	if ( el == "PartyMemberFrame1" ) then SS.Safe(ApplyMovableOrientation, "PartyMemberFrame1"); SU.UpdateDemo(); end
end

-- Where the party sits: anywhere ("free"), or held just under or above the player frame. Holding it there takes you
-- out of the party frames (the newest choice wins).
function SS.PartyPosition()
	local d = SS.DB();
	if ( not d.partyLocked ) then return "free"; end
	return d.partyLockAbove and "above" or "below";
end
function SS.SetPartyPosition(v)
	local d = SS.DB();
	if ( v ~= "free" and d.partyIncludesSelf ) then SS.SetPartySelf(false); end
	d.partyLocked = v ~= "free";
	d.partyLockAbove = v == "above";
	if ( d.partyLocked ) then SS.MakeMovable("PartyMemberFrame1", "they sit by the player frame"); end
	SS.Safe(PlaceAll);
	SU.UpdateDemo();
end

-- Settings that cannot both be on: the one chosen last wins and the other is turned off (it can be turned back on).
--   "self"    you join the party frames: your own player frame goes off, since your card is in the party now. The
--             target frame stays on its own: Mirror Target, which needs the player frame, goes off.
--   "mirror", "combine", "player" (the player frame turned on from its button): you leave the party frames and your
--             player frame comes back; mirroring also brings back a hidden target frame
function SS.ClaimTarget(by)
	local d = SS.DB();
	if ( by == "self" ) then
		if ( d.partyLocked ) then d.partyLocked = false; SS.Notice("The party frames are free again: you are in them now."); end
		if ( d.mirrorTarget ) then SS.SetMirrorTarget(false); SS.Notice("Mirror Target turned off: the target frame stands on its own now."); end
		-- The player is represented inside the party block now; do not let the next setup
		-- rebuild reactivate the standalone player frame from an earlier Mirror Target choice.
		if ( d.elementModes ) then d.elementModes.PlayerFrame = "default"; end
		if ( d.enabledElements ) then d.enabledElements.PlayerFrame = nil; end
		if ( SU.on ) then SU.on.PlayerFrame = nil; end
		if ( handles.PlayerFrame ) then handles.PlayerFrame:Hide(); end
		SS.Notice("The player frame turned off: you are in the party frames now.");
		SS.Safe(SS.PlayerFrameHidden, true);
		return;
	end
	if ( d.partyIncludesSelf ) then
		d.partyIncludesSelf = false;
		SS.Notice("Add yourself to party turned off: the player frame is back.");
		SS.Safe(SS.PlayerFrameHidden, false);
		SS.Safe(ApplyMovableOrientation, "PartyMemberFrame1");
	end
	if ( by == "mirror" and d.hideTarget ) then d.hideTarget = false; SS.Safe(SS.TargetFrameHidden, false); end
end

-- your own player frame (classic or new-school) is hidden while you are in the party frames
function SS.PlayerFrameHidden(on)
	if ( PlayerFrame ) then
		if ( not SS.playerShow ) then SS.playerShow = PlayerFrame.Show; end
		if ( on ) then
			PlayerFrame.Show = function() end;
			PlayerFrame:Hide();
		else
			PlayerFrame.Show = SS.playerShow;
			PlayerFrame:Show();
		end
	end
	local card = getglobal("SlimSuitePlayerCard");
	if ( card ) then SS.Safe(SS.RefreshCard, card); end
end

-- You in the party frames: your own card joins the end of the party column or row and takes your player frame's
-- place, so the player frame is turned off. Unticked, the player frame comes back.
function SS.SetPartySelf(on)
	local was = SS.DB().partyIncludesSelf and true or false;
	SS.ChangeLooks(function()
		SS.DB().partyIncludesSelf = on and true or false;
		if ( on ) then SS.ClaimTarget("self");
		elseif ( was ) then
			SS.Safe(SS.PlayerFrameHidden, false);
			SS.Notice("The player frame is back: you left the party frames.");
			-- in the setup the player frame's element comes back on with it
			if ( setupActive and SU.on and not SU.on.PlayerFrame ) then SU.SetMode("PlayerFrame", "enabled", SU.titles and SU.titles.PlayerFrame or "Unit frame"); end
		end
	end);
	-- Choosing to join the party frames also turns that frame on in the UI setup; otherwise the option
	-- would hide the player plate without giving the user a party-frame handle to place.
	if ( on and setupActive and SU.on and not SU.on.PartyMemberFrame1 ) then
		SU.SetMode("PartyMemberFrame1", "enabled", SU.titles and SU.titles.PartyMemberFrame1 or "Party frames");
	end
	SS.Safe(ApplyMovableOrientation, "PartyMemberFrame1");
	SU.Rebuild();
	SU.UpdateDemo();
end

-- combined, the player and target are one element in the setup, and the player frame takes the target's look
function SS.SetCombineTarget(on)
	-- Kept as an internal compatibility entry point; the UI now has one combined Mirror Target switch.
	SS.SetMirrorTarget(on);
end

function SS.SetLocalClockOn(on)
	local wanted = on and "enabled" or "default";
	if ( setupActive and SU.Mode and SU.SetMode and SU.Mode("SlimSuiteLocalClockFrame") ~= wanted ) then
		SU.SetMode("SlimSuiteLocalClockFrame", wanted, SU.titles and SU.titles.SlimSuiteLocalClockFrame or "Local clock");
	end
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
	if ( SU.focus == frame ) then SU.Focus(nil); else SU.Focus(frame); end
	SS.RefreshToggles();
end

-- the setup leaves Blizzard's interface visible until an element is explicitly enabled or disabled
function SU.PlaceProfiles()
	local panel = SU.bar and SU.bar.profilePanel;
	if ( not panel ) then return; end
	local left = SU.bar:GetLeft() or 0;
	local width = SU.bar:GetWidth() or 0;
	local profileWidth = panel:GetWidth() or 0;
	panel:ClearAllPoints();
	if ( left + width + profileWidth <= (UIParent:GetWidth() or 0) ) then
		panel:SetPoint("TOPLEFT", SU.bar, "TOPRIGHT", -2, 0);
	elseif ( left >= profileWidth ) then
		panel:SetPoint("TOPRIGHT", SU.bar, "TOPLEFT", 2, 0);
	else
		panel:SetPoint("TOPLEFT", SU.bar, "BOTTOMLEFT", 0, 2);
	end
end

function SU.Begin()
	if ( not SU.panel ) then SU.Build(); end
	SU.Unreveal();
	for name in pairs(SU.KEEP_VISIBLE) do                        -- undo an earlier sweep of these, if any
		local c = getglobal(name);
		if ( c and c.SetAlpha and c.GetAlpha and c:GetAlpha() == 0 ) then c:SetAlpha(1); end
	end
	editOnly = "SlimSuiteSetupNothing";                  -- no handles until an element is turned on
	SU.on = {};
	SS.SetUnlocked(true, true);
	SU.elements = {};
	local steps = SU.Steps();
	for i = 1, table.getn(steps) do if ( steps[i].frame and steps[i].frame ~= "SlimSuiteEditGrid" ) then table.insert(SU.elements, steps[i]); end end
	local hasMeter = false;
	for i = 1, table.getn(SU.elements) do if ( SU.elements[i].frame == "SlimSuiteMeterFrame" ) then hasMeter = true; end end
	if ( not hasMeter ) then table.insert(SU.elements, { frame = "SlimSuiteMeterFrame", title = "Damage meter", text = "The damage meter. Its corner grip resizes it any time." }); end
	SU.titles = {};
	for i = 1, table.getn(SU.elements) do SU.titles[SU.elements[i].frame] = SU.elements[i].title; end
	local modes = SS.DB().elementModes or {};
	SS.DB().elementModes = modes;
	local saved = SS.DB().enabledElements or {};
	local d = SS.DB();
	local initializeDisabled = (tonumber(d.firstSetupDefaultsVersion) or 0) < 1 and not d.setupDone and (SS.firstRunSetupPending or not SS.HasPriorUISetup(d));
	-- Rebuilding the editor restores visibility; only an explicit Default click resets settings.
	SU.restoring = not initializeDisabled;
	SU.batching = true;      -- one bar and demo refresh at the end, not one per element
	SS.Safe(SU.SetGridSetting, SS.DB().showEditGrid and true or false);
	-- A clean profile starts with every element, including Blizzard's native version, explicitly Disabled.
	-- Profiles that already chose modes keep those choices and their existing migration data.
	for i = 1, table.getn(SU.elements) do
		local f = SU.elements[i].frame;
		if ( initializeDisabled ) then modes[f] = "disabled"; end
		local mode = SU.Mode(f);
		if ( modes[f] == nil and saved[f] ) then modes[f] = "enabled"; mode = "enabled"; end
		if ( f == "SlimSuiteMeterFrame" and SS.DB().moveMeter ) then mode = modes[f] or "enabled"; end
		if ( f == "PlayerFrame" and SS.DB().partyIncludesSelf ) then mode = modes[f] or "default"; end
		if ( f == "TargetFrame" and SS.DB().hideTarget ) then mode = modes[f] or "disabled"; end
		if ( mode == "enabled" or mode == "disabled" ) then SS.Safe(SU.SetMode, f, mode, SU.titles[f]);
		else SS.Safe(SU.SetMode, f, "default", SU.titles[f]); end
	end
	SU.restoring = false;
	if ( initializeDisabled ) then d.firstSetupDefaultsVersion = 1; end
	SU.batching = false;
	-- the bar: one button per element
	SU.barButtons = SU.barButtons or {};
	-- a vertical list from the top left corner: one element per line, a new column when the screen runs out of height
	local wanted, col, idx, maxIdx = {}, 0, 0, 0;
	local maxH = (UIParent:GetHeight() or 768) - 80;
	local COLUMN, LINE, TOP, BOTTOM = 310, 19, 26, 27;   -- three explicit states beside a plain name; actions stay on the bottom edge
	maxH = maxH - TOP - BOTTOM;
	for i = 1, table.getn(SU.elements) do
		local e = SU.elements[i];
		local name = e.frame;
		wanted[name] = true;
		local b = SU.barButtons[name];
		if ( not b ) then
			b = CreateFrame("Frame", nil, SU.bar);
			SU.barButtons[name] = b;
			b:SetWidth(COLUMN); b:SetHeight(LINE);
			b.nameHit = CreateFrame("Frame", nil, b); b.nameHit:SetWidth(102); b.nameHit:SetHeight(17); b.nameHit:SetPoint("LEFT", b, "LEFT", 0, 0); b.nameHit:EnableMouse(true);
			b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
			b.label:SetPoint("LEFT", b, "LEFT", 0, 0); b.label:SetWidth(102); b.label:SetJustifyH("LEFT");
			b.nameHit:SetScript("OnMouseUp", function()
				if ( arg1 ~= "RightButton" ) then return; end
				if ( setupActive ) then SU.Focus(this.ownerFrame); else SS.OpenSizeMenu(this.ownerFrame, this.elementTitle); end
			end);
			b.nameHit:SetScript("OnEnter", function()
				if ( not GameTooltip ) then return; end
				GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
				GameTooltip:AddLine(this.elementTitle or "", 1, 0.82, 0.2);
				GameTooltip:AddLine(SS.T("Right-click the name to open its settings."), 0.8, 0.8, 0.8, 1);
				if ( this.parentTitle ) then GameTooltip:AddLine("Connected to: " .. this.parentTitle, 0.7, 0.85, 1); end
				GameTooltip:Show();
			end);
			b.nameHit:SetScript("OnLeave", function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
			b.states = {};
			b.stateLabels = { "Enabled", "Disabled", "Default" };
			local stateModes = { "enabled", "disabled", "default" };
			for j = 1, 3 do
				local value, label = stateModes[j], b.stateLabels[j];
				local state = K.Button(b, SS.T(label), 64, function()
					SU.SetMode(this.ownerFrame, this.modeValue, SU.titles and SU.titles[this.ownerFrame]);
				end);
				state:SetHeight(17); state.ownerFrame = name; state.modeValue = value;
				state:SetPoint("LEFT", b, "LEFT", 105 + ((j - 1) * 67), 0);
				state:SetScript("OnEnter", function()
					if ( not GameTooltip ) then return; end
					GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
					if ( this.modeValue == "default" ) then GameTooltip:AddLine(SS.T("Restore Blizzard / Aethus default. Hide Slim Suite's replacement and turn the game's element on."), 1, 0.82, 0.2);
					elseif ( this.modeValue == "enabled" ) then GameTooltip:AddLine(SS.T("Show and move Slim Suite's replacement."), 0.4, 1, 0.4);
					else GameTooltip:AddLine(SS.T("Hide both the game element and Slim Suite's replacement."), 1, 0.45, 0.35); end
					GameTooltip:Show();
				end);
				state:SetScript("OnLeave", function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
				b.states[j] = state;
			end
		end
		b.nameHit.ownerFrame = name; b.nameHit.elementTitle = e.title; b.label:SetText(SS.T(e.title));
		for j = 1, table.getn(b.states) do b.states[j].ownerFrame = name; b.states[j]:SetText(SS.T(b.stateLabels[j])); end
		-- two columns, half the elements in each (a third column only if the screen is too short for two)
		local perCol = math.ceil(table.getn(SU.elements) / 2);
		if ( idx > 0 and (idx >= perCol or 6 + (idx + 1) * LINE > maxH) ) then col = col + 1; idx = 0; end
		b:ClearAllPoints(); b:SetPoint("TOPLEFT", SU.bar, "TOPLEFT", 6 + col * COLUMN, -6 - TOP - idx * LINE); b:Show();
		for j = 1, table.getn(b.states) do b.states[j]:Show(); end
		if ( idx > maxIdx ) then maxIdx = idx; end
		idx = idx + 1;
	end
	for name, b in pairs(SU.barButtons) do if ( not wanted[name] ) then b:Hide(); for j = 1, table.getn(b.states or {}) do b.states[j]:Hide(); end end end
	SU.bar:SetWidth(6 + (col + 1) * COLUMN);
	SU.bar:SetHeight((maxIdx + 1) * LINE + 12 + TOP + BOTTOM);
	SU.PlaceProfiles();
	if ( SU.bar.resetAll ) then
		SU.bar.resetAll:ClearAllPoints(); SU.bar.resetAll:SetPoint("BOTTOMRIGHT", SU.bar, "BOTTOMRIGHT", -104, 7);
		SU.bar.done:ClearAllPoints(); SU.bar.done:SetPoint("BOTTOMRIGHT", SU.bar, "BOTTOMRIGHT", -8, 7);
	end
	SU.bar:Show();
	SU.Focus(nil);
	SU.RefreshBar();
	SU.UpdateDemo();
	SU.RefreshDemoButtons();
end

function SU.RefreshDemoButtons()
	if ( not SU.bar or not SU.bar.demoOn ) then return; end
	local count = 0;
	for i = 1, table.getn(SU.elements or {}) do
		local frame = SU.elements[i].frame;
		if ( SU.Mode(frame) == "enabled" ) then
			count = count + 1;
		end
	end
	if ( SS.demoRunning and SS.demoElements ) then
		local stillEnabled = 0;
		for frame in pairs(SS.demoElements) do
			if ( SU.Mode(frame) ~= "enabled" ) then SS.demoElements[frame] = nil; else stillEnabled = stillEnabled + 1; end
		end
		if ( stillEnabled == 0 ) then SS.StopDemoMode(); return; end
	end
	if ( SU.bar.demoLabel ) then SU.bar.demoLabel:SetText(SS.T("Demo")); end
	if ( count == 0 and not SS.demoRunning ) then SU.bar.demoOn:Disable(); else SU.bar.demoOn:Enable(); end
	if ( SS.demoRunning ) then SU.bar.demoOn:LockHighlight(); SU.bar.demoOff:UnlockHighlight();
	else SU.bar.demoOff:LockHighlight(); SU.bar.demoOn:UnlockHighlight(); end
	local box = getglobal("SlimSuiteDemoBox");
	if ( box and box.on ) then if ( count == 0 ) then box.on:Disable(); else box.on:Enable(); end end
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
		local cb = CreateFrame("CheckButton", nil, SU.bar, "UICheckButtonTemplate");
		cb:SetWidth(20); cb:SetHeight(20); cb:SetPoint("TOPLEFT", SU.bar, "TOPLEFT", x, y);
		cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		cb.label:SetPoint("LEFT", cb, "RIGHT", 0, 1); cb.label:SetText(SS.T(label));
		cb.Refresh = function() cb:SetChecked(get() and 1 or nil); end;
		cb.get = get;
		SS.TrackToggle(cb);
		cb:SetScript("OnClick", function() SS.FlipToggle(get, set); SS.RefreshToggles(); end);
		return cb;
	end
	-- the grid, top right of every setup panel: on or off, and its size
	-- the bar down the left of the screen: the grid on top, one toggle per element, Done at the bottom
	SU.bar = CreateFrame("Frame", "SlimSuiteSetupBar", UIParent);
	SU.grid = Tick(8, -8, "Grid", function() return SS.DB().showEditGrid; end, function(v) SU.SetGridSetting(v); end);
	SU.sizes = {};
	local sizes = { 16, 32, 64, 128 };
	for i = 1, 4 do
		local pixels = sizes[i];
		local b = K.Button(SU.bar, tostring(pixels), 34, function()
			SS.DB().gridDivisions = pixels; SU.SetGridSetting(SS.DB().showEditGrid and true or false); SU.RefreshGridButtons();
		end);
		b:SetHeight(18); b:SetPoint("TOPLEFT", SU.bar, "TOPLEFT", 64 + (i - 1) * 36, -9);
		SU.sizes[i] = b;
	end
	-- the element's own settings (more rows are made when an element needs them)
	SU.checks = {};
	for i = 1, 12 do SU.checks[i] = SU.Check(SU.panel); end
	SU.panel.exit = K.Button(SU.panel, "Exit", 90, function() SS.SetupEnd(false); end);
	SU.panel.exit:SetPoint("BOTTOMLEFT", SU.panel, "BOTTOMLEFT", 10, 8); SU.panel.exit:Hide();
	SU.panel.complete = K.Button(SU.panel, "Complete", 100, function() SS.SetupEnd(true); end);
	SU.panel.complete:SetPoint("BOTTOMRIGHT", SU.panel, "BOTTOMRIGHT", -10, 8);
	-- the same panel is every element's right-click menu outside the setup: Done closes it
	SU.panel.done = K.Button(SU.panel, "Done", 90, function()
		if ( setupActive ) then
			SU.panel:Hide(); if ( SU.glow ) then SU.glow:Hide(); SU.glow.handle = nil; end
			SU.focus, SU.placedFor = nil, nil;
		else SS.HideElementMenu(); end
	end);
	SU.panel.done:SetPoint("BOTTOMRIGHT", SU.panel, "BOTTOMRIGHT", -10, 8);
	SU.panel.done:Hide();
	SU.panel:Hide();
	-- Demo Mode beside the grid: On and Off, the one that is in effect lit
	SU.bar.demoLabel = SU.bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	SU.bar.demoLabel:SetPoint("TOPLEFT", SU.bar, "TOPLEFT", 218, -12); SU.bar.demoLabel:SetText(SS.T("Demo"));
	SU.bar.demoOn = K.Button(SU.bar, "On", 36, function() SS.StartDemoMode(); SU.RefreshDemoButtons(); end);
	SU.bar.demoOn:SetHeight(18); SU.bar.demoOn:SetPoint("TOPLEFT", SU.bar, "TOPLEFT", 255, -9);
	SU.bar.demoOff = K.Button(SU.bar, "Off", 36, function() SS.StopDemoMode(); SU.RefreshDemoButtons(); end);
	SU.bar.demoOff:SetHeight(18); SU.bar.demoOff:SetPoint("TOPLEFT", SU.bar, "TOPLEFT", 296, -9);
	SU.bar.demoHint = SU.bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	SU.bar.demoHint:SetPoint("LEFT", SU.bar.demoOff, "RIGHT", 7, 0); SU.bar.demoHint:SetWidth(280); SU.bar.demoHint:SetHeight(24);
	SU.bar.demoHint:SetJustifyH("LEFT"); SU.bar.demoHint:SetText(SS.T("(Right click element to change settings)"));
	SU.bar.done = K.Button(SU.bar, "Done", 90, function() SS.ConfirmSetupDone(); end);
	SU.bar.done:SetPoint("BOTTOMRIGHT", SU.bar, "BOTTOMRIGHT", -8, 7);
	SU.bar.resetAll = K.Button(SU.bar, "Reset All", 90, function() SS.ResetUI(); end);
	SU.bar.resetAll:SetPoint("RIGHT", SU.bar.done, "LEFT", -6, 0);
	SU.bar:SetFrameStrata("DIALOG");
	SU.bar:SetHeight(52);
	SU.bar:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	SU.bar:SetBackdropColor(0.04, 0.035, 0.07, 0.97);
	SU.bar:SetBackdropBorderColor(0.85, 0.65, 0.2, 1);
	-- A compact sidecar for the starter profiles the author will supply later. It moves with the setup list.
	SU.bar.profilePanel = CreateFrame("Frame", "SlimSuiteDefaultProfiles", SU.bar);
	SU.bar.profilePanel:SetWidth(184); SU.bar.profilePanel:SetHeight(136);
	SU.bar.profilePanel:SetFrameStrata("DIALOG");
	SU.bar.profilePanel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	SU.bar.profilePanel:SetBackdropColor(0.04, 0.035, 0.07, 0.97);
	SU.bar.profilePanel:SetBackdropBorderColor(0.85, 0.65, 0.2, 1);
	SU.bar.profilePanel.title = SU.bar.profilePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	SU.bar.profilePanel.title:SetPoint("TOPLEFT", SU.bar.profilePanel, "TOPLEFT", 10, -10);
	SU.bar.profilePanel.title:SetText(SS.T("Default profiles"));
	SU.bar.profilePanel.note = SU.bar.profilePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	SU.bar.profilePanel.note:SetPoint("TOPLEFT", SU.bar.profilePanel, "TOPLEFT", 10, -34);
	SU.bar.profilePanel.note:SetWidth(160); SU.bar.profilePanel.note:SetJustifyH("LEFT"); SU.bar.profilePanel.note:SetText(SS.T("Read-only presets. Applying one creates your own editable copy."));
	SU.bar.profilePanel.buttons = {};
	SU.bar.profilePanel.Refresh = function()
		local names = {};
		for name, layout in pairs(SS.DEFAULT_PROFILES or {}) do if ( type(name) == "string" and type(layout) == "table" ) then table.insert(names, name); end end
		table.sort(names);
		for i = 1, math.max(table.getn(names), table.getn(SU.bar.profilePanel.buttons)) do
			local button = SU.bar.profilePanel.buttons[i];
			if ( not button and names[i] and K and K.Button ) then
				button = K.Button(SU.bar.profilePanel, names[i], 164, function() SS.ApplyDefaultProfile(this.profileName); end);
				SU.bar.profilePanel.buttons[i] = button;
			end
			if ( button ) then
				if ( names[i] ) then button.profileName = names[i]; button:SetText(names[i]); button:ClearAllPoints(); button:SetPoint("TOPLEFT", SU.bar.profilePanel, "TOPLEFT", 10, -58 - ((i - 1) * 22)); button:Show();
				else button:Hide(); end
			end
		end
		if ( table.getn(names) == 0 ) then
			SU.bar.profilePanel.note:SetText(SS.T("Your read-only presets will appear here. Applying one creates your editable copy."));
		else SU.bar.profilePanel.note:SetText(SS.T("Applying a read-only preset creates your editable copy.")); end
	end;
	SU.bar.profilePanel.Refresh();
	SU.bar.profilePanel:SetPoint("TOPLEFT", SU.bar, "TOPRIGHT", -2, 0);
	-- the list can be dragged by its background; it stays where it was put
	SU.bar:SetMovable(true); SU.bar:EnableMouse(true); SU.bar:RegisterForDrag("LeftButton");
	if ( SU.bar.SetClampedToScreen ) then SU.bar:SetClampedToScreen(true); end
	SU.bar:SetScript("OnDragStart", function() this:StartMoving(); end);
	SU.bar:SetScript("OnDragStop", function()
		this:StopMovingOrSizing();
		local l, t = this:GetLeft(), this:GetTop();
		if ( l and t ) then SS.DB().elementListPlace = { x = l, y = t - UIParent:GetHeight() }; end
		SU.PlaceProfiles();
	end);
	local saved = SS.DB().elementListPlace;
	if ( type(saved) == "table" and saved.x and saved.y ) then SU.bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", saved.x, saved.y);
	else SU.bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 6, -6); end
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

-- The setup hides the whole UI while it runs. If anything in it fails, the UI is brought back at once and the setup
-- closes, so a failure can never leave the screen empty until a /reload (the error is still logged and said in chat).
function SS.SetupRescue(err)
	SS.Report(err);
	pcall(SU.Unreveal);
	pcall(SS.SetupHide);
	setupActive = false;
	editOnly = nil;
	pcall(SS.SetUnlocked, false, true);
	pcall(PlaceAll);
	K.Print(NAME, "the setup hit a problem and closed; your UI is back as it was. /slim errors shows what happened.");
end
function SS.StartSetup(fromStart)
	setupActive = true;
	local ok, err = pcall(SU.Begin);
	if ( not ok ) then SS.SetupRescue(err); end
end

-- what each element brings along: the frames that move with it
SU.COMPANIONS = {
	ChatFrame1 = { "ChatFrame1Tab", "ChatFrame1EditBox" },
	SlimSuiteSpellRowFrame = { "SlimSuiteItemRowFrame" },
	PlayerFrame = { "SlimSuiteProcMeter" },
};

-- an element turned on in the setup, or a frame that comes with one (the jewelry row with the build spells)
function SS.SetupShows(name)
	if ( not setupActive or not SU.on or not name ) then return false; end
	if ( SU.on[name] or SU.on[SS.Element(name)] ) then return true; end
	for parent in pairs(SU.on) do
		local list = SU.CompanionsOf(parent);
		for i = 1, table.getn(list) do if ( list[i] == name ) then return true; end end
	end
	return false;
end

-- the frames that come with an element in the setup (the party's depend on its look)
function SU.CompanionsOf(frame)
	if ( frame == "ChatFrame1" and SS.ChatCompanions ) then return SS.ChatCompanions(); end
	if ( frame == "PartyMemberFrame1" ) then
		if ( SS.Look("PartyMemberFrame1") == "thin" ) then return {}; end   -- the thin lines are one frame, you included
		return { "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4", "SlimSuitePartySelfFrame" };
	end
	return SU.COMPANIONS[frame] or {};
end

-- restore every frame's alpha as it was before the setup
function SU.Unreveal()
	-- the minimap is faded while the setup runs; a faded value saved by mistake must never be put back
	if ( SU.saved ) then
		for _, m in ipairs({ Minimap, MinimapCluster }) do
			if ( m and SU.saved[m] ~= nil and (type(SU.saved[m]) ~= "number" or SU.saved[m] <= 0) ) then SU.saved[m] = 1; end
		end
	end
	for f, a in pairs(SU.saved or {}) do if ( f and f.SetAlpha ) then f:SetAlpha(a); end end
	for f in pairs(SU.shownBefore or {}) do if ( f and f.Show ) then f:Show(); end end
	SU.saved = nil; SU.shownBefore = nil;
	SS.Safe(SS.ApplyNewFrames);
end

function SS.SetupHide()
	setupActive = false;
	SU.on = {};                                            -- nothing is "on in the setup" outside it
	SU.Unreveal();
	SS.Safe(SS.ApplyElementModes);
	if ( SU.panel ) then SU.panel:Hide(); end
	if ( SU.bar ) then SU.bar:Hide(); end
	SS.Safe(SS.EndPreviewsIfDone);
	SS.Safe(SS.RefreshChatDock);
	SS.Safe(SS.HideNative, "meter", false);
	if ( SS.DB().moveMeter ) then SS.Safe(SS.HideNative, "meter", true); end
	if ( SU.glow ) then SU.glow:Hide(); SU.glow.handle = nil; end
end

-- Exit: the UI stays unlocked for moving. Complete: the UI is locked.
function SS.ConfirmSetupDone()
	if ( not SU.confirmDone ) then
		local f = K.Window("SlimSuiteSetupConfirmation", "Finish setup", 380, 150);
		SU.confirmDone = f;
		f:SetFrameStrata("FULLSCREEN_DIALOG");
		local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
		text:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -38); text:SetWidth(340); text:SetHeight(60);
		text:SetText(SS.T("Have you added everything you want? To add more use /slim setup"));
		local confirm = K.Button(f, "Confirm", 110, function() f:Hide(); SS.SetupEnd(true); end);
		f.confirm = confirm;
		confirm:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 14);
		local back = K.Button(f, "Back", 110, function() f:Hide(); end);
		f.back = back;
		back:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 14);
	end
	SU.confirmDone:Show();
	SU.confirmDone:SetAlpha(1);
end

function SS.SetupEnd(finished)
	if ( SU.confirmDone ) then SU.confirmDone:Hide(); end
	SS.DB().setupDone = true;
	local ok, err = pcall(SS.SetupHide);
	if ( not ok ) then SS.SetupRescue(err); return; end
	editOnly = nil;
	SS.SetUnlocked(false, true);   -- Done (or Exit) leaves Edit mode
end

-- ---------------------------------------------------------------- the settings window

-- Places a settings page's visible rows top to bottom. A sub-setting whose setting is off, and a heading with nothing
-- under it, take no room. Runs again after every change, so sub-settings appear and disappear as they are turned on.
function SS.LayoutPage(page)
	local rows, parent = page.rows, page.parent;
	local show = {};
	for i = 1, table.getn(rows) do
		local r = rows[i];
		show[i] = not (r.up and not r.up());
	end
	local y = page.startY;
	for i = 1, table.getn(rows) do
		local r = rows[i];
		if ( r.kind == "head" ) then
			local any = false;
			for j = i + 1, table.getn(rows) do
				if ( rows[j].kind == "head" ) then break; end
				if ( show[j] ) then any = true; break; end
			end
			r.fs:ClearAllPoints(); r.fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y);
			if ( any ) then r.fs:Show(); y = y - 24; else r.fs:Hide(); end
		elseif ( show[i] ) then
			if ( r.kind == "button" ) then
				r.b:ClearAllPoints(); r.b:SetPoint("TOPLEFT", parent, "TOPLEFT", 26, y + 2);
				r.b:Show();
				y = y - 30;
			elseif ( r.kind == "choice" ) then
				r.fs:ClearAllPoints(); r.fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 30 + r.lead, y - 6);
				r.fs:Show(); r.b:Show();
			else
				r.cb:ClearAllPoints(); r.cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 26 + r.lead, y);
				r.cb:Show(); r.cb.label:Show();
			end
			y = y - 28;
		else
			if ( r.kind == "button" ) then r.b:Hide();
			elseif ( r.kind == "choice" ) then r.fs:Hide(); r.b:Hide(); else r.cb:Hide(); r.cb.label:Hide(); end
		end
	end
	parent:SetHeight(math.max(20, -y + 12));
	if ( page.after ) then page.after(y); end
	return y;
end

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
	fs:SetWidth(350); fs:SetHeight(28); fs:SetJustifyH("LEFT"); fs:SetText(SS.T(label));
	cb.label = fs;
	cb:SetScript("OnShow", function() this:SetChecked(get() and 1 or nil); end);
	cb.get = get;
	SS.TrackToggle(cb);
	cb:SetScript("OnClick", function()
		local v = not (get() and true or false);
		set(v);
		K.Sound(v and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff");
		SS.RefreshToggles();
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
	hero.line:SetText(SS.T("A Swiss-army knife of useful tools and UI controls."));
	hero.version=hero:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
	hero.version:SetPoint("TOPRIGHT",hero,"TOPRIGHT",-9,-8); hero.version:SetText("v"..SS.AddonVersion()); hero.version:SetTextColor(0.95,0.76,0.3);
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
	-- A page is a list of groups: {head="Name"} starts one. A row whose label starts with spaces is a sub-setting: it
	-- shows only while the setting above it (the one it belongs to) is on.
	local function AddRows(parent, entries, startY, after)
		SS.pages = SS.pages or {};
		local page = { parent = parent, rows = {}, startY = startY, after = after };
		local up = nil;
		for i = 1, table.getn(entries) do
			local row = entries[i];
			if ( row.head ) then
				local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal");
				fs:SetText(SS.T(row.head)); fs:SetTextColor(1, 0.82, 0);
				table.insert(page.rows, { kind = "head", fs = fs });
				up = nil;
			elseif ( row.button ) then
				local b = K.Button(parent, row.button, 150, row.onClick);
				table.insert(page.rows, { kind = "button", b = b });
				up = nil;
			else
				local label, lead = row[1], 0;
				if ( string.find(label, "^%s") ) then lead = 22; label = string.gsub(label, "^%s+", ""); end
				local r = { lead = lead, up = (lead > 0) and up or nil };
				if ( row.choice ) then
					r.kind = "choice";
					r.fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
					r.fs:SetText(SS.T(label));
					r.b = SS.ChoiceButton(parent, 200);
					r.b.entry = row; r.b:SetPoint("LEFT", r.fs, "RIGHT", 10, 0);
					r.b:SetText(SS.ChoiceText(row) .. "  v");
					r.b:SetScript("OnShow", function() if ( this.entry ) then this:SetText(SS.ChoiceText(this.entry) .. "  v"); end end);
					if ( lead == 0 ) then up = nil; end
				else
					r.kind = "check";
					r.cb = SS.Check(parent, label, startY, row[2], row[3], lead);
					up = row[2];
				end
				table.insert(page.rows, r);
			end
		end
		table.insert(SS.pages, page);
		SS.LayoutPage(page);
		return page;
	end
	local tooltipTitle, tooltipSmaller, tooltipLarger, reset, resetAll, addonsTab, uiLastY, otherLastY;
	-- the tooltip-size and reset controls sit under the last row of the UI page
	local function PlaceTail()
		if ( not tooltipTitle or not uiLastY ) then return; end
		local y0 = uiLastY - 14;
		tooltipTitle:ClearAllPoints(); tooltipTitle:SetPoint("TOPLEFT", uiChild, "TOPLEFT", 10, y0);
		tooltipSmaller:ClearAllPoints(); tooltipSmaller:SetPoint("TOPLEFT", uiChild, "TOPLEFT", 10, y0 - 18);
		reset:ClearAllPoints(); reset:SetPoint("TOPLEFT", uiChild, "TOPLEFT", 10, y0 - 52);
		uiChild:SetHeight(-(y0 - 52) + 44);
	end
	-- the Manage Addons button sits under the last row of the Other page
	local function PlaceAddons()
		if ( not addonsTab or not otherLastY ) then return; end
		addonsTab:ClearAllPoints(); addonsTab:SetPoint("TOPLEFT", otherChild, "TOPLEFT", 10, otherLastY - 12);
		otherChild:SetHeight(-(otherLastY - 12) + 44);
	end
	local function CheckboxRows()
		local noteTitle = uiChild:CreateFontString(nil, "OVERLAY", "GameFontNormal");
		noteTitle:SetPoint("TOPLEFT", uiChild, "TOPLEFT", 10, -8); noteTitle:SetText(SS.T("Moving the game's UI"));
		local note = uiChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		note:SetPoint("TOPLEFT", noteTitle, "BOTTOMLEFT", 0, -3); note:SetWidth(390); note:SetHeight(38);
		note:SetJustifyH("LEFT"); note:SetJustifyV("TOP"); note:SetHeight(52); note:SetText(SS.T("The game's own versions of these parts can't be moved. To move one, say yes below: Slim Suite swaps in its own movable copy. Each copy's other settings are in its menu: right-click it in Toggle UI Settings."));
		AddRows(uiChild, {
			{head="Setup"},
			{"Toggle UI Settings (drag, resize and scale)", function() return SS.DB().unlocked; end, function(v) SS.SetUnlocked(v); end},
			{button = "Demo Mode", onClick = function() SS.ToggleDemoMode(); end},
			{button = "Profiles & import/export", onClick = function() SS.ShowLayoutWindow(); end},
			{button = "Recommended HUD preset", onClick = function() SS.ShowHUDRecommendation(); end},
			{button = "Diagnostics & compatibility", onClick = function() SS.ShowDiagnosticsWindow(); end},
			{"Keep a separate layout for each character", function() return SS.DB().layoutPerCharacter; end, function(v) SS.SetLayoutPerCharacter(v); end},
			{head="Make the game's UI movable"},
			{"Replace Default Level Up with Movable Version?", function() return SS.DB().moveLevelButton; end, function(v) SS.DB().moveLevelButton = v; SS.Safe(SS.UpdateLevelButton); end},
			{"Replace Default Build Rows with Movable Versions?", function() return SS.DB().replaceBuildRows; end, function(v) SS.DB().replaceBuildRows = v; SS.ApplyBuildRowReplacement(); end},
			{"Replace Default Damage Meter with Movable Version?", function() return SS.DB().moveMeter; end, function(v) SS.SetMeterReplacement(v); end},
			{"Replace Default Run Clock with Movable Version?", function() return SS.DB().replaceClock;end,function(v) SS.DB().replaceClock=v;SS.UpdateClock();end},
			{"Replace Default Encounter Bars with Movable Versions?", function() return SS.DB().replaceEncounters;end,function(v) SS.DB().replaceEncounters=v;SS.UpdateBossFrames();end},
			{"Replace Default Kills / Gold / Cache with Movable Version?", function() return SS.DB().replaceTally;end,function(v) SS.DB().replaceTally=v;SS.UpdateTally();end},
			{"Replace Default Announcements with Movable Version?", function() return SS.DB().replaceBanners;end,function(v) SS.DB().replaceBanners=v;SS.UpdateAnnouncementFrame();end},
			{"Replace Default Revive Bar with Movable Version?", function() return SS.DB().replaceRevive; end, function(v) SS.DB().replaceRevive = v; end},
			{"Replace Default Local Clock with Movable Version?", function() return SS.DB().replaceLocalClock; end, function(v) SS.SetLocalClockOn(v); end},
			{"Replace Default Action Bar Art with Plain Version?", function() return SS.DB().plainBar; end, function(v) SS.DB().plainBar = v; SS.PlainBar(v); end},
			{"Replace Default Combat Text with Movable Box?", function() return SS.DB().combatTextBox; end, function(v) SU.FEATURES.SlimSuiteCombatTextFrame(v and true or false); if ( SS.DB().unlocked ) then SS.SetUnlocked(true, true); end SU.Rebuild(); end},
			{"Replace Default Minimap Buttons with a Movable Row? (optional)", function() return SS.DB().minimapBar; end, function(v) SS.SetMinimapBar(v); end},
			{head="Everywhere"},
			{"Show green absorb amounts on player and party frames (when the client exposes them)", function() return SS.DB().showAbsorbs; end, function(v) SS.DB().showAbsorbs = v and true or false; SS.Safe(SS.UpdateAbsorbMarkers); end},
			{"Floating combat text over enemies (Slim Suite's own)", function() return SS.DB().floatingText; end, function(v) SS.DB().floatingText = v; end},
			{"Show Slim Suite above the level-up and new-item cards", function() return SS.DB().onTopOfScreens; end, function(v) SS.DB().onTopOfScreens = v; if ( SlimSuiteWorld ) then SlimSuiteWorld.ApplyOnTop(); end end}
		}, -86, function(y) uiLastY = y; PlaceTail(); end);
	end
	local function BuildOther()
		local purpose=otherChild:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
		purpose:SetPoint("TOPLEFT",otherChild,"TOPLEFT",10,-8);purpose:SetWidth(390);purpose:SetHeight(32);
		purpose:SetJustifyH("LEFT");purpose:SetJustifyV("TOP");purpose:SetText(SS.T("The goal of clearing up chat is to see your friends' chat better in multiplayer."));
		AddRows(otherChild, {
			{head="Chat mods"},
			{"No level-up stat bonuses in chat", function() return SS.DB().hideLevel;end,function(v) SS.DB().hideLevel=v;end},
			{"No new spell lines in chat", function() return SS.DB().hideNewSpells;end,function(v) SS.DB().hideNewSpells=v;end},
			{"Hide racial buff information in chat", function() return SS.DB().hideRacialInfo;end,function(v) SS.DB().hideRacialInfo=v;end},
			{"Hide the Oogax Q opening line (English game text only)", function() return SS.DB().hideOpeningLine;end,function(v) SS.DB().hideOpeningLine=v;end},
			{"Hide 'Who dares to enter my lair' (English game text only)", function() return SS.DB().hideLairLine;end,function(v) SS.DB().hideLairLine=v;end},
			{"Hide in-game roleplay lines from chat", function() return SS.DB().hideRP;end,function(v) SS.DB().hideRP=v;end},
			{head="Enemy frames"},
			{"Show native enemy nameplates", function() return SS.NativeEnemyNameplatesEnabled and SS.NativeEnemyNameplatesEnabled(); end, function(v) SS.SetNativeEnemyNameplates(v); end},
			{"Use modern Slim Suite enemy frames", function() return SS.DB().modernEnemyFrames; end, function(v) SS.SetModernEnemyFrames(v); end},
			{"Only show bosses and lair guardians on modern enemy frames", function() return SS.DB().enemyBossesOnly; end, function(v) SS.SetEnemyPlateBossesOnly(v); end},
			{"Show boss and lair debuffs and remaining time on modern enemy frames", function() return SS.DB().enemyPlateDebuffs; end, function(v) SS.SetEnemyPlateDebuffs(v); end},
			{head="Camera and marks"},
			{"Camera as far out as it goes (50)", function() return SS.DB().camera; end, function(v) SS.DB().camera = v; SS.Camera(v); end},
			{"Mark pulled bosses and Guardians (Skull, X, Circle, Star)", function() return SS.DB().bossMarks; end, function(v) SS.DB().bossMarks = v; end},
			{"   ...and Guardians and lairs before they're pulled", function() return SS.DB().prePullMarks; end, function(v) SS.DB().prePullMarks = v; end},
			{"Raid-mark row when the mouse is over a party member (in a group)", function() return SS.DB().raidRow; end, function(v) SS.DB().raidRow = v and true or false; end},
			{head="Minimap"},
			{"Show caches on the minimap", function() return SS.DB().minimapCaches; end, function(v) SS.DB().minimapCaches = v; end},
			{"Show bosses on the minimap", function() return SS.DB().minimapBosses; end, function(v) SS.DB().minimapBosses = v; end},
			{"Show lairs on the minimap, with their 3:00 refill timer", function() return SS.DB().minimapLairs; end, function(v) SS.DB().minimapLairs = v; end},
			{"Show the game's nearest Guardian lair flag on minimap", function() return SS.DB().showGuardianFlag; end, function(v) SS.DB().showGuardianFlag = v; SS.ApplyGuardianFlag(); end},
			{"Square minimap (off: round)", function() return SS.DB().minimapSquare; end, function(v) SS.SetMinimapSquare(v); end},
			{"Transparent minimap (round or square, no borders)", function() return SS.DB().minimapTransparent; end, function(v) SS.SetMinimapTransparent(v); end},
			SS.MinimapButtonsEntry(),
			{"Minimap button", function() local m = SS.DB().minimap; return not (m and m.hide); end, function(v) if ( SS.Mini ) then local m = SS.DB().minimap; if ( (m and m.hide and true or false) == v ) then SS.Mini.Toggle(); end end end},
			{head="Deaths and spells"},
			{"Mark where a downed friend can be revived", function() return SS.DB().deathMarks; end, function(v) SS.DB().deathMarks = v; end},
			{"Play a sound when you or a teammate dies", function() return SS.DB().deathSound; end, function(v) SS.DB().deathSound = v; end},
			{"   Use LEGO die instead of Baby Crying", function() return SS.DB().legoDeathSound; end, function(v) SS.DB().legoDeathSound = v and true or false; end},
			{button = "Preview: Baby Crying (death)", onClick = function() SS.PreviewSound("death"); end},
			{button = "Preview: LEGO die", onClick = function() SS.PreviewSound("legoDeath"); end},
			{"Play Low Health Sound at 30% health or lower (1 second, every 5 seconds)", function() return SS.DB().lowHealthSound; end, function(v) SS.DB().lowHealthSound = v and true or false; end},
			{button = "Preview: Low Health Sound", onClick = function() SS.PreviewSound("lowHealth"); end},
			{"Play hitmarker when a boss, Guardian, or lair owner is killed", function() return SS.DB().bossHitmarkerSound; end, function(v) SS.DB().bossHitmarkerSound = v and true or false; end},
			{button = "Preview: Hitmarker", onClick = function() SS.PreviewSound("bossHitmarker"); end},
			{"Play whip crack when a boss, Guardian, or lair owner is killed", function() return SS.DB().bossWhipSound; end, function(v) SS.DB().bossWhipSound = v and true or false; end},
			{button = "Preview: Whip Crack", onClick = function() SS.PreviewSound("bossWhip"); end},
			{"Play a sound when opening a cache", function() return SS.DB().chestOpenSound; end, function(v) SS.DB().chestOpenSound = v and true or false; end},
			{button = "Preview: Zelda chest opening", onClick = function() SS.PreviewSound("chestOpen"); end},
			{"Cooldown numbers on the spell squares", function() return SS.DB().cooldowns; end, function(v) SS.DB().cooldowns = v; end},
			{head="Accessibility"},
			{"High-contrast encounter bars", function() return SS.DB().accessibilityContrast; end, function(v) SS.DB().accessibilityContrast = v and true or false; SS.Safe(SS.UpdateBossFrames); end},
			{"Larger encounter names", function() return SS.DB().accessibilityLargeText; end, function(v) SS.DB().accessibilityLargeText = v and true or false; SS.Safe(SS.UpdateBossFrames); end},
			{"Reduce floating combat-text motion", function() return SS.DB().accessibilityReduceMotion; end, function(v) SS.DB().accessibilityReduceMotion = v and true or false; end},
			{head="Support"},
			{button = "View diagnostics & compatibility", onClick = function() SS.ShowDiagnosticsWindow(); end},
		}, -48, function(y) otherLastY = y; PlaceAddons(); end);
	end
	local function BuildAddonManager()
		local title = addonsChild:CreateFontString(nil, "OVERLAY", "GameFontNormal");
		title:SetPoint("TOPLEFT", addonsChild, "TOPLEFT", 8, -8); title:SetText(SS.T("Enabled game addons"));
		local note = addonsChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6); note:SetText(SS.T("Changes apply after reload. Uncheck to disable an addon."));
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
	tooltipTitle = uiChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	tooltipTitle:SetPoint("TOPLEFT", uiChild, "TOPLEFT", 10, -732);
	tooltipTitle:SetText(SS.T("Tooltip width"));
	local function AdjustTooltipSize(delta)
		local size = SS.DB().sizes.GameTooltip;
		if ( type(size) ~= "table" ) then size = { w = 260, h = 140 }; SS.DB().sizes.GameTooltip = size; end   -- the player's own size from now on
		SS.DB().tooltipCustom = true;
		size.w = math.max(160, math.min(600, size.w + delta));
		if ( GameTooltip ) then GameTooltip:SetWidth(size.w); end
		PlaceAll();
	end
	tooltipSmaller = K.Button(uiChild, "Smaller", 82, function() AdjustTooltipSize(-20); end);
	tooltipSmaller:SetPoint("TOPLEFT", uiChild, "TOPLEFT", 10, -750);
	tooltipLarger = K.Button(uiChild, "Larger", 82, function() AdjustTooltipSize(20); end);
	tooltipLarger:SetPoint("LEFT", tooltipSmaller, "RIGHT", 6, 0);
	reset = K.Button(uiChild, "Reset positions", 140, function() SS.ResetPlaces(); end);
	reset:SetPoint("TOPLEFT", uiChild, "TOPLEFT", 10, -784);
	resetAll = K.Button(uiChild, "Reset all UI", 126, function() SS.ResetUI(); end);
	resetAll:SetPoint("LEFT", reset, "RIGHT", 8, 0);
	uiChild:SetHeight(818);
	CheckboxRows(); BuildOther(); BuildAddonManager();
	local function SelectPage(which)
		uiScroll:Hide(); otherScroll:Hide(); addonsScroll:Hide();
		if ( win.reloadButton ) then win.reloadButton:Hide(); end
		if ( which == "ui" ) then uiScroll:Show(); tabUi:LockHighlight(); tabOther:UnlockHighlight();
		elseif ( which == "other" ) then otherScroll:Show(); tabUi:UnlockHighlight(); tabOther:LockHighlight();
		else addonsScroll:Show(); if ( win.reloadButton ) then win.reloadButton:Show(); end end
	end
	tabUi:SetScript("OnClick", function() SelectPage("ui"); end);
	tabOther:SetScript("OnClick", function() SelectPage("other"); end);
	addonsTab = K.Button(otherChild, "Manage Addons", 132, function() SelectPage("addons"); end);
	PlaceTail(); PlaceAddons();
	SelectPage("other");
end

function SS.Toggle()
	if ( not win ) then
		local ok, err = SS.Safe(SS.WinBuild);
		if ( not ok ) then K.Print(NAME, "|cffff4040the settings window could not be made:|r " .. tostring(err)); win = nil; return; end
	end
	if ( win:IsShown() ) then win:Hide(); else win:Show(); end
end

-- "/slimsuite mouse": a small label by the cursor names the frame under it (and the frame that frame belongs to), so a
-- click that does nothing can be traced to whatever is catching it. Type it again to turn the label off.
function SS.ToggleMouseProbe()
	local probe = getglobal("SlimSuiteMouseProbe");
	if ( not probe ) then
		probe = CreateFrame("Frame", "SlimSuiteMouseProbe", UIParent);
		probe:SetFrameStrata("TOOLTIP");
		probe:SetWidth(10); probe:SetHeight(10);
		probe.text = probe:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		probe.text:SetPoint("BOTTOMLEFT", probe, "TOPRIGHT", 4, 4);
		probe.text:SetJustifyH("LEFT");
		probe:Hide();
	end
	if ( probe:IsShown() ) then
		probe:Hide(); SS.Stop("mouseProbe");
		K.Print(NAME, "the frame label is off.");
		return;
	end
	probe:Show();
	SS.Every("mouseProbe", 0.1, function()
		local f = GetMouseFocus and GetMouseFocus();
		local x, y = GetCursorPosition();
		local scale = SS.EffectiveScale(UIParent);
		probe:ClearAllPoints();
		probe:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale);
		if ( not f ) then probe.text:SetText("|cffaaaaaa(the game world)|r"); return; end
		local name = (f.GetName and f:GetName()) or "(no name)";
		local parent = f.GetParent and f:GetParent();
		local pname = parent and parent.GetName and parent:GetName() or "(no name)";
		probe.text:SetText("|cffffd100" .. name .. "|r\n|cffaaaaaain " .. pname .. "|r");
	end);
	K.Print(NAME, "the frame under your cursor is named next to it. /slimsuite mouse turns it off.");
end

SS.HELP = {
	"/slim: the settings window.  /slim edit: move and size the UI (/slim lock when done).  /slim setup: the guided setup.",
	"/slim demo: Demo Mode on or off.  /slim levelup: Slim Suite's Level Up button or the game's own.",
	"/slim layout: manage named profiles and import/export layouts.  /slim layout save <name>, load <name>, delete <name>, list.",
	"/slim hud: recommended positions for this display.  /slim diagnostics: client and game compatibility details.",
	"/slim reset places, /slim reset all: back to where everything started.",
	"/slim hide <words>, /slim unhide <words>, /slim hide: chat lines with those words.",
	"/slim minimap: the gear button.  /slim errors: the error log.  /slim mouse: names the frame under the cursor.",
};
SLASH_SLIMSUITE1 = "/slimsuite";
SLASH_SLIMSUITE2 = "/slim";
SlashCmdList["SLIMSUITE"] = function(msg)
	msg = msg or "";
	local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.-)$");
	cmd = string.lower(cmd or "");
	rest = string.lower(rest or "");
	local d = SS.DB();
	if ( cmd == "help" or cmd == "?" ) then
		for _, line in ipairs(SS.HELP) do K.Print(NAME, line); end
	elseif ( cmd == "hide" and rest == "" ) then
		if ( table.getn(d.words) == 0 ) then K.Print(NAME, "no words are hidden. /slim hide <words> hides chat lines with them.");
		else K.Print(NAME, "hidden in chat: \"" .. table.concat(d.words, "\", \"") .. "\". /slim unhide <words> shows them again."); end
	elseif ( cmd == "hide" ) then
		for i = 1, table.getn(d.words) do
			if ( d.words[i] == rest ) then K.Print(NAME, "\"" .. rest .. "\" is hidden already."); return; end
		end
		table.insert(d.words, rest);
		K.Print(NAME, "chat lines with \"" .. rest .. "\" are hidden now.");
	elseif ( cmd == "unhide" and rest ~= "" ) then
		for i = table.getn(d.words), 1, -1 do if ( d.words[i] == rest ) then table.remove(d.words, i); end end
		K.Print(NAME, "chat lines with \"" .. rest .. "\" are shown again.");
	elseif ( cmd == "errors" ) then
		SS.ShowErrors();
	elseif ( cmd == "diagnostics" or cmd == "compatibility" ) then
		SS.ShowDiagnosticsWindow();
	elseif ( cmd == "hud" or cmd == "recommend" ) then
		SS.ShowHUDRecommendation();
	elseif ( cmd == "mouse" ) then
		SS.ToggleMouseProbe();
	elseif ( cmd == "minimap" ) then
		local shown = SS.Mini and SS.Mini.Toggle();
		K.Print(NAME, shown and "the minimap button is back." or "the minimap button is hidden. /slimsuite minimap brings it back.");
	elseif ( cmd == "unlock" or cmd == "move" or cmd == "edit" ) then
		SS.SetUnlocked(true);
	elseif ( cmd == "lock" ) then
		SS.SetUnlocked(false);
	elseif ( cmd == "setup" ) then
		SS.StartSetup(true);
	elseif ( cmd == "demo" ) then
		SS.ToggleDemoMode();
		K.Print(NAME, SS.demoRunning and "Demo Mode is on. /slim demo turns it off." or "Demo Mode is off.");
	elseif ( cmd == "levelup" ) then
		d.moveLevelButton = not d.moveLevelButton;
		SS.Safe(SS.UpdateLevelButton); SS.RefreshToggles();
		K.Print(NAME, d.moveLevelButton and "Slim Suite's movable Level Up button is on." or "the game's own Level Up button is back.");
	elseif ( cmd == "reset" ) then
		if ( rest == "all" ) then SS.ResetUI(); elseif ( rest == "places" ) then SS.ResetPlaces();
		else K.Print(NAME, "/slim reset places puts every element back where it started; /slim reset all also resets sizes, scales and layouts."); end
	elseif ( cmd == "layout" or cmd == "layouts" ) then
		local _, _, action, name = string.find(rest, "^(%S*)%s*(.-)$");
		if ( action == "save" and name ~= "" ) then
			d.layouts[name] = SS.LayoutSnapshot();
			K.Print(NAME, "layout \"" .. name .. "\" saved.");
		elseif ( action == "load" and name ~= "" ) then
			if ( type(d.layouts[name]) == "table" and string.sub(name, 1, 5) ~= "char:" ) then SS.LayoutApply(d.layouts[name]); K.Print(NAME, "layout \"" .. name .. "\" is in use.");
			else K.Print(NAME, "there is no layout called \"" .. name .. "\". /slim layout list shows them."); end
		elseif ( action == "delete" and name ~= "" ) then
			if ( d.layouts[name] and string.sub(name, 1, 5) ~= "char:" ) then d.layouts[name] = nil; K.Print(NAME, "layout \"" .. name .. "\" deleted.");
			else K.Print(NAME, "there is no layout called \"" .. name .. "\"."); end
		elseif ( action == "list" ) then
			local names = SS.LayoutNames();
			K.Print(NAME, table.getn(names) > 0 and ("saved layouts: " .. table.concat(names, ", ")) or "no layouts saved yet. /slim layout save <name> saves this one.");
		else
			SS.ShowLayoutWindow();
			K.Print(NAME, "/slim layout save <name>, load <name>, delete <name>, list. The window shares a layout as text.");
		end
	else
		SS.Toggle();
	end
end
