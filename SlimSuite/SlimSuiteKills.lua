-- Slim Suite: boss and Guardian kills this run. Split out of SlimSuiteWorld.lua, whose adapter (A) and helpers it shares.
-- Lua 5.0 / 1.12 interface: scripts read `this`, `arg1`; no # operator, no `...` in expressions; only the 1.12 API.
local W = SlimSuiteWorld;
local A, DB, Editing, Previewing = W.A, W.DB, W.Editing, W.Previewing;
local RAID_ICONS, PRE_PULL_ICON, SetRaidIcon = W.RAID_ICONS, W.PRE_PULL_ICON, W.SetRaidIcon;

-- ---------------------------------------------------------------- boss and Guardian kills this run
-- For the Kills / Gold / Cache tally. The game's run summary counts bosses and Guardians only once a run ends, so
-- during a run Slim Suite counts them itself: a boss or Guardian it saw in AZS_UNITS counts as killed once it is seen
-- at 3% health or lower (or dead), so one the game takes off the list the moment it dies is still counted. One that
-- leaves the list with more health left (out of range, despawned, walked off) is never counted. Each is counted once.
-- If the game ever puts its own counts in AZS_RUN, those are used instead.
-- The counts are kept in the saved settings per run, so they survive a /reload.
local tally = { bosses = 0, guardians = 0, alive = {}, counted = {}, run = nil, lastKills = nil };
SS.KILL_PERCENT = 3;                                       -- at or under this much health, a boss or Guardian is as good as dead
-- Three documented confirmation paths share one-to-one event matching. A second
-- channel acknowledges an existing kill instead of replaying its sound; simultaneous
-- same-name kills on the same channel still remain separate events.
local killBannerLastId,killBannersSeeded=0,false;
local killSounds={recent={},dead={},deadSeeded=false,anchorAt=-1,counts={},run=nil};
local function ConfirmKillSound(source,kind,name)
	local now=GetTime(); name=type(name)=="string" and name or "";
	local context=type(AZS_ZONE)=="table" and AZS_ZONE.run;
	for i=table.getn(killSounds.recent),1,-1 do
		local entry=killSounds.recent[i];
		if now-entry.time>3 then table.remove(killSounds.recent,i); end
	end
	for _,entry in ipairs(killSounds.recent) do
		if entry.run==context and entry.kind==kind and not entry.sources[source] and (name=="" or entry.name=="" or name==entry.name) then
			entry.sources[source]=true;
			if entry.name=="" then entry.name=name; end
			return;
		end
	end
	table.insert(killSounds.recent,{kind=kind,name=name,time=now,run=context,sources={[source]=true}});
	SS.PlayBossKillSound();
end
local function SeedKillBanners()
	if type(AZS_BANNERS)~="table" then return; end
	for _,banner in ipairs(AZS_BANNERS) do
		if type(banner.id)=="number" then killBannerLastId=math.max(killBannerLastId,banner.id); end
	end
	killBannersSeeded=true;
end
if type(AZS_BANNERS)=="table" then SeedKillBanners(); end
function SS.OnEncounterKillBanner(banner)
	if type(banner)~="table" or type(banner.id)~="number" then return; end
	if banner.id<=killBannerLastId then return; end
	killBannerLastId=banner.id;
	if banner.kind=="bossdown" or banner.kind=="guardian" then
		ConfirmKillSound("banner",banner.kind=="guardian" and "guardian" or "boss",banner.name);
	end
end
local function TrackKillBanners()
	if not killBannersSeeded then SeedKillBanners(); return; end
	for _,banner in ipairs(type(AZS_BANNERS)=="table" and AZS_BANNERS or {}) do SS.OnEncounterKillBanner(banner); end
