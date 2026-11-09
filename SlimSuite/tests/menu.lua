local function upvalue(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i) if not n then return nil end if n == want then return v end i = i + 1 end end
SU = upvalue(SS.SetupHide, "SU")
local sm
local function show(name)
  SS.OpenSizeMenu(name, name); Tick(1); sm = sm or upvalue(SS.RefreshCrossRefs, "sizeMenu")
  local rows, heads = {}, {}
  for i = 1, #sm.xref do if sm.xref[i]:IsShown() then table.insert(rows, sm.xref[i].label.text) end end
  for i = 1, #(sm.xrefHeads or {}) do if sm.xrefHeads[i]:IsShown() then table.insert(heads, sm.xrefHeads[i].text) end end
  print(name .. ": headers [" .. table.concat(heads, ", ") .. "]  rows " .. #rows)
  for _, r in ipairs(rows) do print("    " .. r) end
end
show("PlayerFrame")
SS.SetMirrorTarget(true); Tick(1)
show("PlayerFrame")
Click(sm.xref[1]); Tick(1)  -- Combine on
show("PlayerFrame")
print(table.concat(ERRORS, "\n"))
