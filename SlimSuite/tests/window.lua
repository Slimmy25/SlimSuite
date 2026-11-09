-- the settings window: every tick box flips its setting, and no box is left showing an old value
local function errs(tag) if #ERRORS > 0 then print("ERR " .. tag .. ": " .. table.concat(ERRORS, " | ")); ERRORS = {} end end
SS.Toggle(); Tick(2); errs("open window")
local boxes = {}
for _, cb in ipairs(SS.toggleBoxes) do if cb.get and cb:IsVisible() then table.insert(boxes, cb) end end
print("window boxes visible: " .. #boxes)
local bad = 0
for round = 1, 3 do
	for i, cb in ipairs(boxes) do
		if cb:IsVisible() then
			local before = cb.get() and true or false
			Click(cb); Tick(1); errs("box " .. i)
			local after = cb.get() and true or false
			if after == before then bad = bad + 1; print("no change: box " .. i) end
			for _, o in ipairs(SS.toggleBoxes) do
				if o.get and o:IsVisible() and ((o.checked and true or false) ~= (o.get() and true or false)) then
					bad = bad + 1; print("stale after box " .. i)
				end
			end
		end
	end
end
print("window problems: " .. bad)
