-- Slim Suite: your buffs in the party, the minimap, Edit mode, the element menus and the tooltip.
if ( setfenv ) then setfenv(1, SS.ENV); end   -- Slim Suite's files share one set of private names (SS.ENV, in SlimSuiteCore.lua)

-- Buffs above the party plates (yours and your friends'): they line up with the plate's portrait and fill rows to
-- the right, each row stopping before the next party member's frame (or the plate's own right edge when the party is
-- a column). More buffs make more rows; the rows read top to bottom and the last row sits just above the plate.
local BUFF_BUTTONS = 24;
function SS.PartyBuffsActive()
	local d = SS.DB();
	return d.partyIncludesSelf and d.buffsOnPlayer and not d.buffsOnTarget and BuffFrame and true or false;
end
-- the room above a plate, in screen units: left edge (the portrait's), and how wide a row may be
function SS.BuffRoom(plate, portrait, nextFrame)
	local pl = (portrait and portrait:IsShown() and portrait:GetLeft()) or plate:GetLeft();
	if ( not pl ) then return nil; end
	local ps, ss = (portrait and SS.EffectiveScale(portrait)) or SS.EffectiveScale(plate), SS.EffectiveScale(plate);
	local left = pl * ps;
	local right = (plate:GetRight() or 0) * ss;
	-- the row ends where the plate's health and mana bars end (the art past them is not the plate's room)
	local name = plate.GetName and plate:GetName();
	if ( type(name) ~= "string" ) then name = nil; end
	local bar = plate.hp or (name and getglobal(name .. "HealthBar"));
	local mana = plate.mp or (name and getglobal(name .. "ManaBar"));
	local barRight = 0;
	for _, b in ipairs({ bar, mana }) do
		if ( b and b.GetRight and b:GetRight() ) then barRight = math.max(barRight, b:GetRight() * (SS.EffectiveScale(b))); end
	end
	if ( barRight > left ) then right = math.min(right, barRight); end
	if ( nextFrame and nextFrame:IsShown() and nextFrame:GetLeft() and SS.CurrentOrientation("PartyMemberFrame1") == "horizontal" ) then
		local nl = nextFrame:GetLeft() * (SS.EffectiveScale(nextFrame));
		if ( nl > left ) then right = nl - 4 * ss; end
	end
	return left, math.max(0, right - left), (plate:GetTop() or 0) * ss;
end
-- lays out a list of shown buttons (all the same size) above a plate, rows growing down, the last row on the plate
function SS.LayoutBuffRows(buttons, parent, plate, portrait, nextFrame)
	local left, width, top = SS.BuffRoom(plate, portrait, nextFrame);
	local n = table.getn(buttons);
	if ( not left or n == 0 ) then return; end
	local ps = SS.EffectiveScale(parent);
	local w, h = buttons[1]:GetWidth() or 16, buttons[1]:GetHeight() or 16;
	local gap = 2;
	local perRow = math.max(1, math.floor((width / ps + gap) / (w + gap)));
	local rows = math.ceil(n / perRow);
	local baseX, baseY = left / ps, top / ps + 2;
	for i = 1, n do
		local row = math.floor((i - 1) / perRow);                  -- 0 is the top row
		local col = math.mod(i - 1, perRow);
		local b = buttons[i];
		b:ClearAllPoints();
		b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", baseX + col * (w + gap), baseY + (rows - 1 - row) * (h + gap));
	end
end
function SS.LayoutPartyBuffs()
	if ( not BuffFrame ) then return; end
	local active = SS.PartyBuffsActive();
	if ( not active ) then
		if ( SS.partyBuffsLaid ) then
			SS.partyBuffsLaid = nil;
			for i = 0, BUFF_BUTTONS - 1 do
				local b = getglobal("BuffButton" .. i);
				local o = b and b.slimPartyOrig;
				if ( o ) then b.slimPartyOrig = nil; b:ClearAllPoints(); if ( o[2] ) then b:SetPoint(o[1], o[2], o[3], o[4], o[5]); end end
			end
		end
		return;
	end
	local P = SS.Pair();
	if ( not P ) then return; end
	local shown = {};
	for i = 0, BUFF_BUTTONS - 1 do
		local b = getglobal("BuffButton" .. i);
		if ( b ) then
			if ( not b.slimPartyOrig ) then local p, rel, rp, x, y = b:GetPoint(1); b.slimPartyOrig = { p, rel, rp, x or 0, y or 0 }; end
			if ( b:IsShown() ) then table.insert(shown, b); end
		end
	end
	local nextFrame = getglobal("PartyMemberFrame1");
	if ( nextFrame == P ) then nextFrame = nil; end
	SS.LayoutBuffRows(shown, BuffFrame, P, P.portrait, nextFrame);
	SS.partyBuffsLaid = true;
end
SS.Every("partyBuffs", 0.25, function() if ( SS.PartyBuffsActive() or SS.partyBuffsLaid ) then SS.Safe(SS.LayoutPartyBuffs); end end);

