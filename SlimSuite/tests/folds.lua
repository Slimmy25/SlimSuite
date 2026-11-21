local bad = 0
local function upvalue(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i) if not n then return SS[want] end if n == want then return v end i = i + 1 end end
SU = upvalue(SS.SetupHide, "SU")
local function check(label, ok) if not ok then bad = bad + 1; print("  MISMATCH " .. label) end end
for k, fn in pairs(SlashCmdList or {}) do if string.find(k, "SLIM") then fn("") break end end
Tick(2)
if SS.OpenModulePage then SS.OpenModulePage("ui") end; Tick(2)
local page; for _, p in ipairs(SS.pages or {}) do for _, r in ipairs(p.rows) do if r.kind == "fold" then page = p end end end
check("the Interface page has element sections", page ~= nil)
local folds, mini = 0, nil
for _, r in ipairs(page and page.rows or {}) do if r.kind == "fold" then folds = folds + 1; if r.title == "Minimap" then mini = r end end end
print("sections", folds)
local all = 0; for name in pairs(SS.ELEMENTS) do if name ~= "SlimSuiteEditGrid" then all = all + 1 end end
check("every element has a section (" .. folds .. " of " .. all .. ")", folds >= all - 1)
check("a Minimap section", mini ~= nil)
local inside = {}; for _, r in ipairs(page.rows) do if r.fold == mini then table.insert(inside, r) end end
local function visible() local n = 0 for _, r in ipairs(inside) do local w = r.cb or r.b; if w and w.shown ~= false and w:IsShown() then n = n + 1 end end return n end
check("closed: its settings are hidden", visible() == 0)
SU.SetMode("MinimapCluster", "disabled", "Minimap"); Tick(1)
local fn = mini.b:GetScript("OnClick"); this = mini.b; fn(); Tick(1)
check("an element that is Off cannot be opened", visible() == 0)
local on = mini.modes[1]; local onClick = on:GetScript("OnClick"); this = on; onClick(); Tick(1)
check("choosing On turns it on but leaves its settings closed", SU.Mode("MinimapCluster") == "enabled" and visible() == 0)
check("the + sits outside the name", mini.sign and mini.sign:GetText() == "+" and mini.b:GetText() == mini.title)
this = mini.b; fn(); Tick(1)
print("minimap rows", table.getn(inside), "visible", visible())
check("open: its settings show", visible() >= 6)
local labels = {}; for _, r in ipairs(inside) do table.insert(labels, (r.cb and r.cb.label and r.cb.label:GetText()) or (r.fs and r.fs:GetText()) or "?") end
print(table.concat(labels, " | "))
fn(); Tick(1); check("closed again", visible() == 0)
-- opacity: every element has it, 0 to 100%, and hiding still wins
SS.SetElementOpacity("SlimSuiteCompassFrame", 40); Tick(3)
check("compass at 40%", math.abs(SlimSuiteCompassFrame:GetAlpha() - 0.4) < 0.01)
SS.SetElementOpacity("SlimSuiteCompassFrame", 100); Tick(3)
check("compass back to solid", SlimSuiteCompassFrame:GetAlpha() == 1)
local every = true
for name in pairs(SS.ELEMENTS) do
	if name ~= "SlimSuiteEditGrid" then
		local found = false
		for _, e in ipairs(SU.ChecksFor(name) or {}) do if e[1] == "Opacity" then found = true end end
		if not found then every = false; print("  no opacity: " .. name) end
	end
end
check("every element has an Opacity setting", every)
-- the minimap's optional parts hide and come back
SS.DB().minimapHideZoom = true; SS.ApplyMinimapExtras()
check("zoom buttons hidden", MinimapZoomIn == nil or MinimapZoomIn:GetAlpha() == 0)
SS.DB().minimapHideZoom = false; SS.ApplyMinimapExtras()
check("zoom buttons back", MinimapZoomIn == nil or MinimapZoomIn:GetAlpha() == 1)
-- the combined-elements list sits after the element sections, open, not inside the last section
local headSeen, combinedRows = false, 0
for _, r in ipairs(page.rows) do
	if r.kind == "head" and r.fs:GetText() == "Optional combined that hide elements" then headSeen = true
	elseif headSeen and r.kind ~= "head" and not r.fold then combinedRows = combinedRows + 1 end