end
-- The raw wire notification remains available if another addon replaces the native
-- banner handler list. Parse exactly the creator's documented AZSBANNER payload.
local killSoundEvents=CreateFrame("Frame");
killSoundEvents:RegisterEvent("CHAT_MSG_ADDON");
killSoundEvents:SetScript("OnEvent",function()
	if arg1~="AZSBANNER" or type(arg2)~="string" then return; end
	local _,_,id,kind,_,name=string.find(arg2,"^id=(%d+);kind=(%w+);boss=(%d);name=([^;]*);text=(.*)$");
	if id then SS.OnEncounterKillBanner({id=tonumber(id),kind=kind,name=name}); end
end);
local function TrackConfirmedKills()
	local run=type(AZS_RUN)=="table" and AZS_RUN or {};
	local context=type(AZS_ZONE)=="table" and AZS_ZONE.run;
	if context~=nil and context~=killSounds.run then
		killSounds.run=context; killSounds.counts={};
	end
	-- These counters are authoritative even if death notifications are not dispatched.
	local phase=A.Call("AZS_GetPhase");
	for _,field in ipairs({"bk","gk"}) do
		local value=tonumber(run[field]); local previous=killSounds.counts[field];
		if value and value>=0 then
			if previous and value>previous and (phase=="playing" or phase=="choosing" or phase=="paused" or phase=="victory") then
				for i=1,math.min(40,value-previous) do ConfirmKillSound("counter",field=="bk" and "boss" or "guardian"); end
			end
			killSounds.counts[field]=value;
		end
	end
	if GetTime()-killSounds.anchorAt<.25 then return; end
	killSounds.anchorAt=GetTime();
	local dead,cursor,complete={},nil,false;
	for pageNumber=1,32 do
		local page=A.Call("AZS_GetWorldAnchors",{kinds={"boss","finalBoss","guardian"},states={"dead"}},cursor);
		if type(page)~="table" or type(page.entries)~="table" then return; end
		for _,entry in ipairs(page.entries) do
			if entry.anchorId and entry.state=="dead" and (entry.kind=="boss" or entry.kind=="finalBoss" or entry.kind=="guardian") then dead[entry.anchorId]=entry; end
		end
		if not page.hasMore then complete=true; break; end
		cursor=page.nextCursor; if not cursor then return; end
	end
	if not complete then return; end
	if killSounds.deadSeeded then
		for id,entry in pairs(dead) do
			if not killSounds.dead[id] then ConfirmKillSound("anchor",entry.kind=="guardian" and "guardian" or "boss",entry.name); end
		end
	end
	killSounds.dead=dead; killSounds.deadSeeded=true;
end
local function CountKill(id, kind)
	if tally.counted[id] then return; end
	tally.counted[id]=true;
	if kind=="boss" then tally.bosses=tally.bosses+1; else tally.guardians=tally.guardians+1; end
end

-- The creator documents AZS_RUN.ck as caches opened. Catalog disappearance is not an open event.
local chestSoundState = { run = nil, count = nil };
local function TrackChestOpens()
	local run = type(AZS_RUN) == "table" and AZS_RUN or nil;
	local count = run and tonumber(run.ck);
	if ( not count or count < 0 ) then return; end
	local context = A.Call("AZS_GetMeterContext");
	local runId = type(AZS_ZONE) == "table" and AZS_ZONE.run or nil;
	runId = runId or (type(context) == "table" and context.runId);
	if ( runId == nil ) then return; end
	runId = tostring(runId);
	local phase = A.Call("AZS_GetPhase");
	local playing = phase == "playing" or phase == "choosing" or phase == "paused";
	if ( playing and chestSoundState.run == runId and chestSoundState.count and count > chestSoundState.count ) then
		SS.Safe(SS.PlayChestOpenSound);
	end
	chestSoundState.run, chestSoundState.count = runId, count;
end

local killSeen = {};
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
		tally.alive, tally.counted, tally.run = {}, {}, key;
	end
	tally.lastKills = kills;
	if ( not playing ) then if ( next(tally.alive) ) then tally.alive = {}; end return; end
	local units = type(AZS_UNITS) == "table" and AZS_UNITS or {};
	-- one table kept and emptied each pass, not a new one ten times a second
	local seen, any = killSeen, false;
	for k in pairs(seen) do seen[k] = nil; end
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
				if ( confirmed or low ) then CountKill(u.id, what); end
				-- The tally keeps its legacy low-health estimate; sounds use confirmed banners independently.
				local alive = tally.alive[u.id];
				if ( alive ) then alive.kind, alive.low = what, low; else tally.alive[u.id] = { kind = what, low = low }; end
			end
		end
	end
	-- gone from the list: no longer followed; an empty list (a loading screen) changes nothing
	if ( any ) then
		for id in pairs(tally.alive) do
			if ( not seen[id] ) then
				tally.alive[id] = nil;
			end
		end
	end
	local saved = DB().runKills;
	if ( type(saved) ~= "table" ) then saved = {}; DB().runKills = saved; end
	if ( saved.run ~= key or saved.bosses ~= tally.bosses or saved.guardians ~= tally.guardians ) then
		saved.run, saved.bosses, saved.guardians = key, tally.bosses, tally.guardians;
	end
end

-- bosses, guardians slain this run
function W.RunKills()
	local run = type(AZS_RUN) == "table" and AZS_RUN or nil;
	local b = run and tonumber(A.Field(run, "bossKills", "bossesKilled", "bk"));
	local g = run and tonumber(A.Field(run, "guardianKills", "guardiansKilled", "gk"));
	return b or tally.bosses, g or tally.guardians;
end


SS.Every("tracker", 0.1, function()
	SS.Safe(TrackKills);
	SS.Safe(TrackKillBanners);
	SS.Safe(TrackConfirmedKills);
	SS.Safe(TrackChestOpens);
end);
