-- Slim Suite: things drawn from the game's newer addon API.
--   * World markers (0.139.2 world anchors): Skull, Cross, Circle and Star over bosses and Guardians that are already
--     pulled, and a "!" over Guardians and lairs before they are pulled. Markers never select a target and have no
--     distance limit. Only what is on screen is marked: the game gives no screen place for anything off screen or
--     behind the camera, so there is nothing to point an edge marker with.
--   * Downed friends (0.139.2): a marker on the spot where each downed friend can be revived, on every map.
--   * Debuffs on the movable encounter bars (0.93), a movable revive bar (0.113 / 0.115), a class proc meter under
--     the player frame (0.105), a combat text test box (0.138), and keeping Slim Suite above the level-up and
--     new-item cards (0.126).
-- Lua 5.0 / 1.12 interface: scripts read `this`, `arg1`; no # operator, no `...` in expressions; only the 1.12 API.
--
-- THE ADAPTER (A, below) is the only place that knows the shape of the game's addon API. It follows the game's addon
-- docs ("Azeroth Survivors: Addon API"): exact arguments (extra ones are errors there), the documented field names,
-- and every call guarded, so a game build without a function simply leaves that feature hidden.

local W = {};
SlimSuiteWorld = W;
local function DB() return SS.DB(); end
local function Editing(name) return SS.IsEditing and SS.IsEditing(name); end
-- sample data shows while an element is being placed (the setup or Toggle UI Settings) and in Demo Mode
local function Previewing(name) return SS.Previewing and SS.Previewing(name); end

-- ---------------------------------------------------------------- the adapter
local A = {};
-- Call a game function with exactly the arguments given. Returns its two results (result, err); nil if it is missing.
function A.Call(name, ...)
	local fn = getglobal(name);
	if ( type(fn) ~= "function" ) then return nil; end
	local ok, result, err = SS.Safe(fn, unpack(arg));
	if ( ok ) then return result, err; end
	return nil;
end
function A.Has(name) return type(getglobal(name)) == "function"; end
-- the first of several possible field names that is set (only for old game builds; the docs' names come first)
function A.Field(t, k1, k2, k3, k4)
	if ( type(t) ~= "table" ) then return nil; end
	if ( t[k1] ~= nil ) then return t[k1]; end
	if ( k2 and t[k2] ~= nil ) then return t[k2]; end
	if ( k3 and t[k3] ~= nil ) then return t[k3]; end
	if ( k4 and t[k4] ~= nil ) then return t[k4]; end
	return nil;
end
function A.Id(t) return A.Field(t, "id", "unitId", "anchorId"); end

-- The world-anchor catalog (AZS_GetWorldAnchors): every page of one catalog, read in one go, as the docs require (a
-- later frame may have another catalog). Only the kinds Slim Suite draws are asked for. Read at most ten times a
-- second and shared by the markers and the minimap pins. Gives { list, byUnit (AZS_UNITS id), byLair (lair index) }.
local CATALOG_QUERY = { kinds = { "boss", "finalBoss", "guardian", "elite", "guardianLair" } };
local catalog = { at = -1, list = {}, byUnit = {}, byLair = {} };
function A.Catalog(now)
	if ( now - catalog.at < 0.1 ) then return catalog; end
	if ( not A.Has("AZS_GetWorldAnchors") ) then return catalog; end
	local list, cursor = {}, nil;
	for pages = 1, 32 do
		local page = A.Call("AZS_GetWorldAnchors", CATALOG_QUERY, cursor);
		if ( type(page) ~= "table" or type(page.entries) ~= "table" ) then return catalog; end   -- not ready: keep the last
		for i = 1, table.getn(page.entries) do table.insert(list, page.entries[i]); end
		if ( not page.hasMore ) then break; end
		cursor = page.nextCursor;
	end
	local byUnit, byLair = {}, {};
	for i = 1, table.getn(list) do
		local e = list[i];
		if ( e.unitId ~= nil and e.state ~= "dead" ) then byUnit[e.unitId] = e; end
		if ( e.lairIndex ~= nil ) then byLair[e.lairIndex] = e; end
	end
	catalog.at, catalog.list, catalog.byUnit, catalog.byLair = now, list, byUnit, byLair;
	return catalog;
end

-- AZS_ProjectWorldAnchors: requests are { anchorId, attachment ("position" or "overhead"), offset = { z = yards } }.
-- Gives a map: anchor id -> { x, y, on, dist } in UIParent units, for the anchors on screen only (the game gives no
-- screen place for one that is off screen or behind the camera). Asks in groups of 256, the most per call.
-- It runs every frame, so its answer and the spots in it are kept and reused, not made new each time: read them
-- before the next call.
local projected, spotPool, spotUsed = {}, {}, 0;
function A.Project(requests)
	local out = projected;
	for id in pairs(out) do out[id] = nil; end
	spotUsed = 0;
	local n = table.getn(requests);
	if ( n == 0 or not A.Has("AZS_ProjectWorldAnchors") ) then return out; end
	local scale = SS.EffectiveScale(UIParent);
	local first = 1;
	while ( first <= n ) do
		local batch = requests;                              -- 256 or fewer (nearly always): asked as they are
		if ( n > 256 ) then
			batch = {};
			for i = first, math.min(n, first + 255) do table.insert(batch, requests[i]); end
		end
		first = first + 256;
		local result = A.Call("AZS_ProjectWorldAnchors", batch);
		if ( type(result) == "table" and type(result.entries) == "table" ) then
			for i = 1, table.getn(result.entries) do
				local e = result.entries[i];
				if ( e.state == "onScreen" and type(e.x) == "number" and type(e.y) == "number" ) then
					spotUsed = spotUsed + 1;
					local s = spotPool[spotUsed];
					if ( not s ) then s = {}; spotPool[spotUsed] = s; end
					s.x, s.y, s.on, s.dist = e.x / scale, e.y / scale, true, e.playerDistance;
					out[e.anchorId] = s;
				end
			end
		end
	end
	return out;
end
function A.Kind(anchor) return string.lower(tostring(A.Field(anchor, "kind") or "")); end
W.API = A;

-- ---------------------------------------------------------------- marker drawing
local RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons";
local PRE_PULL_ICON = "Interface\\GossipFrame\\AvailableQuestIcon";
local BOSS_ICONS = { 8, 7, 2, 1 };                        -- Skull, Cross, Circle, Star
local DEATH_ICONS = { 3, 4, 5, 6 };                       -- Diamond, Triangle, Moon, Square (party slots 1-4)
local DEATH_BLINKS = 16;

local overlay = CreateFrame("Frame", "SlimSuiteWorldMarkers", UIParent);
overlay:SetAllPoints(UIParent);
overlay:SetFrameStrata("BACKGROUND");
overlay:EnableMouse(false);
local pool, used = {}, 0;

local function Marker()
	used = used + 1;
	local m = pool[used];
	if ( not m ) then
		m = CreateFrame("Frame", nil, overlay);
		m:SetWidth(32); m:SetHeight(32);
		m.icon = m:CreateTexture(nil, "ARTWORK");
		m.icon:SetAllPoints(m);
		m.label = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		m.label:SetPoint("TOP", m, "BOTTOM", 0, -1);
		pool[used] = m;
	end
	return m;
end

local function SetRaidIcon(tex, index)
	local col, row = math.mod(index - 1, 4), math.floor((index - 1) / 4);
	tex:SetTexture(RAID_ICONS);
	tex:SetTexCoord(col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25);
end

-- Put a marker at a projected spot. One right at the screen's edge is kept inside it, smaller and fainter.
local function Show(p, size, alpha, text)
	local m = pool[used];
	local w, h = UIParent:GetWidth(), UIParent:GetHeight();
	local x, y, edge = p.x, p.y, not p.on;
	if ( x < 16 or x > w - 16 or y < 16 or y > h - 16 ) then edge = true; end
	if ( edge ) then
		x = math.max(16, math.min(w - 16, x)); y = math.max(24, math.min(h - 16, y));
		size = math.max(16, size * 0.7); alpha = alpha * 0.65;
	end
	m:SetWidth(size); m:SetHeight(size);
	m:ClearAllPoints();
	m:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y);
	m:SetAlpha(alpha);
	local dist = type(p.dist) == "number" and (math.floor(p.dist + 0.5) .. " yd") or nil;
	if ( text and dist ) then m.label:SetText(text .. "  " .. dist);
	else m.label:SetText(text or dist or ""); end
	m:Show();
end

-- nearer is bigger; never smaller than readable
local function SizeFor(dist, big)
	local base = big and 36 or 26;
	if ( type(dist) ~= "number" ) then return base; end
	return math.max(big and 20 or 16, math.min(base, base - (dist - 20) * 0.15));
end

-- ---------------------------------------------------------------- bosses and Guardians
-- Pulled (aggroed): the bosses the game lists (always active once spawned) and Guardians that are awake.
-- An icon stays with its enemy for the whole fight, so icons never swap when another enemy dies; a freed icon goes to
-- the next enemy pulled. A final boss takes Skull whenever Skull is free.
local assigned = {};                                      -- unit id -> icon index

local function Awake(u) return u.awake == true or u.state == 1; end
-- the raid mark a boss or Guardian has right now (Skull, Cross, Circle, Star), for the encounter bars too; Demo Mode's
-- sample bosses (ids -1 to -4) take them in order
W.BOSS_ICONS = BOSS_ICONS;
function W.MarkFor(id)
	if ( id == nil ) then return nil; end
	if ( type(id) == "number" and id < 0 and id >= -4 ) then return BOSS_ICONS[-id]; end
	return assigned[id];
end
W.SetRaidIcon = function(tex, index) SetRaidIcon(tex, index); end

local function PulledEnemies()
	local list, seen = {}, {};
	local function Add(src, kindDefault, wantAwake)
		if ( type(src) ~= "table" ) then return; end
		for i = 1, table.getn(src) do
			local u = src[i];
			if ( type(u) == "table" and u.id ~= nil and not seen[u.id] ) then
				local kind = SS.UnitKind(u) or kindDefault;
				if ( kind ~= "guardian" or Awake(u) == wantAwake ) then
					seen[u.id] = true;
					table.insert(list, { id = u.id, name = u.name, kind = kind });
				end
			end
		end
	end
	Add(A.Call("AZS_GetBosses"), "boss", true);
	Add(A.Call("AZS_GetGuardians"), "guardian", true);
	return list;
