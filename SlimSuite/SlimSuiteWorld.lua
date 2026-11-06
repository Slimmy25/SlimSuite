-- Slim Suite: things drawn from the game's newer addon API.
--   * World markers (0.139.2 world anchors): Skull, Cross, Circle and Star over bosses and Guardians that are already
--     pulled, and a "!" over Guardians and lairs before they are pulled. Markers never select a target and have no
--     distance limit: off-screen ones sit at the screen edge, pointing the way.
--   * Downed friends (0.139.2): a marker on the spot where each downed friend can be revived, on every map.
--   * Debuffs on the movable encounter bars (0.93), a movable revive bar (0.113 / 0.115), a class proc meter under
--     the player frame (0.105), a combat text test box (0.138), and keeping Slim Suite above the level-up and
--     new-item cards (0.126).
-- Lua 5.0 / 1.12 interface: scripts read `this`, `arg1`; no # operator, no `...` in expressions; only the 1.12 API.
--
-- THE ADAPTER (A, below) is the only place that knows the shape of the new API calls. The patch notes name these
-- functions but not their exact arguments or fields, so A reads several likely field names and every call is
-- guarded: if a guess is wrong, that feature stays hidden instead of raising errors. Check A against the addon docs.

local W = {};
SlimSuiteWorld = W;
local function DB() return SlimSuite_DB(); end
local function Editing(name) return SlimSuite_IsEditing and SlimSuite_IsEditing(name); end

-- ---------------------------------------------------------------- the adapter
local A = {};
function A.Call(name, a, b)
	local fn = getglobal(name);
	if ( type(fn) ~= "function" ) then return nil; end
	local ok, result = pcall(fn, a, b);
	if ( ok ) then return result; end
	return nil;
end
function A.Has(name) return type(getglobal(name)) == "function"; end
-- the first of several possible field names that is set
function A.Field(t, k1, k2, k3, k4)
	if ( type(t) ~= "table" ) then return nil; end
	if ( t[k1] ~= nil ) then return t[k1]; end
	if ( k2 and t[k2] ~= nil ) then return t[k2]; end
	if ( k3 and t[k3] ~= nil ) then return t[k3]; end
	if ( k4 and t[k4] ~= nil ) then return t[k4]; end
	return nil;
end
function A.Id(t) return A.Field(t, "id", "unitId", "anchorId", "spawnId"); end
-- AZS_GetWorldAnchors(): every anchor the game offers (enemies, bosses, guardians, caches, lairs, fallen spots).
function A.Anchors()
	local list = A.Call("AZS_GetWorldAnchors");
	if ( type(list) ~= "table" ) then return {}; end
	return list;
end
-- AZS_ProjectWorldAnchors(anchors, liftYards): screen positions. Returns a map: anchor id -> { x, y, on, dist }
-- in UIParent units. Accepts results in the same order as the request, or keyed by anchor id.
function A.Project(anchors, lift)
	local out = {};
	if ( table.getn(anchors) == 0 ) then return out; end
	local result = A.Call("AZS_ProjectWorldAnchors", anchors, lift);
	if ( type(result) ~= "table" ) then return out; end
	local scale = UIParent:GetEffectiveScale() or 1;
	local function Read(anchor, p)
		if ( type(p) ~= "table" ) then return; end
		local x, y = A.Field(p, "x", "screenX", "sx"), A.Field(p, "y", "screenY", "sy");
		if ( type(x) ~= "number" or type(y) ~= "number" ) then return; end
		local on = A.Field(p, "onScreen", "visible", "inView");
		local id = A.Id(anchor) or A.Id(p);
		if ( id == nil ) then return; end
		out[id] = { x = x / scale, y = y / scale, on = on ~= false, dist = A.Field(p, "distance", "dist", "yards") };
	end
	for i = 1, table.getn(anchors) do Read(anchors[i], result[i] or result[A.Id(anchors[i]) or 0]); end
	return out;
end
function A.Kind(anchor) return string.lower(tostring(A.Field(anchor, "kind", "type", "category") or "")); end
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