-- Your friends' buffs, above each friend's plate in the same way (classic plates only; "Party members' buffs" in the
-- party's menu). The icons are Slim Suite's own, read from UnitBuff; hover one for its name.
SS.FRIEND_BUFFS = 16;
function SS.FriendBuffsOn()
	local d = SS.DB();
	return d.partyMemberBuffs ~= false and SS.Look("PartyMemberFrame1") ~= "thin";
end
function SS.UpdateFriendBuffs()
	local on = SS.FriendBuffsOn();
	local size = SS.PartyBuffsActive() and BuffFrame and (getglobal("BuffButton0") or getglobal("BuffButton1")) or nil;
	local icon = 16;
	if ( size and size.GetHeight ) then icon = math.max(10, math.min(22, (size:GetHeight() or 30) * (BuffFrame:GetScale() or 1))); end
	SS.friendBuffs = SS.friendBuffs or {};
	for i = 1, 4 do
		local f = getglobal("PartyMemberFrame" .. i);
		local unit = "party" .. i;
		local set = SS.friendBuffs[i];
		if ( not set and f ) then
			set = {};
			for j = 1, SS.FRIEND_BUFFS do
				local b = CreateFrame("Button", nil, UIParent);
				b:SetFrameStrata("MEDIUM");
				b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints(b);
				b.unit, b.index = unit, j;
				b:SetScript("OnEnter", function()
					if ( GameTooltip and GameTooltip.SetUnitBuff ) then GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT"); GameTooltip:SetUnitBuff(this.unit, this.index); end
				end);
				b:SetScript("OnLeave", function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
				b:Hide();
				set[j] = b;
			end
			SS.friendBuffs[i] = set;
		end
		if ( set ) then
			local shown = {};
			local exists = on and f and f:IsShown() and UnitExists and UnitExists(unit);
			for j = 1, SS.FRIEND_BUFFS do
				local b = set[j];
				local tex = exists and UnitBuff and UnitBuff(unit, j);
				if ( tex ) then
					b.tex:SetTexture(tex); b:SetWidth(icon); b:SetHeight(icon); b:SetScale(SS.EffectiveScale(f) / SS.EffectiveScale(UIParent));
					b:Show(); table.insert(shown, b);
				else b:Hide(); end
			end
			if ( table.getn(shown) > 0 ) then
				SS.LayoutBuffRows(shown, shown[1], f, getglobal("PartyMemberFrame" .. i .. "Portrait"), getglobal("PartyMemberFrame" .. (i + 1)));
			end
		end
	end
end
SS.Every("friendBuffs", 0.5, function() SS.Safe(SS.UpdateFriendBuffs); end);

-- Every tick box that shows a setting, wherever it is: the setup, the right-click menu, the settings window, the move
-- panel. A click always flips the setting itself (not whatever the box happened to show), and afterwards every visible
-- box reads its setting again. One setting can be shown in two places, and turning one setting on can turn another off
-- (the newest choice wins); a box left showing the old value only set the value it already had when clicked, which
-- looked like the box did nothing.
SS.toggleBoxes = {};
function SS.TrackToggle(cb)
	table.insert(SS.toggleBoxes, cb);
	return cb;
end
function SS.FlipToggle(get, set)
	if ( type(get) ~= "function" or type(set) ~= "function" ) then return; end
	set(not (get() and true or false));
end
-- which rows of a page are shown right now, as a string; the page is only laid out again when this changes
function SS.PageSignature(page)
	local parts = {};
	for i = 1, table.getn(page.rows) do
		local r = page.rows[i];
		parts[i] = (not (r.up and not r.up())) and "1" or "0";
	end
	return table.concat(parts);
end

function SS.RefreshToggles()
	for i = 1, table.getn(SS.toggleBoxes) do
		local cb = SS.toggleBoxes[i];
		if ( cb.get and cb:IsVisible() ) then
			local ok, v = pcall(cb.get);
			if ( ok ) then cb:SetChecked(v and 1 or nil); end
			if ( cb.cond ) then
				local okc, c = pcall(cb.cond);
				if ( okc and not c ) then cb:Disable(); if ( cb.label ) then cb.label:SetTextColor(0.45, 0.45, 0.45); end
				else cb:Enable(); if ( cb.label ) then cb.label:SetTextColor(1, 1, 1); end end
			end
		end
	end
	if ( SS.RefreshChoices ) then SS.RefreshChoices(); end
	for i = 1, table.getn(SS.pages or {}) do
		local page = SS.pages[i];
		local sig = SS.PageSignature(page);
		if ( page.sig ~= sig ) then page.sig = sig; SS.LayoutPage(page); end
	end
end
-- the boxes are read again twice a second as well, for settings changed by a slash command or by the game
-- (only while one of those windows is open)
SS.Every("toggleRefresh", 0.5, function()
	local panel = getglobal("SlimSuiteSetupPanel");
	if ( (win and win:IsShown()) or (lockPanel and lockPanel:IsShown()) or (panel and panel:IsShown()) ) then SS.RefreshToggles(); end
end);

function SS.RefreshBuffControls()
	if ( SS.DB().unlocked ) then SS.SetUnlocked(true, true); end        -- shows or hides the buff frame's own handle
end

function SS.SetBuffsOnTarget(on)
	if ( on and SS.DB().buffsOnPlayer ) then SS.Notice("Buffs/Debuffs on the player frame turned off: your buffs are on the target frame now."); end
	SS.DB().buffsOnTarget = on and true or false;
	if ( on ) then SS.DB().buffsOnPlayer = false; SS.MakeMovable("BuffFrame", "they sit on the target frame"); end
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
	-- Mirroring is a combined custom layout. In the setup list, selecting it opts both unit
	-- frames into Slim Suite so a later Default-state pass cannot immediately undo it.
	if ( on and setupActive and SU and SU.SetMode ) then
		SU.SetMode("PlayerFrame", "enabled", SU.titles and SU.titles.PlayerFrame or "Unit frame");
		SU.SetMode("TargetFrame", "enabled", SU.titles and SU.titles.TargetFrame or "Target frame");
	end
	if ( on ) then SS.Safe(SS.ClaimTarget, "mirror"); end   -- the newest choice wins: mirroring takes the target's place
	if ( on ) then SS.MakeMovable("PlayerFrame", "Mirror target moves it"); SS.MakeMovable("TargetFrame", "Mirror target moves it"); end
	-- Mirroring and combining are one user-facing behavior: the target follows the player across the screen,
	-- and the pair uses the same frame appearance and size.
	SS.DB().mirrorTarget, SS.DB().combineTarget = on and true or false, on and true or false;
	SS.DB().mirrorSameScale = true;
	if ( on ) then SS.Safe(SS.MirrorTarget); SS.Safe(SS.OfferMirrorBuffs); end
	SS.Safe(SS.ApplyNewFrames);
	if ( SU and SU.Rebuild ) then SS.Safe(SU.Rebuild); end
end

-- "Square minimap": the minimap's mask is swapped between the round and the square texture. Some clients
-- have no mask API at all, so this is checked and reported rather than assumed.
-- the square mask is Slim Suite's own full-size white square: the game's tiny 8x8 white texture cuts the whole map out
SlimSuiteMinimapMask = { round = "Textures\\MinimapMask", square = "Interface\\AddOns\\SlimSuite\\textures\\MinimapSquare" };
function SS.ApplyMinimapShape()
	if ( not Minimap ) then return false; end
	-- Capture the round map's original appearance before the square/transparent options hide either border.
	SS.Safe(SS.ApplyMinimapTransparency);
	local square = SS.DB().minimapSquare and true or false;
	local ok = false;
	if ( Minimap.SetMaskTexture ) then
		ok = SS.Safe(Minimap.SetMaskTexture, Minimap, square and SlimSuiteMinimapMask.square or SlimSuiteMinimapMask.round);
	else
		ok = not square;                                      -- a round transparent map still works without mask support
	end
	SS.squareActive = square and ok and true or false;
	SS.Safe(SS.ArrangeEdgeButtons, square and ok);   -- the buttons follow the shape the map really has
	if ( MinimapBorder ) then if ( SS.squareActive or SS.DB().minimapTransparent ) then MinimapBorder:Hide(); else MinimapBorder:Show(); end end
	SS.Safe(SS.SquareFrame, square and ok);
	SS.Safe(SS.ApplyMinimapTransparency);
	if ( square and ok ) then SS.Safe(SS.ClockFollowsMap); end
	-- the map is only redrawn with its new shape when it changes zoom: step the zoom and back to force that
	if ( ok and Minimap.GetZoom and Minimap.SetZoom and Minimap.GetZoomLevels ) then
		local zoom, levels = Minimap:GetZoom(), Minimap:GetZoomLevels();
		local other = (zoom < levels - 1) and zoom + 1 or zoom - 1;
		if ( other >= 0 ) then SS.Safe(Minimap.SetZoom, Minimap, other); SS.Safe(Minimap.SetZoom, Minimap, zoom); end
	end
	return ok;
end

local minimapOriginalAlpha, minimapBorderWasShown, minimapBorderTopWasShown;
function SS.ApplyMinimapTransparency()
	if ( not Minimap ) then return; end
	if ( minimapOriginalAlpha == nil and Minimap.GetAlpha ) then minimapOriginalAlpha = Minimap:GetAlpha() or 1; end
	if ( minimapBorderWasShown == nil and MinimapBorder and MinimapBorder.IsShown ) then minimapBorderWasShown = MinimapBorder:IsShown(); end
	if ( minimapBorderTopWasShown == nil and MinimapBorderTop and MinimapBorderTop.IsShown ) then minimapBorderTopWasShown = MinimapBorderTop:IsShown(); end
	local transparent = SS.DB().minimapTransparent and true or false;
	if ( Minimap.SetAlpha ) then Minimap:SetAlpha(transparent and 0.58 or (minimapOriginalAlpha or 1)); end
	if ( MinimapBorder ) then
		if ( transparent or SS.squareActive ) then MinimapBorder:Hide();
		elseif ( minimapBorderWasShown ) then MinimapBorder:Show(); else MinimapBorder:Hide(); end
	end
	if ( MinimapBorderTop ) then
		if ( transparent or SS.squareActive ) then MinimapBorderTop:Hide();
		elseif ( minimapBorderTopWasShown ) then MinimapBorderTop:Show(); else MinimapBorderTop:Hide(); end
	end
	if ( SS.squareTitle ) then
		if ( SS.squareActive ) then SS.squareTitle:Show(); else SS.squareTitle:Hide(); end
		if ( SS.squareTitle.bg ) then if ( transparent ) then SS.squareTitle.bg:Hide(); else SS.squareTitle.bg:Show(); end end
		if ( SS.squareTitle.line ) then if ( transparent ) then SS.squareTitle.line:Hide(); else SS.squareTitle.line:Show(); end end
	end
	if ( SS.squareRing ) then if ( transparent or not SS.squareActive ) then SS.squareRing:Hide(); else SS.squareRing:Show(); end end
end

-- The square map's gold ring: a gold band like the round map's border, with a dark line on each side of it. The zone's
-- name sits on a small plate centred on its top edge, as the round map's name sits on its top.
function SS.SquareFrame(on)
	if ( not Minimap ) then return; end
	local ring = SS.squareRing;
	if ( on and not ring ) then
		ring = CreateFrame("Frame", "SlimSuiteSquareRing", Minimap);
		ring:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 2);
		ring:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -5, 5); ring:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 5, -5);
		local function Band(inset, width, r, g, b)
			local t = {};
			for i = 1, 4 do t[i] = ring:CreateTexture(nil, "OVERLAY"); t[i]:SetTexture(r, g, b, 1); end
			t[1]:SetPoint("TOPLEFT", ring, "TOPLEFT", inset, -inset); t[1]:SetPoint("TOPRIGHT", ring, "TOPRIGHT", -inset, -inset); t[1]:SetHeight(width);
			t[2]:SetPoint("BOTTOMLEFT", ring, "BOTTOMLEFT", inset, inset); t[2]:SetPoint("BOTTOMRIGHT", ring, "BOTTOMRIGHT", -inset, inset); t[2]:SetHeight(width);
			t[3]:SetPoint("TOPLEFT", ring, "TOPLEFT", inset, -inset); t[3]:SetPoint("BOTTOMLEFT", ring, "BOTTOMLEFT", inset, inset); t[3]:SetWidth(width);
			t[4]:SetPoint("TOPRIGHT", ring, "TOPRIGHT", -inset, -inset); t[4]:SetPoint("BOTTOMRIGHT", ring, "BOTTOMRIGHT", -inset, inset); t[4]:SetWidth(width);
		end
		-- the colours of the round map's own ring (measured from it): a dark rim, the worn gold, its lighter middle,
		-- a darker bronze inside it and a dark inner edge
		Band(0, 1, 0.12, 0.08, 0.02);
		Band(1, 3, 0.65, 0.51, 0.20);
		Band(2, 1, 0.73, 0.58, 0.24);
		Band(4, 1, 0.40, 0.34, 0.18);
		Band(5, 1, 0.12, 0.09, 0.03);
		-- the ring is part of the square map, not a setting of its own: it can only show while the map is square
		ring:SetScript("OnShow", function() if ( not SS.squareActive ) then this:Hide(); end end);
		SS.squareRing = ring;
	end
	if ( ring ) then if ( on and not SS.DB().minimapTransparent ) then ring:Show(); else ring:Hide(); end end
	-- A dedicated header keeps the zone name readable and puts a straight lower edge between its title and the square map.
	local title = SS.squareTitle;
	if ( on and not title ) then
		title = CreateFrame("Frame", "SlimSuiteSquareMapTitle", MinimapCluster or UIParent);
		title:SetFrameStrata("HIGH"); title:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 5);
		title:SetHeight(16); title:SetPoint("BOTTOMLEFT", Minimap, "TOPLEFT", 0, 0); title:SetPoint("BOTTOMRIGHT", Minimap, "TOPRIGHT", 0, 0);
		title.bg = title:CreateTexture(nil, "BACKGROUND"); title.bg:SetAllPoints(title); title.bg:SetTexture(0.02, 0.02, 0.03, 0.88);
		title.line = title:CreateTexture(nil, "BORDER"); title.line:SetTexture(0.72, 0.55, 0.2, 1);
		title.line:SetPoint("BOTTOMLEFT", title, "BOTTOMLEFT", 0, 0); title.line:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 0, 0); title.line:SetHeight(1);
		title.text = title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		title.text:SetPoint("LEFT", title, "LEFT", 4, 0); title.text:SetPoint("RIGHT", title, "RIGHT", -4, 0);
		title.text:SetJustifyH("CENTER"); title.text:SetTextColor(1, 0.82, 0.32);
		SS.squareTitle = title;
	end
	if ( title ) then if ( on ) then title:Show(); else title:Hide(); end end
	-- Keep the original zone label alive over the custom title, and restore its original anchor on return to round.
	local zone = MinimapZoneTextButton;
	if ( zone ) then
		if ( on ) then
			if ( not zone.slimSquareOrig ) then
				local p, rel, rp, x, y = zone:GetPoint(1); zone.slimSquareOrig = { p, rel, rp, x or 0, y or 0 };
				zone.slimSquareWasShown = not zone.IsShown or zone:IsShown();
				zone.slimSquareStrata, zone.slimSquareLevel = zone:GetFrameStrata(), zone:GetFrameLevel();
				zone.slimSquareAlpha = zone:GetAlpha() or 1;
			end
			zone:ClearAllPoints(); zone:SetPoint("TOPLEFT", title or Minimap, "TOPLEFT", 2, -1); zone:SetPoint("BOTTOMRIGHT", title or Minimap, "BOTTOMRIGHT", -2, 1);
			zone:SetFrameStrata("HIGH"); zone:SetFrameLevel((title and title:GetFrameLevel() or Minimap:GetFrameLevel() or 1) + 1);
			zone:SetAlpha(0);                               -- the custom title text is stable even when the native label glitches
			zone:Show();
			if ( MinimapBorderTop ) then
				MinimapBorderTop:Hide();
			end
		elseif ( zone.slimSquareOrig ) then
			local o = zone.slimSquareOrig; zone.slimSquareOrig = nil;
			zone:ClearAllPoints(); if ( o[2] ) then zone:SetPoint(o[1], o[2], o[3], o[4], o[5]); end
			if ( zone.slimSquareStrata ) then zone:SetFrameStrata(zone.slimSquareStrata); end
			if ( zone.slimSquareLevel ) then zone:SetFrameLevel(zone.slimSquareLevel); end
			zone:SetAlpha(zone.slimSquareAlpha or 1);
			if ( zone.slimSquareWasShown ) then zone:Show(); else zone:Hide(); end
			zone.slimSquareWasShown, zone.slimSquareStrata, zone.slimSquareLevel, zone.slimSquareAlpha = nil, nil, nil, nil;
		end
	end
