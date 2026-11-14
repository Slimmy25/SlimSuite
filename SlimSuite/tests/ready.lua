-- Useful enabled HUD data is visible at Move to begin, without demo content or made-up events.
local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("MISMATCH " .. label) end end
local d = SS.DB()
d.unlocked = false
SS.demoRunning = false
AZS_GetPhase = function() return "ready" end
AZS_GetRunTime = function() return 900 end -- a stale previous-run timer must not leak into ready
AZS_GetStoredLevels = function() return 0 end
AZS_UNITS = {}
AZS_RUN = { kills = 0, gold = 0, chest = 20, nb = 180 }
local setup = SS.ENV.SU
for _, name in ipairs({ "SlimSuiteTallyFrame", "SlimSuiteClockFrame", "SlimSuiteMeterFrame", "SlimSuiteBossFrames", "SlimSuiteAnnouncementFrame", "SlimSuiteStoredLevelsButton" }) do
    setup.SetMode(name, "enabled", name)
end
Tick(5)
check("ready tally is visible without editing", SlimSuiteTallyFrame:IsShown())
check("ready clock starts at zero", SlimSuiteClockFrame:IsShown() and SlimSuiteClockFrame.time:GetText() == "00:00")
check("enabled damage meter is visible before movement", SlimSuiteMeterFrame:IsShown())
check("no sample bosses before movement", not SlimSuiteBossFrames:IsShown())
check("no invented announcements before movement", not SlimSuiteAnnouncementFrame:IsShown())
check("no empty level-up prompt", not SlimSuiteStoredLevelsButton:IsShown())
local parts = SS.TallyParts(AZS_RUN, false, true)
check("ready values use the real cache cost and zero counts", parts[1][2] == "0" and parts[2][2] == "0" and parts[3][2] == "0" and parts[4][2] == "0" and parts[5][2] == "20")
AZS_RUN = nil; SS.UpdateTally()
check("ready tally survives data arriving late", SlimSuiteTallyFrame:IsShown())
AZS_GetPhase = function() return "playing" end
AZS_RUN = { kills = 7, gold = 9, chest = 35 }
SS.UpdateTally()
check("run values replace starting values", SS.TallyParts(AZS_RUN)[1][2] == "7" and SlimSuiteTallyFrame:IsShown())
setup.SetMode("SlimSuiteTallyFrame", "disabled", "Tally")
AZS_GetPhase = function() return "ready" end
SS.UpdateTally()
check("ready does not enable disabled tally", not SlimSuiteTallyFrame:IsShown())
-- Ready must not force foreground layering after the unsuccessful overlap workaround was removed.
local top = {}
AZS_SetOnTopOfScreens = function(f, on) top[f] = on end
d.onTopOfScreens = false
SlimSuiteWorld.ApplyOnTop()
check("ready does not force foreground layering", top[SlimSuiteClockFrame] == false and top[PlayerFrame] == nil)
d.onTopOfScreens = true; SlimSuiteWorld.ApplyOnTop()
check("explicit card overlay preference still works", top[SlimSuiteClockFrame])
print("ready problems: " .. bad)
print("errors: " .. #ERRORS); for _, e in ipairs(ERRORS) do print("  " .. e) end