-- Put a marker at a projected spot. Off-screen spots are pinned to the nearest screen edge (no distance limit).
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

local function PulledEnemies()
	local list, seen = {}, {};
	local function Add(src, kindDefault, wantAwake)
		if ( type(src) ~= "table" ) then return; end
		for i = 1, table.getn(src) do
			local u = src[i];
			if ( type(u) == "table" and u.id ~= nil and not seen[u.id] ) then
				local kind = SlimSuite_UnitKind(u) or kindDefault;
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
			if ( type(u) == "table" and u.id ~= nil and not Awake(u) and (SlimSuite_UnitKind(u) or "guardian") == "guardian" ) then table.insert(list, { id = u.id, name = u.name }); end
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
	if ( type(list) ~= "table" ) then
		-- Older game builds: still play the sound when a teammate falls, from party health.
		for i = 1, 4 do
			local u = "party" .. i;
			local down = UnitExists(u) and (UnitIsDeadOrGhost and UnitIsDeadOrGhost(u)) and true or false;
			local key = UnitExists(u) and UnitName(u) or nil;
			if ( key and down ) then current[key] = true; if ( not downed[key] ) then downed[key] = { first = now }; if ( SlimSuite_PlayDeathSound ) then SlimSuite_PlayDeathSound(); end end end
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
				if ( SlimSuite_PlayDeathSound ) then SlimSuite_PlayDeathSound(); end
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
local function Gather(now)
	local d = DB();
	local phase = A.Call("AZS_GetPhase");
	local inRun = phase == nil or phase == "playing" or phase == "choosing" or phase == "paused";
	local anchors = (inRun and (d.bossMarks or d.prePullMarks)) and A.Anchors() or {};
	local byId = {};
	for i = 1, table.getn(anchors) do
		local id = A.Id(anchors[i]);
		if ( id ~= nil ) then byId[id] = anchors[i]; end
	end
	local want, kinds = {}, {};
	-- pulled bosses and Guardians
	if ( inRun and d.bossMarks ) then
		local enemies = PulledEnemies();
		AssignIcons(enemies);
		for i = 1, table.getn(enemies) do
			local e = enemies[i];
			if ( assigned[e.id] and byId[e.id] ) then table.insert(want, byId[e.id]); kinds[e.id] = { icon = assigned[e.id] }; end
		end
	else
		for id in pairs(assigned) do assigned[id] = nil; end
	end
	-- Guardians and lairs before they are pulled
	if ( inRun and d.prePullMarks ) then
		local sleeping = SleepingGuardians();
		for i = 1, table.getn(sleeping) do
			local s = sleeping[i];
			if ( byId[s.id] and not kinds[s.id] ) then table.insert(want, byId[s.id]); kinds[s.id] = { prePull = true, name = s.name }; end
		end
		for i = 1, table.getn(anchors) do
			local a = anchors[i];
			local id = A.Id(a);
			if ( id ~= nil and A.Kind(a) == "lair" and not kinds[id] ) then
				table.insert(want, a); kinds[id] = { prePull = true, name = A.Field(a, "name", "label") or "Lair" };
			end
		end
		-- an empty lair is labelled with its refill countdown, so you know when to go back
		local lairs = W.LairInfo(now);
		for i = 1, table.getn(lairs) do
			local l = lairs[i];
			if ( l.state == "empty" and kinds[l.id] ) then
				kinds[l.id].name = l.refill and ("Refills in " .. W.Clock(l.refill)) or "Empty lair";
				kinds[l.id].empty = true;
			end
		end
	end
	-- downed friends
	local friends = (d.deathMarks or d.deathSound) and DownedFriends(now) or {};
	if ( d.deathMarks ) then
		for i = 1, table.getn(friends) do
			local f = friends[i];
			local id = A.Id(f.entry) or f.key;
			if ( type(f.entry) == "table" and A.Id(f.entry) == nil ) then f.entry.id = id; end
			table.insert(want, f.entry); kinds[id] = { friend = f };
		end
	end
	gathered.at, gathered.want, gathered.kinds = now, want, kinds;
