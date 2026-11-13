-- the game's addon API, mocked: kill tally (3%), timer safety, SS.Safe arguments, item link names, the error log filter
local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("  MISMATCH " .. label) end end

-- kill tally: a boss at 3% or less counts once; a Guardian at 0 counts; one that leaves the list alive does not
AZS_GetPhase = function() return "playing" end
AZS_GetMeterContext = function() return { runId = "run1", uiSessionId = 1, epoch = 1 } end
AZS_RUN = { kills = 0 }
AZS_UNITS = { { id = 1, name = "Boss", kind = "boss", hp = 500, hpm = 1000 },
	{ id = 2, name = "Guard", kind = "guardian", hp = 100, hpm = 100 },
	{ id = 3, name = "Runner", kind = "guardian", hp = 90, hpm = 100 } }
Tick(3)
local b, g = SlimSuiteWorld.RunKills()
check("nothing killed yet", b == 0 and g == 0)
AZS_UNITS[1].hp = 30                                    -- 3%
AZS_UNITS[2].hp = 0
table.remove(AZS_UNITS, 3)                              -- left the list alive
Tick(3)
b, g = SlimSuiteWorld.RunKills()
check("boss at 3% counts as a kill", b == 1)
check("guardian at 0 counts, one that left alive does not", g == 1)
Tick(5)
b, g = SlimSuiteWorld.RunKills()
check("a kill counts only once", b == 1 and g == 1)
AZS_UNITS[1].hp = 40                                    -- 4%: still alive
AZS_UNITS[1].id = 9
Tick(3)
check("a boss at 4% is not a kill", (SlimSuiteWorld.RunKills()) == 1)

-- timer: a task that starts and stops others while the tasks run
local ran = {}
SS.Every("t_a", 0, function() ran.a = (ran.a or 0) + 1; SS.Stop("t_b"); if not ran.started then ran.started = true; SS.Every("t_c", 0, function() ran.c = (ran.c or 0) + 1 end) end end)
SS.Every("t_b", 0, function() ran.b = (ran.b or 0) + 1 end)
Tick(3)
SS.Stop("t_a"); SS.Stop("t_c")
check("stopped task does not run", not ran.b)
check("task started from a task runs", (ran.c or 0) >= 1)
Tick(2)
local a = ran.a
Tick(2)
check("stopped tasks stay stopped", ran.a == a)

-- SS.Safe passes nils in the middle through
local got
SS.Safe(function(x, y, z) got = { x, y, z } end, 1, nil, 3)
check("Safe keeps arguments after a nil", got and got[1] == 1 and got[2] == nil and got[3] == 3)

-- item links give their own name
check("item link name", SS.ItemLinkName("|cff1eff00|Hitem:1234:0:0:0|h[Ring of Tests]|h|r") == "Ring of Tests")

-- the error log keeps Slim Suite's errors and leaves other addons' alone
local before = table.getn(SS.ErrorLog())
local saved = SS.LogError
_ERRORMESSAGE("Interface\\AddOns\\Other\\Other.lua:1: boom")
check("other addons' errors are not logged", table.getn(SS.ErrorLog()) == before)
_ERRORMESSAGE("Interface\\AddOns\\SlimSuite\\SlimSuite.lua:1: boom")
check("Slim Suite's errors are logged", table.getn(SS.ErrorLog()) == before + 1)
SS.LogError = saved
for _, e in ipairs(ERRORS) do if string.find(e, "boom", 1, true) then ERRORS[_] = nil end end

-- the HUD: hidden parts are given back when Slim Suite lets go
local shown = {}
AZS_SetHudShown = function(part, on) shown[part] = on end
AZS_IsHudShown = function(part) return shown[part] ~= false end
SS.HideNative("localClock", true)
check("hiding a HUD part", shown.localClock == false)
SS.RestoreNatives()
check("restoring it", shown.localClock ~= false)

