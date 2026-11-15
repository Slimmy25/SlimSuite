local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SS.SetupEnd(true)
local d=SS.DB(); d.cardEdgeHUD=true; d.vanillaUI=false; d.unlocked=false
local phase,value="playing",12
AZS_ZONE={run="clock-one"}
AZS_GetPhase=function() return phase end
AZS_GetRunTime=function() return value end
SS.UpdateChoiceHUD(); phase="choosing"; SS.UpdateChoiceHUD()
check("phase alone does not immediately open overlay",not SS.ChoiceHUDActive())
AdvanceTime(.15); value=12.15; SS.UpdateChoiceHUD()
AdvanceTime(.2); SS.UpdateChoiceHUD()
check("still-moving clock postpones confirmation",not SS.ChoiceHUDActive())
AdvanceTime(.1); SS.UpdateChoiceHUD()
check("choosing plus stopped clock confirms overlay",SS.ChoiceHUDActive() and SS.ChoiceItemsActive())
phase="playing"; SS.UpdateChoiceHUD()
check("playing phase alone keeps a short closing grace",SS.ChoiceHUDActive())
value=12.25; SS.UpdateChoiceHUD()
check("resumed clock plus playing restores normal layout",not SS.ChoiceHUDActive())
phase="paused"; AdvanceTime(2); SS.UpdateChoiceHUD()
check("ordinary pause never opens a choice overlay",not SS.ChoiceHUDActive())
phase="choosing"; SS.UpdateChoiceHUD(); AdvanceTime(.3); SS.UpdateChoiceHUD()
check("subsequent choosing screen confirms normally",SS.ChoiceHUDActive())
phase="dead"; SS.UpdateChoiceHUD()
check("terminal phases close even with stopped clock",not SS.ChoiceHUDActive())
phase="choosing"; SS.UpdateChoiceHUD(); AdvanceTime(.3); SS.UpdateChoiceHUD(); phase="playing"; SS.UpdateChoiceHUD(); AdvanceTime(1.1); SS.UpdateChoiceHUD()
check("clock failure cannot trap the temporary overlay",not SS.ChoiceHUDActive())
phase="choosing"; AZS_GetRunTime=function() return nil end; SS.UpdateChoiceHUD()
check("unavailable clock retains older-client behavior",SS.ChoiceHUDActive())
AZS_GetRunTime=function() return 20 end; AZS_ZONE.run="clock-two"; SS.UpdateChoiceHUD()
check("a new run discards old clock evidence",not SS.ChoiceHUDActive())
AdvanceTime(.3); SS.UpdateChoiceHUD(); d.cardEdgeHUD=false; SS.UpdateChoiceHUD()
check("turning off overlay always closes it",not SS.ChoiceHUDActive())
-- Lua 5.0 has no math.huge; only call production logic while it is absent,
-- because the host mock's geometry implementation intentionally uses Lua 5.3 math.
local originalHuge=math.huge; math.huge=nil
AZS_GetRunTime=function() return 10 end; d.cardEdgeHUD=true; phase="choosing"
local ok,value=pcall(SS.ChoiceHUDActive)
local text=SS.LayoutText(SS.LayoutSnapshot()); local imported=SS.LayoutFromText(text)
AZS_GetRunTime=function() return 1/0 end
local infiniteOk=pcall(SS.ChoiceHUDActive)
AZS_GetRunTime=function() return 0/0 end
local nanOk=pcall(SS.ChoiceHUDActive)
math.huge=originalHuge
check("legacy clock check works without math.huge",ok)
check("legacy numeric profile parsing works without math.huge",imported~=nil)
check("non-finite clock values are handled safely",infiniteOk and nanOk)
print("choice clock problems: "..bad)
assert(bad==0 and #ERRORS==0,"choice clock regressions")
