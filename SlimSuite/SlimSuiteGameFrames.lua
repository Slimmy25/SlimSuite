-- Slim Suite: the game's own frames while editing: the tooltip and its sample, Reset for an element, the target frame and the plain bar.
local K, SU, NAME = SS.Kit, SS.SU, SS.NAME;   -- the three names every Slim Suite file uses (SlimSuiteCore.lua)

-- the tooltip at the place the player moved it to (its lower-left corner), if it has been moved
function SS.PlaceTooltip(tooltip)
	local p = SS.DB().places.GameTooltip;
	if ( type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" ) then
		return SS.PlaceDisplayDefault and SS.PlaceDisplayDefault("GameTooltip", tooltip) or false;
	end
	SS.Place("GameTooltip");
	return true;
end

-- The setup, Edit mode and Demo Mode show a sample tooltip where tooltips will appear, at their size, so there is
-- something to see and drag. Hovering anything shows the real tooltip instead; the sample comes back when it goes.
SS.TOOLTIP_SAMPLE = { { "Hogger", 1, 1, 1 }, { "Level ?? Elite", 1, 0.82, 0 }, { "Tooltips appear here.", 0.8, 0.8, 0.8 },
	{ "Drag the handle to move them; right-click to size them.", 0.6, 0.8, 1 } };
function SS.UpdateTooltipPreview()
	local tt = GameTooltip;
	if ( not tt or not tt.SetOwner ) then return; end
	if ( not SS.Previewing("GameTooltip") ) then
		if ( tt.slimSample ) then tt.slimSample = nil; tt:Hide(); end
		return;
	end
	if ( tt:IsShown() ) then return; end
	tt:SetOwner(UIParent, "ANCHOR_NONE");
	tt:ClearAllPoints();
	if ( not SS.PlaceTooltip(tt) ) then
		local ox = type(CONTAINER_OFFSET_X) == "number" and CONTAINER_OFFSET_X or 0;
		local oy = type(CONTAINER_OFFSET_Y) == "number" and CONTAINER_OFFSET_Y or 70;
		tt:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -ox - 13, oy);           -- the game's usual corner
	end
	local lines = SS.TOOLTIP_SAMPLE;
	tt:SetText(lines[1][1], lines[1][2], lines[1][3], lines[1][4]);
	for i = 2, table.getn(lines) do tt:AddLine(lines[i][1], lines[i][2], lines[i][3], lines[i][4], 1); end
	tt:Show();
	tt.slimSample = true;                                     -- set after SetOwner, which clears it
end

SS.SetAnchorSnap = function(on)
	SS.DB().anchorSnap = on and true or false;
	if ( not on ) then
		for i = 1, table.getn(SS.MOVABLE) do
			local name = SS.MOVABLE[i][1];
			local p = SS.DB().places[name];
			local f = getglobal(name);
			if ( type(p) == "table" and p.relative and f and not (name == "SlimSuiteItemRowFrame" and SS.DB().buildRowsAttached) ) then
				SS.SavePlace(name, f);
				p.relative, p.point, p.relativePoint, p.dx, p.dy = nil, nil, nil, nil, nil;
			end
		end
		SS.PlaceAll();
	end
	K.Print(NAME, on and "nearby frames will latch together when you move them." or "frames will move independently now.");
end

function SS.ResetPlaces()
	for i = 1, table.getn(SS.MOVABLE) do
		local name = SS.MOVABLE[i][1];
		SS.DB().places[name] = nil;
		local frame = getglobal(name);
		local points = SS.basePoints[name];
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
	SS.PlaceAll();
	K.Print(NAME, "movable elements are back at their original locations.");
end