end

local function UpdateMarkers()
	used = 0;
	local now = GetTime();
	if ( now - gathered.at >= 0.1 ) then Gather(now); end
	local want, kinds = gathered.want, gathered.kinds;
	local spots = A.Project(want, 3);
	for i = 1, table.getn(want) do
		local id = A.Id(want[i]);
		local p = id ~= nil and spots[id] or nil;
		local k = id ~= nil and kinds[id] or nil;
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
	for i = used + 1, table.getn(pool) do pool[i]:Hide(); end
end

overlay:SetScript("OnUpdate", function() pcall(UpdateMarkers); end);

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
				local left = tonumber(A.Field(db, "left", "timeLeft", "remaining", "duration"));
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

-- ---------------------------------------------------------------- staying above the level-up and new-item cards
local ON_TOP = { "SlimSuiteWorldMarkers", "SlimSuiteMeterFrame", "SlimSuiteStoredLevelsButton", "SlimSuiteClockFrame",
	"SlimSuiteBossFrames", "SlimSuiteAnnouncementFrame", "SlimSuiteSpellRowFrame", "SlimSuiteItemRowFrame",
	"SlimSuiteTallyFrame", "SlimSuiteReviveFrame", "SlimSuiteCombatTextFrame", "SlimSuiteProcMeter",
	"SlimSuiteLocalClockFrame", "SlimSuiteFloatingText", "SlimSuiteStoreLevelsToggle" };
function W.ApplyOnTop()
	if ( not A.Has("AZS_SetOnTopOfScreens") ) then return; end
	local on = DB().onTopOfScreens and true or false;
	for i = 1, table.getn(ON_TOP) do
		local f = getglobal(ON_TOP[i]);
		if ( f ) then
			local ok = pcall(AZS_SetOnTopOfScreens, f, on);
			if ( not ok and on ) then pcall(AZS_SetOnTopOfScreens, f); end
		end
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

-- Hide one of the game's HUD parts while a Slim Suite replacement is on, and put it back exactly as it was. The
-- original is kept in the saved settings (key) so a logout or a crash can never leave the game's part hidden.
local natives = {};
local function Native(part, key)
	local n = natives[part];
	if ( not n ) then n = { part = part, key = key }; natives[part] = n; end
	return n;
end
function W.SetNativeOriginal(part, original) if ( natives[part] ) then natives[part].was = original; end end
local function SetNativeHidden(n, on)
	if ( not A.Has("AZS_SetHudShown") ) then return; end
	if ( on and not n.overridden ) then
		local shown = A.Call("AZS_IsHudShown", n.part);
		if ( shown == nil ) then shown = true; end
		n.was = shown and true or false;
		if ( n.was ) then
			DB()[n.key] = true;
			n.overridden = pcall(AZS_SetHudShown, n.part, false);
		end
	elseif ( not on and n.overridden ) then
		if ( pcall(AZS_SetHudShown, n.part, n.was ~= false) ) then n.overridden = false; DB()[n.key] = nil; end
	end
end
local reviveNative = Native("revive", "reviveNativeOriginal");

local function UpdateRevive()
	local d = DB();
	if ( not d.replaceRevive ) then revive:Hide(); SetNativeHidden(reviveNative, false); return; end
	SetNativeHidden(reviveNative, true);
	local r = A.Call("AZS_GetRevive");
	local progress, label;
	if ( type(r) == "table" ) then
		progress = tonumber(A.Field(r, "progress", "fraction", "pct"));
		local value, max = tonumber(A.Field(r, "value", "current", "elapsed")), tonumber(A.Field(r, "max", "total", "duration"));
		if ( not progress and value and max and max > 0 ) then progress = value / max; end
		if ( progress and progress > 1 ) then progress = progress / 100; end
		local active = A.Field(r, "active", "reviving");
		if ( active == false ) then progress = nil; end
		local who = A.Field(r, "name", "target", "who");
		local left = tonumber(A.Field(r, "left", "timeLeft", "remaining"));
		label = "Reviving" .. (who and (" " .. tostring(who)) or "") .. (left and string.format("  %.1fs", left) or "");
	end
	if ( progress and progress > 0 ) then
		revive.bar:SetValue(math.max(0, math.min(1, progress))); revive.text:SetText(label); revive:Show();
	elseif ( Editing("SlimSuiteReviveFrame") ) then
		revive.bar:SetValue(0.6); revive.text:SetText("Revive bar"); revive:Show();
	else
		revive:Hide();
	end
