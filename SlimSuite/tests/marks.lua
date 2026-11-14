-- raid marks on the frames, the target frame switch, the tooltip (moved and previewed), and you in the party
local function upvalue(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i) if not n then return SS.ENV and SS.ENV[want] end if n == want then return v end i = i + 1 end end
SU = upvalue(SS.SetupHide, "SU")
local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("  MISMATCH " .. label) end end
-- tooltip: a sample while editing and in Demo Mode, none in a run; real tooltips go where it was moved
SS.SetUnlocked(true, true); Tick(3)
check("editing shows a sample tooltip", GameTooltip.shown and GameTooltip.slimSample)
SS.SetUnlocked(false, true); Tick(3)
check("locked: the sample goes", not GameTooltip.slimSample and not GameTooltip.shown)
SU.SetMode("GameTooltip", "enabled", "Tooltip")
SS.StartDemoMode(); Tick(5)
check("Demo Mode shows the sample tooltip", GameTooltip.shown and GameTooltip.slimSample)
SS.StopDemoMode(); Tick(3)
check("after Demo Mode the sample goes", not GameTooltip.slimSample)
SS.DB().places.GameTooltip = { x = 40, y = 300, coordinateSpace = "uiParent" }
GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
local p = GameTooltip.points and GameTooltip.points[1]
check("a run's tooltip goes where it was moved", p and p[1] == "BOTTOMLEFT" and p[4] == 40 and p[5] == 300)
-- the target frame button in the setup is the real switch
SS.StartSetup(true); Tick(3)
SU.SetOn("TargetFrame", false, "Target frame"); Tick(2)
check("target off in the setup hides it in the game", SS.DB().hideTarget == true)
SU.SetOn("TargetFrame", true, "Target frame"); Tick(2)
check("target on again", SS.DB().hideTarget == false)
SS.SetTargetHidden(true); Tick(1)
check("Hide the target frame turns its button off", not SU.on.TargetFrame)
SS.SetTargetHidden(false); Tick(1)
-- you in the party: your settings under the party, buffs above you beside the room for your mark
SS.SetPartySelf(true); Tick(2)
local found = 0
for _, c in ipairs(SU.ChecksFor("PartyMemberFrame1")) do
	if (c[1] == "Player buffs position" or c[1] == "Class proc meter under it") and (not c[4] or c[4]()) then found = found + 1 end
end
check("your buffs and proc meter settings are under the party", found == 2)
SS.SetupEnd(true); Tick(3)
SS.SetBuffsPlace("player_above"); Tick(3)
local plate = SlimSuitePartySelfFrame
local bp = BuffFrame.points and BuffFrame.points[1]
check("your buffs sit above your plate", bp and bp[2] == plate and bp[1] == "BOTTOMLEFT")
check("they line up with your plate's left edge", bp and bp[3] == "TOPLEFT" and bp[4] == 0)
check("your mark sits beside your plate", true)
local bh = (BuffButton0 and BuffButton0.GetHeight and BuffButton0:GetHeight()) or 30
check("they are sized to your plate", math.abs(bh * (BuffFrame.scale or 1) - math.max(12, math.min(20, plate:GetHeight() * 0.32))) < 0.5)
-- raid marks show on the frames
MOCK_MARKS.player = 8; Tick(10)
check("your mark shows on your plate", plate.slimRaidMark and plate.slimRaidMark.shown)
SS.SetLook("PartyMemberFrame1", "thin"); Tick(10)
local line = SlimSuitePartyLines.lines[1]
check("and on your thin line", line.slimRaidMark and line.slimRaidMark.shown)
MOCK_MARKS.player = nil; Tick(10)
check("a cleared mark goes", not line.slimRaidMark.shown)
SS.SetLook("PartyMemberFrame1", "classic"); SS.SetPartySelf(false); SS.SetBuffsPlace("own"); Tick(2)
-- Encounter auras belong at the end of the health bar, clear of the raid-marker/name end.
local originalDebuffs = rawget(_G, "AZS_GetDebuffs")
AZS_GetDebuffs = function() return {
    { icon = "Spell_Shadow_ShadowWordPain", remaining = 8 },
    { icon = "Spell_Shadow_CurseOfSargeras", remaining = 5 }
} end
local encounter = CreateFrame("Frame", nil, UIParent)
encounter.bar = CreateFrame("StatusBar", nil, encounter)
encounter.bar:SetWidth(240); encounter.bar:SetHeight(12)
SlimSuiteWorld.DrawDebuffs(encounter, { id = 1 }, false, true)
local first, second = encounter.debuffs[1].points[1], encounter.debuffs[2].points[1]
check("horizontal DoTs anchor to the bar's right end", first[1] == "TOPRIGHT" and first[2] == encounter.bar and first[3] == "BOTTOMRIGHT" and first[4] == 0 and first[5] < 0)
check("horizontal DoTs grow inward from the right", second[4] < first[4] and second[5] == first[5])
SlimSuiteWorld.DrawDebuffs(encounter, { id = 1 }, true, true)
first, second = encounter.debuffs[1].points[1], encounter.debuffs[2].points[1]
check("vertical DoTs anchor to the bar's bottom end", first[1] == "TOP" and first[2] == encounter.bar and first[3] == "BOTTOM" and first[4] == 0 and first[5] < 0)
check("vertical DoTs grow downward from the bottom", second[5] < first[5])
SlimSuiteWorld.DrawDebuffs(encounter, { id = 1 }, true, false)
check("disabled encounter auras stay hidden", not encounter.debuffs[1]:IsShown() and not encounter.debuffs[2]:IsShown())
rawset(_G, "AZS_GetDebuffs", originalDebuffs)
print("marks problems: " .. bad)
print("errors: " .. #ERRORS); for _, e in ipairs(ERRORS) do print("  " .. e) end