AZS_UNITS = nil; AZS_RUN = nil
print("api problems: " .. bad)
for _, e in pairs(ERRORS) do print("  " .. e) end
-- the meter puts each pet's abilities on one line named after the pet
SS.StartDemoMode(); Tick(3)
SlimSuiteMeter.view = 'damage'; SlimSuiteMeter.Draw(true, false)
local names, void = {}, nil
for _, r in ipairs(SlimSuiteMeter.rows or {}) do if r.pet then names[r.pet] = (names[r.pet] or 0) + 1; if r.pet == "Voidwalker" then void = r end end end
check("one Voidwalker line", names.Voidwalker == 1 and void and table.getn(void.parts) == 2)
check("Imp has its own line", names.Imp == 1)
SS.StopDemoMode(); Tick(2)
print("meter problems: " .. bad)
-- in the setup, your player frame joined to the party says Connected and names the party
local function upv(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i) if not n then return SS.ENV and SS.ENV[want] end if n == want then return v end i = i + 1 end end
local SU = upv(SS.SetupHide, "SU")
SS.StartSetup(true); Tick(3)
SS.SetPartySelf(true); Tick(2); SU.RefreshBar()
local b = SU.barButtons and SU.barButtons.PlayerFrame
check("player frame tag says Connected", b and b.tag.text:GetText() == "Connected" and b.tag.parentTitle == "Party frames")
SS.SetPartySelf(false); SS.SetupEnd(true); Tick(2)
print("connected problems: " .. bad)
-- you in the party: buffs start at your plate's top-left and grow to the right, wrapping into rows
for i = 0, 9 do local b = getglobal("BuffButton" .. i) or CreateFrame("Button", "BuffButton" .. i, BuffFrame); b:SetWidth(30); b:SetHeight(30); b:Show() end
SS.SetPartySelf(true); SS.SetBuffsPlace("player_above"); Tick(3)
SlimSuitePartySelfFrame.hp:SetWidth(100); SlimSuitePartySelfFrame.mp:SetWidth(100)   -- the mock lays bars out at their own size only
SS.LayoutPartyBuffs()
local b0, b1 = BuffButton0.points and BuffButton0.points[1], BuffButton1.points and BuffButton1.points[1]
local plate = SlimSuitePartySelfFrame
local pl = (plate.portrait and plate.portrait:GetLeft()) or plate:GetLeft()
check("first buff lines up with your portrait", b0 and pl and math.abs(b0[4] * (BuffFrame:GetEffectiveScale() or 1) - pl * (plate:GetEffectiveScale() or 1)) < 1)
check("second buff to its right, same row", b1 and b1[4] > b0[4] and b1[5] == b0[5])
local rows, lowest = {}, nil
for i = 0, 9 do local p = getglobal("BuffButton" .. i).points[1]; rows[p[5]] = true; if not lowest or p[5] < lowest then lowest = p[5] end end
local n = 0; for _ in pairs(rows) do n = n + 1 end
check("more buffs make more rows", n > 1)
check("first buff is on the top row (rows grow down)", b0[5] > lowest)
local right = PartyMemberFrame1:GetLeft()
local last = getglobal("BuffButton9").points[1]
for i = 0, 9 do local p = getglobal("BuffButton" .. i).points[1]
	if SS.CurrentOrientation("PartyMemberFrame1") == "horizontal" and right and (p[4] + 30) * BuffFrame:GetEffectiveScale() > right * PartyMemberFrame1:GetEffectiveScale() then check("buff " .. i .. " stops before the next frame", false) end end
