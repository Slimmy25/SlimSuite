-- Slim Suite's shared core, loaded before the other Slim Suite files:
--   SS                 the one namespace for Slim Suite's functions and shared tables (replaces the SlimSuite_* globals)
--   SS.Safe(fn, a1..a6) calls fn with up to six arguments; an error is logged and said once in chat (returns pcall's results)
--   SS.Every(name, s, fn, watch)  runs fn every s seconds (0 = every frame) from one shared ticker;
--                      skipped while the optional watch frame is hidden, as WoW never sends OnUpdate to a hidden frame
--   SS.Stop(name)      stops a timed task
SS = SS or {};
local MAX_ENTRIES = 200;

function SS.AddonVersion()
	if ( GetAddOnMetadata ) then
		local ok, value = pcall(GetAddOnMetadata, "SlimSuite", "Version");
		if ( ok and type(value) == "string" and value ~= "" ) then return value; end
	end
	return "unknown"; -- Never report an old hardcoded release as the installed version.
end

-- GetEffectiveScale is missing on a few legacy UI regions and third-party minimap controls.
-- Use it when available, then reconstruct the inherited scale from the frame tree.
function SS.EffectiveScale(frame, seen)
	if ( not frame ) then return 1; end
	if ( frame.GetEffectiveScale ) then
		local ok, scale = pcall(frame.GetEffectiveScale, frame);
		if ( ok and type(scale) == "number" and scale > 0 ) then return scale; end
	end
	seen = seen or {};
	if ( seen[frame] ) then return 1; end
	seen[frame] = true;
	local own = 1;
	if ( frame.GetScale ) then
		local ok, scale = pcall(frame.GetScale, frame);
		if ( ok and type(scale) == "number" and scale > 0 ) then own = scale; end
	end
	local parent;
	if ( frame.GetParent ) then
		local ok, value = pcall(frame.GetParent, frame);
		if ( ok ) then parent = value; end
	end
	if ( parent and parent ~= frame ) then return own * SS.EffectiveScale(parent, seen); end
	return own;
end

-- Everything Slim Suite's files share lives in SS itself (SS.PlaceAll, SS.MOVABLE, ...), so nothing Slim Suite
-- makes can clash with another addon. Each file starts with short local names for the three used everywhere:
--   local K, SU, NAME = SS.Kit, SS.SU, SS.NAME;
-- A check in the tests fails if any file creates a new global name by mistake.
SS.SU = SS.SU or {};                                   -- the setup and element editor (SlimSuiteOnboarding.lua and on)
SS.NAME = "Slim Suite";

-- The saved variables can be replaced by the game after this file runs, so the log is looked up every time
-- rather than kept from load. Creates the saved table and the log if they are missing.
-- The game puts the player's saved settings in place only after the addon's files have run, so an error logged while
-- loading goes into a table that is then thrown away: those entries are carried over into the saved log.
local logOwner;
function SS.ErrorLog()
	if ( type(SlimSuiteDB) ~= "table" ) then SlimSuiteDB = {}; end
	if ( type(SlimSuiteDB.errorLog) ~= "table" ) then SlimSuiteDB.errorLog = {}; end
	if ( logOwner ~= SlimSuiteDB ) then
		local early = type(logOwner) == "table" and logOwner.errorLog;
		logOwner = SlimSuiteDB;
		if ( type(early) == "table" and early ~= SlimSuiteDB.errorLog ) then
			for i = 1, table.getn(early) do table.insert(SlimSuiteDB.errorLog, early[i]); end
		end
	end
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

-- An error caught by Slim Suite: always kept in the error log, and said once in chat per place in the code
-- ("File.lua:123"), with where to read it. No popup: a box in the middle of the screen stops a run.
local shownErrors = {};
function SS.Report(err)
	pcall(SS.LogError, err);                               -- logging must never raise an error of its own
	local key = tostring(err);
	local _, _, where = string.find(key, "^(.-:%d+):");
	key = where or (string.gsub(key, "%d+", "#"));
	if ( shownErrors[key] ) then return; end
	shownErrors[key] = true;
	if ( DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage ) then
		pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "|cffffd100Slim Suite|r |cffff6060hit an error|r (kept in /slim errors): " .. tostring(err));
	end
end

