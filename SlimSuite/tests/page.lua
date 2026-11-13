local function upvalue(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i) if not n then return SS.ENV and SS.ENV[want] end if n == want then return v end i = i + 1 end end
SS.Toggle(); Tick(2)
print("pages:", #SS.pages)
for pi, page in ipairs(SS.pages) do
  local heads, rows, subs = {}, 0, 0
  for _, r in ipairs(page.rows) do
    if r.kind == "head" then if r.fs:IsShown() then table.insert(heads, r.fs.text) end
    elseif r.cb and r.cb.label:IsShown() then rows = rows + 1 elseif r.b and r.b:IsShown() then rows = rows + 1 end
  end
  print("page " .. pi .. ": heads [" .. table.concat(heads, ", ") .. "] visible rows " .. rows .. " height " .. page.parent:GetHeight())
end
-- toggle the zone line's parent on, then off: its sub-setting appears and disappears
local page = SS.pages[1]
local parentRow, subRow
for i, r in ipairs(page.rows) do if r.cb and r.cb.label.text == "Replace Default Run Clock with Movable Version?" then parentRow = r end end
for i, r in ipairs(page.rows) do if r.cb and r.cb.label.text:find("zone and Heroic") then subRow = r end end
print("zone sub visible before:", subRow.cb:IsShown())
Click(parentRow.cb); Tick(1)
print("zone sub visible after clicking parent on:", subRow.cb:IsShown(), "parent checked", parentRow.cb.checked)
Click(parentRow.cb); Tick(1)
print("zone sub visible after off:", subRow.cb:IsShown())
print(table.concat(ERRORS, "\n"))
