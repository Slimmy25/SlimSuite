-- Failure paths and resource lifetime checks from the full-code review.
local bad = 0
local function check(label, ok)
    if not ok then bad = bad + 1; print("MISMATCH " .. label) end
end
local setup, d = SS.ENV.SU, SS.DB()
SS.SetupEnd(true)

-- Profiles must round-trip HUD options, native ownership and untrusted input safely.
d.targetAuraSide, d.targetDebuffs, d.clockDetached = "left", false, true
d.ctIcons, d.minimapCaches, d.tallyBackground = false, true, false
d.elementModes.PlayerFrame, d.frameDefault = "default", { PlayerFrame = true }
local snapshot = SS.LayoutSnapshot()
local imported = SS.LayoutFromText(SS.LayoutText(snapshot))
check("complete profile round trip", imported and imported.targetAuraSide == "left" and imported.targetDebuffs == false
    and imported.clockDetached and imported.ctIcons == false and imported.minimapCaches and imported.tallyBackground == false)
PlayerFrame:SetScale(1.7)
SS.LayoutApply(snapshot, true)
check("native profile ownership survives applying", d.frameDefault and d.frameDefault.PlayerFrame)
check("applying a native profile restores physical scale too", PlayerFrame:GetScale() == (SS.nativeScales and SS.nativeScales.PlayerFrame or 1))
local previousLocale = GetLocale
d.tallyBossKills = true
for _, code in ipairs({ "esES", "frFR", "deDE" }) do
    GetLocale = function() return code end
    local parts = SS.TallyParts(nil, true)
    check("boss and guardian labels are localized: " .. code, parts[2][1] == SS.T("Bosses") and parts[3][1] == SS.T("Guardians"))
end
GetLocale = previousLocale
for _, text in ipairs({
    "SSL1;scales.PlayerFrame=slarge", "SSL1;scales.PlayerFrame=n0", "SSL1;scales.PlayerFrame=n1e999", "SSL1;scales.PlayerFrame=n1e300",
    "SSL1;sizes.BuffFrame.w=swide;sizes.BuffFrame.h=n20", "SSL1;sizes.BuffFrame.w=n20",
    "SSL1;elementModes.PlayerFrame=b1", "SSL1;orientations.BuffFrame=sdiagonal",
    "SSL1;playerLook=b1", "SSL1;showAbsorbs=bperhaps", "SSL1;places.PlayerFrame.x=sbad",
    "SSL1;places.PlayerFrame.relative=sTargetFrame;places.TargetFrame.relative=sPlayerFrame"
}) do check("invalid profile rejected: " .. text, SS.LayoutFromText(text) == nil) end
local first = { scales = { PlayerFrame = 1.25, TargetFrame = 0.8 }, playerLook = "new" }
local second = { playerLook = "new", scales = { TargetFrame = 0.8, PlayerFrame = 1.25 } }
check("deterministic profile exports", SS.LayoutText(first) == SS.LayoutText(second))
d.layouts["audit autosave"] = {}; SS.activeCustomProfile = "audit autosave"
d.partyMemberBuffs, d.localClock24 = false, true
SS.LayoutLogout()
check("logout flushes pending custom profile edits", d.layouts["audit autosave"].partyMemberBuffs == false and d.layouts["audit autosave"].localClock24)
SS.activeCustomProfile = nil; d.layouts["audit autosave"] = nil

-- Default must undo applied scale and icon layout, including subsequent orientation refreshes.
SS.StartSetup(true)
setup.SetMode("PlayerFrame", "enabled", "Player")
d.scales.PlayerFrame = 1.6; SS.Place("PlayerFrame")
setup.SetMode("PlayerFrame", "default", "Player")
check("Default restores native player scale", PlayerFrame:GetScale() == (SS.nativeScales and SS.nativeScales.PlayerFrame or 1))
setup.SetMode("BuffFrame", "enabled", "Buffs")
local button = getglobal("BuffButton0") or CreateFrame("Button", "BuffButton0", BuffFrame)
button:ClearAllPoints(); button:SetPoint("TOPRIGHT", BuffFrame, "TOPRIGHT", -3, -4); button:Show()
SS.ApplyBuffOrientation()
local original = SS.ENV.buffButtonOriginalPoints[0][1]
d.buffCustomLayout, d.buffsOnPlayer = true, true
d.orientations.BuffFrame, d.sizes.BuffFrame = "vertical", { w = 40, h = 100 }
SS.ApplyBuffOrientation(); setup.SetMode("BuffFrame", "default", "Buffs"); SS.ApplyBuffOrientation()
local point = button.points[1]
check("Default clears custom buff attachment and layout", not d.buffsOnPlayer and not d.buffCustomLayout and d.orientations.BuffFrame == nil)
check("Default restores native buff anchors", point and point[1] == original[1] and point[2] == original[2]
    and point[3] == original[3] and point[4] == original[4] and point[5] == original[5])
