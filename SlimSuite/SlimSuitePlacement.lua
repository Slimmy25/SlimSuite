-- Slim Suite: where elements sit and how big they are: screen bounds, keeping elements on screen, sizes, scale and hiding a feature.
local K, SU, NAME = SS.Kit, SS.SU, SS.NAME;   -- the three names every Slim Suite file uses (SlimSuiteCore.lua)

-- GetLeft/GetRight are in the queried frame's effective-scale units. All movement state
-- and comparisons below use UIParent units; SetPoint offsets must be converted back.
SS.RootFactor = function(frame)
	return SS.EffectiveScale(frame) / SS.EffectiveScale(UIParent);
end

SS.RootBounds = function(frame)
	local l, r, b, t = frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop();
	if ( not l or not r or not b or not t ) then return nil; end
	local factor = SS.RootFactor(frame);
	-- All saved positions and UIParent anchors use coordinates from its bottom-left, even
	-- on clients where UIParent itself is inset from the physical screen origin.
	local originX, originY = UIParent:GetLeft() or 0, UIParent:GetBottom() or 0;
	return l * factor - originX, r * factor - originX, b * factor - originY, t * factor - originY;
end

SS.SetRootPosition = function(frame, x, y)
	local factor = SS.RootFactor(frame);
	frame:ClearAllPoints();
	frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / factor, y / factor);
end

-- Use resolved edges, in the same units as RootBounds and saved places. A scaled or
-- inset UIParent is not necessarily the whole client viewport. WorldFrame supplies
-- the remaining screen area; taking the union also handles a reduced world viewport
-- without cutting off UI space. Never change either root frame's scale or anchors.
function SS.ScreenBounds()
	local left, right, bottom, top = SS.RootBounds(UIParent);
	if ( not left or not right or not bottom or not top or right <= left or top <= bottom ) then
		left, right, bottom, top = 0, UIParent:GetWidth(), 0, UIParent:GetHeight();
	end
	if ( WorldFrame ) then
		local l, r, b, t = SS.RootBounds(WorldFrame);
		if ( l and r and b and t and r > l and t > b ) then
			left, right = math.min(left, l), math.max(right, r);
			bottom, top = math.min(bottom, b), math.max(top, t);
		end
	end
	return left, right, bottom, top;
end

function SS.ClampPosition(frame, x, y)
	local left, right, bottom, top = SS.ScreenBounds();
	local minX, minY, maxX, maxY = SS.VisualInsets(frame);
	return math.max(left - minX, math.min(right - maxX, x)),
		math.max(bottom - minY, math.min(top - maxY, y));
end

function SS.SavePlace(name, f)
	if ( SS.MarkProfileDirty ) then SS.MarkProfileDirty(); end
	local p = SS.DB().places[name];
	if ( type(p) ~= "table" ) then p = {}; SS.DB().places[name] = p; end
	local left, right, bottom = SS.RootBounds(f);
	p.x, p.y, p.coordinateSpace = left, bottom, "uiParent";
	p.displayDefault = nil;
	local sl, sr, sb, st = SS.ScreenBounds();
	if ( left and bottom and sr > sl and st > sb ) then
		p.screen = { left=sl, bottom=sb, width=sr-sl, height=st-sb };
	end
end
SS.SavePosition = function(name, f)
	SS.SavePlace(name, f);
	if ( name == "MinimapCluster" ) then SS.Safe(SS.ClockFollowsMap); end   -- a moved map takes Slim Suite's clock with it
	local p = SS.DB().places[name];
	if ( p ) then p.relative, p.point, p.relativePoint, p.dx, p.dy = nil, nil, nil, nil, nil; end
end

