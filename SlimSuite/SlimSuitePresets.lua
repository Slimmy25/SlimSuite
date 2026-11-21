-- Preset designs offered first in Quick setup ("Would you like to use a pre-set design?"). Up to 5 are shown.
-- To add one: arrange the HUD the way you want, open /slim layout, export the layout and paste its text
-- (it starts with "SSL1;") as the third value below. Name and description are what players see.
-- Its picture is textures/quick/preset<n>.tga (n = its place among the filled-in presets): python3 tools/quick-image.py shot.jpg preset1
-- A preset with no text is skipped. Designs written out below as specs (SS.BUILTIN_PRESETS) come after these.
if ( setfenv ) then setfenv(1, SS.ENV); end

-- Designs made by hand for Slim Suite. Up to 5 are offered in Quick setup; none yet. Each entry:
-- { "Name", "One line players see.", spec } where spec holds the design's options and places:
--   style = "original" | "meter" | "tooltip"; keys = { option = value, ... }; orientations, scales = { element = ... };
--   places = { { element, x, y }, ... }: x, y is where the CENTRE of the element goes, in fractions of the screen
--   (0,0 bottom left; 1,1 top right; across a centred 16:9 area on wider screens), or { element, dx, y, fromCentre = true }
--   for a distance in UI units from the middle. Listed in order of importance: when real sizes make two elements overlap,
--   the later one is moved clear. on / off = { element, ... } turns elements on or back to the game's own.
-- tests/presetreview.lua lays every design out on ten screen sizes and checks nothing overlaps or leaves the screen.
SS.BUILTIN_PRESETS = {
	-- The console / controller layout: frames in the corners, a large compass in place of the minimap, a big
	-- party, up to five encounter bars top-right.
	{ "Console A", "For a controller or handheld: big party lines, the compass instead of the minimap, frames in the corners.", slot = 4, {
		style = "tooltip",
		keys = { playerLook = "new", targetLook = "new", partyLook = "thin", replaceEncounters = true, encounterMax = 5,
			encounterBarThickness = "thick", compassOn = true, partyGreyDead = true, partyDistance = true,
			partyDimFar = true, xpFullWidth = true, xpSegments = true, showRacialAbility = true, showEmptyActionSlots = true },
		orientations = { PartyMemberFrame1 = "vertical", SlimSuiteBossFrames = "horizontal", MainMenuExpBar = "horizontal",
			MainMenuBar = "horizontal" },
		scales = { SlimSuitePlayerCard = 1.25, SlimSuiteTargetCard = 1.25, SlimSuitePartyLines = 2.4, MainMenuExpBar = 1,
			ChatFrame1 = 0.7 },
		sizes = { SlimSuiteBossFrames = { 260, 250 } },
		-- bottom up: the XP bar along the very bottom edge, all seven action buttons (the racial one included) on it,
		-- your frame and the target's in the corners just above the XP bar
		places = { { "MainMenuExpBar", 0, 0, anchor = "BOTTOM" }, { "MainMenuBar", 0, 15, anchor = "BOTTOM" },
			{ "SlimSuitePlayerCard", 16, 22, anchor = "BOTTOMLEFT" }, { "SlimSuiteTargetCard", -16, 22, anchor = "BOTTOMRIGHT" },
			{ "SlimSuiteBossFrames", -16, -16, anchor = "TOPRIGHT" },
			{ "SlimSuitePartyLines", 16, 176, anchor = "BOTTOMLEFT" }, { "ChatFrame1", 16, 296, anchor = "BOTTOMLEFT" },
			{ "BuffFrame", 16, -16, anchor = "TOPLEFT" }, { "SlimSuiteCompassFrame", 0.5, 0.93 } },
		on = { "SlimSuiteCompassFrame" },
		hide = { "MinimapCluster" } } },
};

-- where the game's own frames sit when a design does not move them: designs keep clear of these
-- { name, width, height, corner } with corner "TOPRIGHT", "BOTTOMLEFT" or "BOTTOM"
SS.PRESET_RESERVED = { { "MinimapCluster", 200, 200, "TOPRIGHT" }, { "BuffFrame", 320, 110, "TOPRIGHT", 205 },
	{ "ChatFrame1", 440, 130, "BOTTOMLEFT", 0, 90 }, { "MainMenuBar", 320, 60, "BOTTOM" } };   -- the action bar measured from an in-game screenshot