MainMenuExpBar.SetOrientation = function(self, orientation) self.layoutOrientation = orientation end
MainMenuExpBar.SetClipsChildren = function(self, enabled) self.clipsChildren = enabled end
setup.SetMode("MainMenuExpBar", "enabled", "XP")
SS.DetachExperienceBar(); d.orientations.MainMenuExpBar = "vertical"
SS.ENV.ApplyMovableOrientation("MainMenuExpBar")
setup.SetMode("MainMenuExpBar", "default", "XP")
check("Default restores horizontal native XP", MainMenuExpBar.layoutOrientation == "HORIZONTAL" and not SS.ENV.xpBarDetached)
check("Default XP allows its native border outside the fill", MainMenuExpBar.clipsChildren == false)
check("Default hides custom XP segments", not SlimSuiteXpSegments or not SlimSuiteXpSegments:IsShown())
SS.SetupEnd(true)

AZS_IsHudShown = function(part) return part ~= "clock" end
AZS_SetHudShown = function() end
d.setupDone, d.replaceClock, d.clockNativeOriginal, d.nativeAdopted = true, false, nil, {}
d.elementModes.SlimSuiteClockFrame = "disabled"
SS.AdoptHiddenNatives()
check("explicit Disabled prevents automatic native adoption", not d.replaceClock)
d.elementModes.SlimSuiteClockFrame = "default"; SS.AdoptHiddenNatives()
check("explicit Default prevents automatic native adoption", not d.replaceClock)

-- An incomplete catalog cannot create orphan frames or poison the next successful update.
local handler, registrations, incomplete, empty, generation = nil, 0, true, false, 0
AZS_RegisterWorldAnchorFrameHandler = function(fn)
    registrations = registrations + 1
    if registrations == 1 then return nil, { code = "NOT_READY" } end
    handler = fn; return true
end
AZS_UnregisterWorldAnchorFrameHandler = function() handler = nil; return true end
AZS_GetWorldAnchors = function(query, cursor)
    if empty then return { entries = {} } end
    if cursor then
        if incomplete then return nil, { code = "NOT_READY" } end
        return { entries = { { anchorId = 2 + generation, unitId = 2, kind = "boss", state = "alive", name = "B" } } }
    end
    return { entries = { { anchorId = 1 + generation, unitId = 1, kind = "boss", state = "alive", name = "A" } }, hasMore = true, nextCursor = "next" }