SS.SetPartySelf(false); Tick(2)
print("partybuffs problems: " .. bad)
-- Demo Mode: menus go away for a small On/Off box and come back after; the party keeps your layout
local win = getglobal("SlimSuiteFrame") or CreateFrame("Frame", "SlimSuiteFrame", UIParent)
win:Show()
SS.StartDemoMode(); Tick(2)
check("menus close in Demo Mode", not win:IsShown())
check("the DEMO MODE box shows", SlimSuiteDemoBox and SlimSuiteDemoBox:IsShown())
check("party layout is yours", SS.demoPartyOrient == nil)
Tick(40)
check("party layout still yours later", SS.demoPartyOrient == nil)
Click(SlimSuiteDemoBox.off); Tick(2)
check("Off stops it", not SS.demoRunning and not SlimSuiteDemoBox:IsShown())
check("the menus come back", win:IsShown())
win:Hide()
print("demo problems: " .. bad)
-- the shared private names stay out of the game's globals
local G = _G
check("private names are not global", rawget(G, "SU") == nil and rawget(G, "win") == nil and rawget(G, "PlaceAll") == nil)
check("they are shared between the files", SS.ENV.SU ~= nil and type(SS.ENV.PlaceAll) == "function")
print("env problems: " .. bad)
-- unit frames redraw on the game's events, not only on the timer
local calls = 0; local old = SS.RefreshCard
SS.RefreshCard = function(f) calls = calls + 1; return old(f) end
Tick(1, 0.01); calls = 0
FireEvent("UNIT_HEALTH", "player"); Tick(1, 0.01)
check("UNIT_HEALTH redraws the cards at once", calls > 0)
SS.RefreshCard = old
print("events problems: " .. bad)
-- side by side: your buffs stop before the first friend's frame; friends' buffs show above their own plates
SS.SetPartySelf(true); SU.SetPartyRow(true); Tick(3)
SlimSuitePartySelfFrame.hp:SetWidth(100); SlimSuitePartySelfFrame.mp:SetWidth(100); SS.LayoutPartyBuffs()
local barEnd = SlimSuitePartySelfFrame.hp:GetRight()
local pastBar = false
for i = 0, 9 do local p = getglobal("BuffButton" .. i).points[1]; if (p[4] + 30) * BuffFrame:GetEffectiveScale() > barEnd + 0.5 then pastBar = true end end
check("buffs stop where the plate's bars end", not pastBar)
local L, W = SS.BuffRoom(SlimSuitePartySelfFrame, SlimSuitePartySelfFrame.portrait, PartyMemberFrame1)
local edge = L + W
local over = false
for i = 0, 9 do local p = getglobal("BuffButton" .. i).points[1]; if (p[4] + 30) * BuffFrame:GetEffectiveScale() > edge then over = true end end
check("row: buffs stay inside the room before party member 1", not over)
local oldExists, oldBuff = UnitExists, UnitBuff
UnitExists = function(u) return u == "player" or u == "party1" end
UnitBuff = function(u, i) if u == "party1" and i <= 5 then return "Interface\\Icons\\Spell_Holy_WordFortitude" end end
PartyMemberFrame1:Show(); SS.UpdateFriendBuffs()
local n = 0; for _, b in ipairs(SS.friendBuffs[1]) do if b:IsShown() then n = n + 1 end end
check("a friend's 5 buffs show above them", n == 5)
SS.DB().partyMemberBuffs = false; SS.UpdateFriendBuffs()
n = 0; for _, b in ipairs(SS.friendBuffs[1]) do if b:IsShown() then n = n + 1 end end
check("and can be turned off", n == 0)
SS.DB().partyMemberBuffs = nil; UnitExists, UnitBuff = oldExists, oldBuff
SU.SetPartyRow(false); SS.SetPartySelf(false); Tick(2)
print("friendbuffs problems: " .. bad)
-- the square's ring belongs to the square map: off means no ring, even if something shows it again
SS.SetMinimapSquare(true); Tick(2)
check("square: ring shows", SS.squareRing and SS.squareRing:IsShown())
SS.SetMinimapSquare(false); Tick(2)
check("round: ring gone", not SS.squareRing:IsShown())
SS.squareRing:Show(); Tick(2, 0.6)
check("round: ring cannot come back", not SS.squareRing:IsShown())
print("ring problems: " .. bad)
-- the button row: optional (off by default), its buttons can be seen, and they go back on the map's ring
check("the button row is off by default", SS.DEFAULTS.minimapBar == false)
local gear = SlimSuiteMinimapButton
gear:SetAlpha(0)                                       -- as the setup's sweep leaves it
SS.SetMinimapBar(true, true); SS.LayoutMinimapBar()
check("buttons in the row can be seen", gear:GetAlpha() == 1)
SS.SetMinimapBar(false, true); Tick(2)
local p = gear.points and gear.points[1]
check("the gear goes back to the ring", p and p[2] == Minimap)
print("corral problems: " .. bad)
-- encounter bars as rows: the frame (and its green handle) is one bar wide, not one bar per boss
SS.DB().replaceEncounters = true; SS.DB().orientations.SlimSuiteBossFrames = "horizontal"
SS.UpdateEncounterRows({ { name = "A", kind = "boss", hp = 5, hpm = 10 }, { name = "B", kind = "boss", hp = 5, hpm = 10 }, { name = "C", kind = "guardian", hp = 5, hpm = 10 } })
check("encounter bars fit on the screen", SlimSuiteBossFrames:GetWidth() <= UIParent:GetWidth() * 0.9)
check("rows are one bar wide", SlimSuiteBossFrames:GetWidth() < 600)
print("encounter problems: " .. bad)
-- a part the player turned off in the game's Interface settings switches on Slim Suite's version, once
local hud = { clock = false }
AZS_IsHudShown = function(p) return hud[p] ~= false end
AZS_SetHudShown = function(p, on) hud[p] = on end
SS.DB().replaceClock = false; SS.DB().nativeAdopted = nil; SS.DB().clockNativeOriginal = nil
SS.AdoptHiddenNatives()
check("the game's run clock off: Slim Suite's is on", SS.DB().replaceClock == true)
check("parts still shown are left alone", not SS.DB().replaceTally)
SS.DB().replaceClock = false; SS.AdoptHiddenNatives()
check("turning ours off afterwards is kept", SS.DB().replaceClock == false)
print("adopt problems: " .. bad)
-- your buffs: own place or a side of the player frame; the target's auras have their own side
local placeNames = {}
for _, p in ipairs(SS.BUFF_PLACES) do placeNames[p[2]] = true end
check("your buffs have no target options", not placeNames.target_above and placeNames.player_left and placeNames.player_right)
SS.SetBuffsPlace("player_left"); Tick(2)
local bp = BuffFrame.points and BuffFrame.points[1]
check("left of the player frame", SS.BuffsPlace() == "player_left" and bp and bp[1] == "TOPRIGHT" and bp[3] == "TOPLEFT")
SS.SetTargetAuraSide("right")
check("the target's side is its own", SS.DB().targetAuraSide == "right" and SS.BuffsPlace() == "player_left")
-- mirroring offers the player's side, mirrored
local shown
StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopup_Show = function(n) shown = n end
SS.DB().targetAuraSide = "below"; SS.SetMirrorTarget(true)
check("mirror target offers to match", shown == "SLIMSUITE_MIRROR_BUFFS")
StaticPopupDialogs.SLIMSUITE_MIRROR_BUFFS.OnAccept()
check("accepting puts the target's auras on the mirrored side", SS.DB().targetAuraSide == "right")
SS.SetMirrorTarget(false); SS.SetBuffsPlace("own")
print("aura problems: " .. bad)
-- combat text: crits and the biggest hits pop out, grow right and fall, sized by how big they are next to normal hits
SS.DB().combatTextBox = true
for i = 1, 8 do SlimSuiteWorld.DemoHit(100, "Hit", nil, false) end
SlimSuiteWorld.DemoHit(400, "Big crit", nil, true)
SlimSuiteWorld.DemoHit(150, "Small crit", nil, true)
Tick(1, 0.05)
local big, small
for _, p in ipairs(SlimSuiteCombatTextFrame.pops) do
	if p:IsShown() then local t = p.text:GetText() or ""; if string.find(t, "Big") then big = p elseif string.find(t, "Small") then small = p end end
