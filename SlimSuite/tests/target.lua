-- with something targeted, every way out of a preview (setup, Edit mode, Demo Mode) redraws the game's target frame
-- without the 1.12 "UnitFrame.lua:25 ... field `name'" error
MOCK_TARGET = true
for _, look in ipairs({ "classic", "new" }) do
	SS.SetLook("TargetFrame", look); Tick(2)
	SS.SetUnlocked(true, true); Tick(3); SS.SetUnlocked(false, true); Tick(3)
	SS.StartSetup(true); Tick(3); SS.SetupEnd(true); Tick(3)
	SS.StartDemoMode(); Tick(10); SS.StopDemoMode(); Tick(3)
end
MOCK_TARGET = false
SS.SetUnlocked(true, true); Tick(2); SS.SetUnlocked(false, true); Tick(2)
SS.SetLook("TargetFrame", "classic"); Tick(1)
print("errors: " .. #ERRORS); for _, e in ipairs(ERRORS) do print("  " .. e) end
