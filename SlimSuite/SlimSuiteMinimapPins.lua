-- Slim Suite: lairs and their refill timer, minimap pins and the movable local clock. Split out of SlimSuiteWorld.lua, whose adapter (A) and helpers it shares.
-- Lua 5.0 / 1.12 interface: scripts read `this`, `arg1`; no # operator, no `...` in expressions; only the 1.12 API.
local W = SlimSuiteWorld;
local A, DB, Editing, Previewing = W.A, W.DB, W.Editing, W.Previewing;
local RAID_ICONS, PRE_PULL_ICON, SetRaidIcon = W.RAID_ICONS, W.PRE_PULL_ICON, W.SetRaidIcon;

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
	if ( type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" ) then A.playerPosition=p; return p.x, p.y, p.spaceId; end
	A.playerPosition=nil;
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
	if ( type(entry)~="table" ) then return true; end
	local position=type(space)=="table" and space or A.playerPosition;
	if ( position ) then
		for _,key in ipairs({"spaceId","mapId","runId"}) do if ( entry[key]~=nil and entry[key]~=position[key] ) then return false; end end
		return true;
	end
	return space==nil or entry.spaceId==nil or entry.spaceId==space;
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
	local edge=(t.size or 13)/2+2;
	local halfH=(Minimap:GetHeight() or 140)/2;
	local ry=halfH-edge; local rx=radius-edge;
	if ( rx<=0 or ry<=0 ) then return nil; end
	dy=north/yards*halfH;
	local outside=SS.squareActive and (math.abs(dx)>rx or math.abs(dy)>ry) or (not SS.squareActive and (dx*dx/(rx*rx)+dy*dy/(ry*ry)>1));
	if ( outside ) then return nil; end
	local p=Pin();
	local size = outside and t.size * 0.8 or t.size;
	p:SetWidth(size); p:SetHeight(size);
	p:SetAlpha((t.alpha or 1) * (outside and 0.7 or 1));
	p:ClearAllPoints();
	p:SetPoint("CENTER", Minimap, "CENTER", dx, dy);
	p.icon:SetTexture(t.texture);
	if ( t.raid ) then SetRaidIcon(p.icon, t.raid); elseif ( t.crop ) then p.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); else p.icon:SetTexCoord(0, 1, 0, 1); end
	p.icon:SetVertexColor(t.r or 1, t.g or 1, t.b or 1);
	if ( p.icon.SetDesaturated ) then p.icon:SetDesaturated(t.grey and 1 or nil); end
	p.label:ClearAllPoints();
	local cross=SS.squareActive and radius or math.sqrt(math.max(0,(radius-2)*(radius-2)-(math.abs(dy)+6)*(math.abs(dy)+6)));
	local room=cross+math.abs(dx)-edge-3;
	if ( dx>0 ) then p.label:SetPoint("RIGHT",p,"LEFT",-2,0); else p.label:SetPoint("LEFT",p,"RIGHT",2,0); end
	p.label:SetText(t.label or ""); SS.FitText(p.label,math.max(0,room),7,12,t.label or "");
	p.tip, p.sub, p.dist = t.tip, t.sub, dist;
	p:Show();
	return p;
end