-- Resize, scale and snapped anchors can all push visible child controls past a screen edge.
-- Clamp the drawn bounds (not just the parent frame) and convert a clipped relative anchor to
-- a stable absolute location. Save the corrected place immediately so it survives /reload.
function SS.ClampToClient(name, frame)
	if ( not frame or not UIParent ) then return; end
	if ( name == "SlimSuiteItemRowFrame" and SS.DB().buildRowsAttached ) then return; end   -- the spell row is clamped for both
	local left, right, bottom = SS.RootBounds(frame);
	if ( not left or not bottom ) then return; end
	local x, y = SS.ClampPosition(frame, left, bottom);
	if ( math.abs(x - left) > 0.01 or math.abs(y - bottom) > 0.01 ) then
		SS.SetRootPosition(frame, x, y);
		local stored = SS.DB().places[name];
		if ( SS.displayReflow or (stored and stored.screen and not stored.relative)
			or (SS.DISPLAY_ANCHORS and SS.DISPLAY_ANCHORS[name] and (not stored or stored.displayDefault)) ) then return; end
		SS.SavePlace(name, frame);
		local p = SS.DB().places[name];
		p.relative, p.point, p.relativePoint, p.dx, p.dy = nil, nil, nil, nil, nil;
	end
end

-- The smallest size each element can be sized to. The size menu and the boss layout both read it, so they agree.
function SS.MinSize(name)
	local vertical = SS.CurrentOrientation(name) == "vertical";
	if ( name == "SlimSuiteClockFrame" ) then
		if ( vertical ) then return 90, (SS.DB().zoneLine and 54 or 36) + SS.FramePadding(name) * 3; end
		return 200, SS.DB().zoneLine and 42 or 24;
	elseif ( name == "SlimSuiteItemRowFrame" ) then
		if ( vertical ) then return 36, 76; end
		return 76, 24;
	elseif ( name == "SlimSuiteSpellRowFrame" ) then
		if ( vertical ) then return 36, 92; end
		return 92, 24;
	elseif ( name == "SlimSuiteAchievementsButton" ) then
		return 120,28;
	elseif ( name == "SlimSuiteReviveFrame" ) then
		if ( SS.DB().orientations and SS.DB().orientations.SlimSuiteReviveFrame == "vertical" ) then return 14, 80; end
		return 80, 14;
	elseif ( name == "SlimSuiteLuckFrame" ) then
		return 240,170;
	elseif ( name == "SlimSuiteCompassFrame" ) then
		return 160,80;
	elseif ( name == "SlimSuiteStatCounterFrame" ) then
		return 120,54;
	elseif ( name == "SlimSuiteMeterFrame" ) then
		return 210, 110;                                   -- the same as the meter's own corner grip
	elseif ( name == "GameTooltip" ) then
		return 160, 80;
	elseif ( name == "SlimSuiteCombatTextFrame" ) then
		return 120, 60;
	elseif ( name == "SlimSuitePartyLines" ) then
		local slots = SS.DB().partyIncludesSelf and 5 or 4;
		if ( SS.CurrentOrientation("PartyMemberFrame1") ~= "horizontal" ) then return 40, slots * 5 + (slots - 1) * 2; end
		return slots * 30 + (slots - 1) * 4, 5;
	elseif ( name == "SlimSuiteBossFrames" ) then
		-- one enemy card: the narrowest card and the shortest one that still reads
		local pad = SS.FramePadding(name);
		if ( vertical ) then return 34, math.max(60, 52 + pad * 3); end
		return 40, 42 + pad * 2;
	end
	return 40, 24;
end

