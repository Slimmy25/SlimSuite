local bad = 0
local function upvalue(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i) if not n then return SS.ENV and SS.ENV[want] end if n == want then return v end i = i + 1 end end
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
check("choosing On turns it on and opens its settings", SU.Mode("MinimapCluster") == "enabled" and visible() >= 6)
SS.openFolds[mini.title] = nil; SS.LayoutPage(page); Tick(1)
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
print("errors: " .. #ERRORS); for _, e in ipairs(ERRORS) do print(e) end
print("fold problems: " .. bad)
if bad > 0 or #ERRORS > 0 then error("folds") end