-- designs as exported layout text from /slim layout (starts with "SSL1;"). These come first.
SS.PRESETS = {
	-- Slot 5: the console layout arranged by hand in game, to compare with slot 4 (exported with /slim layout).
	{ "Console B", "The console layout arranged by hand: huge party lines, upright boss bars top-right, a big action bar.", slot = 5,
		"SSL1;accessibilityContrast=b1;accessibilityLargeText=b1;accessibilityReduceMotion=b0;achievementButton=b0;buffCustomLayout=b1;buffGrowthDirection=sdown;buffsOnPlayer=b1;buffsOnPlayerSide=sabove;buffsOnTarget=b0;buffsOnTargetSide=sbelow;buildRowsAttached=b1;cardEdgeHUD=b1;cardPortraits=b1;clockContextAbove=b1;clockDetached=b0;combatTextBox=b1;combineTarget=b1;compassBosses=b1;compassCaches=b1;compassLairs=b1;compassOn=b1;compassStyle=srail;cooldowns=b1;elementModes.BuffFrame=senabled;elementModes.CharacterFrame=senabled;elementModes.ChatFrame1=senabled;elementModes.GameTooltip=senabled;elementModes.MainMenuBar=senabled;elementModes.MainMenuExpBar=senabled;elementModes.MinimapCluster=sdisabled;elementModes.PartyMemberFrame1=senabled;elementModes.PlayerFrame=senabled;elementModes.SlimSuiteAnnouncementFrame=senabled;elementModes.SlimSuiteBossFrames=senabled;elementModes.SlimSuiteClockFrame=sdisabled;elementModes.SlimSuiteCombatTextFrame=senabled;elementModes.SlimSuiteCompassFrame=senabled;elementModes.SlimSuiteLocalClockFrame=senabled;elementModes.SlimSuiteLuckFrame=sdisabled;elementModes.SlimSuiteMeterFrame=senabled;elementModes.SlimSuitePartyLines=senabled;elementModes.SlimSuitePlayerCard=senabled;elementModes.SlimSuiteReviveFrame=senabled;elementModes.SlimSuiteSpellRowFrame=sdisabled;elementModes.SlimSuiteItemRowFrame=sdisabled;elementModes.SlimSuiteStatCounterFrame=sdisabled;elementModes.SlimSuiteStoredLevelsButton=senabled;elementModes.SlimSuiteTallyFrame=senabled;elementModes.SlimSuiteTargetCard=senabled;elementModes.TalentFrame=senabled;elementModes.TargetFrame=senabled;encounterBarThickness=sthick;encounterDebuffs=b1;encounterMax=n5;encounterNameAlign=scenter;enemyBossesOnly=b0;enemyPlateDebuffs=b0;hideTarget=b0;luckPanel=b0;minimapBosses=b0;minimapCaches=b0;minimapLairs=b0;minimapTransparent=b0;mirrorTarget=b1;modernEnemyFrames=b1;moveLevelButton=b1;moveMeter=b1;orientations.PartyMemberFrame1=svertical;orientations.SlimSuiteBossFrames=svertical;partyFaces=b1;partyIncludesSelf=b0;partyLockAbove=b0;partyLocked=b0;partyLook=sthin;places.BuffFrame.coordinateSpace=suiParent;places.BuffFrame.screen.bottom=n0;places.BuffFrame.screen.height=n853.33;places.BuffFrame.screen.left=n0;places.BuffFrame.screen.width=n1280;places.BuffFrame.x=n277.78;places.BuffFrame.y=n149.3;places.CharacterFrame.coordinateSpace=suiParent;places.CharacterFrame.screen.bottom=n0;places.CharacterFrame.screen.height=n853.33;places.CharacterFrame.screen.left=n0;places.CharacterFrame.screen.width=n1280;places.CharacterFrame.x=n0;places.CharacterFrame.y=n188.74;places.ChatFrame1.coordinateSpace=suiParent;places.ChatFrame1.screen.bottom=n0;places.ChatFrame1.screen.height=n853.33;places.ChatFrame1.screen.left=n0;places.ChatFrame1.screen.width=n1280;places.ChatFrame1.x=n0;places.ChatFrame1.y=n782.54;places.GameTooltip.coordinateSpace=suiParent;places.GameTooltip.screen.bottom=n0;places.GameTooltip.screen.height=n853.33;places.GameTooltip.screen.left=n0;places.GameTooltip.screen.width=n1280;places.GameTooltip.x=n822.22;places.GameTooltip.y=n21.8;places.MainMenuBar.coordinateSpace=suiParent;places.MainMenuBar.screen.bottom=n0;places.MainMenuBar.screen.height=n853.33;places.MainMenuBar.screen.left=n0;places.MainMenuBar.screen.width=n1280;places.MainMenuBar.x=n448.22;places.MainMenuBar.y=n77.06;places.MainMenuExpBar.coordinateSpace=suiParent;places.MainMenuExpBar.screen.bottom=n0;places.MainMenuExpBar.screen.height=n853.33;places.MainMenuExpBar.screen.left=n0;places.MainMenuExpBar.screen.width=n1280;places.MainMenuExpBar.x=n0;places.MainMenuExpBar.y=n0;places.MinimapCluster.coordinateSpace=suiParent;places.MinimapCluster.screen.bottom=n0;places.MinimapCluster.screen.height=n853.33;places.MinimapCluster.screen.left=n0;places.MinimapCluster.screen.width=n1280;places.MinimapCluster.x=n587.54;places.MinimapCluster.y=n397.27;places.SlimSuiteAnnouncementFrame.coordinateSpace=suiParent;places.SlimSuiteAnnouncementFrame.screen.bottom=n0;places.SlimSuiteAnnouncementFrame.screen.height=n853.33;places.SlimSuiteAnnouncementFrame.screen.left=n0;places.SlimSuiteAnnouncementFrame.screen.width=n1280;places.SlimSuiteAnnouncementFrame.x=n314.86;places.SlimSuiteAnnouncementFrame.y=n702.42;places.SlimSuiteBossFrames.coordinateSpace=suiParent;places.SlimSuiteBossFrames.screen.bottom=n0;places.SlimSuiteBossFrames.screen.height=n853.33;places.SlimSuiteBossFrames.screen.left=n0;places.SlimSuiteBossFrames.screen.width=n1280;places.SlimSuiteBossFrames.x=n1098.45;places.SlimSuiteBossFrames.y=n647.25;places.SlimSuiteClockFrame.coordinateSpace=suiParent;places.SlimSuiteClockFrame.screen.bottom=n0;places.SlimSuiteClockFrame.screen.height=n853.33;places.SlimSuiteClockFrame.screen.left=n0;places.SlimSuiteClockFrame.screen.width=n1280;places.SlimSuiteClockFrame.x=n481.64;places.SlimSuiteClockFrame.y=n424.4;places.SlimSuiteCombatTextFrame.coordinateSpace=suiParent;places.SlimSuiteCombatTextFrame.screen.bottom=n0;places.SlimSuiteCombatTextFrame.screen.height=n853.33;places.SlimSuiteCombatTextFrame.screen.left=n0;places.SlimSuiteCombatTextFrame.screen.width=n1280;places.SlimSuiteCombatTextFrame.x=n1020;places.SlimSuiteCombatTextFrame.y=n296.62;places.SlimSuiteCompassFrame.coordinateSpace=suiParent;places.SlimSuiteCompassFrame.screen.bottom=n0;places.SlimSuiteCompassFrame.screen.height=n853.33;places.SlimSuiteCompassFrame.screen.left=n0;places.SlimSuiteCompassFrame.screen.width=n1280;places.SlimSuiteCompassFrame.x=n301.46;places.SlimSuiteCompassFrame.y=n743.33;places.SlimSuiteItemRowFrame.coordinateSpace=suiParent;places.SlimSuiteItemRowFrame.dx=n0;places.SlimSuiteItemRowFrame.dy=n-8;places.SlimSuiteItemRowFrame.point=sTOPLEFT;places.SlimSuiteItemRowFrame.relative=sSlimSuiteSpellRowFrame;places.SlimSuiteItemRowFrame.relativePoint=sBOTTOMLEFT;places.SlimSuiteLuckFrame.coordinateSpace=suiParent;places.SlimSuiteLuckFrame.screen.bottom=n0;places.SlimSuiteLuckFrame.screen.height=n853.33;places.SlimSuiteLuckFrame.screen.left=n0;places.SlimSuiteLuckFrame.screen.width=n1280;places.SlimSuiteLuckFrame.x=n531.41;places.SlimSuiteLuckFrame.y=n351.2;places.SlimSuiteMeterFrame.coordinateSpace=suiParent;places.SlimSuiteMeterFrame.screen.bottom=n0;places.SlimSuiteMeterFrame.screen.height=n853.33;places.SlimSuiteMeterFrame.screen.left=n0;places.SlimSuiteMeterFrame.screen.width=n1280;places.SlimSuiteMeterFrame.x=n1018.31;places.SlimSuiteMeterFrame.y=n106.67;places.SlimSuitePartyLines.coordinateSpace=suiParent;places.SlimSuitePartyLines.screen.bottom=n0;places.SlimSuitePartyLines.screen.height=n853.33;places.SlimSuitePartyLines.screen.left=n0;places.SlimSuitePartyLines.screen.width=n1280;places.SlimSuitePartyLines.x=n0;places.SlimSuitePartyLines.y=n209.88;places.SlimSuitePlayerCard.coordinateSpace=suiParent;places.SlimSuitePlayerCard.screen.bottom=n0;places.SlimSuitePlayerCard.screen.height=n853.33;places.SlimSuitePlayerCard.screen.left=n0;places.SlimSuitePlayerCard.screen.width=n1280;places.SlimSuitePlayerCard.x=n3.89;places.SlimSuitePlayerCard.y=n24.54;places.SlimSuiteReviveFrame.coordinateSpace=suiParent;places.SlimSuiteReviveFrame.screen.bottom=n0;places.SlimSuiteReviveFrame.screen.height=n853.33;places.SlimSuiteReviveFrame.screen.left=n0;places.SlimSuiteReviveFrame.screen.width=n1280;places.SlimSuiteReviveFrame.x=n70.54;places.SlimSuiteReviveFrame.y=n470.41;places.SlimSuiteSpellRowFrame.coordinateSpace=suiParent;places.SlimSuiteSpellRowFrame.screen.bottom=n0;places.SlimSuiteSpellRowFrame.screen.height=n853.33;places.SlimSuiteSpellRowFrame.screen.left=n0;places.SlimSuiteSpellRowFrame.screen.width=n1280;places.SlimSuiteSpellRowFrame.x=n455.11;places.SlimSuiteSpellRowFrame.y=n353.34;places.SlimSuiteStatCounterFrame.coordinateSpace=suiParent;places.SlimSuiteStatCounterFrame.screen.bottom=n0;places.SlimSuiteStatCounterFrame.screen.height=n853.33;places.SlimSuiteStatCounterFrame.screen.left=n0;places.SlimSuiteStatCounterFrame.screen.width=n1280;places.SlimSuiteStatCounterFrame.x=n549.78;places.SlimSuiteStatCounterFrame.y=n344.83;places.SlimSuiteStoredLevelsButton.coordinateSpace=suiParent;places.SlimSuiteStoredLevelsButton.screen.bottom=n0;places.SlimSuiteStoredLevelsButton.screen.height=n853.33;places.SlimSuiteStoredLevelsButton.screen.left=n0;places.SlimSuiteStoredLevelsButton.screen.width=n1280;places.SlimSuiteStoredLevelsButton.x=n852.7;places.SlimSuiteStoredLevelsButton.y=n140.48;places.SlimSuiteTallyFrame.coordinateSpace=suiParent;places.SlimSuiteTallyFrame.screen.bottom=n0;places.SlimSuiteTallyFrame.screen.height=n853.33;places.SlimSuiteTallyFrame.screen.left=n0;places.SlimSuiteTallyFrame.screen.width=n1280;places.SlimSuiteTallyFrame.x=n449.25;places.SlimSuiteTallyFrame.y=n22.11;places.SlimSuiteTargetCard.coordinateSpace=suiParent;places.SlimSuiteTargetCard.screen.bottom=n0;places.SlimSuiteTargetCard.screen.height=n853.33;places.SlimSuiteTargetCard.screen.left=n0;places.SlimSuiteTargetCard.screen.width=n1280;places.SlimSuiteTargetCard.x=n1078.14;places.SlimSuiteTargetCard.y=n24.54;plainBar=b1;playerLook=snew;procMeter=b0;replaceBanners=b1;replaceBuildRows=b1;replaceClock=b1;replaceEncounters=b1;replaceLocalClock=b1;replaceRevive=b1;replaceTally=b1;scales.ChatFrame1=n0.83;scales.MainMenuBar=n1.85;scales.MainMenuExpBar=n1;scales.SlimSuiteBossFrames=n1.85;scales.SlimSuiteCombatTextFrame=n1;scales.SlimSuiteMeterFrame=n1.6;scales.SlimSuitePartyLines=n2;scales.SlimSuitePlayerCard=n1.2;scales.SlimSuiteTallyFrame=n1.9;scales.SlimSuiteTargetCard=n1.2;showAbsorbs=b0;showEmptyActionSlots=b1;showGuardianFlag=b0;showRacialAbility=b1;sizes.ChatFrame1.h=n260;sizes.ChatFrame1.w=n450;sizes.MainMenuExpBar.h=n24;sizes.MainMenuExpBar.w=n1406.25;sizes.SlimSuiteCombatTextFrame.h=n220;sizes.SlimSuiteCombatTextFrame.w=n260;sizes.SlimSuiteCompassFrame.h=n110;sizes.SlimSuiteCompassFrame.w=n680;sizes.SlimSuitePartyLines.h=n182;sizes.SlimSuitePartyLines.w=n270;sizes.SlimSuiteTallyFrame.h=n39;sizes.SlimSuiteTallyFrame.w=n262.25;sizes.SlimSuiteTargetCard.h=n100;sizes.SlimSuiteTargetCard.w=n232;statCounter=b0;statDisplayMode=stotal;tallyBackground=b1;tallyBossKills=b1;tallyContext=b1;tallyVertical=b0;targetAuraSide=sabove;targetDebuffs=b1;targetLook=snew;worldCombatMode=soff;xpFullWidth=b1;zoneLine=b1" },
	-- { "Name", "One line about this design.", "SSL1;..." },
	-- { "Name", "One line about this design.", "SSL1;..." },
	-- { "Name", "One line about this design.", "SSL1;..." },
	-- { "Name", "One line about this design.", "SSL1;..." },
	-- { "Name", "One line about this design.", "SSL1;..." },
};