end

local function SleepingGuardians()
	local list = {};
	local g = A.Call("AZS_GetGuardians");
	if ( type(g) == "table" ) then
		for i = 1, table.getn(g) do
			local u = g[i];
			if ( type(u) == "table" and u.id ~= nil and not Awake(u) and (SS.UnitKind(u) or "guardian") == "guardian" ) then table.insert(list, { id = u.id, name = u.name }); end
		end
	end
	return list;
end

local function AssignIcons(enemies)
	local alive, taken = {}, {};
	for i = 1, table.getn(enemies) do alive[enemies[i].id] = enemies[i]; end
	for id, icon in pairs(assigned) do
		if ( alive[id] ) then taken[icon] = true; else assigned[id] = nil; end
	end
	local function Free()
		for i = 1, table.getn(BOSS_ICONS) do if ( not taken[BOSS_ICONS[i]] ) then return BOSS_ICONS[i]; end end
		return nil;
	end
	for i = 1, table.getn(enemies) do
		local e = enemies[i];
		if ( e.kind == "final" and not assigned[e.id] and not taken[8] ) then assigned[e.id] = 8; taken[8] = true; end
	end
	for i = 1, table.getn(enemies) do
		local e = enemies[i];
		if ( not assigned[e.id] ) then
			local icon = Free();
			if ( not icon ) then break; end
			assigned[e.id] = icon; taken[icon] = true;
		end
	end
end

-- ---------------------------------------------------------------- downed friends
local downed = {};                                        -- friend key -> { first = time, icon }
local function PartySlot(name)
	for i = 1, 4 do if ( UnitName("party" .. i) == name ) then return i; end end
	return nil;
end

local function DownedFriends(now)
	local list = A.Call("AZS_GetDownedPartyMembers");
	local current = {};
	if ( type(list) ~= "table" and A.Has("AZS_GetDownedPartyMembers") ) then return {}; end   -- not ready yet: next time
	if ( type(list) ~= "table" ) then
		-- Older game builds: still play the sound when a teammate falls, from party health.
		for i = 1, 4 do
			local u = "party" .. i;
			local down = UnitExists(u) and (UnitIsDeadOrGhost and UnitIsDeadOrGhost(u)) and true or false;
			local key = UnitExists(u) and UnitName(u) or nil;
			if ( key and down ) then current[key] = true; if ( not downed[key] ) then downed[key] = { first = now }; if ( SS.PlayDeathSound ) then SS.PlayDeathSound(); end end end
		end
		for k in pairs(downed) do if ( not current[k] ) then downed[k] = nil; end end
		return {};
	end
	local me = UnitName and UnitName("player");
	local shown = {};
	for i = 1, table.getn(list) do
		local f = list[i];
		local name = A.Field(f, "name", "playerName", "hero");
		local key = name or A.Id(f) or i;
		if ( name ~= me ) then
			current[key] = true;
			if ( not downed[key] ) then
				local slot = name and PartySlot(name) or nil;
				downed[key] = { first = now, icon = DEATH_ICONS[slot or i] or DEATH_ICONS[1] };
				if ( SS.PlayDeathSound ) then SS.PlayDeathSound(); end
			end
			table.insert(shown, { entry = f, key = key, name = name, state = downed[key] });
		end
	end
	for k in pairs(downed) do if ( not current[k] ) then downed[k] = nil; end end
	return shown;
end

-- ---------------------------------------------------------------- the marker update (every frame)
-- What to mark is gathered ten times a second; where it is on screen is worked out every frame so markers stay put
-- as the camera turns.
local gathered = { at = 0, want = {}, kinds = {} };
local LIFT = { z = 3 };                                   -- a lair's or a fallen friend's marker floats 3 yards up
local function Gather(now)
	local d = DB();
	local phase = A.Call("AZS_GetPhase");
	local inRun = phase == nil or phase == "playing" or phase == "choosing" or phase == "paused";
	local cat = (inRun and (d.bossMarks or d.prePullMarks)) and A.Catalog(now) or { byUnit = {}, byLair = {} };
	local want, kinds = {}, {};
	local function Want(anchorId, attachment, offset, kind)
		if ( anchorId == nil or kinds[anchorId] ) then return; end
		table.insert(want, { anchorId = anchorId, attachment = attachment, offset = offset });
		kinds[anchorId] = kind;
	end
	-- pulled bosses and Guardians: over their heads
	if ( inRun and d.bossMarks ) then
		local enemies = PulledEnemies();
		AssignIcons(enemies);
		for i = 1, table.getn(enemies) do
			local e = enemies[i];
			local a = cat.byUnit[e.id];
			if ( assigned[e.id] and a ) then Want(a.anchorId, "overhead", nil, { icon = assigned[e.id] }); end
		end
	else
		for id in pairs(assigned) do assigned[id] = nil; end
	end
	-- Guardians before they are pulled (over their heads), and their lairs (on the spot)
	if ( inRun and d.prePullMarks ) then
		local sleeping = SleepingGuardians();
		for i = 1, table.getn(sleeping) do
			local s = sleeping[i];
			local a = cat.byUnit[s.id];
			if ( a ) then Want(a.anchorId, "overhead", nil, { prePull = true, name = s.name }); end
		end
		local lairs = W.LairInfo(now);
		for i = 1, table.getn(lairs) do
			local l = lairs[i];
			local a = cat.byLair[l.index];
			if ( a and l.state ~= "awake" ) then
				local kind = { prePull = true, name = l.name };
				-- an empty lair is labelled with its refill countdown, so you know when to go back
				if ( l.state == "empty" ) then
					kind.name = l.refill and ("Refills in " .. W.Clock(l.refill)) or "Empty lair";
					kind.empty = true;
				end
				Want(a.anchorId, "position", LIFT, kind);
			end
		end
	end
	-- downed friends: each fall comes with its own anchor
	local friends = (d.deathMarks or d.deathSound) and DownedFriends(now) or {};
	if ( d.deathMarks ) then
		for i = 1, table.getn(friends) do
			local f = friends[i];
			local e = f.entry;
			if ( type(e) == "table" and e.anchorStatus == "ready" and e.anchorId ) then Want(e.anchorId, "position", LIFT, { friend = f }); end
		end
	end
	gathered.at, gathered.want, gathered.kinds = now, want, kinds;
end

local function UpdateMarkers()
	used = 0;
	if ( overlay:IsShown() ) then
		local now = GetTime();
		if ( now - gathered.at >= 0.1 ) then Gather(now); end
		local want, kinds = gathered.want, gathered.kinds;
		local spots = A.Project(want);
		for i = 1, table.getn(want) do
			local id = want[i].anchorId;
			local p, k = spots[id], kinds[id];
			if ( p and k ) then
				local m = Marker();
				if ( k.icon ) then
					SetRaidIcon(m.icon, k.icon);
					Show(p, SizeFor(p.dist, true), 1, nil);
				elseif ( k.prePull ) then
					m.icon:SetTexture(PRE_PULL_ICON); m.icon:SetTexCoord(0, 1, 0, 1);
					Show(p, SizeFor(p.dist, false), k.empty and 0.5 or 0.85, k.name);
				elseif ( k.friend ) then
					local st = k.friend.state;
					SetRaidIcon(m.icon, st.icon or DEATH_ICONS[1]);
					-- blink 16 times when they fall, then stay lit until they are back up
					local t = now - st.first;
					local lit = t >= DEATH_BLINKS * 0.8 or math.mod(math.floor(t / 0.4), 2) == 0;
					Show(p, SizeFor(p.dist, true), lit and 1 or 0.15, k.friend.name);
				end
			end
		end
	end
	for i = used + 1, table.getn(pool) do pool[i]:Hide(); end
end

-- Markers move in the game's world-anchor frame handler, which runs after the camera has moved each frame (OnUpdate
-- runs before, so markers would trail a frame when you turn). Older game builds: once a frame from the shared ticker.
if ( not (A.Has("AZS_RegisterWorldAnchorFrameHandler") and SS.Safe(AZS_RegisterWorldAnchorFrameHandler, function() SS.Safe(UpdateMarkers); end)) ) then
	SS.Every("markers", 0, function() SS.Safe(UpdateMarkers); end, overlay);
end

