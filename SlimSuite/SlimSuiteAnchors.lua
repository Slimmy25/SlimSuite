-- Slim Suite: placing every element from its saved place, joined build rows, Mirror Target, buffs on unit frames and the game frames' looks.
local K, SU, NAME = SS.Kit, SS.SU, SS.NAME;   -- the three names every Slim Suite file uses (SlimSuiteCore.lua)

-- True when the worn-jewelry row is joined under the spell row. Only the player separates them, with the
-- "Detach build rows" button; nothing else in Slim Suite may break that join.
function SS.BuildRowsJoined(name)
	return name == "SlimSuiteItemRowFrame" and SS.DB().buildRowsAttached and true or false;
end

function SS.Place(name, ignoreAnchor)
	local f = getglobal(name);
	local p = SS.DB().places[name];
	if ( not f ) then return; end
	if ( name == "ChatFrame1" and SS.ChatIsCustom and not SS.ChatIsCustom() ) then return; end
	if ( SS.DB().frameDefault and SS.DB().frameDefault[name] ) then return; end   -- "Default": the game's own placement
	if ( name=="SlimSuiteLocalClockFrame" and not SS.DB().clockDetached and SlimSuiteWorld and SlimSuiteWorld.DockLocalClock ) then
		SlimSuiteWorld.DockLocalClock(); return;
	end
	if ( (name == "SlimSuiteSpellRowFrame" and type(p) ~= "table") or (name == "SlimSuiteItemRowFrame" and
		(type(p) ~= "table" or (SS.BuildRowsJoined(name) and p.relative ~= "SlimSuiteSpellRowFrame"))) ) then
		p = SS.BuildRowDefaultPlace(name);
		SS.DB().places[name] = p;
	end
	local w, h = f:GetWidth(), f:GetHeight();
	if ( w and h and w > 0 and h > 0 and not SS.baseSizes[name] ) then SS.baseSizes[name] = { w = w, h = h }; end
	if ( name ~= "GameTooltip" and not SS.basePoints[name] and f.GetNumPoints ) then
		local points = {};
		for i = 1, f:GetNumPoints() do
			local point, relative, relativePoint, x, y = f:GetPoint(i);
			points[i] = { point, relative, relativePoint, x, y };
		end
		if ( table.getn(points) > 0 ) then SS.basePoints[name] = points; end
	end
	if ( name == "MainMenuBar" and SS.CaptureActionBarLayout ) then SS.CaptureActionBarLayout(); end
	SS.ApplySize(name, f);
	if ( name == "PartyMemberFrame1" ) then
		local saved = SS.DB().scales.PartyMemberFrame1;
		local sc = type(saved) == "number" and saved or 1;
		if ( SS.DisplayElementScale ) then sc = SS.DisplayElementScale(name, sc); end
		for i = 1, 4 do local pf = getglobal("PartyMemberFrame" .. i); if ( pf and pf.SetScale ) then pf:SetScale(sc); end end
		for i = 1, 4 do
			local portrait = getglobal("PartyMemberFrame" .. i .. "Portrait");
			if ( portrait ) then if ( SS.DB().partyFaces == false ) then portrait:Hide(); else portrait:Show(); end end
		end
	end
	if ( (name == "PartyMemberFrame1" or name == "SlimSuitePartyLines") and SS.Shown("PartyMemberFrame1") == name ) then
		local lockTo = getglobal(SS.Shown("PlayerFrame")) or PlayerFrame;
		if ( SS.DB().partyLocked and not SS.DB().partyIncludesSelf and lockTo ) then
			local pl, pr = SS.RootBounds(SS.UnitPortrait(lockTo));
			local fl = SS.RootBounds(f);
			local il, ir = SS.RootBounds(SS.UnitPortrait(f));
			local ll = SS.RootBounds(lockTo);
			local factor = SS.RootFactor(f) or 1;
			local offset = (pl and pr and fl and il and ir and ll) and ((pl + pr) / 2 - ll - ((il + ir) / 2 - fl)) / factor or 0;
			f:ClearAllPoints();
			if ( SS.DB().partyLockAbove ) then
				-- the whole party block (all four places, filled or not, stacked or in a row) sits just above the player
				-- frame, so it never grows down over it when someone joins
				local factor = SS.RootFactor(f);
				if ( not factor or factor <= 0 ) then factor = 1; end
				f:SetPoint("TOPLEFT", lockTo, "TOPLEFT", offset, (6 + SS.PartyBlockDepth(f)) / factor);
			else
				f:SetPoint("TOPLEFT", lockTo, "BOTTOMLEFT", offset, -6 / factor);
			end
			return;
		end
	end
	-- Our edge clamp uses visible child bounds; let it place an inset parent slightly outside the screen.
	if ( SS.DB().unlocked or type(p) == "table" ) then
		if ( f.SetClampedToScreen ) then f:SetClampedToScreen(false); end
		if ( (name == "BuffFrame" or name == "MainMenuBar" or name == "MinimapCluster") and f.SetUserPlaced ) then SS.UserPlace(f); end
	end
	if ( type(p) ~= "table" ) then
		if ( SS.PlaceDisplayDefault ) then SS.PlaceDisplayDefault(name, f); end
		return;
	end
	if ( p.coordinateSpace ~= "uiParent" ) then
		local factor = SS.RootFactor(f);
		if ( p.x ) then p.x = p.x * factor; end
		if ( p.y ) then p.y = p.y * factor; end
		if ( p.dx ) then p.dx = p.dx * factor; end
		if ( p.dy ) then p.dy = p.dy * factor; end
		p.coordinateSpace = "uiParent";
	end
	if ( p.x and p.y and not p.screen and not p.displayDefault ) then
		local sl, sr, sb, st = SS.ScreenBounds();
		p.screen = { left=sl, bottom=sb, width=sr-sl, height=st-sb };
	end
	if ( p.displayDefault and not p.relative and SS.PlaceDisplayDefault ) then SS.PlaceDisplayDefault(name, f); return; end
	local relative = not ignoreAnchor and p.relative and getglobal(p.relative) or nil;
	-- A frame cannot hang off a frame that already hangs off it (the buffs joined to the player frame): skip that anchor
	if ( relative and relative.GetNumPoints ) then
		for i = 1, relative:GetNumPoints() do
			local _, anchorTo = relative:GetPoint(i);
			if ( anchorTo == f ) then relative = nil; break; end
		end
	end
	if ( relative and p.point and p.relativePoint ) then
		f:ClearAllPoints();
		local factor = SS.RootFactor(f);
		f:SetPoint(p.point, relative, p.relativePoint, K.Num(p.dx) / factor, K.Num(p.dy) / factor);
	elseif ( p.x and p.y ) then
		-- Saved coordinates can come from a taller or wider display. Clamp absolute restores to this screen
		-- without rewriting the saved location, so a later return to the larger display restores the user's layout.
		local px, py = K.Num(p.x), K.Num(p.y);
		if ( type(p.screen) == "table" and p.screen.width and p.screen.width > 0 and p.screen.height and p.screen.height > 0 ) then
			local sl, sr, sb, st = SS.ScreenBounds();
			px = sl + (px - (p.screen.left or 0)) * (sr-sl) / p.screen.width;
			py = sb + (py - (p.screen.bottom or 0)) * (st-sb) / p.screen.height;
		end
		local x, y = SS.ClampPosition(f, px, py);
		SS.SetRootPosition(f, x, y);
	end
