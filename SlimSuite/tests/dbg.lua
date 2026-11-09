local function upvalue(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i) if not n then return nil end if n == want then return v end i = i + 1 end end
SU = upvalue(SS.SetupHide, "SU")
SS.StartSetup(true); Tick(3)
for _, name in ipairs({"TargetFrame", "GameTooltip", "SlimSuiteMeterFrame"}) do
  Click(SU.barButtons[name]); Tick(2)
  local n = 0
  for i = 1, #SU.checks do if SU.checks[i]:IsVisible() then n = n + 1 end end
  print(name, "on", SU.on[name], "focus", SU.focus, "visible rows", n, "panel", SU.panel:IsVisible(), "title", SU.panel.title.text, "hideTarget", tostring(SS.DB().hideTarget))
  for i = 1, #SU.checks do local cb = SU.checks[i]; if cb.shown then print("   ", cb.label.text, cb.shown, cb.parent == SU.panel, cb.parent.shown) end end
end
print(table.concat(ERRORS, "\n"))
