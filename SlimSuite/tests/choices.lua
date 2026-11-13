-- every new choice setting, in and out of the setup and Demo Mode: no Lua errors, and each reads back what was chosen
local bad = 0
local function check(label, got, want) if got ~= want then bad = bad + 1; print("  MISMATCH " .. label .. ": " .. tostring(got) .. " ~= " .. tostring(want)) end end
local function round()
	for _, v in ipairs({ "new", "party", "target", "classic", "party", "new", "classic" }) do SS.SetPlayerLookChoice(v); Tick(2); check("player look " .. v, SS.PlayerLookChoice(), v) end
	for _, v in ipairs({ "new", "classic" }) do SS.SetLook("TargetFrame", v); Tick(1); check("target look " .. v, SS.Look("TargetFrame"), v) end
	for _, v in ipairs({ "thin", "classic", "thin" }) do SS.SetLook("PartyMemberFrame1", v); Tick(2); check("party look " .. v, SS.Look("PartyMemberFrame1"), v) end
	for _, v in ipairs({ "below", "above", "free" }) do SS.SetPartyPosition(v); Tick(1); check("party place " .. v, SS.PartyPosition(), v) end
	for _, v in ipairs({ "player_above", "player_below", "player_left", "player_right", "own" }) do SS.SetBuffsPlace(v); Tick(1); check("buffs " .. v, SS.BuffsPlace(), v) end
	SS.SetPartySelf(true); Tick(1); SS.SetPartyPosition("below"); Tick(1)
	check("lock takes you out of the party", SS.DB().partyIncludesSelf, false)
	SS.SetPartySelf(true); Tick(1)
	check("joining frees the party", SS.PartyPosition(), "free")
	SS.SetPartySelf(false); SS.SetLook("PartyMemberFrame1", "classic"); Tick(1)
end
round()
SS.SetUnlocked(true, true); Tick(2); round(); SS.SetUnlocked(false, true); Tick(2)
SS.StartSetup(true); Tick(2); round(); SS.StartDemoMode(); Tick(20); round(); SS.StopDemoMode(); SS.SetupEnd(true); Tick(3)
SS.ResetUI(); Tick(3)
print("choice problems: " .. bad)
print("errors: " .. #ERRORS); for _, e in ipairs(ERRORS) do print("  " .. e) end