end

-- The game's own clock is made for the round map in its first place. Once the map is square or has been moved,
-- Slim Suite's clock takes over (it hangs under the map wherever the map goes) so the two never clash.
function SS.ClockFollowsMap()
	local d = SS.DB();
	if ( d.replaceLocalClock ) then return; end
	SS.SetLocalClockOn(true);
	if ( SS.Notice ) then SS.Notice("Slim Suite's clock now replaces the game's, so it stays with the map."); end
end

-- With the square minimap, the buttons around it follow the square: the zoom buttons stand one above the other at
-- its right edge, and every other minimap button (the game's own, the day/night moon, other addons' and Slim Suite's
-- gear) lines up in a column down its left edge. Switching back to round puts each one back where it was.
-- Gathered buttons and the buttons in their own row are left to those layouts; the map's pins are never touched (they
-- have no name), and neither is the minimap's close button.
SS.SQUARE_KNOWN = { MinimapZoomIn = true, MinimapZoomOut = true, MinimapToggleButton = true, MiniMapWorldMapButton = true,
	WorldMapFrameMinimizeButton = true, GameTimeFrame = true, MiniMapTrackingFrame = true,
	MiniMapMailFrame = true, MiniMapBattlefieldFrame = true, MiniMapMeetingStoneFrame = true };