-- ---------------------------------------------------------------- debuffs on the encounter bars
local function DebuffIcon(row, i)
	row.debuffs = row.debuffs or {};
	local b = row.debuffs[i];
	if ( b ) then return b; end
	b = CreateFrame("Frame", nil, row);
	b:SetWidth(14); b:SetHeight(14);
	b:EnableMouse(true);
	b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(b); b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
	b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall");
	b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -1);
	b.time = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.time:SetPoint("TOP", b, "BOTTOM", 0, 0);
	local font, _, flags = b.time:GetFont();
	if ( font ) then b.time:SetFont(font, 8, flags); end
	b:SetScript("OnEnter", function()
		if ( not this.data or not GameTooltip ) then return; end
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT");
		GameTooltip:AddLine(this.data.name or "Debuff", 1, 0.3, 0.3);
		if ( this.data.dispel ) then GameTooltip:AddLine("Dispel type: " .. tostring(this.data.dispel), 0.7, 0.7, 1); end
		if ( this.data.stacks and this.data.stacks > 1 ) then GameTooltip:AddLine("Stacks: " .. this.data.stacks, 1, 1, 1); end
		GameTooltip:Show();
	end);
	b:SetScript("OnLeave", function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
	row.debuffs[i] = b;
	return b;
end

function W.DrawDebuffs(row, unit, vertical, enabled)
	local list = enabled and (A.Call("AZS_GetDebuffs", unit.id) or (type(unit.debuffs) == "table" and unit.debuffs)) or nil;
	local n = 0;
	if ( type(list) == "table" ) then
		for i = 1, table.getn(list) do
			local db = list[i];
			local icon = A.Field(db, "icon", "texture");
			if ( type(icon) == "string" and n < 8 ) then
				n = n + 1;
				local b = DebuffIcon(row, n);
				if ( not string.find(icon, "\\", 1, true) ) then icon = "Interface\\Icons\\" .. icon; end
				b.icon:SetTexture(icon);
				local stacks = tonumber(A.Field(db, "stacks", "count", "applications")) or 0;
				local left = not db.permanent and tonumber(db.remaining) or nil;
				b.count:SetText(stacks > 1 and tostring(stacks) or "");
				b.time:SetText(left and left > 0 and (left >= 10 and tostring(math.floor(left + 0.5)) or string.format("%.1f", left)) or "");
				b.data = { name = A.Field(db, "name", "spell"), dispel = A.Field(db, "dispel", "dispelType", "type"), stacks = stacks };
				b:ClearAllPoints();
				if ( vertical ) then b:SetPoint("TOP", row, "BOTTOM", 0, -2 - (n - 1) * 24);
				else b:SetPoint("TOPLEFT", row.bar, "BOTTOMLEFT", (n - 1) * 17, -2); end
				b:Show();
			end
		end
	end
	if ( row.debuffs ) then for i = n + 1, table.getn(row.debuffs) do row.debuffs[i]:Hide(); end end
end

-- ---------------------------------------------------------------- debuffs and DoTs on the target frame
-- On by default. Bosses and Guardians report theirs through AZS_GetDebuffs (0.93) with stacks and time left; any
-- other target uses the 1.12 UnitDebuff (icon and stacks). Nothing is drawn while the game's own target frame
-- already shows its debuffs, so they never appear twice.
local targetDebuffs = { icons = {} };
local function TargetDebuffIcon(i)
	local b = targetDebuffs.icons[i];
	if ( b ) then return b; end
	b = CreateFrame("Frame", nil, UIParent);
	b:SetWidth(17); b:SetHeight(17); b:EnableMouse(true);
	b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(b); b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
	b.border = b:CreateTexture(nil, "OVERLAY"); b.border:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1); b.border:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1);
	b.border:SetTexture("Interface\\Buttons\\UI-Debuff-Border");
	b.border:SetVertexColor(0.8, 0, 0);
	b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall");
	b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -1);
	b.time = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.time:SetPoint("TOP", b, "BOTTOM", 0, 0);
	local font, _, flags = b.time:GetFont(); if ( font ) then b.time:SetFont(font, 8, flags); end
	b:SetScript("OnEnter", function()
		if ( not GameTooltip ) then return; end
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT");
		if ( this.buff and GameTooltip.SetUnitBuff ) then GameTooltip:SetUnitBuff("target", this.buff);
		elseif ( this.index and GameTooltip.SetUnitDebuff ) then GameTooltip:SetUnitDebuff("target", this.index);
		else GameTooltip:AddLine(this.name or "Debuff", 1, 0.3, 0.3); if ( this.stacks and this.stacks > 1 ) then GameTooltip:AddLine("Stacks: " .. this.stacks, 1, 1, 1); end end
		GameTooltip:Show();
	end);
	b:SetScript("OnLeave", function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
	targetDebuffs.icons[i] = b;
	return b;
end

local function NativeTargetDebuffsShown()
	local first = getglobal("TargetFrameDebuff1");
	return first and first:IsVisible() and true or false;
end

local function UpdateTargetDebuffs()
	local list = {};
	-- the frame that shows the target: the new-school card, or the game's own frame (whose own debuffs come first)
	local card = SS.UsesCard and SS.UsesCard("TargetFrame") and getglobal("SlimSuiteTargetCard") or nil;
	local anchor = card or TargetFrame;
	if ( DB().targetDebuffs and anchor and anchor:IsVisible() and (anchor:GetAlpha() or 1) > 0.05 and UnitExists and UnitExists("target")
		and (card or not NativeTargetDebuffsShown()) ) then
		local id = type(AZS_TARGET) == "table" and AZS_TARGET.id or nil;
		local api = id ~= nil and A.Call("AZS_GetDebuffs", id) or nil;
		if ( type(api) == "table" and table.getn(api) > 0 ) then
			for i = 1, table.getn(api) do
				local db = api[i];
				local icon = A.Field(db, "icon", "texture");
				if ( type(icon) == "string" ) then
					if ( not string.find(icon, "\\", 1, true) ) then icon = "Interface\\Icons\\" .. icon; end
					table.insert(list, { icon = icon, stacks = tonumber(A.Field(db, "stacks", "count", "applications")) or 0,
						left = tonumber(A.Field(db, "left", "timeLeft", "remaining")), name = A.Field(db, "name", "spell") });
				end
			end
		elseif ( UnitDebuff ) then
			for i = 1, 16 do
				local texture, stacks = UnitDebuff("target", i);
				if ( not texture ) then break; end
				table.insert(list, { icon = texture, stacks = tonumber(stacks) or 0, index = i });
			end
		end
		-- and its buffs, after the debuffs
		if ( UnitBuff ) then
			for i = 1, 16 do
				local texture, stacks = UnitBuff("target", i);
				if ( not texture ) then break; end
				table.insert(list, { icon = texture, stacks = tonumber(stacks) or 0, buff = i });
			end
		end
	end
	local n = math.min(24, table.getn(list));
	local side = DB().targetAuraSide or "below";
	local across = side == "above" or side == "below";
	local stride = across and 19 or 22;
	local extent = across and (anchor.GetWidth and anchor:GetWidth() or 152) or (anchor.GetHeight and anchor:GetHeight() or 44);
	local perLine = math.max(1, math.floor((extent - 8) / stride));
	for i = 1, n do
		local e, b = list[i], TargetDebuffIcon(i);
		b.icon:SetTexture(e.icon);
		b.count:SetText(e.stacks > 1 and tostring(e.stacks) or "");
		b.time:SetText(e.left and e.left > 0 and (e.left >= 10 and tostring(math.floor(e.left + 0.5)) or string.format("%.1f", e.left)) or "");
		b.index, b.name, b.stacks, b.buff = e.index, e.name, e.stacks, e.buff;
		if ( e.buff ) then b.border:Hide(); else b.border:Show(); end   -- debuffs keep their red border
		if ( b:GetParent() ~= anchor ) then b:SetParent(anchor); end   -- its scale and visibility come from the target's frame
		b:ClearAllPoints();
		-- Keep icons within the frame's width above/below or its height beside it; additional rows/columns
		-- extend away from the frame in the chosen direction.
		local col, row;
		if ( across ) then col, row = math.mod(i - 1, perLine), math.floor((i - 1) / perLine);
		else col, row = math.floor((i - 1) / perLine), math.mod(i - 1, perLine); end
		local inset = card and 0 or 30;                       -- the 1.12 frame's art has empty space under it
		if ( side == "above" ) then b:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 4 + col * 19, 2 + row * 22);
		elseif ( side == "left" ) then b:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -2 - col * 19, -4 - row * 22);
		elseif ( side == "right" ) then b:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 2 + col * 19, -4 - row * 22);
		else b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4 + col * 19, -2 + inset - row * 22); end
		b:Show();
	end
	for i = n + 1, table.getn(targetDebuffs.icons) do targetDebuffs.icons[i]:Hide(); end
end

W.UpdateTargetAuras = function() SS.Safe(UpdateTargetDebuffs); end

-- ---------------------------------------------------------------- staying above the level-up and new-item cards
local ON_TOP = { "SlimSuiteWorldMarkers", "SlimSuiteMeterFrame", "SlimSuiteStoredLevelsButton", "SlimSuiteClockFrame",
	"SlimSuiteBossFrames", "SlimSuiteAnnouncementFrame", "SlimSuiteSpellRowFrame", "SlimSuiteItemRowFrame",
	"SlimSuiteTallyFrame", "SlimSuiteReviveFrame", "SlimSuiteCombatTextFrame", "SlimSuiteProcMeter",
	"SlimSuiteLocalClockFrame", "SlimSuiteFloatingText", "SlimSuiteStoreLevelsToggle", "SlimSuitePlayerCard", "SlimSuiteTargetCard",
	"SlimSuitePartyLines", "SlimSuitePartySelfFrame", "SlimSuiteMinimapBar", "SlimSuiteRaidIconPanel", "SlimSuiteStatCounterFrame" };
-- Off by default: the game's cards then cover Slim Suite like the rest of the HUD. Only when the player turns the
-- setting on are Slim Suite's frames lifted above them.
local readyOverlay = {};
local function IsOnTop(frame)
	if ( not A.Has("AZS_IsOnTopOfScreens") ) then return nil; end
	local ok, value = SS.Safe(AZS_IsOnTopOfScreens, frame);
	if ( ok ) then return value and true or false; end
end
local function PutOnTop(frame, on)
	if ( IsOnTop(frame) ~= on ) then SS.Safe(AZS_SetOnTopOfScreens, frame, on); end
end
function W.ApplyOnTop()
	if ( not A.Has("AZS_SetOnTopOfScreens") ) then return; end
	local ready = A.Call("AZS_GetPhase") == "ready";
	local on = ready or (DB().onTopOfScreens and true or false);
	local managed = {};
	for i = 1, table.getn(ON_TOP) do
		local f = getglobal(ON_TOP[i]);
		if ( f ) then
			managed[f] = true; PutOnTop(f, on);
		end
	end
	for i = 1, 64 do
		local f = getglobal("SlimSuiteEnemyNameplate" .. i);
		if ( f ) then
			managed[f] = true; PutOnTop(f, on);
		end
	end
	-- Temporary registrations include the setup/menus and stock elements under Slim Suite control.
	-- Never lift UIParent or WorldFrame: that would also lift unrelated addons and game screens.
	local wanted = {};
	local function Include(f)
		local name = f and f.GetName and f:GetName();
		if ( type(name) == "string" and name ~= "UIParent" and name ~= "WorldFrame" and not managed[f] ) then wanted[f] = true; end
	end
	if ( ready ) then
		if ( UIParent and UIParent.GetChildren ) then
			for _, f in ipairs({ UIParent:GetChildren() }) do
				local name = f.GetName and f:GetName();
				if ( type(name) == "string" and string.find(name, "^SlimSuite") ) then Include(f); end
			end
		end
		for name, mode in pairs(DB().elementModes or {}) do
			if ( mode == "enabled" ) then
				Include(getglobal(SS.Shown(name)));
				local setup = SS.ENV and SS.ENV.SU;
				if ( setup and setup.CompanionsOf ) then
					for _, companion in ipairs(setup.CompanionsOf(name)) do Include(getglobal(companion)); end
				end
			end
		end
	end
	for f, previous in pairs(readyOverlay) do
		if ( not wanted[f] ) then PutOnTop(f, previous); readyOverlay[f] = nil; end
	end
	for f in pairs(wanted) do
		if ( readyOverlay[f] == nil ) then readyOverlay[f] = IsOnTop(f) or false; end
		PutOnTop(f, true);
	end
end

