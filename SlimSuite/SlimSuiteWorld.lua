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
local catalogAttempt = -1;
function A.Catalog(now)
	if ( now - catalogAttempt < 0.1 ) then return catalog; end
	if ( not A.Has("AZS_GetWorldAnchors") ) then return catalog; end
	catalogAttempt = now;
	local list, cursor = {}, nil;
	for pages = 1, 32 do
		local page = A.Call("AZS_GetWorldAnchors", CATALOG_QUERY, cursor);
		if ( type(page) ~= "table" or type(page.entries) ~= "table" ) then return catalog; end   -- not ready: keep the last
		for i = 1, table.getn(page.entries) do table.insert(list, page.entries[i]); end
		if ( not page.hasMore ) then break; end
		cursor = page.nextCursor;
		if ( not cursor or pages == 32 ) then return catalog; end -- never publish a partial catalog
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

-- Compass/map bearings need current world coordinates, not camera projection pixels.
-- Query only moving encounter units, once per UI frame shared by both consumers.
local liveBossAt,liveBosses=nil,{};
local LIVE_BOSS_QUERY={kinds={"boss","finalBoss","guardian"},states={"alive"}};
function A.LiveBossPositions(now)
	if ( liveBossAt==now ) then return liveBosses; end
	liveBossAt=now; liveBosses={};
	if ( not A.Has("AZS_GetWorldAnchors") ) then return liveBosses; end
	local nextList,cursor={},nil;
	for pageNumber=1,32 do
		local page=A.Call("AZS_GetWorldAnchors",LIVE_BOSS_QUERY,cursor);
		if ( type(page)~="table" or type(page.entries)~="table" ) then return liveBosses; end
		for _,entry in ipairs(page.entries) do
			if ( entry.unitId~=nil and entry.state~="dead" and entry.positionAvailable and type(entry.x)=="number" and type(entry.y)=="number" ) then nextList[entry.unitId]=entry; end
		end
		if ( not page.hasMore ) then liveBosses=nextList; return liveBosses; end
		cursor=page.nextCursor; if ( not cursor ) then return liveBosses; end
	end
	return liveBosses;
end

-- Ordinary orbs are absent from AZS_UNITS. Discover their actual spawn IDs through
-- living enemy anchors; obtain HP only from an authoritative unit or current target.
local orbAnchors,orbReadAt={},-1;
function W.ExplosiveOrbs()
	local now=GetTime();
	if now-orbReadAt>=.25 then
		orbReadAt=now; local found,cursor,complete={},nil,false;
		for pageNumber=1,32 do
			local page=A.Call("AZS_GetWorldAnchors",{kinds={"enemy","elite","guardian","boss","finalBoss"},states={"alive"}},cursor);
			if type(page)~="table" or type(page.entries)~="table" then break; end
			for _,entry in ipairs(page.entries) do
				if entry.unitId and entry.state~="dead" and type(entry.name)=="string" and string.lower(entry.name)=="explosive orb" then found[entry.unitId]=entry; end
			end
			if not page.hasMore then complete=true; break; end
			cursor=page.nextCursor; if not cursor then break; end
		end
		orbAnchors=complete and found or {};
	end
	local health={};
	for _,u in ipairs(type(AZS_UNITS)=="table" and AZS_UNITS or {}) do health[u.id]=u; end
	if type(AZS_TARGET)=="table" and AZS_TARGET.id then health[AZS_TARGET.id]=AZS_TARGET; end
	local out={};
	for id,entry in pairs(orbAnchors) do
		local unit=health[id]; local dead=unit and (unit.kind=="dead" or type(unit.hp)=="number" and unit.hp<=0);
		local friendly=unit and (unit.kind=="other" or unit.kind=="player");
		if not dead and not friendly then
			local known=unit and type(unit.hp)=="number" and type(unit.hpm)=="number" and unit.hpm>0;
			table.insert(out,{id=id,name=entry.name,anchorId=entry.anchorId,kind="normal",hp=known and unit.hp or nil,hpm=known and unit.hpm or nil});
		end
	end
	table.sort(out,function(a,b) return a.id<b.id; end);
	return out;
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
		if ( type(result) == "table" and result.frameCurrent ~= false and type(result.entries) == "table" ) then
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
	if ( type(AZS_TARGET)=="table" and AZS_TARGET.id==id and type(GetRaidTargetIndex)=="function" ) then
		local mark=GetRaidTargetIndex("target"); if ( type(mark)=="number" and mark>=1 and mark<=8 ) then return mark; end
	end
	return assigned[id];
end
W.SetRaidIcon = function(tex, index) SetRaidIcon(tex, index); end