end
local projection = { entries = {} }
AZS_ProjectWorldAnchors = function() return projection end
AZS_UNITS = { { id = 1, hp = 20, hpm = 100 }, { id = 2, hp = 80, hpm = 100 } }
SS.SetModernEnemyFrames(true)
check("failed pagination allocates no orphan frames", SlimSuiteEnemyNameplate1 == nil)
incomplete = false; SS.UpdateEnemyNameplates()
check("registration failure is retried", registrations == 2 and handler ~= nil)
local a, b = SlimSuiteEnemyNameplate1, SlimSuiteEnemyNameplate2
check("complete catalog recovers without errors", a and b and #ERRORS == 0)
check("frame name stays separate from name label", a and a:GetName() == "SlimSuiteEnemyNameplate1")
if a and b and handler then
    local byName = { [a.name:GetText()] = a, [b.name:GetText()] = b }
    byName.A.GetEffectiveScale = function() return 2 end
    projection.entries = { { anchorId = 2, state = "onScreen", x = 400, y = 80 }, { anchorId = 1, state = "onScreen", x = 100, y = 60 } }
    handler()
    check("projection identity and UI scale", byName.A.points[1][4] == 50 and byName.B.points[1][4] == 400)
    projection.entries = { { anchorId = 1, state = "onScreen", x = 100, y = 60 } }; handler()
    check("missing projections hide old plates", byName.A:IsShown() and not byName.B:IsShown())
    projection.frameCurrent = false; handler()
    check("stale projections hide plates", not a:IsShown() and not b:IsShown())
    local count = #(a.children or {}) + #(a.regions or {}) + #(b.children or {}) + #(b.regions or {})
    for i = 1, 8 do
        generation = generation + 2; SS.UpdateEnemyNameplates()
    end
    check("plate pool remains bounded", SlimSuiteEnemyNameplate3 == nil)
    check("pooled plates reuse their child controls", count == #(a.children or {}) + #(a.regions or {}) + #(b.children or {}) + #(b.regions or {}))
end
SS.SetModernEnemyFrames(false)

-- The shared marker catalog also rejects truncated pagination and backs off while unavailable.
local api, reads = SlimSuiteWorld.API, 0
AZS_GetWorldAnchors = function() reads = reads + 1; return { entries = { { anchorId = reads, unitId = reads } }, hasMore = true, nextCursor = "never-finishes" } end
local previous = api.Catalog(GetTime() + 10)
check("catalog refuses pagination-limit truncation", #previous.list == 0)
AZS_GetWorldAnchors = function() reads = reads + 1; return nil end
api.Catalog(GetTime() + 20); local before = reads
for i = 1, 5 do api.Catalog(GetTime() + 20.01) end
check("unavailable catalog is rate limited", reads == before)

-- Foreground registration serializes the game's entire registry: do it only when state changes.
local calls = 0
AZS_SetOnTopOfScreens = function() calls = calls + 1 end
SlimSuiteWorld.ApplyOnTop(); before = calls; SlimSuiteWorld.ApplyOnTop()
check("unchanged foreground settings do no native writes", calls == before)
d.onTopOfScreens = not d.onTopOfScreens; SlimSuiteWorld.ApplyOnTop()
check("foreground setting changes still propagate", calls > before)
check("display context reused at unchanged resolution", SS.DisplayContext() == SS.DisplayContext())
projection.frameCurrent = false
check("shared projection adapter rejects stale frames", next(api.Project({ { anchorId = 1 } })) == nil)

local absorb = CreateFrame("StatusBar", nil, UIParent); absorb:SetWidth(100); absorb:SetHeight(12)
d.showAbsorbs = false; SS.UpdateAbsorbMarker(absorb, "player", 100, 100)
check("disabled absorbs allocate no overlays", not absorb.slimAbsorb)
d.showAbsorbs = true
UnitGetTotalAbsorbs = function() return 200 end
SS.UpdateAbsorbMarker(absorb, "player", 100, 100)
local absorbPoint = absorb.slimAbsorb.points[1]
check("absorb overlay stays inside full health bar", absorbPoint[4] >= 0 and absorbPoint[4] + absorb.slimAbsorb:GetWidth() <= 100)

-- Low-health alerts repeat even when health is stationary, and stop at death/recovery.
local hp, sounds = 30, 0
UnitHealth = function() return hp end; UnitHealthMax = function() return 100 end
PlaySoundFile = function(path) if path == SS.SOUND_FILES.lowHealth then sounds = sounds + 1 end end
d.lowHealthSound = true
FireEvent("UNIT_HEALTH", "player"); check("low health warning starts at 30 percent", sounds == 1)
Tick(20); check("low health warning is rate limited", sounds == 1)
Tick(35); check("stationary low health repeats warning", sounds == 2)
local lastSounds = sounds
AdvanceTime(6); hp = 0; FireEvent("UNIT_HEALTH", "player"); Tick(60)
check("dead players get no low health warning", sounds == lastSounds)
lastSounds = sounds
hp = 50; Tick(60); check("recovered players get no low health warning", sounds == lastSounds)

local chestSounds = 0
PlaySoundFile = function(path) if path == SS.SOUND_FILES.chestOpen then chestSounds = chestSounds + 1 end end
AZS_GetPhase = function() return "playing" end
AZS_RUN, AZS_CHESTS = { run = "audit-cache-run" }, { { id = "cache-1" } }
d.chestOpenSound = true; Tick(2)
AZS_CHESTS = nil; Tick(2)
check("unavailable cache data cannot play an opening sound", chestSounds == 0)
AZS_CHESTS = {}; Tick(2)
check("confirmed catalog removal still plays the cache sound", chestSounds == 1)
check("no caught runtime errors", #ERRORS == 0)
print("audit problems: " .. bad)
for _, err in ipairs(ERRORS) do print(err) end
assert(bad == 0, "code audit regression")
