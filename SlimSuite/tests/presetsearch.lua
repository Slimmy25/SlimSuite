-- 100 design passes: propose a change to one design's layout, keep it only if every screen still passes the review
-- and the five designs end up further apart from each other. Not part of run-checks; run with SCENARIO=presetsearch.
local REAL = { MainMenuBar = { 300, 50 }, SlimSuitePlayerCard = { 232, 100 }, SlimSuiteTargetCard = { 232, 100 },
	PartyMemberFrame1 = { 140, 250 }, SlimSuitePartyLines = { 90, 42 }, SlimSuiteBossFrames = { 200, 192 },
	SlimSuiteClockFrame = { 220, 54 }, SlimSuiteTallyFrame = { 252, 28 }, BuffFrame = { 300, 100 }, ChatFrame1 = { 430, 120 },
	SlimSuiteCompassFrame = { 380, 88 }, SlimSuiteMeterFrame = { 250, 180 }, SlimSuiteStatCounterFrame = { 150, 28 },
	SlimSuiteCombatTextFrame = { 120, 60 } }
SS.PresetElementSize = function(name, scale) local s = REAL[name] or { 100, 40 }; return s[1] * scale, s[2] * scale end
local SCREENS = { 1024/768, 1280/720, 1280/800, 1366/768, 1920/1200, 2560/1080, 3440/1440, 3840/1080 }
local real = SS.ScreenBounds
-- where each role sits when a design leaves it to the game
local NATIVE = { bar = { .5, .04 }, you = { .12, .92 }, target = { .3, .92 }, party = { .06, .65 }, boss = { .5, .85 }, clock = { .5, .96 }, chat = { .15, .15 } }
local ROLE = { MainMenuBar = "bar", SlimSuitePlayerCard = "you", SlimSuiteTargetCard = "target", PartyMemberFrame1 = "party",
	SlimSuitePartyLines = "party", SlimSuiteBossFrames = "boss", SlimSuiteClockFrame = "clock", ChatFrame1 = "chat" }
local CHOICES = {
	bar = { { .5, .05 }, { .5, .95 }, { .03, .5, "vertical" }, { .97, .45, "vertical" }, { .3, .05 }, { .7, .05 } },
	pair = { { -170, .21, 170, .21, true }, { .2, .5, .8, .5 }, { -170, .9, 170, .9, true }, { .1, .82, .1, .66 }, { .14, .12, .86, .12 }, { .2, .2, .2, .06 } },
	party = { { .08, .6 }, { .92, .35 }, { .5, .13 }, { .5, .9 }, { .3, .93 }, { .08, .3 } },
	boss = { { .5, .85 }, { .1, .7 }, { .9, .5 }, { .1, .4 }, { .86, .82 } },
	clock = { { .5, .96 }, { .15, .95 }, { .85, .62 }, { .5, .03 }, { .35, .96 } },
	chat = { { .12, .08 }, { .88, .08 }, { .12, .93 }, { .88, .3 } } }
local function Valid(spec)
	for _, a in ipairs(SCREENS) do
		local w = 768 * a
		SS.ScreenBounds = function() return 0, w, 0, 768 end
		local _, placed = SS.BuildPresetLayout(spec)
		local aw = math.min(w, 768 * 16 / 9); local al = (w - aw) / 2
		local spot = {}; for _, at in ipairs(spec.places) do spot[at[1]] = at end
		for i, r in ipairs(placed) do if not r.reserved then
			if r.x < 0 or r.y < 0 or r.x + r.w > w or r.y + r.h > 768 then return false end
			for j = 1, #placed do local o = placed[j]
				if o ~= r and r.x < o.x + o.w and o.x < r.x + r.w and r.y < o.y + o.h and o.y < r.y + r.h then return false end end
			if r.x < w / 2 + aw * .18 and w / 2 - aw * .18 < r.x + r.w and r.y < 768 * .7 and 768 * .3 < r.y + r.h then return false end
			local at = spot[r.name]
			local dx = at.fromCentre and math.abs((r.x + r.w / 2 - w / 2 - at[2]) / aw) or math.abs((r.x + r.w / 2 - al) / aw - at[2])
			if dx > .12 or math.abs((r.y + r.h / 2) / 768 - at[3]) > .12 then return false end
		end end
	end
	return true
