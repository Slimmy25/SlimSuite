-- with something targeted, every way out of a preview (setup, Edit mode, Demo Mode) redraws the game's target frame
-- without the 1.12 "UnitFrame.lua:25 ... field `name'" error
local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("MISMATCH " .. label) end end
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
local setup = SS.ENV.SU
for _, playerLook in ipairs({ "classic", "new" }) do
    SS.StartSetup(true)
    setup.SetMode("PlayerFrame", "enabled", "Player")
    setup.SetMode("TargetFrame", "enabled", "Target")
    SS.SetLook("PlayerFrame", playerLook)
    -- A native refresh/setup restore can re-expose the original before target options change.
    PlayerFrame:Show(); PlayerFrame:SetAlpha(1)
    local targetChoice
    for _, row in ipairs(setup.ChecksFor("TargetFrame")) do if row[1] == "Target frame look" then targetChoice = row end end
    targetChoice[3]("new")
    check("target New-school keeps one player representation: " .. playerLook,
        playerLook == "new" and PlayerFrame:GetAlpha() == 0 or playerLook == "classic" and not SlimSuitePlayerCard:IsShown())
    Tick(6)
    check("player visibility remains exclusive after target refresh: " .. playerLook,
        playerLook == "new" and PlayerFrame:GetAlpha() == 0 or playerLook == "classic" and not SlimSuitePlayerCard:IsShown())
    setup.SetMode("PlayerFrame", "disabled", "Player"); Tick(6)
    check("disabled player cannot reappear as a custom card", not SlimSuitePlayerCard:IsShown())
    SS.SetupEnd(true)
end
print("target problems: " .. bad)
print("errors: " .. #ERRORS); for _, e in ipairs(ERRORS) do print("  " .. e) end
