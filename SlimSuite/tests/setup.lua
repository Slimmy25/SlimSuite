local function upvalue(fn, want)
	local i = 1
	while true do
		local n, v = debug.getupvalue(fn, i)
		if not n then return nil end
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
	local before = SU.on[name] and true or false
	Click(b); Tick(3)
	flush(name .. " click 1")
	local mid = SU.on[name] and true or false
	-- the element's tick boxes while it is focused
	local shown = {}
	for i = 1, #SU.checks do
		local cb = SU.checks[i]
		if cb.shown and cb.scripts and cb.scripts.OnClick and cb.mouse ~= false then table.insert(shown, cb) end
	end
	for _, cb in ipairs(shown) do
		local label = tostring(cb.label and cb.label.text)
		if cb.shown then
			local c0 = cb.checked and true or false
			Click(cb); Tick(2)
			flush(name .. " tick '" .. label .. "' 1")
			local c1 = cb.checked and true or false
			-- the panel may have been rebuilt: refresh reads the setting back
			Click(cb); Tick(2)
			flush(name .. " tick '" .. label .. "' 2")
			local c2 = cb.checked and true or false
			if c1 == c0 or c2 ~= c0 then
				problems = problems + 1
				print(string.format("  TICK %s / '%s': %s -> %s -> %s", name, label, tostring(c0), tostring(c1), tostring(c2)))
			end
		end
	end
	if SU.focus ~= name and mid then Click(b); Tick(1) end   -- refocus
	Click(b); Tick(3)
	flush(name .. " click 2")
	local after = SU.on[name] and true or false
	local ok = (mid ~= before) and (after ~= mid)
	if not ok then problems = problems + 1 end
	print(string.format("%-28s %s -> %s -> %s %s  (%d ticks)", name, tostring(before), tostring(mid), tostring(after), ok and "" or "  <-- BAD", #shown))
end
print("problems: " .. problems)