end

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
	if ( not DB().procMeter or not info or max <= 0 ) then proc:Hide(); return; end
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

local function OnCombatEvent(event)
	if ( not DB().combatTextBox or type(event) ~= "table" or type(event.amount) ~= "number" ) then return; end
	local kind = event.kind;
	if ( kind ~= "damage" and kind ~= "heal" and kind ~= "healing" ) then return; end
	local name = event.meterSource or event.abilityName or event.spell or event.damageType or "";
	table.insert(box.entries, 1, { born = GetTime(), crit = event.critical == true, heal = kind ~= "damage",
		amount = math.floor(event.amount + 0.5), name = tostring(name), icon = IconFor(event) });
	while ( table.getn(box.entries) > 40 ) do table.remove(box.entries); end
end
if ( SlimSuiteMeter and SlimSuiteMeter.listeners ) then table.insert(SlimSuiteMeter.listeners, OnCombatEvent); end

local function DrawBox()
	local d = DB();
	local editing = Editing("SlimSuiteCombatTextFrame");
	if ( not d.combatTextBox and not editing ) then box:Hide(); return; end
	box:Show();
	local now = GetTime();
	local list = box.entries;
	if ( editing and table.getn(list) == 0 ) then
		list = { { born = now, crit = true, amount = 1234, name = "Crit example", icon = "Interface\\Icons\\Spell_Fire_Fireball02" },
		         { born = now, amount = 512, name = "Hit example", icon = "Interface\\Icons\\Spell_Frost_FrostBolt02" } };
	end
	for i = table.getn(box.entries), 1, -1 do
		local e = box.entries[i];
		if ( now - e.born > (e.crit and CRIT_LIFE or NORMAL_LIFE) ) then table.remove(box.entries, i); end
	end
	local y, n = -6, 0;
	local bottom = -(box:GetHeight() or 220) + 6;
	for i = 1, table.getn(list) do
		local e = list[i];
		local h = e.crit and 24 or 15;
		if ( n >= MAX_LINES or y - h < bottom ) then break; end
		n = n + 1;
		local l = BoxLine(n);
		local life = e.crit and CRIT_LIFE or NORMAL_LIFE;
		local age = now - e.born;
		local alpha = 1;
		if ( age > life - FADE ) then alpha = math.max(0, (life - age) / FADE); end
		l:ClearAllPoints();
		l:SetPoint("TOPLEFT", box, "TOPLEFT", e.crit and 26 or 8, y);
		l:SetWidth((box:GetWidth() or 260) - (e.crit and 30 or 12)); l:SetHeight(h);
		l.icon:SetWidth(h - 2); l.icon:SetHeight(h - 2); l.icon:SetTexture(e.icon);
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
	local st = A.Field(l, "state", "status", "phase");
	if ( type(st) == "string" ) then
		st = string.lower(st);
		if ( st == "empty" or st == "dead" or st == "cleared" or st == "slain" ) then return "empty"; end
		if ( st == "awake" or st == "fighting" or st == "active" ) then return "awake"; end
		return "asleep";
	end
	if ( A.Field(l, "empty", "cleared") == true ) then return "empty"; end
	if ( st == 1 or A.Field(l, "awake") == true ) then return "awake"; end
	return "asleep";