-- the size an element takes on screen at the design's scale
function SS.PresetElementSize(name, scale)
	local f = getglobal(name);
	return (f and f.GetWidth and f:GetWidth() or 100) * scale, (f and f.GetHeight and f:GetHeight() or 40) * scale;
end

-- a built-in design turned into a full layout for this screen: everything else goes back to the game's own place
function SS.BuildPresetLayout(spec)
	local layout = {};
	for _, key in ipairs(SS.LAYOUT_TABLES) do layout[key] = {}; end
	for k, v in pairs(spec.keys or {}) do layout[k] = v; end
	for k, v in pairs(spec.orientations or {}) do layout.orientations[k] = v; end
	for k, v in pairs(spec.scales or {}) do layout.scales[k] = v; end
	local sl, sr, sb, st = SS.ScreenBounds();
	local sw, sh = sr - sl, st - sb;
	-- x is measured across a centred 16:9 area, so on ultrawide screens the HUD stays together in the middle
	-- instead of stretching to the far edges; narrower screens use their full width
	local aw = math.min(sw, sh * 16 / 9);
	local al = sl + (sw - aw) / 2;
	local margin = 4;
	local placed = {};
	local function Clamp(r)
		r.x = math.max(sl + margin, math.min(sr - margin - r.w, r.x));
		r.y = math.max(sb + margin, math.min(st - margin - r.h, r.y));
	end
	local function Hits(r)
		for j = 1, table.getn(placed) do
			local o = placed[j];
			if ( r.x < o.x + o.w + margin and o.x < r.x + r.w + margin and r.y < o.y + o.h + margin and o.y < r.y + r.h + margin ) then return o; end
		end
	end
	-- the middle of the screen, where your hero fights
	local function Middle(c)
		return c.x < sl + sw / 2 + aw * 0.18 and sl + sw / 2 - aw * 0.18 < c.x + c.w and c.y < sb + sh * 0.7 and sb + sh * 0.3 < c.y + c.h;
	end
	-- the game's own frames that this design leaves where they are
	local moved = {};
	for _, at in ipairs(spec.places or {}) do moved[at[1]] = true; end
	for _, name in ipairs(spec.hide or {}) do moved[name] = true; end
	for _, res in ipairs(SS.PRESET_RESERVED) do
		if ( not moved[res[1]] ) then
			local w, h, dx, dy = res[2], res[3], res[5] or 0, res[6] or 0;
			local r = { name = res[1], w = w, h = h, reserved = true };
			if ( res[4] == "TOPRIGHT" ) then r.x, r.y = sr - w - dx, st - h - dy;
			elseif ( res[4] == "BOTTOMLEFT" ) then r.x, r.y = sl + dx, sb + dy;
			else r.x, r.y = sl + (sw - w) / 2, sb; end
			table.insert(placed, r);
		end
	end
	for k, v in pairs(spec.sizes or {}) do layout.sizes[k] = { w = v[1], h = v[2] }; end
	-- pinned elements first: { element, dx, dy, anchor = "TOPRIGHT" } holds that corner of the element to the same
	-- corner of the screen, dx, dy UI units in (so a frame that grows, like the encounter bars, grows away from it)
	for _, at in ipairs(spec.places or {}) do
		if ( at.anchor ) then
			local name, a = at[1], at.anchor;
			local w, h = SS.PresetElementSize(name, spec.scales and spec.scales[name] or 1);
			if ( spec.sizes and spec.sizes[name] ) then w, h = spec.sizes[name][1] * (spec.scales and spec.scales[name] or 1), spec.sizes[name][2] * (spec.scales and spec.scales[name] or 1); end
			if ( name == "MainMenuExpBar" and spec.keys and spec.keys.xpFullWidth ) then w = sr - sl; end
			local right, left = string.find(a, "RIGHT") ~= nil, string.find(a, "LEFT") ~= nil;
			local top, bottom = string.find(a, "TOP") ~= nil, string.find(a, "BOTTOM") ~= nil;
			local x = right and (sr + at[2] - w) or (left and (sl + at[2]) or ((sl + sr - w) / 2 + at[2]));
			local y = top and (st + at[3] - h) or (bottom and (sb + at[3]) or ((sb + st - h) / 2 + at[3]));
			local r = { name = name, w = w, h = h, pinned = true, x = x, y = y };
			table.insert(placed, r);
			layout.places[name] = { relative = "UIParent", point = a, relativePoint = a, dx = at[2], dy = at[3] };
			layout.elementModes[name] = "enabled";
		end
	end
	for _, at in ipairs(spec.places or {}) do if ( not at.anchor ) then
		local name = at[1];
		local w, h = SS.PresetElementSize(name, spec.scales and spec.scales[name] or 1);
		-- an element the design turns on its side takes its turned size
		local turn = spec.orientations and spec.orientations[name == "SlimSuitePartyLines" and "PartyMemberFrame1" or name];
		if ( name == "SlimSuitePartyLines" and SS.PARTY_LINE and turn ) then
			local L, sc = SS.PARTY_LINE, spec.scales and spec.scales[name] or 1;
			local slots = (spec.keys and spec.keys.partyIncludesSelf) and 5 or 4;
			if ( turn == "horizontal" ) then w, h = (slots * L.W + (slots - 1) * L.ROWGAP) * sc, L.H * sc;
			else w, h = L.W * sc, (slots * L.H + (slots - 1) * L.GAP) * sc; end
		elseif ( (turn == "vertical" and w > h) or (turn == "horizontal" and h > w) ) then w, h = h, w; end
		-- fromCentre: x is a distance in UI units from the middle of the screen (a pair that should sit close together)
		local cx = at.fromCentre and (sl + sw / 2 + at[2]) or (al + at[2] * aw);
		local r = { name = name, w = w, h = h, x = cx - w / 2, y = sb + at[3] * sh - h / 2 };
		Clamp(r);
		-- clear of anything more important: of the spots just past the obstacle (above, below, left, right), take the
		-- nearest one that is on screen and keeps out of the middle
		local wantX, wantY = r.x, r.y;
		local tries = 0;
		local o = Hits(r);
		while ( o and tries < 40 ) do
			tries = tries + 1;
			local best, bestCost;
			for _, c in ipairs({ { r.x, o.y + o.h + margin }, { r.x, o.y - r.h - margin }, { o.x - r.w - margin, r.y }, { o.x + o.w + margin, r.y } }) do
				local cand = { w = r.w, h = r.h, x = c[1], y = c[2] };
				if ( cand.x >= sl + margin and cand.x + cand.w <= sr - margin and cand.y >= sb + margin and cand.y + cand.h <= st - margin ) then
					local cost = math.abs(cand.x - wantX) + math.abs(cand.y - wantY) + (Middle(cand) and 100000 or 0);
					if ( not bestCost or cost < bestCost ) then best, bestCost = cand, cost; end
				end
			end
			if ( not best ) then break; end
			r.x, r.y = best.x, best.y;
			o = Hits(r);
		end
		table.insert(placed, r);
		layout.places[name] = { x = r.x, y = r.y, coordinateSpace = "uiParent", screen = { left = sl, bottom = sb, width = sw, height = sh } };
		layout.elementModes[name] = "enabled";
	end end
	for _, name in ipairs(spec.on or {}) do layout.elementModes[name] = "enabled"; end
	for _, name in ipairs(spec.off or {}) do layout.elementModes[name] = "default"; end
	for _, name in ipairs(spec.hide or {}) do layout.elementModes[name] = "disabled"; end
	-- every element the design does not mention is set to the game's own (Default), never left blank: a blank one was
	-- later read from old saved data as "on", so opening the setup turned a dozen elements back on by itself
	for name in pairs(SS.ELEMENTS) do
		if ( layout.elementModes[name] == nil ) then layout.elementModes[name] = "default"; end
	end
	return layout, placed;