SS.nativeScales = {};
function SS.ApplySize(name, f)
	if ( SS.nativeScales[name] == nil and f.GetScale ) then SS.nativeScales[name] = f:GetScale(); end
	if ( name == "PartyMemberFrame1" ) then
		for i = 1, 4 do
			local memberName = "PartyMemberFrame" .. i;
			local member = getglobal(memberName);
			if ( member and member.GetScale and SS.nativeScales[memberName] == nil ) then SS.nativeScales[memberName] = member:GetScale(); end
		end
	end
	if ( name == "ChatFrame1" and SS.CaptureChatLayout ) then SS.CaptureChatLayout(); end
	local s = SS.DB().sizes[name];
	if ( name == "GameTooltip" and type(s) ~= "table" ) then
		s = { w = 260, h = 140 };
	end
	if ( type(s) == "table" and s.w and s.h and s.w > 0 and s.h > 0 ) then
		local mw,mh=SS.MinSize(name); s.w,s.h=math.max(s.w,mw),math.max(s.h,mh);
		f:SetWidth(s.w);
		f:SetHeight(s.h);
	end
	-- Stretch across the whole screen: the XP bar is as wide as the screen at its scale, on any resolution
	if ( name == "MainMenuExpBar" and SS.DB().xpFullWidth and SS.ScreenBounds ) then
		local l, r = SS.ScreenBounds();
		local sc = tonumber(SS.DB().scales.MainMenuExpBar) or 1;
		if ( r and l and r > l and sc > 0 ) then f:SetWidth((r - l) / sc); end
		if ( SS.LayoutXpSegments ) then SS.Safe(SS.LayoutXpSegments); end
	end
	if ( name == "SlimSuiteClockFrame" ) then SS.ApplyClockLayout(); end
	if ( name == "MainMenuBar" and SS.ApplyMovableOrientation ) then SS.ApplyMovableOrientation(name); end
	if ( name == "SlimSuiteItemRowFrame" ) then SS.LayoutItemRow(); end
	if ( name == "SlimSuiteSpellRowFrame" ) then SS.LayoutSpellRow(); end
	if ( name == "SlimSuitePartyLines" and SS.UpdatePartyLines ) then SS.Safe(SS.UpdatePartyLines); end
	local scale = SS.DB().scales[name];
	if ( SS.DisplayElementScale ) then scale = SS.DisplayElementScale(name, type(scale) == "number" and scale or 1); end
	if ( name == "MinimapCluster" and SS.bigMapOn ) then scale = SS.BIG_MAP_SCALE; end   -- the big map (Ctrl-click the minimap)
	if ( type(scale) == "number" ) then
		if ( name == "PartyMemberFrame1" ) then
			for i = 1, 4 do local party = getglobal("PartyMemberFrame" .. i); if ( party and party.SetScale ) then party:SetScale(scale); end end
		elseif ( f.SetScale ) then f:SetScale(scale); end
	end
	if ( name == "ChatFrame1" and SS.SyncChatLayout ) then SS.SyncChatLayout(); end
end

-- Include visible child frames in edge clamping. Some Blizzard bars draw their buttons a few
-- logical pixels outside the parent frame, so clamping only the parent's rectangle leaves a gap.
SS.VisualInsets = function(frame)
	local baseLeft, baseRight, baseBottom = SS.RootBounds(frame);
	if ( not baseLeft or not baseBottom ) then return 0, 0, 0, 0; end
	local uiScale = SS.EffectiveScale(UIParent);
	local frameScale = SS.EffectiveScale(frame);
	local factor = frameScale / uiScale;
	-- MainMenuExpBar's child textures retain their old horizontal extents after the native
	-- status bar is rotated. Its own bounds are the visible/movable bounds in either layout.
	if ( frame == MainMenuExpBar ) then
		return 0, 0, (frame:GetWidth() or 0) * factor, (frame:GetHeight() or 0) * factor;
	end
	if ( frame == MainMenuBar or frame == PartyMemberFrame1 or frame == BuffFrame or frame == MinimapCluster ) then
		-- These Blizzard groups have unused parent padding or detached siblings. Clamp their
		-- actual visible controls as a group so scale cannot leave a gap or clip a companion.
		local minX, minY, maxX, maxY;
		local function Include(child)
			if ( not child or (child.IsShown and not child:IsShown()) ) then return; end
			local left, right, bottom, top = SS.RootBounds(child);
			if ( left and right and bottom and top ) then
				local l, r, b, t = left - baseLeft, right - baseLeft, bottom - baseBottom, top - baseBottom;
				minX = minX and math.min(minX, l) or l; maxX = maxX and math.max(maxX, r) or r;
				minY = minY and math.min(minY, b) or b; maxY = maxY and math.max(maxY, t) or t;
			end
		end
		if ( frame == MinimapCluster ) then
			Include(Minimap); Include(SS.squareRing);
			for _,name in ipairs({"MinimapZoneTextButton","MinimapToggleButton","MiniMapWorldMapButton","GameTimeFrame","MinimapZoomIn","MinimapZoomOut"}) do Include(getglobal(name)); end
			if ( SS.DB().replaceLocalClock and not SS.DB().clockDetached ) then Include(getglobal("SlimSuiteLocalClockFrame")); end
		elseif ( frame == MainMenuBar ) then
			for i = 1, 6 do Include(getglobal("ActionButton" .. i)); end
			Include(ActionButton12);
			if ( ActionButton12 ) then Include(ActionButton12.slimRacialBorder); end
			Include(ActionBarUpButton); Include(ActionBarDownButton);
		elseif ( frame == BuffFrame ) then
			for i = 0, (MAX_PLAYER_BUFFS or 32) do Include(getglobal("BuffButton" .. i)); end
			if ( SS.BuffSamples ) then for _, s in pairs(SS.BuffSamples()) do Include(s); end end
		else
			for i = 1, 4 do Include(getglobal("PartyMemberFrame" .. i)); end
			Include(getglobal("SlimSuitePartySelfFrame"));          -- your plate, before the first member
		end
		if ( minX and minY and maxX and maxY ) then return minX, minY, maxX, maxY; end
	end
	local minX, minY = 0, 0;
	local maxX = (frame:GetWidth() or 0) * factor;
	local maxY = (frame:GetHeight() or 0) * factor;
	-- Generic recursive child bounds can include detached/hidden Blizzard art and stale
	-- child anchors outside Slim Suite's custom frame. That falsely shrinks the usable
	-- screen area. Native composite frames above are handled explicitly; custom elements
	-- are clamped to their own visible rectangle.
	if ( frame == SS.spellRow and SS.itemRow and SS.DB().buildRowsAttached and SS.itemRow:IsShown() ) then
		local l, r, b, t = SS.RootBounds(SS.itemRow);
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

