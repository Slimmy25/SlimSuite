-- Slim Suite's shared core, loaded before the other Slim Suite files:
--   SS                 the one namespace for Slim Suite's functions and shared tables (replaces the SlimSuite_* globals)
--   SS.Safe(fn, ...)   calls fn with the given arguments and logs any error to the error log (returns pcall's results)
--   SS.Every(name, s, fn, watch)  runs fn every s seconds (0 = every frame) from one shared ticker;
--                      skipped while the optional watch frame is hidden, as WoW never sends OnUpdate to a hidden frame
--   SS.Stop(name)      stops a timed task
SS = SS or {};
local MAX_ENTRIES = 200;

-- The saved variables can be replaced by the game after this file runs, so the log is looked up every time
-- rather than kept from load. Creates the saved table and the log if they are missing.
function SS.ErrorLog()
	if ( type(SlimSuiteDB) ~= "table" ) then SlimSuiteDB = {}; end
	if ( type(SlimSuiteDB.errorLog) ~= "table" ) then SlimSuiteDB.errorLog = {}; end
	return SlimSuiteDB.errorLog;
end

-- record one error message: the same error twice in a row is one line with a count
function SS.LogError(msg)
	local log = SS.ErrorLog();
	msg = tostring(msg or "");
	local stamp = date("%Y-%m-%d %H:%M:%S");
	-- a repeat is merged wherever it sits in the log, so a message that keeps coming back cannot push others out
	local found;
	for i = table.getn(log), 1, -1 do
		if ( log[i].msg == msg ) then found = log[i]; break; end
	end
	if ( found ) then
		found.count = (found.count or 1) + 1;
		found.at = stamp;
	else
		table.insert(log, { msg = msg, at = stamp, count = 1 });
	end
	while ( table.getn(log) > MAX_ENTRIES ) do table.remove(log, 1); end
end

-- True once each time the game's phase (waiting, in a run, ...) has changed since this key was last asked. Used to
-- check again whether the game has shown one of its own HUD parts that Slim Suite replaces.
local lastPhase = {};
function SS.PhaseChanged(key)
	local phase = "none";
	if ( type(AZS_GetPhase) == "function" ) then
		local ok, p = pcall(AZS_GetPhase);
		if ( ok ) then phase = tostring(p); end
	end
	local changed = lastPhase[key] ~= nil and lastPhase[key] ~= phase;
	lastPhase[key] = phase;
	return changed;
end

-- lets a frame keep the position the user placed it at; a frame the game will not move is skipped, not an error
function SS.UserPlace(f)
	if ( not f or not f.SetUserPlaced ) then return; end
	if ( f.SetMovable ) then pcall(f.SetMovable, f, true); end
	pcall(f.SetUserPlaced, f, true);
end

-- The game's answer to "is this HUD part shown?" as true or false: it can come as true/false, 1/0 or "1"/"0".
function SS.HudShown(value)
	if ( type(value) == "number" ) then return value ~= 0; end
	if ( type(value) == "string" ) then return value ~= "0" and string.lower(value) ~= "false" and value ~= ""; end
	return value and true or false;
end

-- Calls fn with the given arguments, like pcall. A real error is logged; a missing function (an optional
-- addon call that is not there) is skipped quietly, since that is expected rather than a fault.
-- each distinct error is shown in the game's error popup once, so it is seen even when chat is unusable;
-- repeats only go to the log. The popup goes through _ERRORMESSAGE, which the error log also records.
local shownErrors = {};
function SS.Safe(fn, ...)
	if ( type(fn) ~= "function" ) then return false; end
	-- exactly the arguments given, as pcall passed them: some game functions reject extra nil arguments
	local ok, r1, r2, r3, r4 = pcall(fn, unpack(arg));
	if ( not ok ) then
		-- one popup per place in the code ("File.lua:123"), not per message: a message carrying a changing number or
		-- name would otherwise count as new every time
		local key = tostring(r1);
		local _, _, where = string.find(key, "^(.-:%d+):");
		key = where or (string.gsub(key, "%d+", "#"));
		if ( not shownErrors[key] and type(_ERRORMESSAGE) == "function" ) then
			shownErrors[key] = true;
			pcall(_ERRORMESSAGE, r1);
		else
			pcall(SS.LogError, r1);   -- logging must never raise an error of its own
		end
	end
	return ok, r1, r2, r3, r4;
end

local tasks = {};
local driver = CreateFrame("Frame");
-- Runs fn every `seconds` (0 = every frame). If `watch` is given, the task is skipped while that frame is
-- hidden, which matches WoW: a hidden frame never receives OnUpdate.
function SS.Every(name, seconds, fn, watch)
	tasks[name] = { interval = seconds or 0, elapsed = 0, fn = fn, watch = watch };
end
function SS.Stop(name)
	tasks[name] = nil;
end
driver:SetScript("OnUpdate", function()
	local dt = arg1 or 0;
	for _, t in pairs(tasks) do
		if ( t.watch and not t.watch:IsShown() ) then
			t.elapsed = 0;
		else
			t.elapsed = t.elapsed + dt;
			if ( t.elapsed >= t.interval ) then
				t.elapsed = 0;
				SS.Safe(t.fn);
			end
		end
	end
end);