-- ---------------------------------------------------------------- the movable revive bar
local revive = CreateFrame("Frame", "SlimSuiteReviveFrame", UIParent);
revive:SetWidth(220); revive:SetHeight(26);
revive:SetPoint("CENTER", UIParent, "CENTER", 0, -140);
revive:SetFrameStrata("MEDIUM");
revive:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
revive:SetBackdropColor(0.03, 0.03, 0.05, 0.85);
revive:SetBackdropBorderColor(0.7, 0.52, 0.2, 0.9);
revive.bar = CreateFrame("StatusBar", nil, revive);
revive.bar:SetPoint("TOPLEFT", revive, "TOPLEFT", 5, -5);
revive.bar:SetPoint("BOTTOMRIGHT", revive, "BOTTOMRIGHT", -5, 5);
revive.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
revive.bar:SetStatusBarColor(0.25, 0.85, 0.35);
revive.bar:SetMinMaxValues(0, 1);
revive.text = revive.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
revive.text:SetPoint("CENTER", revive.bar, "CENTER", 0, 0);
revive:Hide();

local function UpdateRevive()
	local d = DB();
	if ( not d.replaceRevive ) then revive:Hide(); SS.HideNative("revive", false); return; end
	SS.HideNative("revive", true);
	local r = A.Call("AZS_GetRevive");
	local progress, label;
	if ( type(r) == "table" ) then
		if ( tonumber(r.down) == 1 ) then                  -- you are down and a friend is bringing you back
			progress = tonumber(r.share);
			label = "Revived by " .. ((r.by and r.by ~= "") and tostring(r.by) or "a friend");
		elseif ( r.reviving and r.reviving ~= "" ) then     -- you stand over a downed friend
			progress = tonumber(r.rshare);
			label = "Reviving " .. tostring(r.reviving);
		end
	end
	if ( progress and progress > 0 ) then
		revive.bar:SetValue(math.max(0, math.min(1, progress))); revive.text:SetText(label); revive:Show();
	elseif ( Previewing("SlimSuiteReviveFrame") ) then
		local demo = SS.Demoing("SlimSuiteReviveFrame");
		local share = demo and SS.demoRevive or 0.6;
		revive.bar:SetValue(share); revive.text:SetText(demo and ("Reviving Brann  " .. math.floor(share * 100) .. "%") or "Revive bar"); revive:Show();
	else
		revive:Hide();
	end
end
W.UpdateRevive = function() SS.Safe(UpdateRevive); end

-- ---------------------------------------------------------------- class proc meter, attached under the player frame
local PROCS = {
	seal_fate = { "Combo points", 1, 0.9, 0.2 },
	soul_fire = { "Soul shards", 0.7, 0.35, 1 },
	bloodrage = { "Bloodrage", 1, 0.25, 0.15 },
	lightwell = { "Lightwell", 1, 0.95, 0.6 },
};
local proc = CreateFrame("Frame", "SlimSuiteProcMeter", PlayerFrame or UIParent);
proc:SetWidth(120); proc:SetHeight(16);
if ( PlayerFrame ) then proc:SetPoint("TOPLEFT", PlayerFrame, "BOTTOMLEFT", 104, 26); else proc:SetPoint("CENTER", UIParent, "CENTER", 0, -200); end
proc.pips = {};
proc.bar = CreateFrame("StatusBar", nil, proc);
proc.bar:SetAllPoints(proc);
proc.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
proc.bar.bg = proc.bar:CreateTexture(nil, "BACKGROUND"); proc.bar.bg:SetAllPoints(proc.bar); proc.bar.bg:SetTexture(0, 0, 0, 0.5);
proc.text = proc:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
proc.text:SetPoint("LEFT", proc, "RIGHT", 4, 0);
proc:Hide();

local function UpdateProc()
	local run = type(AZS_RUN) == "table" and AZS_RUN or nil;
	local kind = run and run.proc;
	local info = kind and PROCS[kind];
	local value, max = run and tonumber(run.pv) or 0, run and tonumber(run.pm) or 0;
	if ( DB().procMeter and (not info or max <= 0) and Previewing("SlimSuiteProcMeter") ) then
		info, value, max = PROCS.seal_fate, 3, 5;          -- a sample while it is placed or in Demo Mode
	end
	if ( not DB().procMeter or not info or max <= 0 ) then proc:Hide(); return; end
	-- under the frame that shows you: the game's player frame, the new-school card, or your place in the party
	local anchor = (SS.PlayerAnchor and SS.PlayerAnchor()) or PlayerFrame;
	if ( anchor and proc.anchor ~= anchor ) then
		proc.anchor = anchor;
		proc:SetParent(anchor);
		proc:ClearAllPoints();
		if ( anchor == PlayerFrame ) then proc:SetPoint("TOPLEFT", PlayerFrame, "BOTTOMLEFT", 104, 26);
		else proc:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -3); end
	end
	proc.text:SetText(info[1]);
	if ( max <= 10 ) then
		proc.bar:Hide();
		local gap, size = 3, math.min(14, (120 - 3 * (max - 1)) / max);
		for i = 1, 10 do
			local p = proc.pips[i];
			if ( not p and i <= max ) then
				p = proc:CreateTexture(nil, "ARTWORK"); p:SetTexture("Interface\\Buttons\\WHITE8X8"); proc.pips[i] = p;
			end
			if ( p ) then
				if ( i <= max ) then
					p:SetWidth(size); p:SetHeight(size); p:ClearAllPoints();
					p:SetPoint("LEFT", proc, "LEFT", (i - 1) * (size + gap), 0);
					if ( i <= value ) then p:SetVertexColor(info[2], info[3], info[4], 1); else p:SetVertexColor(0.15, 0.15, 0.15, 0.8); end
					p:Show();
				else p:Hide(); end
			end
		end
	else
		for i = 1, table.getn(proc.pips) do proc.pips[i]:Hide(); end
		proc.bar:SetStatusBarColor(info[2], info[3], info[4]);
		proc.bar:SetMinMaxValues(0, max); proc.bar:SetValue(value); proc.bar:Show();
		proc.text:SetText(info[1] .. " " .. math.floor(value) .. "/" .. math.floor(max));
	end
	proc:Show();
end

-- ---------------------------------------------------------------- combat text test box
-- A fixed, movable box (not floating in the world): your newest hits on top, each with its spell icon. Crits stick
-- out of the group: indented further, bigger, and they stay on screen twice as long.
local NORMAL_LIFE, CRIT_LIFE, FADE, MAX_LINES = 3, 6, 0.6, 14;
-- each option is on unless turned off in its setting (ctHeals, ctCrits, ctIcons, ctLong)
local function CTOn(key) return DB()[key] ~= false; end
local function CTLife(e) return (e.crit and CRIT_LIFE or NORMAL_LIFE) * (CTOn("ctLong") and 2 or 1); end
local box = CreateFrame("Frame", "SlimSuiteCombatTextFrame", UIParent);
box:SetWidth(260); box:SetHeight(220);
box:SetPoint("RIGHT", UIParent, "RIGHT", -260, 40);
box:SetFrameStrata("MEDIUM");
box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
box:SetBackdropColor(0.02, 0.02, 0.03, 0.55);
box:SetBackdropBorderColor(0.5, 0.4, 0.2, 0.6);
box:Hide();
box.lines, box.entries = {}, {};

local function BoxLine(i)
	local l = box.lines[i];
	if ( l ) then return l; end
	l = CreateFrame("Frame", nil, box);
	l:SetWidth(240); l:SetHeight(14);
	l.icon = l:CreateTexture(nil, "ARTWORK"); l.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
	l.icon:SetPoint("LEFT", l, "LEFT", 0, 0);
	l.text = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	l.text:SetPoint("LEFT", l.icon, "RIGHT", 4, 0);
	l.text:SetJustifyH("LEFT");
	box.lines[i] = l;
	return l;
end

local function IconFor(event)
	local icon = A.Field(event, "icon", "spellIcon", "texture");
	if ( type(icon) == "table" ) then icon = icon.path; end
	if ( type(icon) ~= "string" ) then
		local meter = SlimSuiteMeter;
		local snap = meter and meter.snapshot;
		local src = snap and snap.sources and event.meterSourceKey and snap.sources[event.meterSourceKey];
		if ( src and src.icon and src.icon.status == "ready" ) then icon = src.icon.path; end
	end
	if ( type(icon) ~= "string" ) then return "Interface\\Icons\\INV_Misc_QuestionMark"; end
	if ( not string.find(icon, "\\", 1, true) ) then icon = "Interface\\Icons\\" .. icon; end
	return icon;
end

-- Big hits: a crit, or a hit as big as the best of the last few, leaves the list and "pops": it grows to the right and
-- slowly falls away, off the screen if it gets that far. How big it grows, how far right it goes and how long it hangs
-- before falling all depend on how big it is next to your normal hits (the running average of your non-crit damage).
local recentBest = {};                                     -- the biggest damage of the last 20 hits
local function MarkBig(e)
	if ( e.heal ) then return e; end
	if ( not e.crit ) then
		box.normalAvg = box.normalAvg and (box.normalAvg * 0.9 + e.amount * 0.1) or e.amount;
	end
	table.insert(recentBest, e.amount);
	if ( table.getn(recentBest) > 20 ) then table.remove(recentBest, 1); end
	local best = 0;
	for i = 1, table.getn(recentBest) do if ( recentBest[i] > best ) then best = recentBest[i]; end end
	local top = table.getn(recentBest) >= 5 and e.amount >= best;
	if ( (e.crit or top) and CTOn("ctPop") and not DB().accessibilityReduceMotion ) then
		local normal = box.normalAvg or e.amount;
		e.pop = math.max(1, math.min(4, e.amount / math.max(1, normal)));   -- 1 = a normal-sized hit, 4 = four times or more
	end
	return e;
end
local POP_LIMIT = 6;
box.pops = {};
local function PopLine(i)
	local p = box.pops[i];
	if ( p ) then return p; end
	p = CreateFrame("Frame", nil, UIParent);
	p:SetFrameStrata("HIGH"); p:SetWidth(260); p:SetHeight(20);
	p.icon = p:CreateTexture(nil, "ARTWORK"); p.icon:SetPoint("LEFT", p, "LEFT", 0, 0); p.icon:SetWidth(15); p.icon:SetHeight(15);
	p.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
	p.text = p:CreateFontString(nil, "OVERLAY");
	p.text:SetPoint("LEFT", p.icon, "RIGHT", 4, 0); p.text:SetJustifyH("LEFT");
	p.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE");
	box.pops[i] = p;
	return p;
