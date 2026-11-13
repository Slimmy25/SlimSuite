local function upvalue(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i) if not n then return SS.ENV and SS.ENV[want] end if n == want then return v end i = i + 1 end end
SU = upvalue(SS.SetupHide, "SU")
local sm
local function show(name)
  SS.OpenSizeMenu(name, name); Tick(1); sm = sm or upvalue(SS.PrepareSizeTools, "sizeMenu")
  local rows, heads = {}, {}
  for i = 1, #SU.checks do if SU.checks[i]:IsVisible() then table.insert(rows, SU.checks[i].label.text) end end
  print(name .. ": headers [" .. table.concat(heads, ", ") .. "]  rows " .. #rows)
  for _, r in ipairs(rows) do print("    " .. r) end
end
show("PlayerFrame")
SS.SetMirrorTarget(true); Tick(1)
show("PlayerFrame")
local function row(label) for i = 1, #SU.checks do if SU.checks[i]:IsVisible() and string.find(SU.checks[i].label.text, label, 1, true) then return SU.checks[i] end end end
Click(row("Combine")); Tick(1)  -- Combine on
show("PlayerFrame")
-- outside the setup the right-click menu is the setup's panel with Done, its settings and the size tools under them
SS.SetUnlocked(true, true); Tick(2)
SS.OpenSizeMenu("MainMenuBar", "Action bar"); Tick(1)
local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("  MISMATCH " .. label) end end
check("the panel opens", SU.panel:IsVisible())
check("with Done, not Exit/Complete", SU.panel.done:IsVisible() and not SU.panel.exit:IsVisible())
check("its title is the setup's", SU.panel.title.text == "Action bar")
check("the size tools are in it", sm:IsVisible() and sm:GetParent() == SU.panel)
Click(SU.panel.done); Tick(1)
check("Done closes it", not SU.panel:IsVisible())
SS.OpenSizeMenu("BuffFrame", "Buffs"); Tick(1)
SS.SetUnlocked(false, true); Tick(1)
check("locking closes it", not SU.panel:IsVisible())
print("menu problems: " .. bad)
print(table.concat(ERRORS, "\n"))