SS.SQUARE_SKIP = { MinimapPing = true };
-- true while the square layout places the buttons (the minimap buttons' "Around the minimap" choice)
function SS.SquareColumn()
	return SS.squareActive and SS.MinimapButtonPlace() == "ring";
end
function SS.ArrangeEdgeButtons(square)
	if ( not Minimap or not Minimap.GetCenter ) then return; end
	local mx, my = Minimap:GetCenter();
	if ( not mx ) then return; end
	local ms = SS.EffectiveScale(Minimap);
	local half = (Minimap:GetWidth() or 140) / 2;
	local halfH = (Minimap:GetHeight() or 140) / 2;
	local column = square and SS.MinimapButtonPlace() == "ring";
	local left, zoomIn, zoomOut = {}, nil, nil;
	for _, root in ipairs({ Minimap, MinimapCluster }) do
		local kids = { root:GetChildren() };
		for i = 1, table.getn(kids) do
			local f = kids[i];
			local name = f and f.GetName and f:GetName();
			if ( name and f ~= SS.Mini and f ~= Minimap and not f.slimOrig and not f.slimBarOrig and not SS.SQUARE_SKIP[name]
				and string.sub(name, 1, 9) ~= "SlimSuite" ) then
				local w, h = f:GetWidth() or 0, f:GetHeight() or 0;
				if ( w > 0 and w <= 40 and h > 0 and h <= 40 ) then
					if ( column ) then
						-- a button joins the layout once: the game's own by name, another addon's if it sits around the edge
						local member = f.slimSquareOrig ~= nil or SS.SQUARE_KNOWN[name];
						if ( not member ) then
							local fx, fy = f:GetCenter();
							if ( fx ) then
								local fs = SS.EffectiveScale(f);
								local dx, dy = fx * fs / ms - mx, fy * fs / ms - my;
								member = math.sqrt(dx * dx + dy * dy) >= half * 0.75;
							end
						end
						if ( member ) then
							if ( not f.slimSquareOrig ) then
								local p, rel, rp, x, y = f:GetPoint(1);
								f.slimSquareOrig = { p, rel, rp, x or 0, y or 0 };
								-- its place around the round ring, kept as an angle: on the square it sits on the ring at that angle
								local fx, fy = f:GetCenter();
								if ( fx ) then
									local fs = SS.EffectiveScale(f);
									f.slimSquareAngle = (math.atan2 or math.atan)(fy * fs / ms - my, fx * fs / ms - mx);
								end
							end
							if ( name == "MinimapZoomIn" ) then zoomIn = f;
							elseif ( name == "MinimapZoomOut" ) then zoomOut = f;
							else table.insert(left, f); end
						end
					elseif ( f.slimSquareOrig ) then
						local o = f.slimSquareOrig;
						f.slimSquareOrig = nil;
						f:ClearAllPoints();
						if ( o[2] ) then f:SetPoint(o[1], o[2], o[3], o[4], o[5]); end
					end
				end
			end
		end
	end
	if ( column ) then
		-- a button's offsets are in its own scale; sizes and places here are in the minimap's
		local function Put(f, x, y)
			local k = ms / (SS.EffectiveScale(f));
			f:ClearAllPoints();
			f:SetPoint("CENTER", Minimap, "CENTER", x * k, y * k);
		end
		local function Size(f)
			local k = ms / (SS.EffectiveScale(f));
			return (f:GetWidth() or 32) / k, (f:GetHeight() or 32) / k;
		end
		-- every button sits centred on the gold ring at the angle it had around the round map, as the round map does
		local function OnRing(f, angle)
			local x, y = math.cos(angle), math.sin(angle);
			local most = math.max(math.abs(x), math.abs(y));
			if ( most > 0 ) then x, y = x / most, y / most; end
			Put(f, x * (half + 3), y * (halfH + 3));
		end
		if ( zoomIn ) then table.insert(left, zoomIn); end
		if ( zoomOut ) then table.insert(left, zoomOut); end
		for i = 1, table.getn(left) do
			local f = left[i];
			local angle = f.slimSquareAngle;
			if ( not angle ) then angle = math.rad(150 + i * 20); end
			OnRing(f, angle);
		end
	end
	if ( SS.Mini and SS.Mini.Place ) then SS.Safe(SS.Mini.Place); end
end

-- buttons that appear later (new mail, a queue, another addon's button) join the square's column
SS.Every("squareEdge", 1, function()
	if ( SS.SquareColumn() ) then SS.ArrangeEdgeButtons(true); end
	if ( SS.squareActive and SS.squareTitle and SS.squareTitle.text ) then
		local mapName = type(GetRealZoneText) == "function" and GetRealZoneText() or nil;
		if ( type(mapName) ~= "string" or mapName == "" ) then mapName = type(GetZoneText) == "function" and GetZoneText() or ""; end
		SS.squareTitle.text:SetText(mapName or "");
	end
	-- the ring and the round border always match the map's real shape, whatever else showed or hid them
	local ring = SS.squareRing;
	if ( ring and ring:IsShown() and not SS.squareActive ) then ring:Hide(); end
	if ( ring and not ring:IsShown() and SS.squareActive ) then ring:Show(); end
	if ( MinimapBorder and SS.squareActive and MinimapBorder:IsShown() ) then MinimapBorder:Hide(); end
end);

-- The mouse wheel over the minimap zooms it, as the + and - buttons do.
function SS.MinimapWheel(delta)
	if ( not Minimap or not Minimap.GetZoom or not Minimap.SetZoom ) then return; end
	local zoom = Minimap:GetZoom() or 0;
	local levels = Minimap.GetZoomLevels and Minimap:GetZoomLevels() or 6;
	if ( delta > 0 and zoom < levels - 1 ) then
		if ( type(Minimap_ZoomInClick) == "function" ) then Minimap_ZoomInClick(); else Minimap:SetZoom(zoom + 1); end
	elseif ( delta < 0 and zoom > 0 ) then
		if ( type(Minimap_ZoomOutClick) == "function" ) then Minimap_ZoomOutClick(); else Minimap:SetZoom(zoom - 1); end
	end
end
if ( Minimap and Minimap.EnableMouseWheel and not Minimap:GetScript("OnMouseWheel") ) then
	Minimap:EnableMouseWheel(true);
	Minimap:SetScript("OnMouseWheel", function() SS.Safe(SS.MinimapWheel, arg1 or 0); end);
end

function SS.SetMinimapSquare(on)
	SS.DB().minimapSquare = on and true or false;
	if ( not SS.ApplyMinimapShape() ) then
		K.Print(NAME, "this client cannot change the minimap's shape.");
	end
end

function SS.SetMinimapTransparent(on)
	SS.DB().minimapTransparent = on and true or false;
	SS.Safe(SS.ApplyMinimapShape);
	SS.Safe(SS.ApplyMinimapTransparency);
end

-- "Same size scaling": the mirrored target copies the player frame's scale. Only meaningful while mirroring.
function SS.SetMirrorSameScale(on)
	-- Legacy saved value retained for migration; mirrored frames are always the same scale now.
	SS.DB().mirrorSameScale = true;
	if ( SS.DB().mirrorTarget ) then SS.Safe(SS.MirrorTarget); end
end

function SS.ApplyTallyLayout(resetSize)
	if ( not tallyFrame ) then return; end
	if ( resetSize ) then SS.DB().sizes.SlimSuiteTallyFrame = nil; end
	PlaceAll();
	SS.UpdateTally();
end

function SS.ToggleMovableOrientation(name)
	if ( name == "SlimSuiteItemRowFrame" or name == "SlimSuiteSpellRowFrame" ) then
		SS.SetBuildOrientation(name, SS.CurrentOrientation(name) ~= "vertical");
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
	-- the chat windows that stay docked (Combat Log, ...) open where the main window is now, not at its old place
	for i = 2, (NUM_CHAT_WINDOWS or 7) do
		local cf = getglobal("ChatFrame" .. i);
		if ( cf and cf.isDocked and cf.SetPoint ) then
			cf:ClearAllPoints();
			cf:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, 0);
			cf:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", 0, 0);
		end
	end
	-- the other chat tabs (Combat, Trade, ...) sit in a row beside the General tab, on the same line
	local general = SS.DB().chatOffsets["ChatFrame1Tab"];
	if ( type(general) == "table" and type(general.x) == "number" and type(general.y) == "number" ) then
		local x = general.x;
		local tab1 = getglobal("ChatFrame1Tab");
		x = x + (tab1 and tab1.GetWidth and (tab1:GetWidth() or 60) or 60) - 4;
		for i = 2, 7 do
			local tab = getglobal("ChatFrame" .. i .. "Tab");
			if ( tab and tab.SetPoint and tab.IsShown and tab:IsShown() ) then
				tab:ClearAllPoints();
				tab:SetPoint("BOTTOMLEFT", chat, "BOTTOMLEFT", x, general.y);
				x = x + (tab:GetWidth() or 60) - 4;
			end
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
	-- a new parent puts it at the bottom of the drawing order, under the bar's frame and gryphons: lift it above them
	local art = MainMenuBarArtFrame or MainMenuBar;
	if ( art and MainMenuExpBar.SetFrameStrata ) then
		MainMenuExpBar:SetFrameStrata(art:GetFrameStrata() or "MEDIUM");
		MainMenuExpBar:SetFrameLevel((art:GetFrameLevel() or 1) + 5);
	end
	xpBarDetached = true;
end

-- Vertical or horizontal for a build row (spells or worn jewelry). Joined, the two rows turn together (a column of
-- spells with the jewelry column beside it); split, each turns on its own. A row takes its own size for the new way.
function SS.SetBuildOrientation(name, vertical)
	local rows = SS.DB().buildRowsAttached and { "SlimSuiteSpellRowFrame", "SlimSuiteItemRowFrame" } or { name };
	for i = 1, table.getn(rows) do
		SS.DB().orientations[rows[i]] = vertical and "vertical" or "horizontal";
		SS.DB().sizes[rows[i]] = nil;
	end
	SS.LayoutSpellRow(); SS.LayoutItemRow();
	if ( SS.DB().buildRowsAttached ) then SS.DB().places.SlimSuiteItemRowFrame = SS.BuildRowDefaultPlace("SlimSuiteItemRowFrame"); end
	SS.Safe(PlaceAll);
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
end

-- The size & layout tools of an element's menu: width, height, scale, layout (for the elements with no layout setting
-- of their own), buff growth, padding, hide, the clock's daylight saving and Reset. Built once, set up for the element,
-- and shown as a section of the element's menu (SU.Focus) under its settings. Only the rows the element uses are
-- shown, one under the other with no gaps. Returns false when the element has no frame yet.
function SS.PrepareSizeTools(name, label)
	name = SS.Element(name);
	local f = getglobal(SS.Shown(name));
	if ( not f ) then return false; end
	if ( not sizeMenu ) then
		sizeMenu = CreateFrame("Frame", nil, UIParent);
		sizeMenu:SetWidth(206); sizeMenu:SetHeight(120);
		sizeMenu:SetFrameStrata("DIALOG");
		sizeMenu.rows = {};
		-- a row is the things on one line: each { thing, its corner, x, y from the row's top }
		local function Row(key, parts)
			local row = { parts = parts };
			sizeMenu.rows[key] = row;
			table.insert(sizeMenu.rows, row);
			return row;
		end
		local function Label()
			return sizeMenu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		end
		-- the mouse wheel over a row's label or its - and + does what the buttons do
		local function WheelPair(down, up)
			local zone = CreateFrame("Frame", nil, sizeMenu);
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
		local function ShowSize()
			local t = sizeTarget and getglobal(sizeTarget);
			if ( not t ) then return; end
			sizeMenuWidth:SetText("Width: " .. math.floor((t:GetWidth() or 0) + 0.5));
			sizeMenuHeight:SetText("Height: " .. math.floor((t:GetHeight() or 0) + 0.5));
		end
		sizeMenu.ShowSize = ShowSize;
		sizeMenuText = sizeMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		sizeMenuText:SetPoint("TOPLEFT", sizeMenu, "TOPLEFT", 12, -6);
		sizeMenuText:SetText("Size & layout");
		local function ResizeBy(axis, delta)
			if ( not sizeTarget ) then return; end
			local t = getglobal(sizeTarget);
			if ( not t ) then return; end
			local w, h = t:GetWidth(), t:GetHeight();
			local scaleRatio = RootFactor(t);
			if ( not scaleRatio or scaleRatio <= 0 ) then scaleRatio = 1; end
			if ( axis == "w" ) then
				local minWidth = SS.MinSize(sizeTarget);
				w = math.max(minWidth, math.min((UIParent:GetWidth() or 1920) / scaleRatio, w + delta));
			else
				local _, minHeight = SS.MinSize(sizeTarget);
				h = math.max(minHeight, math.min((UIParent:GetHeight() or 1080) / scaleRatio, h + delta));
			end
			t:SetWidth(w); t:SetHeight(h);
			if ( sizeTarget == "MainMenuBar" ) then
				-- the bar is its buttons: six (seven with the racial), 2 apart (the racial 4 further)
				local vertical = SS.CurrentOrientation(sizeTarget) == "vertical";
				local count = SS.DB().showRacialAbility and 7 or 6;
				local gaps = 2 * (count - 1) + (SS.DB().showRacialAbility and 4 or 0);
				local side = (axis == "w") and (vertical and w or (w - gaps) / count) or (vertical and (h - gaps) / count or h);
				local maxLong = (vertical and UIParent:GetHeight() or UIParent:GetWidth()) / scaleRatio;
				local maxShort = (vertical and UIParent:GetWidth() or UIParent:GetHeight()) / scaleRatio;
				side = math.max(12, math.min(side, (maxLong - gaps) / count, maxShort));
				w, h = vertical and side or side * count + gaps, vertical and side * count + gaps or side;
				t:SetWidth(w); t:SetHeight(h);
			end
			if ( sizeTarget == "BuffFrame" ) then SS.DB().buffCustomLayout = true; end   -- the icons follow the size
			SS.DB().sizes[sizeTarget] = { w = w, h = h };
			if ( sizeTarget == "GameTooltip" ) then SS.DB().tooltipCustom = true; end
			if ( sizeTarget == "BuffFrame" ) then SS.Safe(SS.ApplyBuffOrientation); end
			if ( sizeTarget == "SlimSuiteClockFrame" ) then SS.ApplyClockLayout(); end
			if ( SS.Element(sizeTarget) == "TargetFrame" ) then SS.Safe(SS.MirrorPlayer); end
			PlaceAll();
			ShowSize();
		end
		sizeMenuWidth = Label();
		local narrower = K.Button(sizeMenu, "-", 30, function() ResizeBy("w", -20); end);
		local wider = K.Button(sizeMenu, "+", 30, function() ResizeBy("w", 20); end);
		Row("width", { { WheelPair(narrower, wider), "TOPLEFT", 10, 0 }, { sizeMenuWidth, "TOPLEFT", 12, -8 }, { narrower, "TOPRIGHT", -72, 0 }, { wider, "TOPRIGHT", -32, 0 } });
		sizeMenuHeight = Label();
		local shorter = K.Button(sizeMenu, "-", 30, function() ResizeBy("h", -20); end);
		local taller = K.Button(sizeMenu, "+", 30, function() ResizeBy("h", 20); end);
		Row("height", { { WheelPair(shorter, taller), "TOPLEFT", 10, 0 }, { sizeMenuHeight, "TOPLEFT", 12, -8 }, { shorter, "TOPRIGHT", -72, 0 }, { taller, "TOPRIGHT", -32, 0 } });
		sizeMenuScale = Label();
		sizeMenuScale:SetText("Scale %:");
		sizeMenuScaleInput = CreateFrame("EditBox", nil, sizeMenu);
		sizeMenuScaleInput:SetWidth(46); sizeMenuScaleInput:SetHeight(20);
		sizeMenuScaleInput:SetAutoFocus(false); sizeMenuScaleInput:SetNumeric(true);
		sizeMenuScaleInput:SetJustifyH("CENTER"); sizeMenuScaleInput:SetMaxLetters(3);
		sizeMenuScaleInput:SetFontObject(GameFontHighlightSmall);
		sizeMenuScaleInput:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } });
		sizeMenuScaleInput:SetBackdropColor(0.02, 0.02, 0.03, 0.95);
		sizeMenuScaleInput:SetBackdropBorderColor(0.55, 0.43, 0.2, 1);
		local function SetScalePercent(percent)
			if ( not sizeTarget ) then return; end
			percent = math.max(20, math.min(200, math.floor(tonumber(percent) or 100)));   -- never so small it disappears
			SS.DB().scales[sizeTarget] = percent / 100;
			if ( SS.Element(sizeTarget) == "TargetFrame" ) then SS.Safe(SS.MirrorPlayer); end
			PlaceAll();
			sizeMenuScaleInput:SetText(tostring(percent));
		end
		local function ScaleNow() return math.floor((SS.DB().scales[sizeTarget] or 1) * 100 + 0.5); end
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
			this:SetText(tostring(ScaleNow()));
		end);
		local scaleDown = K.Button(sizeMenu, "-", 30, function() SetScalePercent(ScaleNow() - 5); end);
		local scaleUp = K.Button(sizeMenu, "+", 30, function() SetScalePercent(ScaleNow() + 5); end);
		Row("scale", { { WheelPair(scaleDown, scaleUp), "TOPLEFT", 10, 0 }, { sizeMenuScale, "TOPLEFT", 12, -8 }, { sizeMenuScaleInput, "TOPLEFT", 58, -1 },
			{ scaleDown, "TOPRIGHT", -72, 0 }, { scaleUp, "TOPRIGHT", -32, 0 } });
		-- vertical or horizontal, for the elements that have no layout setting among their own settings above
		local layout = K.Button(sizeMenu, "Switch to vertical", 116, function()
			if ( not sizeTarget ) then return; end
			SS.ToggleMovableOrientation(SS.Element(sizeTarget));
			ShowSize();
			sizeMenu.LayoutText();
		end);
		sizeMenu.layoutButton = layout;
		sizeMenu.LayoutText = function()
			local el = SS.Element(sizeTarget);
			local orientation = el == "SlimSuiteTallyFrame" and (SS.DB().tallyVertical and "vertical" or "horizontal") or SS.CurrentOrientation(el);
			layout:SetText(orientation == "vertical" and "Switch to horizontal" or "Switch to vertical");
		end;
		local growth;
		growth = K.Button(sizeMenu, "Grow down", 68, function()
			if ( sizeTarget ~= "BuffFrame" ) then return; end
			SS.DB().buffCustomLayout = true;
			SS.DB().buffGrowthDirection = SS.BuffGrowthDirection() == "up" and "down" or "up";
			growth:SetText("Grow " .. SS.BuffGrowthDirection());
			SS.Safe(SS.ApplyBuffOrientation);
			PlaceAll();
		end);
		sizeMenu.growthButton = growth;
		Row("layout", { { layout, "TOPLEFT", 10, 0 }, { growth, "TOPRIGHT", -10, 0 } });
		sizeMenuPadding = Label();
		local function Pad(by)
			if ( not sizeTarget ) then return; end
			SS.DB().padding[sizeTarget] = math.max(0, math.min(SS.FramePaddingLimit(sizeTarget), SS.FramePadding(sizeTarget) + by));
			SS.ApplyMovablePadding(sizeTarget);
			sizeMenuPadding:SetText("Padding: " .. SS.FramePadding(sizeTarget));
			ShowSize();
		end
		local padDown = K.Button(sizeMenu, "-", 30, function() Pad(-2); end);
		local padUp = K.Button(sizeMenu, "+", 30, function() Pad(2); end);
		Row("padding", { { WheelPair(padDown, padUp), "TOPLEFT", 10, 0 }, { sizeMenuPadding, "TOPLEFT", 12, -8 }, { padDown, "TOPRIGHT", -72, 0 }, { padUp, "TOPRIGHT", -32, 0 } });
		-- the local clock's hour for daylight saving: automatic -> forced on (+1 hour) -> forced off -> automatic
		sizeMenu.clockDst = K.Button(sizeMenu, "Daylight saving: auto", 184, function()
			local dst = SS.DB().localClockDST;
			if ( dst == nil ) then SS.DB().localClockDST = 1;
			elseif ( dst == 1 ) then SS.DB().localClockDST = 0;
			else SS.DB().localClockDST = nil; end
			if ( SlimSuiteWorld and SlimSuiteWorld.UpdateLocalClock ) then SlimSuiteWorld.UpdateLocalClock(); end
			sizeMenu.ClockLabels();
		end);
		sizeMenu.ClockLabels = function()
			local d = SS.DB();
			-- automatic unless set by hand; the text says what the clock is doing now
			local now = SlimSuiteWorld and SlimSuiteWorld.DaylightOffset and SlimSuiteWorld.DaylightOffset() or 0;
			if ( d.localClockDST == nil ) then
				sizeMenu.clockDst:SetText("Daylight saving: auto (" .. (now > 0 and "on" or "off") .. ")");
			else
				local dst = tonumber(d.localClockDST) or 0;
				sizeMenu.clockDst:SetText("Daylight saving: " .. (dst > 0 and "+1 hour" or (dst < 0 and "-1 hour" or "off")));
			end
		end;
		Row("dst", { { sizeMenu.clockDst, "TOPLEFT", 10, 0 } });
		local muteButton = K.Button(sizeMenu, "Hide feature", 112, function()
			if ( sizeTarget ) then SS.ToggleFeatureMute(sizeTarget); end
		end);
		sizeMenu.muteButton = muteButton;
		local reset = K.Button(sizeMenu, "Reset", 62, function()
			if ( not SS.ResetElement(sizeTarget) ) then
				K.Print(NAME, "the original size is not available yet; try again after the frame appears.");
				return;
			end
			SS.OpenSizeMenu(sizeMenu.element or sizeTarget, sizeMenu.label);
		end);
		Row("last", { { muteButton, "TOPLEFT", 10, 0 }, { reset, "TOPRIGHT", -10, 0 } });
	end
	sizeTarget = SS.Shown(name);
	sizeMenu.element, sizeMenu.label = name, label;
	sizeMenu.ShowSize();
	-- the classic player, target and party frames' and the minimap's artwork has a fixed size: width and height would
	-- only change the area you can click, so they are resized with Scale alone (the new-school cards keep all three)
	local fixedArt = sizeTarget == "PlayerFrame" or sizeTarget == "TargetFrame" or sizeTarget == "PartyMemberFrame1"
		or sizeTarget == "MinimapCluster" or sizeTarget == "SlimSuiteMinimapBar";
	local rows = sizeMenu.rows;
	rows.width.on, rows.height.on = not fixedArt, not fixedArt and name ~= "GameTooltip";   -- a tooltip is as tall as its text
	rows.scale.on, rows.last.on = true, true;
	sizeMenuScaleInput:SetText(tostring(math.max(20, math.min(200, math.floor((SS.DB().scales[sizeTarget] or 1) * 100 + 0.5)))));
	-- the other elements that turn have "vertical" among their settings, so it is not offered twice
	rows.layout.on = name == "SlimSuiteTallyFrame" or name == "SlimSuiteClockFrame" or name == "BuffFrame";
	if ( rows.layout.on ) then sizeMenu.LayoutText(); end
	sizeMenu.growthButton.wanted = name == "BuffFrame";
	if ( name == "BuffFrame" ) then sizeMenu.growthButton:SetText("Grow " .. SS.BuffGrowthDirection()); end
	rows.padding.on = name == "SlimSuiteClockFrame" or name == "SlimSuiteBossFrames" or name == "SlimSuiteTallyFrame"
		or name == "SlimSuiteAnnouncementFrame" or name == "BuffFrame";
	if ( rows.padding.on ) then sizeMenuPadding:SetText("Padding: " .. SS.FramePadding(name)); end
	rows.dst.on = name == "SlimSuiteLocalClockFrame";
	if ( rows.dst.on ) then sizeMenu.ClockLabels(); end
	sizeMenu.muteButton:SetText(SS.DB().muted[sizeTarget] and "Show feature" or "Hide feature");
	-- the rows in use, one under the other
	local y = -24;
	for i = 1, table.getn(rows) do
		local row = rows[i];
		for k = 1, table.getn(row.parts) do
			local p = row.parts[k];
			local thing = p[1];
			if ( row.on and thing.wanted ~= false ) then
				thing:ClearAllPoints();
				thing:SetPoint(p[2], sizeMenu, p[2], p[3], y + p[4]);
				thing:Show();
			else
				thing:Hide();
			end
		end
		if ( row.on ) then y = y - 27; end
	end
	sizeMenu:SetHeight(-y + 2);
	SS.sizeMenuName = name;
	return true;
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
		note:SetText("Drag to move. Right-click for its settings, size and layout. Shift-left-click also hides/shows.");
		local gridCheck = CreateFrame("CheckButton", nil, lockPanel, "UICheckButtonTemplate");
		gridCheck:SetPoint("TOPLEFT", lockPanel, "TOPLEFT", 6, -52); gridCheck:SetWidth(22); gridCheck:SetHeight(22);
		gridCheck:SetScript("OnShow", function() this:SetChecked(SS.DB().showEditGrid and 1 or nil); end);
		gridCheck.get = function() return SS.DB().showEditGrid; end;
		SS.TrackToggle(gridCheck);
		gridCheck:SetScript("OnClick", function() SS.DB().showEditGrid = not SS.DB().showEditGrid; if ( SS.DB().unlocked ) then ShowEditGrid(); end SS.RefreshToggles(); end);
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
			cb.get = function() return SS.DB()[key]; end;
			SS.TrackToggle(cb);
			cb:SetScript("OnClick", function() SS.DB()[key] = not SS.DB()[key]; if ( SS.DB().unlocked ) then ShowEditGrid(); end SS.RefreshToggles(); end);
			local label = lockPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
			label:SetPoint("LEFT", cb, "RIGHT", 0, 0); label:SetText(labelText);
		end
		AddGridLineToggle(8, "gridCenterVertical", "Vertical red center line");
		AddGridLineToggle(184, "gridCenterHorizontal", "Horizontal red center line");
		local snap = CreateFrame("CheckButton", nil, lockPanel, "UICheckButtonTemplate");
		snap:SetPoint("TOPLEFT", lockPanel, "TOPLEFT", 6, -111); snap:SetWidth(22); snap:SetHeight(22);
		snap:SetScript("OnShow", function() this:SetChecked(SS.DB().anchorSnap and 1 or nil); end);
		snap.get = function() return SS.DB().anchorSnap; end;
		SS.TrackToggle(snap);
		snap:SetScript("OnClick", function() SetAnchorSnap(not SS.DB().anchorSnap); SS.RefreshToggles(); end);
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
		choices:SetPoint("TOPLEFT", choose, "BOTTOMLEFT", 0, -2);
		if ( choices.SetClampedToScreen ) then choices:SetClampedToScreen(true); end
		choices:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12});
		choices:SetBackdropColor(0.04, 0.035, 0.07, 1);
		-- one row per element: the new-school cards and the thin party lines are their element's own row (the frame that
		-- shows it now is the one chosen)
		local count = 0;
		for i = 1, table.getn(MOVABLE) do
			local name, label = MOVABLE[i][1], MOVABLE[i][2];
			if ( SS.Element(name) == name ) then
				local row = K.Button(choices, label, 208, function()
					editOnly = SS.Shown(name); choose:SetText(label .. " ▼"); all:UnlockHighlight(); choices:Hide();
					SS.HideElementMenu();
					SS.SetUnlocked(true, true);
				end);
				row:SetPoint("TOPLEFT", choices, "TOPLEFT", 4, -4 - count * 23);
				count = count + 1;
			end
		end
		choices:SetHeight(count * 23 + 8);
		choices:Hide();
		choose:SetScript("OnClick", function() if ( choices:IsShown() ) then choices:Hide(); else choices:Show(); end end);
		all = K.Button(lockPanel, "ALL?", 62, function()
			editOnly = nil; choose:SetText("Choose element ▼"); all:LockHighlight(); choices:Hide();
			SS.HideElementMenu();
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
		editGrid:SetFrameStrata("HIGH");
		editGrid:EnableMouse(false);
		editGrid:SetScript("OnSizeChanged", function()
			if ( SS.DB().showEditGrid and SS.DB().unlocked ) then ShowEditGrid(); end
		end);
	end
	local left, right, bottom, top = SS.ScreenBounds();
	local width, height = right - left, top - bottom;
	editGrid:ClearAllPoints();
	editGrid:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom);
	editGrid:SetWidth(width); editGrid:SetHeight(height);
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