end
local function DrawPops(now)
	local n = 0;
	local list = box.popList or {};
	local screenBottom = -((UIParent:GetHeight() or 768) + 60);
	for i = table.getn(list), 1, -1 do
		local e = list[i];
		local r = e.pop;
		local life = 2.5 + 1.5 * r;                         -- bigger hits hang on longer
		local age = now - e.born;
		local grow = math.min(1, age / 0.35);                -- it swells in the first third of a second
		local scale = 1 + (0.05 + 0.08 * (r - 1)) * grow;   -- subtle growth for large hits
		local x = 14 + age * (8 + 5 * r);                    -- a slow drift keeps repeated hits easy to read
		local hang = 0.4 + 0.35 * r;                         -- it holds before it falls
		local fall = age > hang and (age - hang) * (age - hang) * (120 / r) or 0;   -- bigger ones fall more slowly
		local top = (box:GetTop() or 400) - (UIParent:GetTop() or 768);
		if ( age > life or top - 6 - fall < screenBottom or n >= POP_LIMIT ) then
			table.remove(list, i);
		else
			n = n + 1;
			local p = PopLine(n);
			p:SetScale((SS.EffectiveScale(box)) / (SS.EffectiveScale(UIParent)) * scale);
			p:ClearAllPoints();
			p:SetPoint("TOPLEFT", UIParent, "TOPLEFT", ((box:GetLeft() or 0) + x) / scale, (top - 6 - fall) / scale);
			p.icon:SetTexture(e.icon or nil); p.icon:SetWidth(e.icon and 15 or 0);
			p.text:SetText((e.crit and (e.amount .. "!") or tostring(e.amount)) .. "  " .. e.name);
			if ( e.crit ) then p.text:SetTextColor(1, 0.85, 0.2); else p.text:SetTextColor(1, 0.55, 0.25); end
			local fade = life - age < 0.6 and math.max(0, (life - age) / 0.6) or 1;
			p:SetAlpha(fade);
			p:Show();
		end
	end
	for i = n + 1, table.getn(box.pops) do box.pops[i]:Hide(); end
end
local function AddEntry(e)
	MarkBig(e);
	if ( e.pop ) then
		box.popList = box.popList or {};
		table.insert(box.popList, e);
		return;                                            -- it pops instead of taking a line in the list
	end
	table.insert(box.entries, 1, e);
	while ( table.getn(box.entries) > 40 ) do table.remove(box.entries); end
end

local function OnCombatEvent(event)
	if ( not DB().combatTextBox or type(event) ~= "table" or type(event.amount) ~= "number" ) then return; end
	local kind = event.kind;
	if ( kind ~= "damage" and kind ~= "heal" and kind ~= "healing" ) then return; end
	if ( kind ~= "damage" and not CTOn("ctHeals") ) then return; end
	local name = event.meterSource or event.abilityName or event.spell or event.damageType or "";
	AddEntry({ born = GetTime(), crit = event.critical == true and CTOn("ctCrits"), heal = kind ~= "damage",
		amount = math.floor(event.amount + 0.5), name = tostring(name), icon = CTOn("ctIcons") and IconFor(event) or nil });
end
if ( SlimSuiteMeter and SlimSuiteMeter.listeners ) then table.insert(SlimSuiteMeter.listeners, OnCombatEvent); end
-- Demo Mode: a sample hit or heal goes into the real box (its own options still apply to what is drawn)
function SlimSuiteWorld.DemoHit(amount, name, icon, crit, heal)
	AddEntry({ born = GetTime(), crit = crit and CTOn("ctCrits"), heal = heal and true or false,
		amount = amount, name = name, icon = CTOn("ctIcons") and icon or nil });
end

local function DrawBox()
	local d = DB();
	local editing = Editing("SlimSuiteCombatTextFrame");
	local demo = SS.Demoing("SlimSuiteCombatTextFrame");   -- Demo Mode samples only this enabled element
	local now = GetTime();
	if ( not d.combatTextBox and not editing and not demo ) then box:Hide(); box.popList = {}; DrawPops(now); return; end
	DrawPops(now);
	local list = box.entries;
	-- nothing to show (no hits yet): the box stays out of the way unless it is being placed
	if ( table.getn(list) == 0 and not editing and not demo ) then box:Hide(); return; end
	box:Show();
	if ( editing and table.getn(list) == 0 ) then
		list = { { born = now, crit = true, amount = 1234, name = "Crit example", icon = "Interface\\Icons\\Spell_Fire_Fireball02" },
			{ born = now, amount = 512, name = "Hit example", icon = "Interface\\Icons\\Spell_Frost_FrostBolt02" } };
	end
	for i = table.getn(box.entries), 1, -1 do
		local e = box.entries[i];
		if ( now - e.born > CTLife(e) ) then table.remove(box.entries, i); end
	end
	local y, n = -6, 0;
	local bottom = -(box:GetHeight() or 220) + 6;
	for i = 1, table.getn(list) do
		local e = list[i];
		local h = e.crit and 24 or 15;
		if ( n >= MAX_LINES or y - h < bottom ) then break; end
		n = n + 1;
		local l = BoxLine(n);
		local life = CTLife(e);
		local age = now - e.born;
		local alpha = 1;
		if ( age > life - FADE ) then alpha = math.max(0, (life - age) / FADE); end
		l:ClearAllPoints();
		l:SetPoint("TOPLEFT", box, "TOPLEFT", e.crit and 26 or 8, y);
		l:SetWidth((box:GetWidth() or 260) - (e.crit and 30 or 12)); l:SetHeight(h);
		l.icon:SetWidth(e.icon and (h - 2) or 0); l.icon:SetHeight(h - 2); l.icon:SetTexture(e.icon or nil);
		l.text:SetFontObject(e.crit and NumberFontNormalLarge or GameFontHighlightSmall);
		l.text:SetText((e.crit and (e.amount .. "!") or tostring(e.amount)) .. "  " .. e.name);
		if ( e.heal ) then l.text:SetTextColor(0.3, 1, 0.4);
		elseif ( e.crit ) then l.text:SetTextColor(1, 0.85, 0.2);
		else l.text:SetTextColor(1, 1, 1); end
		l:SetAlpha(alpha);
		l:Show();
		y = y - h - 1;
	end
	for i = n + 1, table.getn(box.lines) do box.lines[i]:Hide(); end
end

-- ---------------------------------------------------------------- lairs and their refill timer
-- A lair is asleep (its Guardian waits), awake (its Guardian is fighting) or empty (game guide). An empty lair fills
-- again after 3:00 (patch 0.27.0, "was 2:30"). AZS_LAIRS entries carry x, y, z and a flag field (0.97, 0.102).
-- If the game gives its own refill time, that is used; otherwise Slim Suite starts a 3:00 timer the moment it
-- sees a lair go empty. A timer started that way is only known from that moment on (not after a /reload mid-wait).
local LAIR_REFILL = 180;
local lairEmptySince = {};                                -- lair id -> GetTime() when it was first seen empty

function A.Lairs()
	return type(AZS_LAIRS) == "table" and AZS_LAIRS or {};
end
-- "asleep", "awake" or "empty"
function A.LairState(l)
	local st = type(l.state) == "string" and string.lower(l.state) or "";
	if ( st == "empty" or st == "awake" ) then return st; end
	return "asleep";
end
-- seconds until an empty lair fills again ("left"), else Slim Suite's own 3:00 count, else nil
function A.LairRefill(l, key, now)
	local left = tonumber(l.left);
	if ( left and left >= 0 ) then return left; end
	local since = lairEmptySince[key];
	if ( since ) then return math.max(0, LAIR_REFILL - (now - since)); end
	return nil;
end
function W.LairInfo(now)
	local list, seen = {}, {};
	local lairs = A.Lairs();
	for i = 1, table.getn(lairs) do
		local l = lairs[i];
		if ( type(l) == "table" ) then
			local key = l.index or i;                      -- the lair's own number (its guardian id is 0 while empty)
			local state = A.LairState(l);
			seen[key] = true;
			if ( state == "empty" ) then
				if ( not lairEmptySince[key] ) then lairEmptySince[key] = now; end
			else
				lairEmptySince[key] = nil;
			end
			table.insert(list, { index = key, id = l.id, entry = l, state = state, flagged = tonumber(l.flag) == 1,
				name = (l.name and l.name ~= "") and l.name or "Lair",
				refill = state == "empty" and A.LairRefill(l, key, now) or nil });
		end
	end
	for key in pairs(lairEmptySince) do if ( not seen[key] ) then lairEmptySince[key] = nil; end end
	return list;
end
local function Clock(sec) sec = math.floor(sec + 0.5); return string.format("%d:%02d", math.floor(sec / 60), math.mod(sec, 60)); end
W.Clock = Clock;

-- ---------------------------------------------------------------- minimap pins: caches, bosses and lairs (separate settings)
-- Positions are in the game's yards (AZS_RUN px/py and the caches' and lairs' x/y share them, per patch 0.97).
-- Pins are fixed to their spot in the world: they are placed every frame from your hero's position, so they glide
-- with the minimap instead of stepping. A lair out of the minimap's range is simply not shown; caches and bosses out
-- of range wait on the rim, pointing the way.
-- North is +x and west is +y, as the game's addon docs fix them.
-- the 1.12 minimap's diameter in yards at each zoom level, outdoors and indoors
local OUTDOOR = { [0] = 466.67, 400, 333.33, 266.67, 200, 133.33 };
local INDOOR = { [0] = 300, 240, 180, 120, 80, 50 };

function A.Pos(t)
	if ( type(t) ~= "table" ) then return nil; end
	local x, y = A.Field(t, "x", "wx", "worldX"), A.Field(t, "y", "wy", "worldY");
	if ( type(x) ~= "number" or type(y) ~= "number" ) then
		local p = A.Field(t, "pos", "position", "world");
		if ( type(p) == "table" ) then x, y = A.Field(p, "x", 1), A.Field(p, "y", 2); end
	end
	if ( type(x) == "number" and type(y) == "number" ) then return x, y; end
	return nil;
end
-- the caches on the field: AZS_CHESTS
function A.Caches()
	return type(AZS_CHESTS) == "table" and AZS_CHESTS or {};
end

