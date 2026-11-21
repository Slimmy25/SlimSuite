-- Teammate revive sound: plays once when a downed teammate you were helping gets back up.
-- Two pieces of evidence are needed (see docs/api-capabilities.md):
--   1. AZS_GetRevive() showed you reviving that teammate (reviving = their name, rshare > 0) in that fall, and
--      no more than HELP_WINDOW seconds before the fall ended.
--   2. That fall's downed anchor then expired with reason "revived" in AZS_ProjectWorldAnchors.
-- A reset bar, the teammate leaving, the run ending or an empty/not-ready list never plays it.
-- This is a sound only: it is not revive credit, and someone else may have finished the revive with you.
local K, SU, NAME = SS.Kit, SS.SU, SS.NAME;   -- the three names every Slim Suite file uses (SlimSuiteCore.lua)
local HELP_WINDOW = 3;     -- your progress must have been seen this recently before the fall ended
local ANSWER_WAIT = 5;     -- how long an ended fall is asked about before it is dropped
local falls, played, lastRun = {}, {}, nil;   -- anchor id -> { name, helped, gone }; anchor id -> true

local function CurrentRun()
	return type(AZS_ZONE) == "table" and AZS_ZONE.run or nil;
end

function SS.OnTeammateRevived(anchorId)
	if ( played[anchorId] ) then return false; end
	played[anchorId] = true;
	local selected = SS.SoundSelection("revive");
	if ( selected == "off" ) then return false; end
	return SS.PlayAddonSound(selected);
end

function SS.UpdateReviveSound()
	local now = GetTime();
	local run = CurrentRun();
	if ( run ~= lastRun ) then falls = {}; played = {}; lastRun = run; end
	if ( type(AZS_GetDownedPartyMembers) ~= "function" ) then return; end
	local ok, list = SS.Safe(AZS_GetDownedPartyMembers);
	if ( not ok or type(list) ~= "table" ) then return; end            -- not ready: never proof of anything
	local me = UnitName and UnitName("player");
	local present = {};
	for i = 1, table.getn(list) do
		local f = list[i];
		if ( type(f) == "table" and f.anchorId ~= nil and type(f.name) == "string" and f.name ~= me
		     and (f.run == nil or run == nil or f.run == run) ) then
			present[f.anchorId] = true;
			local fall = falls[f.anchorId];
			if ( not fall ) then fall = { name = f.name }; falls[f.anchorId] = fall; end
			fall.gone = nil;
		end
	end
	-- Your current revive target and progress.
	if ( type(AZS_GetRevive) == "function" ) then
		local okR, r = SS.Safe(AZS_GetRevive);
		if ( okR and type(r) == "table" and type(r.reviving) == "string" and r.reviving ~= "" and (tonumber(r.rshare) or 0) > 0 ) then
			for id, fall in pairs(falls) do
				if ( present[id] and fall.name == r.reviving ) then fall.helped = now; end
			end
		end
	end
	-- Falls that just left the list: ask the game how each one ended.
	local ask = {};
	for id, fall in pairs(falls) do
		if ( not present[id] ) then
			fall.gone = fall.gone or now;
			if ( not fall.helped or fall.gone - fall.helped > HELP_WINDOW or now - fall.gone > ANSWER_WAIT ) then
				falls[id] = nil;
			else
				table.insert(ask, { anchorId = id, attachment = "position" });
			end
		end
	end
	if ( table.getn(ask) == 0 or type(AZS_ProjectWorldAnchors) ~= "function" ) then return; end
	local okP, result = SS.Safe(AZS_ProjectWorldAnchors, ask);
	if ( not okP or type(result) ~= "table" or type(result.entries) ~= "table" ) then return; end
	for i = 1, table.getn(result.entries) do
		local e = result.entries[i];
		local fall = type(e) == "table" and falls[e.anchorId];
		if ( fall and e.reason ~= nil ) then
			falls[e.anchorId] = nil;
			if ( e.reason == "revived" ) then SS.OnTeammateRevived(e.anchorId); end
		end
	end
end

SS.Every("reviveSound", .1, function() SS.Safe(SS.UpdateReviveSound); end);