end

SS.PlaceAll = function()
	local attached = {};
	for i = 1, table.getn(SS.MOVABLE) do
		local name = SS.MOVABLE[i][1];
		SS.Safe(SS.Place, name, true);
		local p = SS.DB().places[name];
		if ( type(p) == "table" and p.relative ) then table.insert(attached, name); end
	end
	-- Reapply saved frame-to-frame anchors after every movable frame has its stored size and base position: only the
	-- elements hanging off another one need it (an anchor chain is at most three frames deep)
	for pass = 1, 3 do
		for i = 1, table.getn(attached) do SS.Safe(SS.Place, attached[i], false); end
	end
	-- Relative snaps and scale changes must not leave a frame clipped or padded away from the edge.
	for i = 1, table.getn(SS.MOVABLE) do
		local name = SS.MOVABLE[i][1];
		local frame = getglobal(name);
		if ( frame ) then
			SS.Safe(SS.ClampToClient,name,frame);
			if ( SS.EnforceElementBounds ) then SS.Safe(SS.EnforceElementBounds,frame,SS.DB().vanillaUI or (SS.DB().frameDefault and SS.DB().frameDefault[name])); end
		end
	end
	if ( SS.DB().mirrorTarget ) then SS.Safe(SS.MirrorTarget); end
	if ( SS.DB().buffsOnTarget or SS.DB().buffsOnPlayer ) then SS.Safe(SS.AttachBuffs); end
