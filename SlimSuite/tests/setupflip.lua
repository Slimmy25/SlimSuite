local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("  MISMATCH " .. label) end end
-- old saved data that marks everything as on, then a written-out design that mentions only a few elements
local d = SS.DB(); d.enabledElements = {}
for name in pairs(SS.ELEMENTS) do d.enabledElements[name] = true end
-- a layout that turns on only the run clock: every other element is left at Default
d.elementModes = {}
for name in pairs(SS.ELEMENTS) do d.elementModes[name] = "default" end
d.elementModes.SlimSuiteClockFrame = "enabled"; Tick(3)
local before = {}; for name in pairs(SS.ELEMENTS) do before[name] = SS.DB().elementModes[name] end
SS.StartSetup(true); Tick(5); SS.SetupEnd(true); Tick(3)
for name in pairs(SS.ELEMENTS) do
	if before[name] ~= "enabled" then check(name .. " not switched on by opening the setup", SS.DB().elementModes[name] ~= "enabled") end
end
print("errors: " .. #ERRORS); print("setup flip problems: " .. bad)
if bad > 0 or #ERRORS > 0 then error("setup flip") end