end
-- seconds until an empty lair fills again, or nil if not known
function A.LairRefill(l, id, now)
	local left = tonumber(A.Field(l, "refill", "refillIn", "fillsIn", "left"));
	if ( left ) then return math.max(0, left); end
	local at = tonumber(A.Field(l, "refillAt", "fillAt", "respawnAt"));
	if ( at ) then return math.max(0, at - now); end
	local since = id ~= nil and lairEmptySince[id];
	if ( since ) then return math.max(0, LAIR_REFILL - (now - since)); end
	return nil;
end
function W.LairInfo(now)
	local list, seen = {}, {};
	local lairs = A.Lairs();
	for i = 1, table.getn(lairs) do
		local l = lairs[i];
		if ( type(l) == "table" ) then
			local id = A.Id(l) or i;
			local state = A.LairState(l);
			seen[id] = true;
			if ( state == "empty" ) then
				if ( not lairEmptySince[id] ) then lairEmptySince[id] = now; end
			else
				lairEmptySince[id] = nil;
			end
			table.insert(list, { id = id, entry = l, state = state, flagged = A.Field(l, "flag", "flagged") and true or false,
				name = A.Field(l, "guardian", "guardianName", "name") or "Lair",
				refill = state == "empty" and A.LairRefill(l, id, now) or nil });
		end
	end
	for id in pairs(lairEmptySince) do if ( not seen[id] ) then lairEmptySince[id] = nil; end end
	return list;
end
local function Clock(sec) sec = math.floor(sec + 0.5); return string.format("%d:%02d", math.floor(sec / 60), math.mod(sec, 60)); end
W.Clock = Clock;

-- ---------------------------------------------------------------- minimap pins: caches, bosses and lairs (separate settings)
-- Positions are in the game's yards (AZS_RUN px/py and the caches' x/y share them, per the 0.97 patch notes).
-- ASSUMPTION to check against the docs: +x is north and +y is west, as in WoW's own world coordinates. If pins
-- come out mirrored or turned, change NORTH_SIGN / WEST_SIGN / SWAP_AXES here.
local NORTH_SIGN, WEST_SIGN, SWAP_AXES = 1, 1, false;
-- the 1.12 minimap's diameter in yards at each zoom level, outdoors and indoors
local OUTDOOR = { [0] = 466.67, 400, 333.33, 266.67, 200, 133.33 };
local INDOOR = { [0] = 300, 240, 180, 120, 80, 50 };

function A.PlayerPos()
	local run = type(AZS_RUN) == "table" and AZS_RUN or nil;
	if ( run and type(run.px) == "number" and type(run.py) == "number" ) then return run.px, run.py; end
	return nil;
end
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
-- the caches on the field (0.92): a getter if the game has one, else its table
function A.Caches()
	local list = A.Call("AZS_GetCaches");
	if ( type(list) ~= "table" ) then list = type(AZS_CACHES) == "table" and AZS_CACHES or {}; end
	return list;
end

local pins, pinUsed = {}, 0;
local function Pin()
	pinUsed = pinUsed + 1;
	local p = pins[pinUsed];
	if ( not p ) then
		p = CreateFrame("Frame", nil, Minimap);
		p:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 5);
		p:EnableMouse(true);
		p.icon = p:CreateTexture(nil, "OVERLAY"); p.icon:SetAllPoints(p);
		p.label = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		p.label:SetPoint("TOP", p, "BOTTOM", 0, 1);
		local font, _, flags = p.label:GetFont();
		if ( font ) then p.label:SetFont(font, 9, "OUTLINE"); end
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