local function PulledEnemies()
	local list, seen = {}, {};
	for _,orb in ipairs(W.ExplosiveOrbs()) do seen[orb.id]=true; table.insert(list,{id=orb.id,name=orb.name,kind="explosive",anchorId=orb.anchorId}); end
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
	for _,u in ipairs(type(AZS_UNITS)=="table" and AZS_UNITS or {}) do
		if ( not seen[u.id] and SS.IsExplosiveOrb(u) and (u.hp or 0)>0 ) then seen[u.id]=true; table.insert(list,{id=u.id,name=u.name,kind="explosive"}); end
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
	-- An orb is the highest-priority threat: reserve Skull before assigning other encounters.
	local orb;
	for _,e in ipairs(enemies) do if e.kind=="explosive" then orb=e; break; end end
	if orb and assigned[orb.id]~=8 then
		for id,icon in pairs(assigned) do if icon==8 or id==orb.id then assigned[id]=nil; taken[icon]=nil; end end
		assigned[orb.id]=8; taken[8]=true;
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
			if ( key and down ) then current[key] = true; if ( not downed[key] ) then downed[key] = { first = now }; if ( SS.PlayDeathSound ) then SS.PlayDeathSound("teammate"); end end end
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
				if ( SS.PlayDeathSound ) then SS.PlayDeathSound("teammate"); end
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
	local want, kinds, markedUnits = {}, {}, {};
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
			local a = cat.byUnit[e.id] or (e.anchorId and {anchorId=e.anchorId});
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
			if ( a ) then Want(a.anchorId, "overhead", nil, { prePull = true, name = s.name }); markedUnits[s.id]=true; end
		end
		local lairs = W.LairInfo(now);
		for i = 1, table.getn(lairs) do
			local l = lairs[i];
			local a = cat.byLair[l.index];
			if ( a and l.state ~= "awake" and not markedUnits[l.id] ) then
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
	local friends = (d.deathMarks or SS.DeathSoundSelection("teammate")~="off") and DownedFriends(now) or {};
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
	SS.Every("markers", 0.05, function() SS.Safe(UpdateMarkers); end, overlay);
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
				-- Keep auras at the bar's far end, away from the name/raid-marker end.
				if ( vertical ) then b:SetPoint("TOP", row.bar, "BOTTOM", 0, -2 - (n - 1) * 24);
				else b:SetPoint("TOPRIGHT", row.bar, "BOTTOMRIGHT", -(n - 1) * 17, -2); end
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
local onTopApplied, onTopAPI = {}, nil;
local function ApplyOnTopFrame(f, on)
	if ( f and onTopApplied[f] ~= on and SS.Safe(AZS_SetOnTopOfScreens, f, on) ) then onTopApplied[f] = on; end
end
-- Each element can be set on its own (its right-click menu, its section): over the cards or under them. An element
-- with no choice of its own follows the global setting.
function SS.OnTopFor(name)
	local own = DB().onTop and DB().onTop[name];
	if ( own ~= nil ) then return own and true or false; end
	return DB().onTopOfScreens and true or false;
end
function SS.SetOnTopFor(name, on)
	local d = DB(); d.onTop = d.onTop or {};
	d.onTop[name] = on and true or false;
	SS.Safe(W.ApplyOnTop);
end
local function ElementFrames(name)
	local out, seen = {}, {};
	local function Add(n) local f = n and getglobal(n); if ( f and not seen[f] ) then seen[f] = true; table.insert(out, f); end end
	Add(SS.Shown and SS.Shown(name) or name); Add(name);
	if ( name == "PartyMemberFrame1" ) then
		for i = 2, 4 do Add("PartyMemberFrame" .. i); end
		Add("SlimSuitePartyLines"); Add("SlimSuitePartySelfFrame");
	elseif ( name == "PlayerFrame" ) then Add("SlimSuitePlayerCard");
	elseif ( name == "TargetFrame" ) then Add("SlimSuiteTargetCard");
	elseif ( name == "MinimapCluster" ) then Add("SlimSuiteMinimapBar");
	elseif ( name == "MainMenuBar" ) then Add("SlimSuiteStoreLevelsToggle"); end
	return out;
end
function W.ApplyOnTop()
	if ( not A.Has("AZS_SetOnTopOfScreens") ) then return; end
	if ( onTopAPI ~= AZS_SetOnTopOfScreens ) then onTopApplied, onTopAPI = {}, AZS_SetOnTopOfScreens; end
	local on = DB().onTopOfScreens and true or false;
	local done, listed = {}, {};
	for i = 1, table.getn(ON_TOP) do local f = getglobal(ON_TOP[i]); if ( f ) then listed[f] = true; end end
	for name in pairs(SS.ELEMENTS or {}) do
		local own = SS.OnTopFor(name);
		for _, f in ipairs(ElementFrames(name)) do
			-- the game's own frames are only handed to the game when lifted (or to put back one that was lifted)
			if ( own or listed[f] or onTopApplied[f] ~= nil ) then ApplyOnTopFrame(f, own); end
			done[f] = true;
		end
	end
	for i = 1, table.getn(ON_TOP) do
		local f = getglobal(ON_TOP[i]);
		if ( f and not done[f] ) then ApplyOnTopFrame(f, on); end
	end
	for i = 1, 64 do
		local f = getglobal("SlimSuiteEnemyNameplate" .. i);
		ApplyOnTopFrame(f, on);
	end