end

-- "Mirror target": the target frame stands where the player frame would be if the screen were folded at its center
-- line: same height, same scale, the same distance from the right edge as the player frame is from the left.
-- Which look each unit frame shows. The player frame has its own (classic or new) until it joins another frame: in the
-- party it takes the party's look, combined with the target it takes the target's. The target always keeps its own.
function SS.Look(el)
	local d = SS.DB();
	if ( el == "TargetFrame" ) then return d.targetLook == "new" and "new" or "classic"; end
	if ( el == "PartyMemberFrame1" ) then return d.partyLook == "thin" and "thin" or "classic"; end
	if ( el == "PlayerFrame" ) then
		if ( d.partyIncludesSelf ) then return "party"; end
		if ( d.combineTarget ) then return SS.Look("TargetFrame"); end
		return d.playerLook == "new" and "new" or "classic";
	end
	return "classic";
end
function SS.UsesCard(el) return SS.Look(el) == "new"; end

-- The frame that shows an element now: a new-school card, the thin party lines, or the game's own frame. Every handle,
-- size, reset, hide and buff action goes to the frame the player can see; the others stay invisible underneath.
function SS.Shown(name)
	if ( name == "PlayerFrame" and SS.UsesCard("PlayerFrame") ) then return "SlimSuitePlayerCard"; end
	if ( name == "TargetFrame" and SS.UsesCard("TargetFrame") ) then return "SlimSuiteTargetCard"; end
	if ( name == "PartyMemberFrame1" and SS.Look("PartyMemberFrame1") == "thin" ) then return "SlimSuitePartyLines"; end
	return name;
end
function SS.Element(name)
	if ( name == "SlimSuitePlayerCard" ) then return "PlayerFrame"; end
	if ( name == "SlimSuiteTargetCard" ) then return "TargetFrame"; end
	if ( name == "SlimSuitePartyLines" ) then return "PartyMemberFrame1"; end
	return name;
end

-- where "the player frame" is for buffs and mirroring: your own plate or line while you are in the party
function SS.PlayerAnchor()
	if ( SS.DB().partyIncludesSelf ) then
		local c = getglobal("SlimSuitePartyLines");
		if ( SS.Look("PartyMemberFrame1") == "thin" and c ) then
			for i = 1, table.getn(c.lines or {}) do if ( c.lines[i].unit == "player" and c.lines[i]:IsShown() ) then return c.lines[i]; end end
			return c;
		end
		return getglobal("SlimSuitePartySelfFrame") or PlayerFrame;
	end
	return getglobal(SS.Shown("PlayerFrame"));
end
function SS.Pair()
	return SS.PlayerAnchor(), getglobal(SS.Shown("TargetFrame"));
end