local function PlacePin(px, py, x, y, size, tip)
	local north, west = (x - px) * NORTH_SIGN, (y - py) * WEST_SIGN;
	if ( SWAP_AXES ) then north, west = west, north; end
	local zoom = Minimap:GetZoom() or 0;
	local inside = GetCVar and tonumber(GetCVar("minimapInsideZoom")) == zoom and IsIndoors and IsIndoors();
	local yards = ((inside and INDOOR[zoom]) or OUTDOOR[zoom] or 466.67) / 2;
	local radius = (Minimap:GetWidth() or 140) / 2;
	local dist = math.sqrt(north * north + west * west);
	local dx, dy = -west / yards * radius, north / yards * radius;
	local p = Pin();
	local onEdge = dist > yards * 0.92;
	if ( onEdge and dist > 0 ) then
		-- out of the minimap's range: keep it on the rim, pointing the way, however far it is
		local k = (radius - 6) / math.sqrt(dx * dx + dy * dy);
		dx, dy = dx * k, dy * k;
	end
	p:SetWidth(onEdge and size * 0.8 or size); p:SetHeight(onEdge and size * 0.8 or size);
	p:SetAlpha(onEdge and 0.7 or 1);
	p:ClearAllPoints();
	p:SetPoint("CENTER", Minimap, "CENTER", dx, dy);
	p.tip, p.dist, p.sub = tip, dist, nil;
	p.label:SetText("");
	p.icon:SetVertexColor(1, 1, 1);
	if ( p.icon.SetDesaturated ) then p.icon:SetDesaturated(nil); end
	p:Show();
	return p;
end

local function UpdateMinimapPins()
	pinUsed = 0;
	local d = DB();
	local px, py = A.PlayerPos();
	local phase = A.Call("AZS_GetPhase");
	local inRun = phase == nil or phase == "playing" or phase == "choosing" or phase == "paused";
	if ( Minimap and px and inRun ) then
		if ( d.minimapCaches ) then
			local caches = A.Caches();
			for i = 1, table.getn(caches) do
				local c = caches[i];
				local x, y = A.Pos(c);
				local opened = A.Field(c, "opened", "looted", "taken");
				if ( x and not opened ) then
					local p = PlacePin(px, py, x, y, 14, A.Field(c, "name", "label") or "Cache");
					p.icon:SetTexture("Interface\\Icons\\INV_Box_02"); p.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
				end
			end
		end
		if ( d.minimapLairs ) then
			local now = GetTime();
			local lairs = W.LairInfo(now);
			for i = 1, table.getn(lairs) do
				local l = lairs[i];
				local x, y = A.Pos(l.entry);
				if ( x ) then
					local p = PlacePin(px, py, x, y, l.flagged and 15 or 12, l.name);
					p.icon:SetTexture(PRE_PULL_ICON); p.icon:SetTexCoord(0, 1, 0, 1);
					if ( l.state == "awake" ) then
						p.icon:SetVertexColor(1, 0.25, 0.2); p.sub = "Awake: its Guardian is fighting";
					elseif ( l.state == "empty" ) then
						if ( p.icon.SetDesaturated ) then p.icon:SetDesaturated(1); end
						p.icon:SetVertexColor(0.6, 0.6, 0.6);
						if ( l.refill ) then p.label:SetText(Clock(l.refill)); p.sub = "Empty: fills again in " .. Clock(l.refill);
						else p.sub = "Empty: fills again within 3:00"; end
					else
						p.sub = "Asleep: its Guardian waits";
					end
					if ( l.flagged ) then p.sub = (p.sub or "") .. "\n(the game's red flag points here)"; end
				end
			end
		end
		if ( d.minimapBosses ) then
			local bosses = A.Call("AZS_GetBosses");
			local byId = {};
			if ( type(bosses) == "table" ) then
				local anchors = A.Anchors();
				for i = 1, table.getn(anchors) do local id = A.Id(anchors[i]); if ( id ~= nil ) then byId[id] = anchors[i]; end end
				for i = 1, table.getn(bosses) do
					local b = bosses[i];
					if ( type(b) == "table" ) then
						local x, y = A.Pos(b);
						if ( not x and b.id ~= nil ) then x, y = A.Pos(byId[b.id]); end
						if ( x ) then
							local p = PlacePin(px, py, x, y, 16, b.name or "Boss");
							-- the boss's own marker icon when it has one, else a skull
							SetRaidIcon(p.icon, (b.id ~= nil and assigned[b.id]) or 8);
						end
					end
				end
			end
		end
	end
	for i = pinUsed + 1, table.getn(pins) do pins[i]:Hide(); end