end

-- ---------------------------------------------------------------- the movable revive bar
local revive = CreateFrame("Frame", "SlimSuiteReviveFrame", UIParent);
revive:SetWidth(220); revive:SetHeight(26);
revive:SetPoint("CENTER", UIParent, "CENTER", 0, -140);
revive:SetFrameStrata("MEDIUM");
SS.OwnLook(revive, function()
revive:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
revive:SetBackdropColor(0.03, 0.03, 0.05, 0.85);
revive:SetBackdropBorderColor(0.7, 0.52, 0.2, 0.9);
end);
revive.bar = CreateFrame("StatusBar", nil, revive);
revive.bar:SetPoint("TOPLEFT", revive, "TOPLEFT", 5, -5);
revive.bar:SetPoint("BOTTOMRIGHT", revive, "BOTTOMRIGHT", -5, 5);
revive.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
revive.bar:SetStatusBarColor(0.25, 0.85, 0.35);
revive.bar:SetMinMaxValues(0, 1);
revive.text = revive.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
revive.text:SetPoint("CENTER", revive.bar, "CENTER", 0, 0);

-- Vertical: the bar fills from the bottom up and its words sit above it. Turning it swaps the frame's width and
-- height (and the saved size), so a 220 x 26 bar becomes 26 x 220.
function SS.ReviveVertical() return SS.DB().orientations and SS.DB().orientations.SlimSuiteReviveFrame == "vertical"; end
function SS.ApplyReviveOrientation()
	local vertical = SS.ReviveVertical() and true or false;
	local w, h = revive:GetWidth() or 220, revive:GetHeight() or 26;
	if ( (vertical and w > h) or (not vertical and h > w) ) then
		revive:SetWidth(h); revive:SetHeight(w);
		local saved = SS.DB().sizes and SS.DB().sizes.SlimSuiteReviveFrame;
		if ( type(saved) == "table" and saved.w and saved.h ) then saved.w, saved.h = h, w; end
	end
	if ( revive.bar.SetOrientation ) then revive.bar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL"); end
	revive.text:ClearAllPoints();
	if ( vertical ) then revive.text:SetPoint("BOTTOM", revive, "TOP", 0, 2);
	else revive.text:SetPoint("CENTER", revive.bar, "CENTER", 0, 0); end
	revive.vertical = vertical;
end
revive:Hide();

local function UpdateRevive()
	local d = DB();
	if ( not SS.FeatureEnabled("SlimSuiteReviveFrame") ) then revive:Hide(); SS.HideNative("revive", false); return; end
	SS.HideNative("revive", true);
	if ( revive.vertical ~= (SS.ReviveVertical() and true or false) ) then SS.ApplyReviveOrientation(); end
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
proc.bar.bg = proc.bar:CreateTexture(nil, "BACKGROUND"); proc.bar.bg:SetAllPoints(proc.bar);
-- the empty part of the bar follows the chosen look; Original keeps its dark tint exactly
SS.AddThemeHook(function(key)
	local s = SS.PANEL_STYLES[key];
	if ( key == "original" or not s ) then proc.bar.bg:SetTexture(0, 0, 0, 0.5);
	else proc.bar.bg:SetTexture(s.color[1], s.color[2], s.color[3], 0.9); end
end, "SlimSuiteProcMeter");
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


-- shared with the other world files (SlimSuiteCombatText, SlimSuiteMinimapPins, SlimSuiteKills)
W.A, W.DB, W.Editing, W.Previewing = A, DB, Editing, Previewing;
W.RAID_ICONS, W.PRE_PULL_ICON, W.SetRaidIcon = RAID_ICONS, PRE_PULL_ICON, SetRaidIcon;

-- ---------------------------------------------------------------- tickers
local ticker = CreateFrame("Frame");
SS.Every("worldUpdates", 0.1, function()
	SS.Safe(UpdateTargetDebuffs);
	SS.Safe(UpdateRevive);
	SS.Safe(UpdateProc);
end);
ticker:RegisterEvent("PLAYER_ENTERING_WORLD");
ticker:SetScript("OnEvent", function() SS.Safe(W.ApplyOnTop); end);