-- the frame a handle sits on: its outline follows the frame (the tooltip handle also keeps itself on top)
function SS.FollowHandle(h, name)
	local t = getglobal(name);
	if ( not t ) then return; end
	if ( name == "GameTooltip" and t:IsShown() ) then
		h:SetFrameStrata("TOOLTIP");
		if ( h:GetFrameLevel() <= t:GetFrameLevel() ) then h:SetFrameLevel(t:GetFrameLevel() + 1); end
	end
	local l, r, b, top = RootBounds(t);
	if ( l and b ) then
		-- measuring what a frame shows looks at all its parts: done when the frame moves or changes size, and otherwise
		-- twice a second (its parts can change on their own)
		local now = GetTime and GetTime() or 0;
		if ( h.followL == l and h.followR == r and h.followB == b and h.followT == top and now - (h.followAt or 0) < 0.5 and now >= (h.followAt or 0) ) then return; end
		h.followL, h.followR, h.followB, h.followT, h.followAt = l, r, b, top, now;
		local x1, y1, x2, y2 = VisualInsets(t);
		h:ClearAllPoints();
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
	local scale = SS.EffectiveScale(UIParent);
	local x, y = GetCursorPosition(); x, y = x / scale, y / scale;
	local deltaX, deltaY = x - h.dragStartX, y - h.dragStartY;
	local nextX, nextY = h.frameStartX + deltaX, h.frameStartY + deltaY;
	local moved = getglobal(h.mover or name) or t;
	nextX, nextY = SS.ClampPosition(moved, nextX, nextY);
	SetRootPosition(moved, nextX, nextY);
	SS.SavePlace(h.mover or name, moved);          -- keep the newest location even if /reload happens mid-session
	-- mirrored frames move together: drag either one and the other moves the opposite way
	if ( SS.DB().mirrorTarget ) then
		local element = SS.Element(h.mover or name);
		if ( element == "PlayerFrame" ) then SS.MirrorTarget();
		elseif ( element == "TargetFrame" ) then SS.MirrorPlayer(); end
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
				if ( type(size) ~= "table" ) then size = { w = 260, h = 140 }; end
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
		if ( SS.QUIET_HANDLES[name] ) then
			-- the player and target frames are previewed as they really look: no green box over them, just a faint
			-- outline and the name while the mouse is over the frame (it still drags and right-clicks as before)
			h.quiet = true;
			h:SetBackdropColor(0, 0, 0, 0); h:SetBackdropBorderColor(0.3, 1, 0.3, 0); h.text:Hide();
			h:SetScript("OnEnter", function() this:SetBackdropBorderColor(0.3, 1, 0.3, 0.7); this.text:Show(); end);
			h:SetScript("OnLeave", function() this:SetBackdropBorderColor(0.3, 1, 0.3, 0); this.text:Hide(); end);
		end
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
			if ( (name == "BuffFrame" or name == "MainMenuBar" or name == "MinimapCluster" or name == "PartyMemberFrame1") and t.SetUserPlaced ) then SS.UserPlace(t); end
			local scale = SS.EffectiveScale(UIParent);
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