end

-- ---------------------------------------------------------------- movable local clock (0.136)
-- AZS_GetLocalTime() gives the clock's text, hour, minute and format, even with the clock or minimap hidden and out of
-- a run. While this is on, the game's own clock under the minimap is hidden with AZS_SetHudShown("localClock", false).
local localNative = Native("localClock", "localClockNativeOriginal");
local clock = CreateFrame("Frame", "SlimSuiteLocalClockFrame", UIParent);
clock:SetWidth(70); clock:SetHeight(20);
if ( Minimap ) then clock:SetPoint("TOP", Minimap, "BOTTOM", 0, -6); else clock:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -60, -170); end
clock:SetFrameStrata("MEDIUM");
clock:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } });
clock:SetBackdropColor(0.03, 0.03, 0.05, 0.75);
clock:SetBackdropBorderColor(0.7, 0.52, 0.2, 0.8);
clock.text = clock:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
clock.text:SetPoint("CENTER", clock, "CENTER", 0, 0);
clock:Hide();

local function LocalTimeText()
	local t = A.Call("AZS_GetLocalTime");
	if ( type(t) == "string" ) then return t; end
	if ( type(t) ~= "table" ) then return nil; end
	local text = A.Field(t, "text", "label");
	if ( type(text) == "string" and text ~= "" ) then return text; end
	local h, m = tonumber(A.Field(t, "hour", "h")), tonumber(A.Field(t, "minute", "min", "m"));
	if ( not h or not m ) then return nil; end
	local fmt = tostring(A.Field(t, "format", "fmt") or "24");
	if ( string.find(fmt, "12", 1, true) ) then
		local suffix = h >= 12 and " PM" or " AM";
		h = math.mod(h, 12); if ( h == 0 ) then h = 12; end
		return string.format("%d:%02d%s", h, m, suffix);
	end
	return string.format("%02d:%02d", h, m);
end

local function UpdateLocalClock()
	local editing = Editing("SlimSuiteLocalClockFrame");
	if ( not DB().replaceLocalClock ) then clock:Hide(); SetNativeHidden(localNative, false); return; end
	local text = LocalTimeText();
	if ( not text and not editing ) then clock:Hide(); SetNativeHidden(localNative, false); return; end
	SetNativeHidden(localNative, true);
	clock.text:SetText(text or "12:00");
	clock:SetWidth(math.max(50, (clock.text:GetStringWidth() or 40) + 16));
	clock:Show();
end

-- ---------------------------------------------------------------- floating combat text (0.138)
-- Each of your hits floats up from the enemy it struck, stays over the spot where an enemy fell, and hides when that
-- spot leaves your view. Text is sized by distance. Crits are bigger, pop, and stay twice as long. Positions are
-- worked out in AZS_RegisterCombatTextFrameHandler (after the camera moves each frame) so numbers never trail behind.
-- ASSUMPTION to check against the docs: each event carries its anchor as event.anchor (or anchorId / targetAnchor),
-- and AZS_ProjectCombatTextAnchors(list) answers like AZS_ProjectWorldAnchors (x, y, onScreen, distance).
local FLOAT_LIFE, FLOAT_CRIT_LIFE, FLOAT_RISE = 1.1, 2.2, 46;
local floatLayer = CreateFrame("Frame", "SlimSuiteFloatingText", UIParent);
floatLayer:SetAllPoints(UIParent);
floatLayer:SetFrameStrata("LOW");
floatLayer:EnableMouse(false);
local floats, floatPool = {}, {};

local function FloatAnchor(event)
	local a = A.Field(event, "anchor", "anchorId", "targetAnchor", "worldAnchor");
	if ( a == nil ) then return nil; end
	if ( type(a) ~= "table" ) then a = { id = a }; end
	if ( A.Id(a) == nil ) then a.id = tostring(event); end
	return a;
end