-- What to pin is gathered ten times a second; pins are placed every frame.
local targets = {};
local pinNames, pinAwake, pinNamesAt = nil, nil, 0;
local function GatherPins(space, options)
	local result = {};
	local d = options or DB();
	local phase = A.Call("AZS_GetPhase");
	local inRun = phase == nil or phase == "playing" or phase == "choosing" or phase == "paused" or phase == "ready";
	if ( SS.Demoing("MinimapCluster") and Minimap and type(W.demoPins) == "table" ) then
		-- Demo Mode: sample caches sitting still and sample bosses (with their marks) walking about, around you
		for i = 1, table.getn(W.demoPins) do table.insert(result, W.demoPins[i]); end
		return result;
	end
	if ( not Minimap or not inRun ) then return result; end
	if ( d.minimapCaches ) then
		local caches = A.Caches();
		for i = 1, table.getn(caches) do
			local c = caches[i];
			local x, y = A.Pos(c);
			if ( x and SameSpace(c, space) ) then
				table.insert(result, { x = x, y = y, size = 13, crop = true, texture = "Interface\\Icons\\INV_Box_02", tip = SS.T("Cache"), category = "cache", grey = phase=="ready", alpha = phase=="ready" and .45 or 1, sub = phase=="ready" and SS.T("Not yet available") or nil });
			end
		end
	end
	if ( d.minimapLairs or (not options and SS.CustomGuardianFlag()) ) then
		local lairs = W.LairInfo(GetTime());
		for i = 1, table.getn(lairs) do
			local l = lairs[i];
			local x, y = A.Pos(l.entry);
			if ( x and (d.minimapLairs or l.flagged) and SameSpace(l.entry, space) ) then
				local mark=W.MarkFor(l.id);
				local t = { x = x, y = y, size = l.flagged and 13 or 11, texture = mark and RAID_ICONS or PRE_PULL_ICON, tip = l.name, category = "lair", unitId = l.id, raid = mark, label = mark and l.name or nil };
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
				table.insert(result, t);
			end
		end
	end
	if ( d.minimapBosses ) then
		local live=A.LiveBossPositions(GetTime());
		-- the boss and guardian lists only change now and then: read once a second, not on every refresh
		local now=GetTime();
		if ( not pinNames or now>=pinNamesAt ) then
			pinNamesAt=now+1; pinNames=pinNames or {}; pinAwake=pinAwake or {};
			for k in pairs(pinNames) do pinNames[k]=nil; end
			for k in pairs(pinAwake) do pinAwake[k]=nil; end
			for _,entry in ipairs(A.Call("AZS_GetBosses") or {}) do pinNames[entry.id]=entry.name; end
			for _,entry in ipairs(A.Call("AZS_GetGuardians") or {}) do pinNames[entry.id]=entry.name; pinAwake[entry.id]=entry.awake==true or entry.state==1; end
		end
		local names,awake=pinNames,pinAwake;
		for _,entry in ipairs(type(AZS_UNITS)=="table" and AZS_UNITS or {}) do
			if ( entry.kind=="guardian" ) then awake[entry.id]=entry.awake==true or entry.state==1; end
		end
		for id,entry in pairs(live) do
			local kind=entry.kind; local guardian=kind=="guardian";
			if ( (kind=="boss" or kind=="finalBoss" or kind=="final" or (guardian and awake[id])) and SameSpace(entry,space) ) then
				local name=entry.name or names[id] or SS.T("Boss");
				-- Bosses on the map: their raid mark (or a plain red dot), with or without their name beside it
				local icons, named = d.minimapBossIcons ~= false, d.minimapBossNames ~= false;
				table.insert(result,{x=entry.x,y=entry.y,size=icons and 15 or 9,texture=icons and RAID_ICONS or "Interface\\Buttons\\WHITE8X8",
				 raid=icons and (W.MarkFor(id) or 8) or nil,r=not icons and 0.9 or nil,g=not icons and 0.15 or nil,b=not icons and 0.15 or nil,
				 tip=name,label=named and name or nil,category="boss",unitId=id,anchorId=entry.anchorId,
				 grey=phase=="ready",alpha=phase=="ready" and .45 or 1,sub=phase=="ready" and SS.T("Not yet available") or nil});
			end
		end
	end
	-- Prefer the moving guardian over its fixed home when both filters are enabled.
	local liveUnits={}; for _,point in ipairs(result) do if point.category=="boss" then liveUnits[point.unitId]=true; end end
	for i=table.getn(result),1,-1 do local point=result[i]; if point.category=="lair" and point.unitId and point.unitId~=0 and liveUnits[point.unitId] then table.remove(result,i); end end
	return result;
