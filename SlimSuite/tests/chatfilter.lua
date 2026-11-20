-- The chat toggles for addon text, location, difficulty, talent experience and the Troll racial list lines.
local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("  MISMATCH " .. label) end end
local d = SS.DB()
local function hidden(line) return SS.Hidden(line, "CHAT_MSG_SYSTEM") end
d.hideAddonText, d.hideLocation, d.hideDifficulty, d.hideTalentXP, d.hideRacialInfo = true, true, true, true, true
check("addon text line hidden", hidden("Azeroth Stats : Loaded  2.0.4  /azstats"))
check("location line hidden", hidden("Arulrha the Troll Warlock enters Naxxramas. Move to begin."))
check("difficulty line hidden", hidden("Heroic II"))
check("talent experience hidden", hidden("Your Warlocks earn 24 talent experience."))
check("racial regen line hidden", hidden("- Regeneration: +1.5 health per second"))
check("racial throwing line hidden", hidden("- Throwing Specialization: +3% critical strike"))
check("racial berserking line hidden", hidden("- Berserking: every 35 sec. cooldowns recover 30% faster for 10 sec"))
check("an ordinary line is kept", not hidden("You hit the Lich for 300."))
d.hideAddonText, d.hideLocation, d.hideDifficulty, d.hideTalentXP, d.hideRacialInfo = false, false, false, false, false
check("off: addon text kept", not hidden("Azeroth Stats : Loaded  2.0.4  /azstats"))
check("off: difficulty kept", not hidden("Heroic II"))
check("off: talent experience kept", not hidden("Your Warlocks earn 24 talent experience."))
d.hideRacialInfo = true
check("gnome racial line hidden", hidden("- Escape Artist: every 20 sec, roots nearby enemies for 2 sec"))
check("dwarf racial line hidden", hidden("- Stoneform: every 30 sec, a shield absorbing 45% of max health"))
check("undead racial line hidden", hidden("- Will of the Forsaken: near death, 4 sec of immunity"))
check("human racial line hidden", hidden("- Perception: every 30 sec, +15% damage for 10 sec"))
d.hideRacialInfo = false
if bad == 0 then print("chat filter checks ok") end