local function OnFloatEvent(event)
	if ( not DB().floatingText or type(event) ~= "table" or type(event.amount) ~= "number" ) then return; end
	local kind = event.kind;
	if ( kind ~= "damage" and kind ~= "heal" and kind ~= "healing" ) then return; end
	local anchor = FloatAnchor(event);
	if ( not anchor ) then return; end
	if ( table.getn(floats) >= 60 ) then table.remove(floats, 1); end
	table.insert(floats, { anchor = anchor, born = GetTime(), crit = event.critical == true, heal = kind ~= "damage",
		text = tostring(math.floor(event.amount + 0.5)), icon = IconFor(event),
		drift = math.mod(table.getn(floats), 5) * 9 - 18,
		kind = SlimSuite_UnitKind(A.Field(event, "target", "targetId", "unitId")) });
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

local function DrawFloats()
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
	local anchors = {};
	for i = 1, n do anchors[i] = floats[i].anchor; end
	local result = A.Call("AZS_ProjectCombatTextAnchors", anchors);
	local scale = UIParent:GetEffectiveScale() or 1;
	local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF";
	local shown = 0;
	for i = 1, n do
		local e = floats[i];
		local p = type(result) == "table" and (result[i] or result[A.Id(e.anchor)]) or nil;
		local x, y = A.Field(p, "x", "screenX", "sx"), A.Field(p, "y", "screenY", "sy");
		local on = A.Field(p, "onScreen", "visible", "inView");
		if ( type(x) == "number" and type(y) == "number" and on ~= false ) then
			shown = shown + 1;
			local f = FloatText(shown);
			local life = e.crit and FLOAT_CRIT_LIFE or FLOAT_LIFE;
			local t = (now - e.born) / life;
			local dist = tonumber(A.Field(p, "distance", "dist", "yards"));
			local near = dist and math.max(0.6, math.min(1.25, 1.35 - dist / 90)) or 1;
			local pop = (e.crit and t < 0.12) and (1.3 - t * 2.5) or 1;
			local size = math.floor((e.crit and 22 or 14) * near * pop + 0.5);
			f.text:SetFont(font, math.max(8, size), "OUTLINE");
			f.text:SetText(e.crit and (e.text .. "!") or e.text);
			if ( e.heal ) then f.text:SetTextColor(0.3, 1, 0.4);
			elseif ( e.crit ) then f.text:SetTextColor(1, 0.82, 0.15);
			elseif ( e.kind == "boss" or e.kind == "final" ) then f.text:SetTextColor(1, 0.6, 0.3);
			else f.text:SetTextColor(1, 1, 1); end
			f.icon:SetWidth(size); f.icon:SetHeight(size); f.icon:SetTexture(e.icon);
			f:ClearAllPoints();
			f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale + e.drift, y / scale + 20 + t * FLOAT_RISE * near);
			f:SetAlpha(t > 0.7 and math.max(0, (1 - t) / 0.3) or 1);
			f:Show();
		end
	end
	for i = shown + 1, table.getn(floatPool) do floatPool[i]:Hide(); end
end

if ( not (A.Has("AZS_RegisterCombatTextFrameHandler") and pcall(AZS_RegisterCombatTextFrameHandler, function() pcall(DrawFloats); end)) ) then
	floatLayer:SetScript("OnUpdate", function() pcall(DrawFloats); end);
end

-- ---------------------------------------------------------------- tickers
local ticker = CreateFrame("Frame");
ticker.elapsed = 0;
ticker:SetScript("OnUpdate", function()
	pcall(DrawBox);
	this.elapsed = this.elapsed + (arg1 or 0);
	if ( this.elapsed < 0.1 ) then return; end
	this.elapsed = 0;
	pcall(UpdateRevive);
	pcall(UpdateProc);
	pcall(UpdateMinimapPins);
	pcall(UpdateLocalClock);
end);
ticker:RegisterEvent("PLAYER_ENTERING_WORLD");
ticker:SetScript("OnEvent", function() pcall(W.ApplyOnTop); end);