SS.ApplyFeatureMute = function(name)
	local frame = getglobal(name);
	if ( not frame ) then return; end
	local list, seen = {}, {};
	SS.CollectFeatureFrames(frame, list, seen, 0);
	if ( name == "PartyMemberFrame1" ) then
		for i = 2, 4 do SS.CollectFeatureFrames(getglobal("PartyMemberFrame" .. i), list, seen, 0); end
		SS.CollectFeatureFrames(getglobal("SlimSuitePartySelfFrame"), list, seen, 0);
	elseif ( name == "ChatFrame1" ) then
		local companions = SS.ChatCompanions and SS.ChatCompanions() or { "ChatFrame1Tab", "ChatFrameEditBox", "ChatFrame1EditBox" };
		for _, companion in ipairs(companions) do SS.CollectFeatureFrames(getglobal(companion), list, seen, 0); end
	end
	local muted = SS.DB().muted[name] and true or false;
	if ( name=="SlimSuiteItemRowFrame" and SS.ChoiceItemsActive and SS.ChoiceItemsActive() ) then muted=false; end
	if ( name == "ChatFrame1" and not SS.setupActive and SS.DB().elementModes.ChatFrame1 == "disabled" ) then muted = true; end
	for i = 1, table.getn(list) do
		local target = list[i];
		if ( target and target.GetAlpha and target.SetAlpha ) then
			if ( muted ) then
				if ( SS.mutedBaseAlphas[target] == nil ) then
					local ok, alpha = SS.Safe(target.GetAlpha, target);
					SS.mutedBaseAlphas[target] = ok and alpha or 1;
				end
				if ( SS.mutedBaseMouse[target] == nil and target.IsMouseEnabled ) then
					local ok, enabled = SS.Safe(target.IsMouseEnabled, target);
					if ( ok ) then SS.mutedBaseMouse[target] = enabled and true or false; end
				end
				SS.Safe(target.SetAlpha, target, 0);
				if ( target.EnableMouse and SS.mutedBaseMouse[target] ~= nil ) then SS.Safe(target.EnableMouse, target, false); end
			else
				local alpha = SS.mutedBaseAlphas[target];
				if ( alpha ~= nil ) then SS.Safe(target.SetAlpha, target, alpha); SS.mutedBaseAlphas[target] = nil; end
				local enabled = SS.mutedBaseMouse[target];
				if ( enabled ~= nil and target.EnableMouse ) then SS.Safe(target.EnableMouse, target, enabled); SS.mutedBaseMouse[target] = nil; end
			end
		end
	end
	local handle = SS.handles[name];
	if ( handle ) then
		if ( muted ) then
			handle:SetBackdropColor(0.22, 0.22, 0.24, 0.58);
			handle:SetBackdropBorderColor(0.6, 0.6, 0.62, 0.85);
			if ( handle.text and name ~= "GameTooltip" ) then handle.text:SetTextColor(0.72, 0.72, 0.74); end
		elseif ( handle.quiet ) then
			handle:SetBackdropColor(0, 0, 0, 0); handle:SetBackdropBorderColor(0.3, 1, 0.3, 0);
			if ( handle.text ) then handle.text:SetTextColor(1, 1, 1); end
		else
			handle:SetBackdropColor(0.1, 0.6, 0.1, 0.45);
			handle:SetBackdropBorderColor(0.3, 1, 0.3, 0.9);
			if ( handle.text and name ~= "GameTooltip" ) then handle.text:SetTextColor(1, 1, 1); end
		end
	end