end
check("crits pop out", big and small)
Tick(20, 0.05)
local bigS, smallS = big:GetScale(), small:GetScale()
check("a bigger crit grows bigger", bigS > smallS)
local bx = big.points[1][4] * bigS
Tick(10, 0.05)
check("it moves right", big.points[1][4] * big:GetScale() > bx)
Tick(200, 0.05)
check("and goes away in the end", not big:IsShown())
print("pop problems: " .. bad)
-- Demo Mode moves everything the way a run would
SS.DB().replaceEncounters, SS.DB().replaceTally, SS.DB().replaceClock = true, true, true
SS.StartDemoMode(); Tick(4, 0.25)
local b1 = SS.BOSS_SAMPLE[1][2]; local k1 = SS.TALLY_SAMPLE.kills; local t1 = SS.ENV.SU.SAMPLE_TARGET.hp; local run1 = SS.demoClock.run; local nb1 = SS.demoClock.nextBoss
local downOnly, tallyUp = true, true
for i = 1, 40 do
	local before, kb = SS.BOSS_SAMPLE[1][2], SS.TALLY_SAMPLE.kills
	Tick(1, 0.25)
	local now = SS.BOSS_SAMPLE[1][2]
	if now > before and now ~= 100 then downOnly = false end
	if SS.TALLY_SAMPLE.kills < kb and SS.demoState.cycle > 1 then tallyUp = false end
end
check("bosses only lose health (or start again full)", downOnly)
check("the tally only climbs", tallyUp and SS.TALLY_SAMPLE.kills > k1)
check("the run clock counts up", SS.demoClock.run > run1)
check("four sample bosses with marks", table.getn(SS.BOSS_SAMPLE) == 4 and SlimSuiteWorld.MarkFor(-1) == 8 and SlimSuiteWorld.MarkFor(-2) == 7)
check("the minimap has sample caches and bosses", SlimSuiteWorld.demoPins and table.getn(SlimSuiteWorld.demoPins) == 7)
check("the revive bar fills", SS.demoRevive and SS.demoRevive > 0)
SS.StopDemoMode(); Tick(2)
print("demoworld problems: " .. bad)
