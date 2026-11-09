local function upvalue(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i) if not n then return nil end if n == want then return v end i = i + 1 end end
SU = upvalue(SS.SetupHide, "SU")
SS.StartSetup(true); Tick(3)
local function onBar(n) for _, e in ipairs(SU.elements) do if e.frame == n then return SU.barButtons[n]:IsVisible() end end return false end
Click(SU.barButtons.PlayerFrame); Tick(2); Click(SU.barButtons.TargetFrame); Tick(2)
SS.SetMirrorTarget(true); Tick(2)
print("before: player on", SU.on.PlayerFrame, "target on", SU.on.TargetFrame, "mirror", SS.DB().mirrorTarget)
Click(SU.barButtons.PartyMemberFrame1); Tick(2)
local function row(label) for i = 1, #SU.checks do if SU.checks[i]:IsVisible() and SU.checks[i].label.text == label then return SU.checks[i] end end end
Click(row("Add yourself to the party frames")); Tick(2)
print("self on: player on", SU.on.PlayerFrame, "player shown", PlayerFrame.shown, "target on", SU.on.TargetFrame, "target on bar", onBar("TargetFrame"), "mirror", SS.DB().mirrorTarget, "hideTarget", SS.DB().hideTarget)
Click(SU.barButtons.PlayerFrame); Tick(2)
print("player clicked: self", SS.DB().partyIncludesSelf, "player on", SU.on.PlayerFrame, "player shown", PlayerFrame.shown)
-- right-click menus show the same settings as the setup
local sm = upvalue(SS.RefreshCrossRefs, "sizeMenu")
for _, e in ipairs(SU.elements) do
  if SU.on[e.frame] or true then
    SS.OpenSizeMenu(e.frame, e.title)
    sm = sm or upvalue(SS.RefreshCrossRefs, "sizeMenu")
    local n = 0; for i = 1, #sm.xref do if sm.xref[i].shown then n = n + 1 end end
    local want = #SU.ChecksFor(e.frame)
    print(string.format("  menu %-24s rows %d / setup %d %s", e.frame, n, want, n == want and "" or "<-- MISMATCH"))
  end
end
print(table.concat(ERRORS, "\n"))