function SS.ResetElement(name)
	if ( SS.MarkProfileDirty ) then SS.MarkProfileDirty(); end
	local frame = name and getglobal(name);
	if ( not frame ) then return false; end
	local d = SS.DB();
	d.places[name], d.sizes[name], d.scales[name], d.padding[name], d.orientations[name] = nil, nil, nil, nil, nil;
	if ( name == "SlimSuiteTallyFrame" ) then d.tallyVertical = true; end
	if ( name == "BuffFrame" ) then d.buffCustomLayout = false; d.buffGrowthDirection = "down"; end
	if ( name == "SlimSuiteSpellRowFrame" or name == "SlimSuiteItemRowFrame" ) then
		d.places[name] = SS.BuildRowDefaultPlace(name);
	end
	local points = SS.basePoints[name];
	if ( points and name ~= "GameTooltip" ) then
		frame:ClearAllPoints();
		for i = 1, table.getn(points) do
			local p = points[i]; frame:SetPoint(p[1], p[2], p[3], p[4], p[5]);
		end
	end
	if ( name == "MainMenuBar" and SS.actionBarOriginal and SS.actionBarOriginal.buttonSize ) then
		for i = 1, 6 do
			local button = getglobal("ActionButton" .. i);
			if ( button ) then button:SetWidth(SS.actionBarOriginal.buttonSize); button:SetHeight(SS.actionBarOriginal.buttonSize); end
		end
	end
	local base = SS.baseSizes[name];
	if ( base ) then frame:SetWidth(base.w); frame:SetHeight(base.h); end
	if ( name == "GameTooltip" ) then frame:SetWidth(260); frame:SetHeight(140); d.tooltipCustom = nil; end
	if ( name == "GameTooltip" ) then frame:Hide(); end
	SS.ApplySize(name, frame);
	if ( name == "SlimSuiteTallyFrame" ) then SS.ApplyTallyLayout(false); end
	if ( name == "SlimSuiteBossFrames" ) then SS.UpdateBossFrames(); end
	if ( name == "SlimSuiteAnnouncementFrame" ) then SS.ApplyMovablePadding(name); end
	if ( name == "BuffFrame" ) then SS.Safe(SS.ApplyBuffOrientation); end
	if ( name == "PartyMemberFrame1" or name == "MainMenuExpBar" or name == "MainMenuBar" ) then SS.Safe(SS.ApplyMovableOrientation, name); end
	if ( d.muted[name] ) then d.muted[name] = nil; SS.Safe(SS.ApplyFeatureMute, name); end
	SS.PlaceAll();
	return true;
end

function SS.ResetUI()
	if ( SS.MarkProfileDirty ) then SS.MarkProfileDirty(); end
	local d = SS.DB();
	d.places, d.sizes, d.scales, d.padding, d.orientations, d.muted = {}, {}, {}, {}, {}, {};
	d.tallyVertical, d.buffCustomLayout, d.buffGrowthDirection = true, false, "down";
	d.xpHideBorder,d.hideBuildSpells,d.hideBuildItems,d.matchBuildSizes=false,false,false,false;
	d.tooltipCustom = nil;
	d.buildRowsAttached = true;
	d.places.SlimSuiteSpellRowFrame = SS.BuildRowDefaultPlace("SlimSuiteSpellRowFrame");
	d.places.SlimSuiteItemRowFrame = SS.BuildRowDefaultPlace("SlimSuiteItemRowFrame");
	d.chatOffsets = {};
	for i = 1, table.getn(SS.MOVABLE) do
		local name = SS.MOVABLE[i][1];
		local frame, points, base = getglobal(name), SS.basePoints[name], SS.baseSizes[name];
		if ( frame and points and name ~= "GameTooltip" ) then
			frame:ClearAllPoints();
			for j = 1, table.getn(points) do
				local p = points[j]; frame:SetPoint(p[1], p[2], p[3], p[4], p[5]);
			end
		end
		if ( frame and base ) then frame:SetWidth(base.w); frame:SetHeight(base.h); end
		if ( frame and frame.SetScale ) then frame:SetScale(1); end
	end
	if ( SS.actionBarOriginal and SS.actionBarOriginal.buttonSize ) then
		for i = 1, 6 do
			local button = getglobal("ActionButton" .. i);
			if ( button ) then button:SetWidth(SS.actionBarOriginal.buttonSize); button:SetHeight(SS.actionBarOriginal.buttonSize); end
		end
	end
	if ( GameTooltip ) then GameTooltip:SetWidth(260); GameTooltip:SetHeight(140); GameTooltip:Hide(); end
	if ( type(SS.PrepareChatWindow) == "function" ) then SS.Safe(SS.PrepareChatWindow); end
	if ( type(SS.ApplyTallyLayout) == "function" ) then SS.Safe(SS.ApplyTallyLayout, false); end
	if ( type(SS.UpdateBossFrames) == "function" ) then SS.Safe(SS.UpdateBossFrames); end
	SS.Safe(SS.ApplyMovablePadding, "SlimSuiteAnnouncementFrame");
	if ( type(SS.ApplyBuffOrientation) == "function" ) then SS.Safe(SS.ApplyBuffOrientation); end
	for _, name in ipairs({ "MainMenuBar", "MainMenuExpBar", "PartyMemberFrame1" }) do SS.Safe(SS.ApplyMovableOrientation, name); end
	for i = 1, table.getn(SS.MOVABLE) do
		local name = SS.MOVABLE[i][1];
		SS.Safe(SS.ApplyFeatureMute, name);
	end
	SS.PlaceAll();
	SS.HideElementMenu();
	K.Print(NAME, "all movable UI elements are back at their addon defaults.");
