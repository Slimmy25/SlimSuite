-- Focused Slim Suite module; loaded in manifest order.
if ( setfenv ) then setfenv(1, SS.ENV); end
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
