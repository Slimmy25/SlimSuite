-- checks for the 1.10 review fixes
local function upvalue(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i) if not n then return SS.ENV and SS.ENV[want] end if n == want then return v end i = i + 1 end end
SU = upvalue(SS.SetupHide, "SU")
local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("  MISMATCH " .. label) end end
-- the settings table is prepared once, and again when the game swaps in another one
local d = SS.DB()
check("defaults are there", d.bossMarks == true and type(d.places) == "table" and d.raidRow == true)
d.bossMarks = nil
check("not re-applied on every read", SS.DB().bossMarks == nil)
d.bossMarks = true
local old = SlimSuiteDB
SlimSuiteDB = { hideLevel = false }
check("a swapped-in table gets its defaults", SS.DB().bossMarks == true and SS.DB().hideLevel == false)
SlimSuiteDB = old; SS.DB()
-- the game's HUD parts: hidden once, left alone when the player had them off, put back on logout
local shown, calls = { meter = true, clock = false }, 0
rawset(_G, "AZS_IsHudShown", function(part) return shown[part] end)
rawset(_G, "AZS_SetHudShown", function(part, on) calls = calls + 1; shown[part] = on end)
SS.HideNative("meter", true); SS.HideNative("meter", true); SS.HideNative("meter", true)
check("the meter is hidden with one call", shown.meter == false and calls == 1 and SS.DB().meterNativeOriginal == true)
SS.HideNative("clock", true)
check("a part the player turned off is not touched", shown.clock == false and calls == 1 and SS.DB().clockNativeOriginal == nil)
SS.HideNative("meter", false)
check("turning the replacement off shows the game's again", shown.meter == true and SS.DB().meterNativeOriginal == nil)
SS.HideNative("meter", true); SS.RestoreNatives()
check("logout puts it back", shown.meter == true and SS.DB().meterNativeOriginal == nil)
rawset(_G, "AZS_IsHudShown", nil); rawset(_G, "AZS_SetHudShown", nil)
-- an error is logged and said in chat once, with no popup
local popups, lines = 0, 0
local oldPopup, oldAdd = _ERRORMESSAGE, DEFAULT_CHAT_FRAME.AddMessage
_ERRORMESSAGE = function() popups = popups + 1 end
DEFAULT_CHAT_FRAME.AddMessage = function() lines = lines + 1 end
local before = #ERRORS
for i = 1, 3 do SS.Safe(function() error("review test error") end) end
_ERRORMESSAGE, DEFAULT_CHAT_FRAME.AddMessage = oldPopup, oldAdd
check("no popup, one chat line, every time logged", popups == 0 and lines == 1 and #ERRORS == before + 3)
for i = #ERRORS, before + 1, -1 do table.remove(ERRORS, i) end
-- Toggle UI Settings always opens the element list (with the grid and Done); the old move panel is gone
SS.DB().setupDone = nil
SS.SetUnlocked(true); Tick(2)
check("first time: the setup", SU.bar:IsVisible())
SS.SetupEnd(true); Tick(2)
SS.SetUnlocked(true); Tick(2)
check("afterwards: the element list again", SU.bar:IsVisible() and not (SlimSuiteMovePanel and SlimSuiteMovePanel:IsVisible()))
check("grid and Done are on the list", SU.grid:GetParent() == SU.bar and SU.bar.done:IsVisible())
check("Demo controls precede the settings hint", SU.bar.demoLabel:GetText() == "Demo" and SU.bar.demoOn.points[1][4] < SU.bar.demoOff.points[1][4] and SU.bar.demoHint.points[1][2] == SU.bar.demoOff)
Click(SU.bar.done); Tick(2)
check("Done asks before closing setup", SU.bar:IsVisible() and SU.confirmDone:IsVisible())
SU.HideAll(); Tick(2)
check("setup hiding keeps confirmation visible", SU.confirmDone:IsVisible() and SU.confirmDone:GetAlpha() > 0)
Click(SU.confirmDone.back); Tick(1)
check("Back keeps setup open", SU.bar:IsVisible() and not SU.confirmDone:IsVisible())
Click(SU.bar.done); Click(SU.confirmDone.confirm); Tick(2)
check("Done closes it", not SU.bar:IsVisible() and not SS.DB().unlocked)
SS.SetUnlocked(true, true); Tick(2)
-- the element menu: only the rows an element uses, and no setting offered twice
local sm
local function rows(name) SS.OpenSizeMenu(name, name); Tick(1); sm = sm or upvalue(SS.PrepareSizeTools, "sizeMenu"); return sm.rows end
local r = rows("PlayerFrame")
check("classic player frame: scale only", not r.width.on and not r.height.on and r.scale.on and not r.layout.on and not r.padding.on)
local short = sm:GetHeight()
r = rows("SlimSuiteClockFrame")
check("run clock: size, layout and padding", r.width.on and r.layout.on and r.padding.on and sm:GetHeight() > short)
r = rows("MainMenuBar")
check("action bar: vertical is a setting, not also a button", not r.layout.on and sm.layoutButton.shown == false)
r = rows("GameTooltip")
check("tooltip: width only", r.width.on and not r.height.on)
SS.SetUnlocked(false, true); Tick(2)
-- layouts: saved, changed, loaded back; and as text
SS.DB().places.SlimSuiteClockFrame = { x = 111, y = 222, coordinateSpace = "uiParent" }
SS.DB().scales.SlimSuiteClockFrame = 1.5
SS.DB().partyLook = "thin"
local snap = SS.LayoutSnapshot()
local text = SS.LayoutText(snap)
SS.DB().places.SlimSuiteClockFrame.x = 5; SS.DB().scales.SlimSuiteClockFrame = nil; SS.DB().partyLook = "classic"
check("applying a layout", SS.LayoutApply(snap) and SS.DB().places.SlimSuiteClockFrame.x == 111 and SS.DB().scales.SlimSuiteClockFrame == 1.5 and SS.DB().partyLook == "thin")
local back = SS.LayoutFromText(text)
check("a layout survives being text", back and back.places.SlimSuiteClockFrame.x == 111 and back.places.SlimSuiteClockFrame.coordinateSpace == "uiParent"
	and back.scales.SlimSuiteClockFrame == 1.5 and back.partyLook == "thin" and back.buildRowsAttached == snap.buildRowsAttached)
check("other text is refused", SS.LayoutFromText("hello") == nil and SS.LayoutFromText("SSL1;evil.key=n1") == nil)
SlashCmdList.SLIMSUITE("layout save test one"); SS.DB().partyLook = "classic"
SlashCmdList.SLIMSUITE("layout load test one")
check("/slim layout save and load", SS.DB().partyLook == "thin" and SS.LayoutNames()[1] == "test one")
SlashCmdList.SLIMSUITE("layout delete test one")
check("/slim layout delete", #SS.LayoutNames() == 0)
-- per character
SS.SetLayoutPerCharacter(true)
SS.LayoutLogout()
check("each character's layout is kept at logout", type(SS.DB().layouts[SS.LayoutCharacter()]) == "table")
SS.SetLayoutPerCharacter(false); SS.DB().layouts = {}
SS.SetLook("PartyMemberFrame1", "classic"); SS.DB().places.SlimSuiteClockFrame = nil
-- /slim hide: no duplicates
SlashCmdList.SLIMSUITE("hide some words"); SlashCmdList.SLIMSUITE("hide some words")
check("a hidden word is kept once", #SS.DB().words == 1)
SlashCmdList.SLIMSUITE("unhide some words"); SlashCmdList.SLIMSUITE("help"); SlashCmdList.SLIMSUITE("hide")
-- the camera zooms out once a session
local zooms = 0
CameraZoomOut = function() zooms = zooms + 1 end
SS.cameraZoomed = nil; SS.Camera(true); SS.Camera(true)
check("the camera zooms out once", zooms == 1)
print("review problems: " .. bad)
print("errors: " .. #ERRORS); for _, e in ipairs(ERRORS) do print("  " .. e) end
-- the list shows every element, on or off; the combat text gets its green handle when turned on there
SS.DB().combatTextBox = false; SS.SetupEnd(true); Tick(1)
SS.SetUnlocked(true); Tick(2)
local listed = false
for _, e in ipairs(SU.elements) do if e.frame == "SlimSuiteCombatTextFrame" then listed = true end end
check("combat text is listed while off", listed)
SU.SetMode("SlimSuiteCombatTextFrame", "enabled", "Combat text"); SS.SetUnlocked(true, true); Tick(2)
check("turning it on turns the box on", SS.DB().combatTextBox == true)
check("and it has a green handle", SS.ENV.handles.SlimSuiteCombatTextFrame and SS.ENV.handles.SlimSuiteCombatTextFrame:IsShown())
print("list problems: " .. bad)
-- the element list: two columns, and it can be dragged
local cols = {}
for _, b in pairs(SU.barButtons) do if b:IsShown() then local p = b.points[1]; cols[p[4]] = true end end
local nc = 0; for _ in pairs(cols) do nc = nc + 1 end
check("element list in two columns", nc == 2)
check("element list can be dragged", SU.bar.movable or (SU.bar.IsMovable and SU.bar:IsMovable()) or SU.bar:GetScript("OnDragStart") ~= nil)
print("listcols problems: " .. bad)
-- Demo On/Off beside the grid; the list stays while the demo runs
Click(SU.bar.demoOn); Tick(2)
check("Demo On from the list closes the list", SS.demoRunning and not SU.bar:IsVisible())
check("only the small box shows", SlimSuiteDemoBox and SlimSuiteDemoBox:IsShown())
Click(SlimSuiteDemoBox.off); Tick(2)
check("Off brings the list back", not SS.demoRunning and SU.bar:IsVisible())
print("listdemo problems: " .. bad)