-- one shared follower keeps every shown handle on its frame, 20 times a second (the one being dragged follows every
-- frame, from its own drag step)
SS.Every("handleFollow", 0.05, function()
	for i = 1, table.getn(handleList) do
		local h = handleList[i];
		if ( h:IsShown() ) then SS.FollowHandle(h, h.handleName); end
	end
end);

-- unlocked: the handles show (the frames are shown too, so even an empty party frame can be placed)
-- Which movable frames are switched off right now (false): a feature turned off, or the design not in use (the
-- classic player/target frames while the new-school cards are on, and the other way round). Anything not listed is on.
function SS.AvailableElements()
	local d = SS.DB();
	local off = {
		SlimSuiteStoredLevelsButton = d.moveLevelButton, SlimSuiteSpellRowFrame = d.replaceBuildRows, SlimSuiteItemRowFrame = d.replaceBuildRows,
		SlimSuiteMeterFrame = d.moveMeter, SlimSuiteClockFrame = d.replaceClock, SlimSuiteBossFrames = d.replaceEncounters,
		SlimSuiteTallyFrame = d.replaceTally, SlimSuiteAnnouncementFrame = d.replaceBanners, SlimSuiteReviveFrame = d.replaceRevive,
		SlimSuiteLocalClockFrame = d.replaceLocalClock and d.clockDetached, SlimSuiteCombatTextFrame = d.combatTextBox and true or false, SlimSuiteMinimapBar = d.minimapBar and true or false,
		TargetFrame = not d.hideTarget and not SS.UsesCard("TargetFrame"), PlayerFrame = not SS.UsesCard("PlayerFrame") and not d.partyIncludesSelf,
		SlimSuitePlayerCard = SS.UsesCard("PlayerFrame"), SlimSuiteTargetCard = SS.UsesCard("TargetFrame") and not d.hideTarget,
		PartyMemberFrame1 = SS.Look("PartyMemberFrame1") ~= "thin", SlimSuitePartyLines = SS.Look("PartyMemberFrame1") == "thin",
	};
	local out = {};
	for name, isOn in pairs(off) do out[name] = isOn and true or false; end
	return out;