end

-- the target frame: hidden for good while the setting is on (this game targets for you)
SS.targetShow = nil;
function SS.TargetFrameHidden(on)
	if ( not TargetFrame ) then return; end
	if ( not SS.targetShow ) then SS.targetShow = TargetFrame.Show; end
	if ( on ) then
		TargetFrame.Show = function() end;
		TargetFrame:Hide();
	else
		TargetFrame.Show = SS.targetShow;
		if ( UnitExists("target") ) then TargetFrame:Show(); end
	end
end

-- the plain action bar: the gryphons at its ends and all of the bar's art (the game's slices, its own extra ones and
-- the racial's old rim) made see-through. Keep six spell squares and the native racial button;
-- hide only the character and talent micro buttons.
SS.PLAIN_HIDE = { "CharacterMicroButton", "TalentMicroButton" };
SS.plainShow = {};
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

function SS.PlainBar(on)
	if ( not MainMenuBar ) then return; end
	SS.BarArt(on and 0 or 1);
	SS.Safe(SS.ApplyMovableOrientation, "MainMenuBar");
	for i = 1, table.getn(SS.PLAIN_HIDE) do
		local f = getglobal(SS.PLAIN_HIDE[i]);
		if ( f ) then
			if ( not SS.plainShow[f] ) then SS.plainShow[f] = f.Show; end
			if ( on ) then
				f.Show = function() end;
				f:Hide();
			elseif ( f.Show ~= SS.plainShow[f] ) then
				f.Show = SS.plainShow[f];
				f:Show();
			end
		end
	end
end

-- the cooldown numbers: the seconds until each spell square's spell is ready again. The game's spells (AZS_SPELLS, the
-- racial last) map to ActionButton1 to 6, followed by the native racial ActionButton12.
SS.cdText = {};
SS.Every("cooldowns", 0.1, function()
	local on = SS.DB().cooldowns;
	if ( not on and not SS.cooldownsShown ) then return; end   -- off, and nothing left on the squares
	SS.cooldownsShown = on and true or false;
	local spells = type(AZS_SPELLS) == "table" and AZS_SPELLS or {};
	local n = table.getn(spells);
	for i = 1, 7 do
		local btn = getglobal("ActionButton" .. (i == 7 and 12 or i));
		if ( btn ) then
			local t = SS.cdText[i];
			if ( not t ) then
				t = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge");
				t:SetPoint("CENTER", btn, "CENTER", 0, 0);
				t:SetTextColor(1, 0.82, 0);
				SS.cdText[i] = t;
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
