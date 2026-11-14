local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("MISMATCH " .. label) end end
local setup, d = SS.ENV.SU, SS.DB()
SS.StartSetup(true)
for frame in pairs(setup.NATIVE) do
    setup.SetMode(frame, "default", frame)
    check("Default gives native placement control: " .. frame, d.frameDefault[frame])
    d.muted[frame] = true
    setup.SetMode(frame, "enabled", frame)
    check("Enabled selects movable mode: " .. frame, not d.frameDefault[frame] and not d.muted[frame] and setup.Mode(frame) == "enabled")
end
SS.SetPartySelf(false); SS.SetLook("PlayerFrame", "classic"); SS.SetLook("PartyMemberFrame1", "classic")
local function Rect(frame, left, right, bottom, top)
    frame.GetLeft = function() return left end; frame.GetRight = function() return right end
    frame.GetBottom = function() return bottom end; frame.GetTop = function() return top end
end
Rect(PlayerFrame, 100, 340, 400, 480)
local portrait = CreateFrame("Frame", "PlayerPortrait", PlayerFrame)
Rect(portrait, 140, 200, 410, 470)
Rect(PartyMemberFrame1, 50, 210, 300, 350)
Rect(PartyMemberFrame1Portrait, 60, 100, 310, 350)
SS.SetPartyPosition("below")
local point = PartyMemberFrame1.points[1]
check("party aligns portrait centers, not element padding", point[2] == PlayerFrame and point[3] == "BOTTOMLEFT" and point[4] == 40)
SS.SetPartyPosition("above")
check("party above uses the same portrait alignment", PartyMemberFrame1.points[1][4] == 40)
setup.SetMode("BuffFrame", "disabled", "Buffs")
d.sizes.BuffFrame = { w = 40, h = 90 }
d.orientations.BuffFrame, d.buffGrowthDirection = "horizontal", "down"
for i = 0, 2 do
    local b = CreateFrame("Button", "BuffButton" .. i, BuffFrame)
    b:SetWidth(16); b:SetHeight(16); b:Show()
end
SS.SetBuffsPlace("player_above"); SS.ApplyBuffOrientation(); SS.AttachBuffs()
point = BuffFrame.points[1]
check("requesting attachment enables movable Buffs", setup.Mode("BuffFrame") == "enabled" and not d.frameDefault.BuffFrame and setup.on.BuffFrame)
check("above buffs anchor to the visible portrait", point[1] == "BOTTOMLEFT" and point[2] == portrait and point[3] == "TOPLEFT")
check("attached buffs replace the original icon layout", d.buffCustomLayout and BuffButton0.points[1][2] == BuffFrame)
check("extra rows grow above the player instead of across it", BuffButton1.points[1][5] > 0 and BuffButton2.points[1][5] > BuffButton1.points[1][5])
print("attachment problems: " .. bad)
print("errors: " .. #ERRORS); for _, e in ipairs(ERRORS) do print("  " .. e) end
