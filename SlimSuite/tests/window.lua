-- the settings window: every tick box flips its setting, and no box is left showing an old value
local function errs(tag) if #ERRORS > 0 then print("ERR " .. tag .. ": " .. table.concat(ERRORS, " | ")); ERRORS = {} end end
if not SS.ENV.win then SS.WinBuild() end; SS.ENV.win:Show(); Tick(2); errs("open window")
local bad=0
local visited=0
for _,module in ipairs(SS.MODULE_ORDER) do
SS.SetModuleEnabled(module,true); SS.OpenModulePage(module); visited=visited+1
local boxes = {}
for _, cb in ipairs(SS.toggleBoxes) do if cb.get and cb:IsVisible() and not cb.moduleControl then table.insert(boxes, cb) end end
print("window boxes visible: " .. #boxes)
for round = 1, 3 do
	for i, cb in ipairs(boxes) do
		if cb:IsVisible() then
			local before = cb.get() and true or false
			Click(cb); Tick(1); errs("box " .. i)
			local after = cb.get() and true or false
			if cb.soundGroup then
    if not after or SS.SoundSelection(cb.soundGroup)~=cb.soundKey then bad=bad+1; print("radio selection failed: box "..i) end
   elseif after == before then bad = bad + 1; print("no change: box " .. i) end
			for _, o in ipairs(SS.toggleBoxes) do
				if o.get and o:IsVisible() and ((o.checked and true or false) ~= (o.get() and true or false)) then
					bad = bad + 1; print("stale after box " .. i)
				end
			end
		end
	end
end
SS.ENV.win:Show(); SS.OpenModulePage(module)
end
assert(visited==#SS.MODULE_ORDER,"all module pages reviewed")
print("window problems: " .. bad)