-- Calls fn with the given arguments, like pcall. A real error is logged and reported (above); a missing function (an
-- optional addon call that is not there) is skipped quietly, since that is expected rather than a fault.
-- Up to six arguments, passed on without trailing nils (some game functions reject extra nil arguments). Written
-- without "..." on purpose: in Lua 5.0 every "..." call makes a new table, and this runs hundreds of times a second.
function SS.Safe(fn, a1, a2, a3, a4, a5, a6)
	if ( type(fn) ~= "function" ) then return false; end
	local ok, r1, r2, r3, r4;
	-- cut after the last argument given (a nil in the middle is still passed)
	if ( a6 ~= nil ) then ok, r1, r2, r3, r4 = pcall(fn, a1, a2, a3, a4, a5, a6);
	elseif ( a5 ~= nil ) then ok, r1, r2, r3, r4 = pcall(fn, a1, a2, a3, a4, a5);
	elseif ( a4 ~= nil ) then ok, r1, r2, r3, r4 = pcall(fn, a1, a2, a3, a4);
	elseif ( a3 ~= nil ) then ok, r1, r2, r3, r4 = pcall(fn, a1, a2, a3);
	elseif ( a2 ~= nil ) then ok, r1, r2, r3, r4 = pcall(fn, a1, a2);
	elseif ( a1 ~= nil ) then ok, r1, r2, r3, r4 = pcall(fn, a1);
	else ok, r1, r2, r3, r4 = pcall(fn); end
	if ( not ok ) then SS.Report(r1); end
	return ok, r1, r2, r3, r4;
end

-- Hiding one of the game's own HUD parts while a Slim Suite replacement is on, and putting it back exactly as it was:
-- one set of rules for every part (meter, clock, bosses, banners, levels, tally, build, revive, localClock). The
-- original is kept in the saved settings (key) until it is put back, so a crash can never leave the game's part hidden;
-- a part the player had already turned off is never touched.
local natives = {};
local nativeElements = SS.NATIVE_ELEMENTS;
function SS.HideNative(part, on)
	if ( type(AZS_SetHudShown) ~= "function" ) then return; end
	local key = SS.NATIVE_KEYS[part];
	if ( not key ) then return; end                        -- a missing name would hide the whole HUD
	local modes = SS.DB().elementModes;
	if ( modes and modes[nativeElements[part]] == "disabled" ) then on = true; end
	local n = natives[part];
	if ( not n ) then n = {}; natives[part] = n; end
	-- already hidden: ask the game again only when its phase changes, and hide its part again if it came back
	local rearm = SS.PhaseChanged("hud:" .. part);
	if ( on and n.overridden ) then
		if ( rearm and type(AZS_IsHudShown) == "function" ) then
			local ok, shown = SS.Safe(AZS_IsHudShown, part);
			if ( ok and SS.HudShown(shown) ) then SS.Safe(AZS_SetHudShown, part, false); end
		end
		return;
	end
	if ( on ) then
		if ( n.off and not rearm ) then return; end         -- the player's own choice: looked at again when the phase changes
		local shown = true;
		if ( type(AZS_IsHudShown) == "function" ) then
			local ok, value = SS.Safe(AZS_IsHudShown, part);
			if ( ok and value ~= nil ) then shown = SS.HudShown(value); end
		end
		n.off = not shown;
		if ( shown ) then
			SS.DB()[key] = true;
			n.overridden = SS.Safe(AZS_SetHudShown, part, false) and true or false;
		end
	else
		n.off = nil;
		if ( n.overridden and SS.Safe(AZS_SetHudShown, part, true) ) then n.overridden = false; SS.DB()[key] = nil; end
	end
end
-- every part Slim Suite hid goes back to shown: at logout (so turning Slim Suite off leaves nothing hidden) and once
-- the saved settings are in (for a session that crashed before it could)
function SS.RestoreNatives()
	if ( type(AZS_SetHudShown) ~= "function" ) then return; end
	local d = SS.DB();
	for part, key in pairs(SS.NATIVE_KEYS) do
		if ( d[key] ~= nil and SS.Safe(AZS_SetHudShown, part, d[key] and true or false) ) then
			d[key] = nil;
			if ( natives[part] ) then natives[part].overridden = false; natives[part].off = nil; end
		end
	end
end

-- Runs one of the game's own frame functions as that frame: the 1.12 FrameXML functions (TargetFrame_Update,
-- UnitFrame_Update...) work on the global `this`, which is otherwise whatever frame's script is running now
-- (up to two arguments, passed through SS.Safe: no "..." table is made per call)
function SS.RunAs(frame, fn, a1, a2)
	local was = this;
	this = frame;
	local ok = SS.Safe(fn, a1, a2);
	this = was;
	return ok;
end

