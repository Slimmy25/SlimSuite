-- random clicks through the setup, checking after each one that the click did what it says
local function upvalue(fn, want)
	local i = 1
	while true do
		local n, v = debug.getupvalue(fn, i)
		if not n then return nil end
		if n == want then return v end
		i = i + 1
	end
end
SU = upvalue(SS.SetupHide, "SU")
local dropdown = {}
function UIDropDownMenu_Initialize(menu, fn) menu.init = fn end
function UIDropDownMenu_AddButton(info) table.insert(dropdown, info) end
function ToggleDropDownMenu(level, value, menu) dropdown = {}; if menu and menu.init then menu.init() end end

local seed = tonumber(os.getenv("SEED") or "1")
local steps = tonumber(os.getenv("STEPS") or "300")
math.randomseed(seed)
local log = {}
local function note(s) table.insert(log, s); if #log > 40 then table.remove(log, 1) end end
local failures = 0
local function fail(msg)
	failures = failures + 1
	print("FAIL seed " .. seed .. ": " .. msg)
	for _, l in ipairs(log) do print("    " .. l) end
	log = {}
end
local function errs(tag)
	if #ERRORS > 0 then
		local m = tag .. "\n      " .. table.concat(ERRORS, "\n      ")
		ERRORS = {}
		fail("error after " .. m)
	end
end

local function effAlpha(f)
	local a, p = 1, f
	while p do a = a * (p.alpha or 1); p = p.parent end
	return a
end
local function strata(f)
	local p = f
	while p do if p.strata then return p.strata end p = p.parent end
	return "MEDIUM"
end
local RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

SS.StartSetup(true)
Tick(3)
errs("start")
local sizeMenu
local function visibleRows()
	local rows = {}
	for i = 1, #SU.checks do
		local cb = SU.checks[i]
		if cb:IsVisible() and cb.enabled ~= false then
			local e = { cb = cb, where = "setup", label = cb.label.text, get = cb.get }
			if cb.choiceBtn and cb.choiceBtn.shown and cb.choiceBtn.entry then e.choice = cb.choiceBtn end
			if e.choice or cb.mouse ~= false then table.insert(rows, e) end
		end
	end
	return rows
end

for step = 1, steps do
	local r = math.random()
	if r < 0.35 then
		local e = SU.elements[math.random(#SU.elements)]
		local name = e.frame
		local b = SU.barButtons[name]
		local before = SU.on[name] and true or false
		note("bar " .. name .. " (was " .. tostring(before) .. ")")
		if not b:IsVisible() then fail("bar button hidden: " .. name) end
		Click(b); Tick(2)
		errs("bar " .. name)
		local still = false
		for _, x in ipairs(SU.elements) do if x.frame == name then still = true end end
		local after = SU.on[name] and true or false
		if still and after == before then fail("bar button did not toggle: " .. name .. " stays " .. tostring(after)) end
	elseif r < 0.5 then
		-- right-click an element that is on
		local on = {}
		for _, e in ipairs(SU.elements) do if SU.on[e.frame] then table.insert(on, e) end end
		if #on > 0 then
			local e = on[math.random(#on)]
			note("menu " .. e.frame)
			SS.OpenSizeMenu(e.frame, e.title); Tick(1)
			errs("open menu " .. e.frame)
		end
	else
		local rows = visibleRows()
		if #rows > 0 then
			local row = rows[math.random(#rows)]
			if row.choice then
				local entry = row.choice.entry
				Click(row.choice)
				local opts = dropdown
				if #opts == 0 then fail("choice menu empty: " .. tostring(row.label))
				else
					local o = opts[math.random(#opts)]
					note(row.where .. " choice '" .. tostring(row.label) .. "' -> " .. tostring(o.text))
					o.func(); Tick(2)
					errs("choice " .. tostring(row.label))
					local now = SS.ChoiceText(entry)
					if now ~= o.text then fail("choice '" .. tostring(row.label) .. "' picked " .. tostring(o.text) .. " but shows " .. tostring(now)) end
				end
			else
				local before = row.get() and true or false
				note(row.where .. " tick '" .. tostring(row.label) .. "' (was " .. tostring(before) .. ")")
				Click(row.cb); Tick(2)
				errs("tick " .. tostring(row.label))
				local after = row.get() and true or false
				if after == before then fail(row.where .. " tick did not change its setting: '" .. tostring(row.label) .. "' stays " .. tostring(after)) end
				local shownNow = row.cb.checked and true or false
				if row.cb:IsVisible() and row.cb.get == row.get and shownNow ~= after then fail("tick box shows " .. tostring(shownNow) .. " but setting is " .. tostring(after) .. ": " .. tostring(row.label)) end
			end
		end
	end
	for _, cb in ipairs(SS.toggleBoxes or {}) do
		if cb.get and cb:IsVisible() and not (cb.choiceBtn and cb.choiceBtn.shown) then
			local want = cb.get() and true or false
			if (cb.checked and true or false) ~= want then fail("stale box '" .. tostring(cb.label and cb.label.text) .. "' shows " .. tostring(not want)) end
		end
	end
	if not SU.panel:IsVisible() then fail("setup panel hidden") ; SU.Focus(SU.focus) end
	if not SU.bar:IsVisible() then fail("setup bar hidden") end
end
-- invisible frames that still catch the mouse above the setup's own layer
local blockers = {}
for _, f in ipairs(_G.__allFrames or {}) do end
print(string.format("seed %d: %d steps, %d failures", seed, steps, failures))
local seen = MissingGlobals()
print("unmodelled globals touched: " .. table.concat(seen, " "))