end

-- whether a frame may have a handle now: not left to the game's own layout, its design in use, not joined to a unit frame
function SS.HandleAllowed(name, available)
	local d = SS.DB();
	if ( d.frameDefault and d.frameDefault[name] ) then return false; end
	if ( (available or SS.AvailableElements())[name] == false ) then return false; end
	if ( name == "BuffFrame" and (d.buffsOnTarget or d.buffsOnPlayer) ) then return false; end
	return true;
end

function SS.SetUnlocked(on, quiet)
	-- The first time the mover is opened, the setup walks through the UI one element at a time instead.
	-- After that it opens Edit mode (every handle, and the move panel with "Run setup again").
	-- Edit mode is the element list: every element, Enabled or Disabled, the grid on top and Done at the bottom.
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
		if ( type(size) ~= "table" ) then size = { w = 260, h = 140 }; end
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
	if ( not on ) then SS.HideElementMenu(); end
	if ( not on ) then SS.Safe(SS.EndPreviewsIfDone); end   -- the sample party and target go when nothing previews them
	if ( on ) then
		-- Leave the settings/menu window before presenting the in-world mover and its Done control.
		if ( win ) then win:Hide(); end
		if ( lockPanel ) then lockPanel:Hide(); end   -- the old move panel is gone: the element list replaces it
	elseif ( lockPanel ) then
		lockPanel:Hide();
	end
	if ( on ) then ShowEditGrid(); else SS.HideEditGrid(); end
	local available = SS.AvailableElements();
	for i = 1, table.getn(MOVABLE) do
		local name = MOVABLE[i][1];
		-- in the setup the elements turned on there have handles; otherwise every element (or the one chosen)
		local wanted = (setupActive and SS.SetupShows and SS.SetupShows(name)) or (not setupActive and (not editOnly or editOnly == name));
		if ( on and wanted and SS.HandleAllowed(name, available) ) then
			local ok, h = SS.Safe(SS.Handle, name, MOVABLE[i][2]);
			if ( ok and h ) then h:Show(); end
		elseif ( handles[name] ) then
			handles[name]:Hide();
		end
		if ( SS.DB().muted[name] ) then SS.Safe(ApplyFeatureMute, name); end
	end
	SS.Safe(SS.UpdateLevelButton);
	SS.Safe(UpdateMeter);
	-- while unlocked the action bar uses the movable layout; locked again with no custom layout, the game's own returns
	if ( not on ) then
		local d = SS.DB();
		if ( not d.showRacialAbility and not d.plainBar and d.orientations.MainMenuBar ~= "vertical" and type(d.sizes.MainMenuBar) ~= "table" ) then
			SS.Safe(SS.RestoreNativeActionBarLayout);
		end
	end
	if ( not quiet ) then K.Print(NAME, on and "drag a handle to move it; right-click for its settings, size and layout. Shift-left-click hides/shows a feature. Use Lock UI when done." or "the UI is locked."); end