end
check("combined list with its settings (" .. combinedRows .. ")", headSeen and combinedRows >= 6)
-- each element can sit over the level-up cards on its own, the rest follow the global setting
local lifted = {}
AZS_SetOnTopOfScreens = function(f, on) lifted[f] = on; return true end
SS.DB().onTopOfScreens = false; SS.DB().onTop = {}
SS.SetOnTopFor("SlimSuiteCompassFrame", true); Tick(2)
check("compass over the cards", lifted[SlimSuiteCompassFrame] == true)
check("damage meter still under them", lifted[SlimSuiteMeterFrame] == false)
local has = false; for _, e in ipairs(SU.ChecksFor("SlimSuiteMeterFrame")) do if e[1] == "Show over the level-up / new-item cards" then has = true end end
check("every element offers it", has)
AZS_SetOnTopOfScreens = nil
-- search: a buzz word opens every matching section for as long as it is typed
SU.SetMode("MinimapCluster", "enabled", "Minimap"); SS.openFolds = {}
SS.searchText = "hidden"; SS.LayoutPage(page); Tick(1)
check("search opens matching sections", visible() >= 1 and mini.searchOpen)
SS.searchText = ""; SS.LayoutPage(page); Tick(1)
check("clearing the search closes them again", visible() == 0)
-- reset button, undo and redo
check("reset button sits next to Default", mini.modes[4] and mini.modes[4]:GetText() == "Reset")
SS.SetElementOpacity("MinimapCluster", 40)
local hist = SS.historyPos
local rb = mini.modes[4]; local rf = rb:GetScript("OnClick"); this = rb; rf(); Tick(1)
check("reset clears opacity", SS.ElementOpacity("MinimapCluster") == 100 and SS.historyPos == hist + 1)
SS.Undo(); Tick(1)
check("undo brings it back", SS.ElementOpacity("MinimapCluster") == 40)
SS.Redo(); Tick(1)
check("redo resets again", SS.ElementOpacity("MinimapCluster") == 100)
local offB = mini.modes[2]; local of = offB:GetScript("OnClick"); this = offB; of(); Tick(1)
check("Off is undoable", SU.Mode("MinimapCluster") == "disabled")
SS.Undo(); Tick(1)
check("undo turns it back On", SU.Mode("MinimapCluster") == "enabled")
for i = 1, 30 do SS.RecordChange("test " .. i, i, i + 1, function() end) end
check("only the last 25 are kept", table.getn(SS.history) == 25)
-- open in settings
check("open in settings finds it", SS.OpenElementSettings("MinimapCluster") and SS.openFolds[mini.title])
SS.OpenModulePage("changelog"); Tick(1)
local cl = SS.settingsViews.changelog
check("changelog page opens", cl and cl.scroll:IsShown() and table.getn(cl.page.rows) == table.getn(SS.CHANGELOG))
check("newest release first", SS.CHANGELOG[table.getn(SS.CHANGELOG)].v == "1.06" and string.find(cl.page.rows[1].fs:GetText(), SS.CHANGELOG[1].v, 1, true))
local enc; for _, r in ipairs(page.rows) do if r.kind == "fold" and r.element == "SlimSuiteBossFrames" then enc = r end end
SS.searchText = "encounter"; SS.LayoutPage(page)
check("searching encounter finds the Encounter bars", enc and enc.searchOpen)
SS.searchText = "dps"; SS.LayoutPage(page)
local meter; for _, r in ipairs(page.rows) do if r.kind == "fold" and r.element == "SlimSuiteMeterFrame" then meter = r end end
check("searching dps finds the damage meter", meter and meter.searchOpen)
SS.searchText = ""; SS.LayoutPage(page)
-- the element groups: close one, and its buttons change every element in it with one Undo
local aethus; for _, r in ipairs(page.rows) do if r.kind == "head" and r.count == "aethus" then aethus = r end end
check("each group has On, Off, Default and Reset", aethus and aethus.groupButtons and table.getn(aethus.groupButtons) == 4)
SS.closedGroups = {}; SS.LayoutPage(page)
local c = aethus.click:GetScript("OnClick"); this = aethus.click; c(); Tick(1)
check("clicking a group's name closes it", SS.closedGroups.aethus and not (enc and enc.b:IsShown()))
this = aethus.click; c(); Tick(1)
check("and opens it again", not SS.closedGroups.aethus and enc.b:IsShown())
local hist0 = SS.historyPos
local onB = aethus.groupButtons[1]; local onF = onB:GetScript("OnClick"); this = onB; onF(); Tick(2)
check("group On turns every element in it on", SU.Mode("SlimSuiteBossFrames") == "enabled" and SU.Mode("SlimSuiteMeterFrame") == "enabled")
check("as one Undo step", SS.history[SS.historyPos] and string.find(SS.history[SS.historyPos].what, "All enabled", 1, true) ~= nil)
SS.Undo(); Tick(2)
check("Undo puts the whole group back", SU.Mode("SlimSuiteBossFrames") ~= "enabled" or SU.Mode("SlimSuiteMeterFrame") ~= "enabled")
check("group count reads on/total", string.find(SS.SectionCount("aethus"), "^%d+/%d+$") ~= nil)
print("errors: " .. #ERRORS); for _, e in ipairs(ERRORS) do print(e) end
print("fold problems: " .. bad)
if bad > 0 or #ERRORS > 0 then error("folds") end
