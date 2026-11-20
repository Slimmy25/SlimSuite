-- The Character window offers Vertical in its size menu, choosing it turns the element on, and the gold focus outline
-- only shows during setup.
local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SU = SS.ENV.SU
SS.SetupEnd(true); Tick(3,.1)
if not getglobal("CharacterFrame") then CreateFrame("Frame","CharacterFrame",UIParent) end
SS.OpenSizeMenu("CharacterFrame","Character")
check("the size menu offers a layout row for the Character window", SS.ENV.sizeMenu and SS.ENV.sizeMenu.rows.layout.on==true)
SU.SetMode("CharacterFrame","default","Character")
SS.ToggleMovableOrientation("CharacterFrame")
check("choosing vertical turns the Character window on", SU.Mode("CharacterFrame")=="enabled")
check("and it is vertical", SS.CurrentOrientation("CharacterFrame")=="vertical")
SU.Focus(CharacterFrame)
check("the gold outline does not show outside setup", not (SU.outline and SU.outline:IsShown()))
SU.Focus(nil)
print("character layout problems: "..bad)
assert(bad==0 and #ERRORS==0,"character layout regressions")