-- Your hero's position this frame (AZS_GetPlayerPosition, every map), with its coordinate space: a cache's or a lair's
-- x, y is used only when its spaceId is yours. Older game builds: AZS_RUN's position, carried forward between its
-- twice-a-second updates so pins do not jump.
local hero = { at = 0, vx = 0, vy = 0 };
function A.PlayerPos()
	local p = A.Call("AZS_GetPlayerPosition");
	if ( type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" ) then return p.x, p.y, p.spaceId; end
	if ( A.Has("AZS_GetPlayerPosition") ) then return nil; end   -- not ready (a loading screen): no pins this frame
	local run = type(AZS_RUN) == "table" and AZS_RUN or nil;
	if ( not run or type(run.px) ~= "number" or type(run.py) ~= "number" ) then return nil; end
	local now = GetTime();
	if ( run.px ~= hero.x or run.py ~= hero.y ) then
		if ( hero.x and now - hero.at > 0.02 and now - hero.at < 1 ) then
			hero.vx, hero.vy = (run.px - hero.x) / (now - hero.at), (run.py - hero.y) / (now - hero.at);
		else hero.vx, hero.vy = 0, 0; end
		hero.x, hero.y, hero.at = run.px, run.py, now;
	end
	local t = math.min(now - hero.at, 0.25);
	if ( now - hero.at > 0.4 ) then hero.vx, hero.vy = 0, 0; end
	return hero.x + hero.vx * t, hero.y + hero.vy * t;
end
-- the same coordinate space as yours (an entry without one, from an old build, is taken as yours)
local function SameSpace(entry, space)
	return space == nil or type(entry) ~= "table" or entry.spaceId == nil or entry.spaceId == space;
end

-- north and west in yards from a world offset: the docs fix the axes (+x north, +y west), and the 1.12 minimap keeps
-- north up
local function Bearing(dx, dy) return dx, dy; end

-- Indoors or out: the 1.12 minimap keeps a zoom for each (the minimapZoom and minimapInsideZoom settings). When both
-- are the same, a quick zoom nudge shows which one follows. Checked when the zoom or the zone changes, not each frame.
local indoors = false;
local nudgedAt = 0;
local function CheckIndoors(mayNudge)
	if ( not Minimap or not GetCVar ) then return; end
	local zoom = Minimap:GetZoom() or 0;
	local out, ins = tonumber(GetCVar("minimapZoom")), tonumber(GetCVar("minimapInsideZoom"));
	if ( out and ins and out ~= ins ) then indoors = ins == zoom; return; end
	-- only on a zone change, never in answer to a zoom event (the nudge itself is one)
	if ( not mayNudge or GetTime() - nudgedAt < 2 ) then return; end
	nudgedAt = GetTime();
	local test = zoom < 5 and zoom + 1 or zoom - 1;
	Minimap:SetZoom(test);
	indoors = tonumber(GetCVar("minimapInsideZoom")) == test;
	Minimap:SetZoom(zoom);
end
local zoomWatch = CreateFrame("Frame");
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "MINIMAP_UPDATE_ZOOM" }) do
	SS.Safe(zoomWatch.RegisterEvent, zoomWatch, e);
end
zoomWatch:SetScript("OnEvent", function()
	if ( GetTime() - nudgedAt < 2 and event == "MINIMAP_UPDATE_ZOOM" ) then return; end
	SS.Safe(CheckIndoors, event ~= "MINIMAP_UPDATE_ZOOM");
end);

local pins, pinUsed = {}, 0;
local function Pin()
	pinUsed = pinUsed + 1;
	local p = pins[pinUsed];
	if ( not p ) then
		p = CreateFrame("Frame", nil, Minimap);
		p:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 5);
		p:EnableMouse(true);
		p.icon = p:CreateTexture(nil, "OVERLAY"); p.icon:SetAllPoints(p);
		p.label = p:CreateFontString(nil, "OVERLAY");
		p.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 9);
		p.label:SetShadowColor(0, 0, 0, 1); p.label:SetShadowOffset(1, -1);
		p.label:SetTextColor(0.88, 0.82, 0.72);
		p.label:SetPoint("LEFT", p, "RIGHT", 1, 0);
		p:SetScript("OnEnter", function()
			if ( not GameTooltip or not this.tip ) then return; end
			GameTooltip:SetOwner(this, "ANCHOR_LEFT");
			GameTooltip:AddLine(this.tip, 1, 0.82, 0);
			if ( this.sub ) then GameTooltip:AddLine(this.sub, 1, 1, 1); end
			if ( this.dist ) then GameTooltip:AddLine(math.floor(this.dist + 0.5) .. " yards away", 1, 1, 1); end
			GameTooltip:Show();
		end);
		p:SetScript("OnLeave", function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
		pins[pinUsed] = p;
	end
	return p;
end

-- Place one pin. Returns nil when the spot is out of range and the pin should not show there.
local function PlacePin(px, py, t)
	local north, west = Bearing(t.x - px, t.y - py);
	local zoom = Minimap:GetZoom() or 0;
	local yards = ((indoors and INDOOR[zoom]) or OUTDOOR[zoom] or 466.67) / 2;
	local radius = (Minimap:GetWidth() or 140) / 2;
	local dist = math.sqrt(north * north + west * west);
	local dx, dy = -west / yards * radius, north / yards * radius;
	local outside = dist > yards * 0.94;
	if ( outside and not t.rim ) then return nil; end
	local p = Pin();
	if ( outside and dist > 0 ) then
		local k = (radius - 6) / math.sqrt(dx * dx + dy * dy);
		dx, dy = dx * k, dy * k;
	end
	local size = outside and t.size * 0.8 or t.size;
	p:SetWidth(size); p:SetHeight(size);
	p:SetAlpha((t.alpha or 1) * (outside and 0.7 or 1));
	p:ClearAllPoints();
	p:SetPoint("CENTER", Minimap, "CENTER", dx, dy);
	p.icon:SetTexture(t.texture);
	if ( t.raid ) then SetRaidIcon(p.icon, t.raid); elseif ( t.crop ) then p.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); else p.icon:SetTexCoord(0, 1, 0, 1); end
	p.icon:SetVertexColor(t.r or 1, t.g or 1, t.b or 1);
	if ( p.icon.SetDesaturated ) then p.icon:SetDesaturated(t.grey and 1 or nil); end
	p.label:SetText(outside and "" or (t.label or ""));
	p.tip, p.sub, p.dist = t.tip, t.sub, dist;
	p:Show();
	return p;
end

-- What to pin is gathered ten times a second; pins are placed every frame.
local targets = {};
local function GatherPins(space)
	targets = {};
	local d = DB();
	local phase = A.Call("AZS_GetPhase");
	local inRun = phase == nil or phase == "playing" or phase == "choosing" or phase == "paused";
	if ( SS.Demoing("MinimapCluster") and Minimap and type(W.demoPins) == "table" ) then
		-- Demo Mode: sample caches sitting still and sample bosses (with their marks) walking about, around you
		for i = 1, table.getn(W.demoPins) do table.insert(targets, W.demoPins[i]); end
		return;
	end
	if ( not Minimap or not inRun ) then return; end
	if ( d.minimapCaches ) then
		local caches = A.Caches();
		for i = 1, table.getn(caches) do
			local c = caches[i];
			local x, y = A.Pos(c);
			if ( x and SameSpace(c, space) ) then
				table.insert(targets, { x = x, y = y, size = 13, rim = true, crop = true, texture = "Interface\\Icons\\INV_Box_02", tip = "Cache" });
			end
		end
	end
	if ( d.minimapLairs ) then
		local lairs = W.LairInfo(GetTime());
		for i = 1, table.getn(lairs) do
			local l = lairs[i];
			local x, y = A.Pos(l.entry);
			if ( x and SameSpace(l.entry, space) ) then
				local t = { x = x, y = y, size = l.flagged and 13 or 11, texture = PRE_PULL_ICON, tip = l.name };
				if ( l.state == "awake" ) then
					t.r, t.g, t.b, t.sub = 1, 0.3, 0.25, "Awake: its Guardian is fighting";
				elseif ( l.state == "empty" ) then
					t.grey, t.alpha = true, 0.75;
					if ( l.refill ) then t.label = Clock(l.refill); t.sub = "Empty: fills again in " .. Clock(l.refill);
					else t.sub = "Empty: fills again within 3:00"; end
				else
					t.sub = "Asleep: its Guardian waits";
				end
				if ( l.flagged ) then t.sub = t.sub .. "\n(the game's red flag points here)"; end
				table.insert(targets, t);
			end
		end
	end
	if ( d.minimapBosses ) then
		-- a boss's place comes from the world-anchor catalog (AZS_GetBosses carries no position)
		local bosses = A.Call("AZS_GetBosses");
		local cat = A.Catalog(GetTime());
		if ( type(bosses) == "table" ) then
			for i = 1, table.getn(bosses) do
				local b = bosses[i];
				local a = type(b) == "table" and b.id ~= nil and cat.byUnit[b.id] or nil;
				if ( a and a.positionAvailable and SameSpace(a, space) ) then
					-- the boss's own marker icon when it has one, else a skull
					table.insert(targets, { x = a.x, y = a.y, size = 15, rim = true, texture = RAID_ICONS,
						raid = assigned[b.id] or 8, tip = b.name or "Boss" });
				end
			end
		end
	end
end

local pinGather = 0;
local function UpdateMinimapPins()
	local d = DB();
	if ( not (d.minimapCaches or d.minimapBosses or d.minimapLairs or SS.Demoing("MinimapCluster")) ) then
		if ( pinUsed > 0 ) then for i = 1, table.getn(pins) do pins[i]:Hide(); end pinUsed = 0; end
		return;
	end
	local now = GetTime();
	pinUsed = 0;
	local px, py, space = A.PlayerPos();
	if ( SS.Demoing("MinimapCluster") and not px ) then px, py = 0, 0; end   -- Demo Mode samples use the player's map centre
	if ( now >= pinGather ) then pinGather = now + 0.1; GatherPins(space); end
	if ( px and Minimap and Minimap:IsVisible() ) then
		for i = 1, table.getn(targets) do PlacePin(px, py, targets[i]); end
	end
	for i = pinUsed + 1, table.getn(pins) do pins[i]:Hide(); end
end
local pinDriver = CreateFrame("Frame");
SS.Every("pins", 0, function() SS.Safe(UpdateMinimapPins); end, pinDriver);

