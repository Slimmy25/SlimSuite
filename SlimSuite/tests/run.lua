-- Loads Slim Suite into the mock client and drives the setup screen.
local DIR = "/home/claude/src/SlimSuite/SlimSuite/"
dofile("/tmp/harness/wow.lua")

local function loadFile(name)
	local fh = assert(io.open(DIR .. name, "rb"))
	local src = fh:read("a"); fh:close()
	src = src:gsub("unpack%(arg%)", "...")
	local chunk, err = load(src, "@" .. name)
	if not chunk then print("COMPILE " .. err) return end
	local ok, e = pcall(chunk)
	if not ok then print("LOAD " .. tostring(e)) end
end
for _, f in ipairs({ "SlimSuiteCore.lua", "AZSKit.lua", "SlimSuiteErrors.lua", "SlimSuiteItems.lua", "SlimSuiteMeter.lua", "SlimSuite.lua", "SlimSuiteWorld.lua" }) do
	loadFile(f)
end
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
dofile("/tmp/harness/" .. scenario .. ".lua")