-- Places "to" as the mirror image of "from" across the screen's vertical centre line. The pair always shares
-- scale, so there is no separate same-size setting to maintain.
function SS.MirrorFrames(from, to)
	if ( not from or not to ) then return; end
	local fromName, toName = from:GetName(), to:GetName();
	local scale = SS.DB().scales[fromName];
	SS.DB().scales[toName] = scale;
	if ( to.SetScale ) then
		local applied = type(scale) == "number" and scale or 1;
		-- both frames take the same on-screen scale, worked out from the source frame, so the pair always matches
		if ( SS.DisplayElementScale ) then applied = SS.DisplayElementScale(fromName, applied); end
		to:SetScale(applied);
	end
	local w, h = from:GetWidth(), from:GetHeight();
	if ( w and h and w > 0 and h > 0 and toName ~= "PlayerFrame" and toName ~= "TargetFrame" ) then   -- classic art: scale only
		to:SetWidth(w); to:SetHeight(h);
		SS.DB().sizes[toName] = { w = w, h = h };
	end
	local l, r, b, t = SS.RootBounds(from);
	if ( not l or not t ) then return; end
	local factor = SS.RootFactor(to);
	local tw, th = (to:GetWidth() or 0) * factor, (to:GetHeight() or 0) * factor;
	local screenLeft, screenRight = SS.ScreenBounds();
	local x = screenLeft + screenRight - l - tw;
	local y = (b + t) / 2 - th / 2;
	if ( to.SetUserPlaced ) then SS.UserPlace(to); end
	SS.SetRootPosition(to, x, y);
	local p = SS.DB().places[toName];
	if ( type(p) ~= "table" ) then p = {}; SS.DB().places[toName] = p; end
	p.x, p.y, p.coordinateSpace = x, y, "uiParent";
	p.relative, p.point, p.relativePoint, p.dx, p.dy = nil, nil, nil, nil, nil;
end

-- the target placed as the player's mirror image (the player leads)
function SS.MirrorTarget()
	if ( not SS.DB().mirrorTarget ) then return; end
	local P, T = SS.Pair();
	SS.MirrorFrames(P, T);
end

-- the player placed as the target's mirror image (while the target is being dragged or resized)
function SS.MirrorPlayer()
	if ( not SS.DB().mirrorTarget ) then return; end
	local P, T = SS.Pair();
	SS.MirrorFrames(T, P);
end

-- "Buffs on the target frame": the buff frame joins the target frame, above or below it, at the target's scale, and
-- loses its own handle while joined. It is shown in both frames' right-click menus and in the setup's steps.
function SS.UnitPortrait(frame)
	if ( not frame ) then return nil; end
	local name = frame.GetName and frame:GetName();
	local native = name == "PlayerFrame" and getglobal("PlayerPortrait") or (type(name) == "string" and getglobal(name .. "Portrait"));
	for _, region in pairs({ frame.portrait, frame.model, native }) do
		if ( region and region.GetLeft and type(region:GetLeft()) == "number" and (not region.IsShown or region:IsShown()) ) then return region; end
	end
	return frame;
end