end

local function Parse(text)
	if ( not SS.LayoutFromText ) then return nil; end
	local ok, layout = SS.Safe(SS.LayoutFromText, text);
	return ok and type(layout) == "table" and layout or nil;
end

-- the presets that are filled in and can be read, at most 5
-- Presets fill five numbered slots. An entry with slot = n takes that place; the rest fill the free places in order
-- (exported layouts first, then written-out designs). Empty slots are skipped, so the list has no gaps.
function SS.UsablePresets()
	local slots, loose = {}, {};
	local function Usable(p, builtin)
		if ( type(p) ~= "table" or type(p[1]) ~= "string" ) then return false; end
		if ( builtin ) then return type(p[3]) == "table"; end
		return type(p[3]) == "string" and p[3] ~= "" and Parse(p[3]) and true or false;
	end
	local function Add(p, builtin)
		if ( not Usable(p, builtin) ) then return; end
		local n = tonumber(p.slot);
		if ( n and n >= 1 and n <= 5 and not slots[n] ) then slots[n] = p; else table.insert(loose, p); end
	end
	for _, p in ipairs(SS.PRESETS or {}) do Add(p, false); end
	for _, p in ipairs(SS.BUILTIN_PRESETS or {}) do Add(p, true); end
	for n = 1, 5 do if ( not slots[n] and table.getn(loose) > 0 ) then slots[n] = table.remove(loose, 1); end end
	local out = {};
	for n = 1, 5 do
		local p = slots[n];
		if ( p ) then p.picture = "preset" .. n; table.insert(out, p); end   -- textures/quick/preset<n>.tga
	end
	return out;
end

function SS.ApplyPreset(p)
	if ( not p ) then return false; end
	local layout = type(p[3]) == "table" and SS.BuildPresetLayout(p[3]) or Parse(p[3]);
	if ( not layout ) then return false; end
	SS.LayoutApply(layout);
	if ( type(p[3]) == "table" ) then
		-- options a saved layout does not carry (party extras, compass, ...) are set as well, then drawn again
		local d = SS.DB();
		for k, v in pairs(p[3].keys or {}) do d[k] = v; end
		if ( PlaceAll ) then SS.Safe(PlaceAll); end
		for _, fn in ipairs({ SS.UpdateCompass, SS.UpdateLuck, SS.UpdateStats, SS.UpdateAchievementButton, SS.UpdateEnemyNameplates, SS.UpdatePartyStatus }) do
			if ( fn ) then SS.Safe(fn); end
		end
	end
	if ( type(p[3]) == "table" and p[3].style and SS.SetPanelStyle ) then SS.Safe(SS.SetPanelStyle, p[3].style); end
	if ( SS.LogAction ) then SS.LogAction("Preset design applied: " .. p[1]); end
	return true;
end