end

function SS.SetMeterReplacement(on)
	SS.DB().moveMeter = on and true or false;
	SS.Safe(UpdateMeter);
end

tooltipOwnerOriginal = nil;
tooltipShowOriginal = nil;
function SS.HookTooltipOwner()
	if ( not GameTooltip or tooltipOwnerOriginal or not GameTooltip.SetOwner ) then return; end
	tooltipOwnerOriginal = GameTooltip.SetOwner;
	GameTooltip.SetOwner = function(self, owner, anchor, x, y)
		tooltipOwnerOriginal(self, owner, anchor, x, y);
		self.slimSample = nil;                                -- a real tooltip replaces the sample
		if ( self.SetClampedToScreen ) then self:SetClampedToScreen(true); end
		-- Leave every tooltip at the game's own size until the player resizes it or moves it.
		if ( not SS.DB().tooltipCustom and not SS.DB().unlocked ) then return; end
		-- the chosen width; the height is whatever the text needs (a one-line tooltip stays one line tall)
		local size = SS.DB().sizes.GameTooltip;
		if ( type(size) ~= "table" ) then size = { w = 260, h = 140 }; end
		self:SetWidth(size.w);
		local p = SS.DB().places.GameTooltip;
		if ( SS.DB().unlocked and type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" ) then
			SetRootPosition(self, p.x, p.y);
		end
	end;
	-- the tooltips the game puts in its usual corner (units in the world, unit frames, most of the HUD) go where the
	-- player moved the tooltip, in a run as well as while editing; tooltips pinned to a button stay by their button
	if ( type(GameTooltip_SetDefaultAnchor) == "function" and not SS.tooltipDefaultOriginal ) then
		SS.tooltipDefaultOriginal = GameTooltip_SetDefaultAnchor;
		GameTooltip_SetDefaultAnchor = function(tooltip, parent)
			SS.tooltipDefaultOriginal(tooltip, parent);
			if ( tooltip == GameTooltip ) then SS.Safe(SS.PlaceTooltip, tooltip); end
		end;
	end
	if ( GameTooltip.Show and not tooltipShowOriginal ) then
		tooltipShowOriginal = GameTooltip.Show;
		GameTooltip.Show = function(self)
			local size = (SS.DB().tooltipCustom or SS.DB().unlocked) and SS.DB().sizes.GameTooltip or nil;
			-- Set wrapping width before the game lays out its rows. Applying it only after Show
			-- leaves the old row heights in place and lets long text paint outside the tooltip.
			if ( type(size) == "table" and size.w ) then self:SetWidth(size.w); end
			tooltipShowOriginal(self);
		end;
	end
end

-- the tooltip at the place the player moved it to (its lower-left corner), if it has been moved
function SS.PlaceTooltip(tooltip)
	local p = SS.DB().places.GameTooltip;
	if ( type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" ) then return false; end
	SetRootPosition(tooltip, p.x, p.y);
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
	if ( name == "SlimSuiteTallyFrame" ) then d.tallyVertical = true; end
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
	d.tallyVertical, d.buffCustomLayout, d.buffGrowthDirection = true, false, "down";
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
	SS.HideElementMenu();
	K.Print(NAME, "all movable UI elements are back at their addon defaults.");
end

-- the target frame: hidden for good while the setting is on (this game targets for you)
targetShow = nil;
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
PLAIN_HIDE = { "CharacterMicroButton", "TalentMicroButton" };
plainShow = {};
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
cdText = {};
SS.Every("cooldowns", 0.1, function()
	local on = SS.DB().cooldowns;
	if ( not on and not SS.cooldownsShown ) then return; end   -- off, and nothing left on the squares
	SS.cooldownsShown = on and true or false;
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
