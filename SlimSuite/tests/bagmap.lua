-- Optional Gameplay buttons hide the Bag and Map buttons; Ctrl-click (toggle) enlarges the minimap.
local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SS.SetupEnd(true); Tick(3,.1)
for _,n in ipairs({"MainMenuBarBackpackButton","MiniMapWorldMapButton"}) do if not getglobal(n) then CreateFrame("Button", n, UIParent) end end
local bag, map = MainMenuBarBackpackButton, MiniMapWorldMapButton
SS.DB().hideBagButton=true; SS.DB().hideMapButton=true; SS.ApplyBagMapButtons()
check("bag button hidden", not bag:IsShown())
check("map button hidden", not map:IsShown())
SS.DB().hideBagButton=false; SS.DB().hideMapButton=false; SS.ApplyBagMapButtons()
check("bag button back when the option is off", bag:IsShown())
check("map button back when the option is off", map:IsShown())
check("big map starts off", not SS.bigMapOn)
SS.ToggleBigMap(); check("ctrl-click turns the big map on", SS.bigMapOn==true)
SS.ToggleBigMap(); check("ctrl-click again turns it off", not SS.bigMapOn)
print("bag/map problems: "..bad)
assert(bad==0 and #ERRORS==0,"bag/map regressions")