-- ---------------------------------------------------------------- movable local clock (0.136)
-- AZS_GetLocalTime() gives the clock's text, hour, minute and format, even with the clock or minimap hidden and out of
-- a run. While this is on, the game's own clock under the minimap is hidden with AZS_SetHudShown("localClock", false).
-- It is drawn like the game's own clock: cream text in the game's font on a dark see-through box with soft edges
-- and no border. The right-click menu can remove the box, switch between 12- and 24-hour time and shift the time an
-- hour for daylight saving.
local CLOCK_TEXT, CLOCK_BOX = { 0.88, 0.82, 0.72 }, 0.6;
local clock = CreateFrame("Frame", "SlimSuiteLocalClockFrame", UIParent);
clock:SetWidth(60); clock:SetHeight(20);
if ( Minimap ) then clock:SetPoint("TOP", Minimap, "BOTTOM", 0, -2); else clock:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -60, -170); end
clock:SetFrameStrata("MEDIUM");
clock.left = clock:CreateTexture(nil, "BACKGROUND");
clock.left:SetPoint("TOPLEFT", clock, "TOPLEFT", 0, 0); clock.left:SetPoint("BOTTOMLEFT", clock, "BOTTOMLEFT", 0, 0); clock.left:SetWidth(5);
clock.right = clock:CreateTexture(nil, "BACKGROUND");
clock.right:SetPoint("TOPRIGHT", clock, "TOPRIGHT", 0, 0); clock.right:SetPoint("BOTTOMRIGHT", clock, "BOTTOMRIGHT", 0, 0); clock.right:SetWidth(5);
clock.bg = clock:CreateTexture(nil, "BACKGROUND");
clock.bg:SetPoint("TOPLEFT", clock.left, "TOPRIGHT", 0, 0); clock.bg:SetPoint("BOTTOMRIGHT", clock.right, "BOTTOMLEFT", 0, 0);
for _, t in ipairs({ clock.bg, clock.left, clock.right }) do t:SetTexture(1, 1, 1, 1); t:SetVertexColor(0, 0, 0, CLOCK_BOX); end
if ( clock.left.SetGradientAlpha ) then
	clock.left:SetGradientAlpha("HORIZONTAL", 0, 0, 0, 0, 0, 0, 0, CLOCK_BOX);
	clock.right:SetGradientAlpha("HORIZONTAL", 0, 0, 0, CLOCK_BOX, 0, 0, 0, 0);
end
clock.text = clock:CreateFontString(nil, "OVERLAY");
clock.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13);
clock.text:SetShadowColor(0, 0, 0, 1); clock.text:SetShadowOffset(1, -1);
clock.text:SetTextColor(CLOCK_TEXT[1], CLOCK_TEXT[2], CLOCK_TEXT[3]);
clock.text:SetPoint("CENTER", clock, "CENTER", 0, 0);
clock:Hide();

-- The game's time as hour (0-23) and minute, and whether the game shows it as 24-hour. AZS_GetLocalTime gives the
-- clock's text, hour, minute and format (0.136); if only the text comes back, it is read as "7:09 PM" or "19:09".
local function GameTime()
	local t = A.Call("AZS_GetLocalTime");
	local text, h, m, fmt;
	if ( type(t) == "string" ) then text = t;
	elseif ( type(t) == "table" ) then
		text = A.Field(t, "text", "label");
		h, m = tonumber(A.Field(t, "hour", "h")), tonumber(A.Field(t, "minute", "min", "m"));
		fmt = t.is24Hour;
	end
	local is24;
	if ( type(fmt) == "boolean" ) then is24 = fmt; end
	if ( (not h or not m) and type(text) == "string" ) then
		local _, _, hh, mm, ampm = string.find(text, "(%d+):(%d+)%s*([AaPp]?[Mm]?)");
		h, m = tonumber(hh), tonumber(mm);
		if ( h and ampm and ampm ~= "" ) then
			local pm = string.upper(string.sub(ampm, 1, 1)) == "P";
			if ( pm and h < 12 ) then h = h + 12; elseif ( not pm and h == 12 ) then h = 0; end
			if ( is24 == nil ) then is24 = false; end
		elseif ( h and is24 == nil ) then is24 = true; end
	end
	if ( h and m ) then return h, m, is24 ~= false, text; end
	return nil, nil, nil, text;
end

-- what the right-click menu shows for the clock
function W.ClockIs24()
	local mode = DB().localClock24;
	if ( mode ~= nil ) then return mode and true or false; end
	local _, _, gameIs24 = GameTime();
	return gameIs24 and true or false;
end

-- The hour that daylight saving adds to the clock. Automatic (the setting not set) follows the computer's own clock,
-- which knows the zone's rules and whether daylight saving is in effect today; otherwise +1, -1 or off as chosen.
function W.DaylightOffset()
	local v = DB().localClockDST;
	if ( v ~= nil ) then return tonumber(v) or 0; end
	if ( type(date) == "function" ) then
		local ok, t = pcall(date, "*t");
		if ( ok and type(t) == "table" and t.isdst ) then return 1; end
	end
	return 0;
end

local function LocalTimeText()
	local h, m, gameIs24, text = GameTime();
	if ( not h ) then return text; end
	h = math.mod(h + W.DaylightOffset() + 24, 24);
	local use24 = DB().localClock24;
	if ( use24 == nil ) then use24 = gameIs24; end
	if ( use24 ) then return string.format("%02d:%02d", h, m); end
	local suffix = h >= 12 and " PM" or " AM";
	local h12 = math.mod(h, 12); if ( h12 == 0 ) then h12 = 12; end
	return string.format("%d:%02d%s", h12, m, suffix);
end

local function UpdateLocalClock()
	local editing = Editing("SlimSuiteLocalClockFrame");
	if ( not DB().replaceLocalClock ) then clock:Hide(); SS.HideNative("localClock", false); return; end
	local text = LocalTimeText();
	if ( not text and not editing ) then clock:Hide(); SS.HideNative("localClock", false); return; end
	SS.HideNative("localClock", true);
	clock.text:SetText(text or "7:09 PM");
	local band = DB().localClockBackground ~= false;
	if ( band ) then clock.bg:Show(); clock.left:Show(); clock.right:Show(); else clock.bg:Hide(); clock.left:Hide(); clock.right:Hide(); end
	local custom = DB().sizes and DB().sizes.SlimSuiteLocalClockFrame;
	local w, h = (clock.text:GetStringWidth() or 40) + 18, 20;
	if ( type(custom) == "table" and custom.w and custom.h ) then w, h = custom.w, custom.h; end   -- the size set is the size
	clock:SetWidth(w); clock:SetHeight(h);
	if ( SS.FitText ) then SS.FitText(clock.text, math.max(10, w - 10)); end   -- the time shrinks to fit a small box
	clock:Show();
end
W.UpdateLocalClock = function() SS.Safe(UpdateLocalClock); end

-- the local clock either hangs under the minimap or stands alone (then it gets its own button in the setup bar)
W.SetClockDetached = function(on)
	local db = SS.DB();
	if ( on ) then
		local l, b = clock:GetLeft(), clock:GetBottom();
		clock:ClearAllPoints();
		if ( l and b ) then clock:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b);
		else clock:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -60, -170); end
	else
		if ( db.places ) then db.places.SlimSuiteLocalClockFrame = nil; end
		clock:ClearAllPoints();
		if ( Minimap ) then clock:SetPoint("TOP", Minimap, "BOTTOM", 0, -2);
		else clock:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -60, -170); end
	end
	SS.Safe(UpdateLocalClock);
end

-- ---------------------------------------------------------------- floating combat text (0.138)
-- Each of your hits floats up from the enemy it struck, stays over the spot where an enemy fell, and hides when that
-- spot leaves your view. Text is sized by distance. Crits are bigger, pop, and stay twice as long. Positions are
-- worked out in AZS_RegisterCombatTextFrameHandler (after the camera moves each frame) so numbers never trail behind.
-- Each event carries its anchor as event.anchorId; AZS_ProjectCombatTextAnchors(list) answers like
-- AZS_ProjectWorldAnchors (x, y, onScreen, distance), matched back by anchor id (or by order if it gives none).
local FLOAT_LIFE, FLOAT_CRIT_LIFE, FLOAT_RISE = 1.1, 2.2, 46;
local floatLayer = CreateFrame("Frame", "SlimSuiteFloatingText", UIParent);
floatLayer:SetAllPoints(UIParent);
floatLayer:SetFrameStrata("LOW");
floatLayer:EnableMouse(false);
local floats, floatPool = {}, {};

-- an event's anchor: a handle the game says is ready, else none (never a place the game does not know)
local function FloatAnchor(event)
	if ( event.anchorStatus ~= nil and event.anchorStatus ~= "ready" ) then return nil; end
	return event.anchorId;
end

local function OnFloatEvent(event)
	if ( not DB().floatingText or type(event) ~= "table" or event.kind ~= "damage" or type(event.amount) ~= "number" ) then return; end
	local anchor = FloatAnchor(event);
	if ( not anchor ) then return; end
	local now = GetTime();
	local born = tonumber(event.presentedAt) or now;
	if ( now - born > FLOAT_LIFE ) then return; end      -- a delayed batch's old hit: not shown
	if ( table.getn(floats) >= 60 ) then table.remove(floats, 1); end
	table.insert(floats, { anchor = anchor, born = born, crit = event.critical == true,
		text = tostring(math.floor(event.amount + 0.5)), icon = IconFor(event),
		drift = math.mod(table.getn(floats), 5) * 9 - 18,
		kind = event.targetUnitId ~= nil and SS.UnitKind(event.targetUnitId) or nil });
end
if ( SlimSuiteMeter and SlimSuiteMeter.listeners ) then table.insert(SlimSuiteMeter.listeners, OnFloatEvent); end

local function FloatText(i)
	local f = floatPool[i];
	if ( f ) then return f; end
	f = CreateFrame("Frame", nil, floatLayer);
	f:SetWidth(120); f:SetHeight(24);
	f.text = f:CreateFontString(nil, "OVERLAY");
	f.text:SetPoint("CENTER", f, "CENTER", 8, 0);
	f.icon = f:CreateTexture(nil, "ARTWORK"); f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
	f.icon:SetPoint("RIGHT", f.text, "LEFT", -3, 0);
	floatPool[i] = f;
	return f;
end