end;

-- Elements joined to this one right now: the build spell row and the worn rings / trinkets row while they are
-- joined, and any element whose saved place is pinned to another one. Hiding or turning off one of them does the same
-- to the others, so a joined set never comes apart half shown.
function SS.JoinedElements(name)
	local d, out, seen = SS.DB(), {}, { [name] = true };
	local function Add(n) if ( n and not seen[n] and SS.ELEMENTS and SS.ELEMENTS[n] ) then seen[n] = true; table.insert(out, n); end end
	if ( d.buildRowsAttached ~= false ) then
		if ( name == "SlimSuiteSpellRowFrame" ) then Add("SlimSuiteItemRowFrame"); end
		if ( name == "SlimSuiteItemRowFrame" ) then Add("SlimSuiteSpellRowFrame"); end
	end
	local i = 0;
	local queue = { name };
	while ( i < table.getn(queue) ) do
		i = i + 1;
		local current = queue[i];
		for other, p in pairs(d.places or {}) do
			local buildPair = (other == "SlimSuiteItemRowFrame" or other == "SlimSuiteSpellRowFrame") and (p and (p.relative == "SlimSuiteItemRowFrame" or p.relative == "SlimSuiteSpellRowFrame"));
			if ( type(p) == "table" and p.relative and SS.ELEMENTS and SS.ELEMENTS[other] and not (buildPair and d.buildRowsAttached == false) ) then
				if ( p.relative == current and not seen[other] ) then Add(other); table.insert(queue, other); end
				if ( other == current and SS.ELEMENTS[p.relative] and not seen[p.relative] ) then Add(p.relative); table.insert(queue, p.relative); end
			end
		end
	end
	return out;
end

function SS.ToggleFeatureMute(name)
	SS.DB().muted[name] = not SS.DB().muted[name];
	SS.ApplyFeatureMute(name);
	for _, other in ipairs(SS.JoinedElements(name)) do
		SS.DB().muted[other] = SS.DB().muted[name];
		SS.ApplyFeatureMute(other);
	end
	if ( SS.sizeMenu and SS.sizeMenu.muteButton ) then
		SS.sizeMenu.muteButton:SetText(SS.DB().muted[name] and "Show feature" or "Hide feature");
	end
end

function SS.CurrentOrientation(name)
	if ( SS.DB().frameDefault and SS.DB().frameDefault[name] ) then
		return name == "PartyMemberFrame1" and "vertical" or "horizontal";
	end
	if ( name == "PartyMemberFrame1" and SS.Demoing("PartyMemberFrame1") and SS.demoPartyOrient ) then return SS.demoPartyOrient; end
	local orientation = SS.DB().orientations[name];
	if ( orientation == "vertical" or orientation == "horizontal" ) then return orientation; end
	if ( name == "SlimSuiteClockFrame" ) then return "vertical"; end
	if ( name == "PartyMemberFrame1" ) then return "vertical"; end
	return "horizontal";
end

function SS.BuffGrowthDirection()
	return SS.DB().buffGrowthDirection == "up" and "up" or "down";
end
