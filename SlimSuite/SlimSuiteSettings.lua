-- Focused Slim Suite module; loaded in manifest order.
if ( setfenv ) then setfenv(1, SS.ENV); end
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

-- Legacy option checkboxes may still write feature flags. Translate those edits into a mode
-- transition; never let a compatibility flag become a competing source of visibility state.
function SS.ChangeSetting(get, set, value)
 local d, before = SS.DB(), {};
 for name, element in pairs(SS.ELEMENTS) do
  if ( element.feature ) then before[name] = { value=d[element.feature], mode=d.elementModes[name] }; end
 end
 set(value);
 for name, previous in pairs(before) do
  local element = SS.ELEMENTS[name];
  if ( previous.value ~= d[element.feature] and previous.mode == d.elementModes[name] ) then
   SU.SetMode(name, d[element.feature] and "enabled" or "default", element.title);
  end
 end
 if ( SS.MarkProfileDirty ) then SS.MarkProfileDirty(); end
end

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
		info.text = SS.T(opt[1]);
		info.checked = current == opt[2];
		info.func = function() SS.ChangeSetting(e[2], e[3], opt[2]); SS.AfterChoice(); end;
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
	if ( SS.MarkProfileDirty ) then SS.MarkProfileDirty(); end
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
SU.NATIVE = SS.NATIVE_FRAMES;

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