end
local function Where(spec)
	local out = {}; for k, v in pairs(NATIVE) do out[k] = { v[1], v[2] } end
	for _, at in ipairs(spec.places) do local role = ROLE[at[1]]
		if role then out[role] = { at.fromCentre and (.5 + at[2] / 1365) or at[2], at[3] } end end
	return out
end
local function Distance(a, b)
	local A, B, d = Where(a), Where(b), 0
	for role in pairs(NATIVE) do d = d + math.abs(A[role][1] - B[role][1]) + math.abs(A[role][2] - B[role][2]) end
	return d
end
local function Score(list)
	local least, total = 1e9, 0
	for i = 1, #list do for j = i + 1, #list do local d = Distance(list[i][3], list[j][3]); least = math.min(least, d); total = total + d end end
	return least * 10 + total
end
local function Copy(t) if type(t) ~= "table" then return t end local o = {}; for k, v in pairs(t) do o[k] = Copy(v) end; return o end
local function Set(spec, name, x, y, fromCentre)
	for i = #spec.places, 1, -1 do if spec.places[i][1] == name then table.remove(spec.places, i) end end
	if x then table.insert(spec.places, { name, x, y, fromCentre = fromCentre or nil }) end
end
math.randomseed(25)
local designs = Copy(SS.BUILTIN_PRESETS)
local best = Score(designs)
print(string.format("pass 0: score %.2f", best))
for pass = 1, tonumber(os.getenv("PASSES") or 100) do
	local d = math.random(2, #designs)          -- Classic Plus stays the game's own layout
	local spec = Copy(designs[d][3])
	local roles = { "bar", "pair", "party", "boss", "clock", "chat" }
	local role = roles[math.random(#roles)]
	local c = CHOICES[role][math.random(#CHOICES[role])]
	local has = {}; for _, at in ipairs(spec.places) do has[at[1]] = true end
	if role == "bar" and has.MainMenuBar then
		Set(spec, "MainMenuBar", c[1], c[2]); spec.orientations = spec.orientations or {}; spec.orientations.MainMenuBar = c[3]
	elseif role == "pair" and (has.SlimSuitePlayerCard or has.SlimSuiteTargetCard) then
		if has.SlimSuitePlayerCard then Set(spec, "SlimSuitePlayerCard", c[1], c[2], c[5]) end
		Set(spec, "SlimSuiteTargetCard", c[3], c[4], c[5])
	elseif role == "party" then
		local n = has.SlimSuitePartyLines and "SlimSuitePartyLines" or (has.PartyMemberFrame1 and "PartyMemberFrame1")
		if n then Set(spec, n, c[1], c[2]); spec.orientations = spec.orientations or {}
			if n == "SlimSuitePartyLines" then spec.orientations.PartyMemberFrame1 = (c[2] < .2 or c[2] > .85) and "horizontal" or "vertical" end end
	elseif role == "boss" and has.SlimSuiteBossFrames then Set(spec, "SlimSuiteBossFrames", c[1], c[2])
	elseif role == "clock" and has.SlimSuiteClockFrame then Set(spec, "SlimSuiteClockFrame", c[1], c[2])
	elseif role == "chat" and has.ChatFrame1 then Set(spec, "ChatFrame1", c[1], c[2]) end
	local trial = Copy(designs); trial[d][3] = spec
	local ok = Valid(spec); local s = ok and Score(trial) or -1
	local kept = ok and s > best
	if kept then designs = trial; best = s end
	print(string.format("pass %d: %s, %s -> %s%s", pass, designs[d][1], role, ok and string.format("score %.2f", s) or "breaks a screen", kept and "  KEPT" or ""))
end
SS.ScreenBounds = real
for _, p in ipairs(designs) do
	print("== " .. p[1]); if p[3].orientations then for k, v in pairs(p[3].orientations) do print("  orientation " .. k .. " " .. v) end end
	for _, at in ipairs(p[3].places) do print(string.format("  { \"%s\", %s, %s%s },", at[1], tostring(at[2]), tostring(at[3]), at.fromCentre and ", fromCentre = true" or "")) end
end