end

W.PointsOfInterest=GatherPins;

local pinGather = 0; local pinIdentity;
local function UpdateMinimapPins()
	local d = DB();
	SS.ApplyGuardianFlag();
	if ( not (d.minimapCaches or d.minimapBosses or d.minimapLairs or SS.CustomGuardianFlag() or SS.Demoing("MinimapCluster")) ) then
		if ( pinUsed > 0 ) then for i = 1, table.getn(pins) do pins[i]:Hide(); end pinUsed = 0; end
		return;
	end
	local now = GetTime();
	pinUsed = 0;
	local px, py, space = A.PlayerPos();
	if ( SS.Demoing("MinimapCluster") and not px ) then px, py = 0, 0; end   -- Demo Mode samples use the player's map centre
	local position=A.playerPosition;
	local identity=tostring(space)..":"..tostring(position and position.runId)..":"..tostring(position and position.mapId);
	-- moving bosses are gathered on every refresh so their pins keep up; otherwise ten times a second
	if ( d.minimapBosses or now >= pinGather or identity~=pinIdentity ) then pinIdentity=identity; pinGather = now + 0.1; targets=GatherPins(position or space); end
	if ( px and Minimap and Minimap:IsVisible() ) then
		for i = 1, table.getn(targets) do PlacePin(px, py, targets[i]); end
	end
	for i = pinUsed + 1, table.getn(pins) do pins[i]:Hide(); end
end
local pinDriver = CreateFrame("Frame");
SS.Every("pins", 0.05, function() SS.Safe(UpdateMinimapPins); end, pinDriver);

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

function W.DockLocalClock()
	if ( DB().clockDetached or not Minimap ) then return; end
	local scale=DB().scales.SlimSuiteLocalClockFrame;
	if ( SS.DisplayElementScale ) then scale=SS.DisplayElementScale("SlimSuiteLocalClockFrame",type(scale)=="number" and scale or 1); end
	if ( type(scale)=="number" ) then clock:SetScale(scale); end
	local ratio=SS.EffectiveScale(Minimap)/SS.EffectiveScale(clock);
	local border=SS.squareActive and not DB().minimapTransparent and 5 or 0;
	clock:ClearAllPoints(); clock:SetPoint("TOP",Minimap,"BOTTOM",0,-(border+2)*ratio);
end
local function UpdateLocalClock()
	local editing = Editing("SlimSuiteLocalClockFrame");
	if ( not SS.FeatureEnabled("SlimSuiteLocalClockFrame") ) then clock:Hide(); SS.HideNative("localClock", false); return; end
	local text = LocalTimeText();
	if ( not text and not editing ) then clock:Hide(); SS.HideNative("localClock", false); return; end
	SS.HideNative("localClock", true);
	clock.text:SetText(text or "7:09 PM");
	local band = DB().localClockBackground ~= false;
	SS.StyleBand(clock, { clock.bg, clock.left, clock.right }, band);
	local custom = DB().sizes and DB().sizes.SlimSuiteLocalClockFrame;
	local w, h = (clock.text:GetStringWidth() or 40) + 18, 20;
	if ( type(custom) == "table" and custom.w and custom.h ) then w, h = custom.w, custom.h; end   -- the size set is the size
	clock:SetWidth(w); clock:SetHeight(h);
	if ( SS.FitText ) then SS.FitText(clock.text, math.max(10, w - 10)); end   -- the time shrinks to fit a small box
	if ( not DB().clockDetached ) then
		W.DockLocalClock();
		if ( Minimap and not Minimap:IsVisible() and not editing ) then clock:Hide(); return; end
	end
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
		if ( Minimap ) then W.DockLocalClock();
		else clock:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -60, -170); end
	end
	SS.Safe(UpdateLocalClock);
end


SS.Every("localClock", 0.5, function() SS.Safe(UpdateLocalClock); end);   -- a clock that shows minutes
