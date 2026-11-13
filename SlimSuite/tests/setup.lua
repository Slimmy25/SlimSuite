local function upvalue(fn, want)
	local i = 1
	while true do
		local n, v = debug.getupvalue(fn, i)
		if not n then return SS.ENV and SS.ENV[want] end
		if n == want then return v end
		i = i + 1
	end
end
su_ = upvalue(SS.SetupHide, "SU")
SU = su_; assert(type(SU) == "table" and SU.Begin, "no SU")
local function flush(tag)
	if #ERRORS > 0 then
		print("  !! " .. tag)
		for _, e in ipairs(ERRORS) do print("     " .. e) end
		ERRORS = {}
	end
end

SS.StartSetup(true)
Tick(5)
flush("start setup")
print("elements: " .. #SU.elements)

local function checksState()
	local l = {}
	for i = 1, #SU.checks do
		local cb = SU.checks[i]
		if cb.shown then table.insert(l, i .. ":" .. tostring(cb.label and cb.label.text) .. "=" .. tostring(cb.checked)) end
	end
	return l
end

local problems = 0
for _, e in ipairs(SU.elements) do
	local name = e.frame
	local b = SU.barButtons[name]
	local tag = b and b.tag
	local before = SU.Mode(name)
	RunScript(tag, "OnMouseUp", "LeftButton"); Tick(2)
	flush(name .. " status cycle 1")
	local mid = SU.Mode(name)
	RunScript(tag, "OnMouseUp", "LeftButton"); Tick(2)
	local third = SU.Mode(name)
	RunScript(tag, "OnMouseUp", "LeftButton"); Tick(2)
	local after = SU.Mode(name)
	local ok = mid ~= before and third ~= mid and after == before
	if not ok then problems = problems + 1 end
	print(string.format("%-28s %s -> %s -> %s -> %s %s", name, tostring(before), tostring(mid), tostring(third), tostring(after), ok and "" or "  <-- BAD"))
	Click(b); Tick(3) -- open this element's detailed options
	flush(name .. " open options")
	-- the element's tick boxes while it is focused
	local shown = {}
	for i = 1, #SU.checks do
		local cb = SU.checks[i]
		if cb.shown and cb.scripts and cb.scripts.OnClick and cb.mouse ~= false and (not cb.IsEnabled or cb:IsEnabled()) then table.insert(shown, cb) end
	end
	-- rows can move as sub-settings appear: each click finds its row again by its label
	local labels = {}
	for _, cb in ipairs(shown) do table.insert(labels, tostring(cb.label and cb.label.text)) end
	local function find(label)
		for i = 1, #SU.checks do
			local c = SU.checks[i]
			if c.shown and tostring(c.label and c.label.text) == label and c.mouse ~= false and (not c.IsEnabled or c:IsEnabled()) then return c end
		end
	end
	for _, label in ipairs(labels) do
		local cb = find(label)
		if cb then
			local c0 = cb.checked and true or false
			Click(cb); Tick(2)
			flush(name .. " tick '" .. label .. "' 1")
			cb = find(label) or cb
			local c1 = cb.checked and true or false
			-- the panel may have been rebuilt: refresh reads the setting back
			Click(cb); Tick(2)
			cb = find(label) or cb
			flush(name .. " tick '" .. label .. "' 2")
			local c2 = cb.checked and true or false
			if c1 == c0 or c2 ~= c0 then
				problems = problems + 1
				print(string.format("  TICK %s / '%s': %s -> %s -> %s", name, label, tostring(c0), tostring(c1), tostring(c2)))
			end
		end
	end
	if SU.focus == name then Click(b); Tick(1) end
end
print("problems: " .. problems)