local floatIds, floatById, NONE = {}, {}, {};
local function DrawFloats()
	if ( DB().floatingText and SlimSuiteMeter and SlimSuiteMeter.Drain ) then SS.Safe(SlimSuiteMeter.Drain); end
	local now = GetTime();
	for i = table.getn(floats), 1, -1 do
		local e = floats[i];
		if ( now - e.born > (e.crit and FLOAT_CRIT_LIFE or FLOAT_LIFE) ) then table.remove(floats, i); end
	end
	local n = table.getn(floats);
	if ( n == 0 or not DB().floatingText ) then
		for i = 1, table.getn(floatPool) do floatPool[i]:Hide(); end
		return;
	end
	-- AZS_ProjectCombatTextAnchors(ids, "follow"): over the living enemy, then where it fell
	-- the lists below are kept and refilled each frame, not made new
	local ids = floatIds;
	for i = 1, n do ids[i] = floats[i].anchor; end
	for i = table.getn(ids), n + 1, -1 do table.remove(ids, i); end
	local result = A.Call("AZS_ProjectCombatTextAnchors", ids, "follow");
	local entries = type(result) == "table" and type(result.entries) == "table" and result.entries or NONE;
	-- each reply is matched to its hit by the anchor id it carries; a reply without ids is taken in the order asked
	local byId;
	for id in pairs(floatById) do floatById[id] = nil; end
	for i = 1, table.getn(entries) do
		local id = type(entries[i]) == "table" and entries[i].anchorId;
		if ( id ~= nil ) then byId = floatById; byId[id] = entries[i]; end
	end
	local scale = SS.EffectiveScale(UIParent);
	local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF";
	local shown = 0;
	for i = 1, n do
		local e = floats[i];
		local p;
		if ( byId ) then p = byId[e.anchor]; else p = entries[i]; end
		local x, y = p and p.x, p and p.y;
		if ( p and p.state == "onScreen" and type(x) == "number" and type(y) == "number" ) then
			shown = shown + 1;
			local f = FloatText(shown);
			local life = e.crit and FLOAT_CRIT_LIFE or FLOAT_LIFE;
			local t = (now - e.born) / life;
			local dist = tonumber(p.playerDistance);
			local near = dist and math.max(0.6, math.min(1.25, 1.35 - dist / 90)) or 1;
			local reduceMotion = DB().accessibilityReduceMotion and true or false;
			local pop = (not reduceMotion and e.crit and t < 0.12) and (1.3 - t * 2.5) or 1;
			local size = math.floor((e.crit and 22 or 14) * near * pop + 0.5);
			size = math.max(8, size);
			if ( f.fontSize ~= size ) then f.fontSize = size; f.text:SetFont(font, size, "OUTLINE"); end
			f.text:SetText(e.crit and (e.text .. "!") or e.text);
			if ( e.crit ) then f.text:SetTextColor(1, 0.82, 0.15);
			elseif ( e.kind == "boss" or e.kind == "final" ) then f.text:SetTextColor(1, 0.6, 0.3);
			else f.text:SetTextColor(1, 1, 1); end
			f.icon:SetWidth(size); f.icon:SetHeight(size); f.icon:SetTexture(e.icon);
			f:ClearAllPoints();
			f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale + (reduceMotion and 0 or e.drift), y / scale + 20 + (reduceMotion and 0 or t * FLOAT_RISE * near));
			f:SetAlpha(t > 0.7 and math.max(0, (1 - t) / 0.3) or 1);
			f:Show();
		end
	end
	for i = shown + 1, table.getn(floatPool) do floatPool[i]:Hide(); end
end

if ( not (A.Has("AZS_RegisterCombatTextFrameHandler") and SS.Safe(AZS_RegisterCombatTextFrameHandler, function() SS.Safe(DrawFloats); end)) ) then
	SS.Every("floats", 0, function() SS.Safe(DrawFloats); end, floatLayer);
end

-- ---------------------------------------------------------------- boss and Guardian kills this run
-- For the Kills / Gold / Cache tally. The game's run summary counts bosses and Guardians only once a run ends, so
-- during a run Slim Suite counts them itself: a boss or Guardian it saw in AZS_UNITS counts as killed once it is seen
-- at 3% health or lower (or dead), so one the game takes off the list the moment it dies is still counted. One that
-- leaves the list with more health left (out of range, despawned, walked off) is never counted. Each is counted once.
-- If the game ever puts its own counts in AZS_RUN, those are used instead.
-- The counts are kept in the saved settings per run, so they survive a /reload.
local tally = { bosses = 0, guardians = 0, alive = {}, counted = {}, soundPlayed = {}, run = nil, lastKills = nil };
SS.KILL_PERCENT = 3;                                       -- at or under this much health, a boss or Guardian is as good as dead
local function BossKillSoundOnce(id)
	if ( tally.soundPlayed[id] ) then return; end
	tally.soundPlayed[id] = true;
	if ( SS.PlayBossKillSound ) then SS.PlayBossKillSound(); end
end
local function CountKill(id, kind, confirmed)
	if ( tally.counted[id] ) then if ( confirmed ) then BossKillSoundOnce(id); end; return; end
	tally.counted[id] = true;
	if ( kind == "boss" ) then tally.bosses = tally.bosses + 1; else tally.guardians = tally.guardians + 1; end
	if ( confirmed ) then BossKillSoundOnce(id); end
end

-- AZS_CHESTS lists caches waiting to be opened. A cache disappearing in the same run means it was opened;
-- remember ids so unrelated full-list refreshes cannot replay the sound for an already opened cache.
local chestSoundState = { run = nil, known = nil };
local function TrackChestOpens()
	local phase = A.Call("AZS_GetPhase");
	if ( phase ~= "playing" and phase ~= "choosing" and phase ~= "paused" ) then return; end
	local run = type(AZS_RUN) == "table" and AZS_RUN or nil;
	local context = A.Call("AZS_GetMeterContext");
	local runId = (run and run.run) or (type(context) == "table" and context.runId);
	if ( runId == nil ) then return; end
	runId = tostring(runId);
	local caches, current = A.Caches(), {};
	for i = 1, table.getn(caches) do
		local cache = caches[i];
		if ( type(cache) == "table" and cache.id ~= nil ) then current[cache.id] = true; end
	end
	if ( chestSoundState.run == runId and chestSoundState.known ) then
		for id in pairs(chestSoundState.known) do
			if ( not current[id] ) then
				if ( SS.PlayChestOpenSound ) then SS.PlayChestOpenSound(); end
				break;
			end
		end
	end
	chestSoundState.run, chestSoundState.known = runId, current;
end

local function TrackKills()
	local run = type(AZS_RUN) == "table" and AZS_RUN or nil;
	local phase = A.Call("AZS_GetPhase");
	local playing = phase == "playing" or phase == "choosing" or phase == "paused";
	local ctx = A.Call("AZS_GetMeterContext");
	local key = type(ctx) == "table" and ctx.runId or nil;
	local kills = run and tonumber(run.kills) or nil;
	-- a new run: its id changes, or the run's kill count goes back down
	if ( (key ~= nil and key ~= tally.run) or (kills and tally.lastKills and kills < tally.lastKills) ) then
		local saved = DB().runKills;
		if ( key ~= nil and type(saved) == "table" and saved.run == key ) then
			tally.bosses, tally.guardians = tonumber(saved.bosses) or 0, tonumber(saved.guardians) or 0;
		else
			tally.bosses, tally.guardians = 0, 0;
		end
		tally.alive, tally.counted, tally.soundPlayed, tally.run = {}, {}, {}, key;
	end
	tally.lastKills = kills;
	if ( not playing ) then tally.alive = {}; return; end
	local units = type(AZS_UNITS) == "table" and AZS_UNITS or {};
	local seen, any = {}, false;
	for i = 1, table.getn(units) do
		local u = units[i];
		if ( type(u) == "table" and u.id ~= nil ) then
			any = true;
			local kind = SS.UnitKind(u);
			local boss = kind == "boss" or kind == "final";
			if ( boss or kind == "guardian" ) then
				seen[u.id] = true;
				local what = boss and "boss" or "guardian";
				local hp, hpm = tonumber(u.hp), tonumber(u.hpm);
				local pct = (hp and hpm and hpm > 0) and hp * 100 / hpm or nil;
				local confirmed = (hp and hp <= 0) or u.dead;
				local low = pct and pct <= SS.KILL_PERCENT or false;
				if ( confirmed or low ) then CountKill(u.id, what, confirmed and true or false); end
				-- Keep a low-health special enemy tracked until it disappears from the live list. The
				-- tally can count at 3%, but the optional kill sound waits for confirmed death/disappearance.
				tally.alive[u.id] = { kind = what, low = low };
			end
		end
	end
	-- gone from the list: no longer followed; an empty list (a loading screen) changes nothing
	if ( any ) then
		for id in pairs(tally.alive) do
			if ( not seen[id] ) then
				local previous = tally.alive[id];
				if ( type(previous) == "table" and previous.low ) then BossKillSoundOnce(id); end
				tally.alive[id] = nil;
			end
		end
	end
	local saved = DB().runKills;
	if ( type(saved) ~= "table" ) then saved = {}; DB().runKills = saved; end
	saved.run, saved.bosses, saved.guardians = key, tally.bosses, tally.guardians;
end

-- bosses, guardians slain this run
function W.RunKills()
	local run = type(AZS_RUN) == "table" and AZS_RUN or nil;
	local b = run and tonumber(A.Field(run, "bossKills", "bossesKilled", "bk"));
	local g = run and tonumber(A.Field(run, "guardianKills", "guardiansKilled", "gk"));
	return b or tally.bosses, g or tally.guardians;
end

-- ---------------------------------------------------------------- tickers
local ticker = CreateFrame("Frame");
SS.Every("box", 0.05, function() SS.Safe(DrawBox); end);
SS.Every("tracker", 0.1, function()
	SS.Safe(TrackKills);
	SS.Safe(TrackChestOpens);
	SS.Safe(UpdateTargetDebuffs);
	SS.Safe(UpdateRevive);
	SS.Safe(UpdateProc);
end);
SS.Every("localClock", 0.5, function() SS.Safe(UpdateLocalClock); end);   -- a clock that shows minutes
ticker:RegisterEvent("PLAYER_ENTERING_WORLD");
ticker:SetScript("OnEvent", function() SS.Safe(W.ApplyOnTop); end);
SS.Every("readyOverlay", 0.2, function() SS.Safe(W.ApplyOnTop); end);