function SS.AttachBuffs()
	local P, T = SS.Pair();
	local anchor = SS.DB().buffsOnTarget and T or (SS.DB().buffsOnPlayer and P) or nil;
	if ( not anchor or not BuffFrame ) then return; end
	local side = SS.DB().buffsOnTarget and SS.DB().buffsOnTargetSide or SS.DB().buffsOnPlayerSide;
	local factor = SS.RootFactor(anchor) or 1;
	local scale, x = factor, 6;                                -- the unit frame's size on screen
	if ( anchor == P and SS.DB().partyIncludesSelf and not SS.DB().buffsOnTarget ) then
		-- you in the party: the buffs are sized to your plate or line (about a third of a plate's height, a little taller
		-- than a line) and line up with its left edge; your raid mark sits beside your plate, so the row above is theirs
		local line = (SS.IsPartyLine and SS.IsPartyLine(anchor)) or anchor == getglobal("SlimSuitePartyLines");
		local h = anchor:GetHeight() or 9;
		local icon = line and math.max(10, h * 1.5) or math.max(12, math.min(20, h * 0.32));
		local button = getglobal("BuffButton0") or getglobal("BuffButton1");
		local bh = (button and button.GetHeight and button:GetHeight()) or 30;
		if ( not bh or bh <= 0 ) then bh = 30; end
		scale = factor * icon / bh;
		x = 0;
	end
	BuffFrame:ClearAllPoints();
	if ( SS.DB().partyIncludesSelf and (side == "left" or side == "right") ) then side = "above"; end   -- in the party: above your plate
	if ( side == "above" ) then
		local portrait = SS.DB().partyIncludesSelf and anchor or SS.UnitPortrait(anchor);
		-- the game refuses an anchor that loops back (the portrait hangs off the buffs): fall back to a fixed spot
		-- checked first: the game reports a looping anchor as an error it does not hand back to us
		local loops = false;
		if ( portrait and portrait.GetNumPoints ) then
			for i = 1, portrait:GetNumPoints() do
				local _, anchorTo = portrait:GetPoint(i);
				if ( anchorTo == BuffFrame ) then loops = true; break; end
			end
		end
		if ( loops or not portrait ) then BuffFrame:ClearAllPoints(); BuffFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 200);
		else BuffFrame:SetPoint("BOTTOMLEFT", portrait, "TOPLEFT", portrait == anchor and x or 0, 2); end
	elseif ( side == "left" ) then BuffFrame:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -4, 0);
	elseif ( side == "right" ) then BuffFrame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0);
	else BuffFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, -2); end
	if ( BuffFrame.SetScale ) then BuffFrame:SetScale(scale); end
	SS.Safe(SS.LayoutPartyBuffs);
end

-- ---------------------------------------------------------------- default game frames in RPG and New School
-- The game's own frame keeps its look in Original. In the other two looks its top-level background textures are hidden
-- and the chosen panel is drawn behind it, in a child overlay that is removed from the game's frame only by hiding.
-- Child frames (bars, portraits, text) are left alone. The minimap, chat and tooltip are not included yet: the minimap is
-- round, the chat draws its text itself, and the tooltip is re-drawn by the game on every show.
-- Default game frames keep the game's own look in every style. A panel behind them looked wrong, and hiding their
-- textures also hides the frame art, so the reskin is off until a transparent version is worked out.
SS.SKINNABLE_BLIZZARD = {};
function SS.SkinBlizzardFrame(name)
	local frame = getglobal(name);
	if ( not frame or not frame.GetRegions or getglobal("SlimSuiteSkin_" .. name) ) then return; end
	local overlay = CreateFrame("Frame", "SlimSuiteSkin_" .. name, frame);
	overlay.slimName = name;
	overlay:SetAllPoints(frame);
	-- the panel sits at the frame's own level, so the frame's bars, buttons and text (children one level up) stay on top
	overlay:SetFrameLevel(frame:GetFrameLevel() or 1);
	overlay:EnableMouse(false);
	overlay:Hide();
	local textures = {};
	local regions = { frame:GetRegions() };
	for i = 1, table.getn(regions) do
		local r = regions[i];
		if ( r and r.GetObjectType and r:GetObjectType() == "Texture" ) then table.insert(textures, r); end
	end
	SS.AddThemeHook(function(key)
		if ( key == "original" or not SS.PANEL_STYLES[key] ) then
			for i = 1, table.getn(textures) do textures[i]:Show(); end
			overlay:Hide();
		else
			for i = 1, table.getn(textures) do textures[i]:Hide(); end
			SS.ApplyPanelStyle(overlay);
			overlay:Show();
		end
	end, name);
end
for i = 1, table.getn(SS.SKINNABLE_BLIZZARD) do SS.SkinBlizzardFrame(SS.SKINNABLE_BLIZZARD[i]); end
