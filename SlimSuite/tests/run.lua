-- Loads Slim Suite into the mock client and drives the setup screen.
-- Paths are relative to this file (tests/), so it runs from any checkout: sh tests/run-checks.sh
local HERE = (arg and arg[0] and string.match(arg[0], "^(.*[/\\])")) or "./"
local DIR = HERE .. "../"
dofile(HERE .. "wow.lua")
local testLocale = os.getenv("TEST_LOCALE")
if testLocale then GetLocale = function() return testLocale end end

local function loadFile(name)
	local fh = assert(io.open(DIR .. name, "rb"))
	local src = fh:read("a"); fh:close()
	src = src:gsub("unpack%(arg%)", "...")
	src = src:gsub("if %( setfenv %) then setfenv%(1, SS%.ENV%); end", "local _ENV = SS;")
	local chunk, err = load(src, "@" .. name)
	if not chunk then error("COMPILE " .. err, 0) end
	local ok, e = pcall(chunk)
	if not ok then error("LOAD " .. tostring(e), 0) end
end
-- the game's globals before Slim Suite loads: anything Slim Suite adds is checked after login (see below)
local globalsBefore = {}
for k in pairs(_G) do globalsBefore[k] = true end
-- Follow the actual addon manifest so new modules cannot silently disappear from the harness.
for line in io.lines(DIR .. "SlimSuite.toc") do
	local file = line:match("^%s*(.-%.lua)%s*$")
	if file then loadFile(file) end
end
-- every error Slim Suite catches counts as a test error
do local log = SS.LogError; SS.LogError = function(m) table.insert(ERRORS, "error: " .. tostring(m)); return log(m) end end
local scenario = os.getenv("SCENARIO") or "setup"
print("loaded; errors so far: " .. #ERRORS)
assert(#ERRORS == 0 and table.getn(SS.ErrorLog()) == 0, "addon load reported errors")
FireEvent("ADDON_LOADED", "SlimSuite")
FireEvent("VARIABLES_LOADED")
FireEvent("PLAYER_LOGIN")
FireEvent("PLAYER_ENTERING_WORLD")
Tick(20)
print("after login; errors: " .. #ERRORS)
for _, e in ipairs(ERRORS) do print("  " .. e) end
assert(#ERRORS == 0, "addon startup reported errors")
-- Slim Suite keeps everything it shares in SS. The only new global names it may make are its saved settings, its
-- slash commands and frames named SlimSuite...; anything else could clash with another addon.
do
	local missing = {}
	for _, k in ipairs(MissingGlobals()) do missing[k] = true end
	local leaked = {}
	for k in pairs(_G) do
		if type(k) == "string" and not globalsBefore[k] and not missing[k]
			and not string.match(k, "^SlimSuite") and not string.match(k, "^SLASH_SLIM") and k ~= "SS"
			and k ~= "event" and k ~= "this" and not string.match(k, "^arg%d$") then   -- the game's own event globals
			table.insert(leaked, k)
		end
	end
	table.sort(leaked)
	if #leaked > 0 then print("  GLOBAL LEAK: " .. table.concat(leaked, ", ")) end
	assert(#leaked == 0, "Slim Suite made new global names")
end
ERRORS = {}
dofile(HERE .. scenario .. ".lua")
