-- Loads Slim Suite into the mock client and drives the setup screen.
-- Paths are relative to this file (tests/), so it runs from any checkout: sh tests/run-checks.sh
local HERE = (arg and arg[0] and string.match(arg[0], "^(.*[/\\])")) or "./"
local DIR = HERE .. "../"
dofile(HERE .. "wow.lua")

local function loadFile(name)
	local fh = assert(io.open(DIR .. name, "rb"))
	local src = fh:read("a"); fh:close()
	src = src:gsub("unpack%(arg%)", "...")
	src = src:gsub("if %( setfenv %) then setfenv%(1, SS%.ENV%); end", "local _ENV = SS.ENV;")
	local chunk, err = load(src, "@" .. name)
	if not chunk then print("COMPILE " .. err) return end
	local ok, e = pcall(chunk)
	if not ok then print("LOAD " .. tostring(e)) end
end
-- Follow the actual addon manifest so new modules cannot silently disappear from the harness.
for line in io.lines(DIR .. "SlimSuite.toc") do
	local file = line:match("^%s*(.-%.lua)%s*$")
	if file then loadFile(file) end
end
-- every error Slim Suite catches counts as a test error
do local log = SS.LogError; SS.LogError = function(m) table.insert(ERRORS, "error: " .. tostring(m)); return log(m) end end
local scenario = os.getenv("SCENARIO") or "setup"
print("loaded; errors so far: " .. #ERRORS)
FireEvent("ADDON_LOADED", "SlimSuite")
FireEvent("VARIABLES_LOADED")
FireEvent("PLAYER_LOGIN")
FireEvent("PLAYER_ENTERING_WORLD")
Tick(20)
print("after login; errors: " .. #ERRORS)
for _, e in ipairs(ERRORS) do print("  " .. e) end
ERRORS = {}
dofile(HERE .. scenario .. ".lua")