-- The tasks are kept in a list, run in order. A task started or stopped by another task while they run takes effect
-- safely: a stopped one is marked and skipped, and a new one joins the list from the next frame.
local tasks, list = {}, {};
local driver = CreateFrame("Frame");
-- Runs fn every `seconds` (0 = every frame). If `watch` is given, the task is skipped while that frame is
-- hidden, which matches WoW: a hidden frame never receives OnUpdate.
function SS.Every(name, seconds, fn, watch)
	local old = tasks[name];
	if ( old ) then old.stopped = true; end
	local t = { name = name, interval = seconds or 0, elapsed = 0, fn = fn, watch = watch };
	tasks[name] = t;
	table.insert(list, t);
end
function SS.Stop(name)
	if ( tasks[name] ) then tasks[name].stopped = true; end
	tasks[name] = nil;
end
driver:SetScript("OnUpdate", function()
	local dt = arg1 or 0;
	local n = table.getn(list);
	local i = 1;
	while ( i <= n ) do
		local t = list[i];
		if ( t.stopped ) then table.remove(list, i); n = n - 1; t = nil; else i = i + 1; end
		if ( not t ) then
			-- removed
		elseif ( t.watch and not t.watch:IsShown() ) then
			t.elapsed = 0;
		else
			t.elapsed = t.elapsed + dt;
			if ( t.elapsed >= t.interval ) then
				-- keep the remainder so a timer keeps its rhythm instead of running a little late every time;
				-- after a long stall it runs once and starts over rather than catching up
				t.elapsed = t.elapsed - t.interval;
				if ( t.elapsed >= t.interval ) then t.elapsed = 0; end
				local ok, err;
				if ( SS.perf ) then ok, err = SS.PerfRun(t);
				else ok, err = pcall(t.fn); end               -- called directly: nothing is made just to run a timer
				if ( not ok ) then SS.Report(err); end
			end
		end
	end
end);

-- ---------------------------------------------------------------- /slim perf
-- While on (10 seconds), every timer is measured: how often it ran, how long it took and how much memory it used up
-- (garbage the game has to clean up later, which is what causes small hitches). Off, it costs nothing.
local clock = type(debugprofilestop) == "function" and function() return debugprofilestop(); end
	or function() return GetTime() * 1000; end         -- milliseconds
local function MemoryKB() if ( type(gcinfo) == "function" ) then return (gcinfo()); end return 0; end
function SS.PerfRun(t)
	local p = SS.perf.tasks[t.name];
	if ( not p ) then p = { runs = 0, ms = 0, kb = 0 }; SS.perf.tasks[t.name] = p; end
	local m0, c0 = MemoryKB(), clock();
	local ok, err = pcall(t.fn);
	local c1, m1 = clock(), MemoryKB();
	p.runs = p.runs + 1; p.ms = p.ms + (c1 - c0);
	if ( m1 > m0 ) then p.kb = p.kb + (m1 - m0); end   -- a drop is the game cleaning up, not this timer
	return ok, err;
end
function SS.StartPerf(seconds)
	seconds = seconds or 10;
	SS.perf = { tasks = {}, started = GetTime(), memory = MemoryKB(), seconds = seconds };
	if ( SS.Kit ) then SS.Kit.Print(SS.NAME, "measuring every timer for " .. seconds .. " seconds; play normally..."); end
	SS.Every("perfReport", seconds, function() SS.Stop("perfReport"); SS.ReportPerf(); end);
end
function SS.ReportPerf()
	local p = SS.perf; if ( not p ) then return; end
	SS.perf = nil;
	local span = math.max(0.1, GetTime() - p.started);
	local list = {};
	for name, r in pairs(p.tasks) do if ( name ~= "perfReport" ) then table.insert(list, { name = name, runs = r.runs, ms = r.ms, kb = r.kb }); end end
	table.sort(list, function(a, b) return a.ms + a.kb > b.ms + b.kb; end);
	local totalMs, totalKb = 0, 0;
	for _, r in ipairs(list) do totalMs, totalKb = totalMs + r.ms, totalKb + r.kb; end
	local lines = {
		string.format("Slim Suite over %.0fs: %.1f ms of work per second (%.2f%% of the time), %.1f KB of garbage per second, %d KB in use.",
			span, totalMs / span, totalMs / span / 10, totalKb / span, MemoryKB()),
		"Busiest timers (runs per second, ms per second, KB of garbage per second):",
	};
	for i = 1, math.min(10, table.getn(list)) do
		local r = list[i];
		table.insert(lines, string.format("  %d. %s: %.1f runs, %.2f ms, %.1f KB", i, r.name, r.runs / span, r.ms / span, r.kb / span));
	end
	for _, line in ipairs(lines) do
		if ( SS.Kit ) then SS.Kit.Print(SS.NAME, line); end
		if ( SS.LogAction ) then SS.LogAction("[perf] " .. line); end
	end
	return lines;
end
