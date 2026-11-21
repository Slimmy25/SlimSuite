local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("  MISMATCH " .. label) end end
SS.DB().moveMeter = true; SS.DB().unlocked = true; SS.DB().anchorSnap = true; SS.DB().gridSnap = true
if SS.SetUnlocked then SS.SetUnlocked(true) end
Tick(3)
local function probe(name)
  local f = getglobal(name); if not f then print("no", name) return end
  local function sz() return string.format("%.1fx%.1f s%.3f eff%.3f", f:GetWidth(), f:GetHeight(), f:GetScale() or 1, (f.GetEffectiveScale and f:GetEffectiveScale() or 0)) end
  local before = sz()
  local l, r, b, t = SS.ScreenBounds()
  local h = SS.Handle(name, name)
  -- drag to the top right corner
  this = h; local down = h:GetScript("OnMouseDown"); arg1 = "LeftButton"; GetCursorPosition = function() return 0, 0 end
  down(); h.frameStartX, h.frameStartY = r - 5, t - 5
  SS.DB().scales[name] = 0.5; SS.ApplySize(name, f)   -- something shrinks it on the way
  SS.DragStep(h, name); SS.FinishHandleMove(h, name); Tick(5)
  local after = sz()
  print(name, before, "->", after, SS.DB().scales[name], (SS.DB().places[name] or {}).relative)
  check(name .. " keeps its size in the corner", before == after)
end
for _, n in ipairs({ "SlimSuiteMeterFrame", "SlimSuiteClockFrame", "SlimSuiteTallyFrame", "SlimSuiteBossFrames", "SlimSuiteCompassFrame" }) do probe(n) end
print("errors: " .. #ERRORS)
