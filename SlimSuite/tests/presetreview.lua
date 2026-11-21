-- Review of the built-in preset designs on many screens, using the elements' real in-game sizes (UI units at
-- scale 1; the action bar is estimated). Every element must be fully on screen, nothing may overlap, and each
-- element must stay near where the design wants it.
local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("  MISMATCH " .. label) end end
local REAL = { MainMenuBar = { 300, 50 }, SlimSuitePlayerCard = { 232, 100 }, SlimSuiteTargetCard = { 232, 100 },
	PlayerFrame = { 232, 100 }, TargetFrame = { 232, 100 }, PartyMemberFrame1 = { 140, 250 }, SlimSuitePartyLines = { 90, 42 },
	SlimSuiteBossFrames = { 200, 192 }, SlimSuiteClockFrame = { 220, 54 }, SlimSuiteTallyFrame = { 252, 28 },
	BuffFrame = { 300, 100 }, ChatFrame1 = { 430, 120 }, SlimSuiteCompassFrame = { 380, 88 }, SlimSuiteSpellRowFrame = { 240, 76 }, SlimSuiteMeterFrame = { 250, 180 }, SlimSuiteStatCounterFrame = { 150, 28 }, SlimSuiteCombatTextFrame = { 120, 60 } }
SS.PresetElementSize = function(name, scale) local s = REAL[name] or { 100, 40 }; return s[1] * scale, s[2] * scale end
-- UI units are 768 tall; width follows the aspect ratio
local SCREENS = { { 1024, 768, "4:3" }, { 1280, 720, "720p" }, { 1280, 800, "Steam Deck" }, { 1366, 768, "laptop" },
	{ 1920, 1080, "1080p" }, { 1920, 1200, "16:10" }, { 2560, 1440, "1440p" }, { 2560, 1080, "21:9" },
	{ 3440, 1440, "ultrawide" }, { 3840, 1080, "32:9" } }
local real = SS.ScreenBounds
for pass, scr in ipairs(SCREENS) do
	local w = 768 * scr[1] / scr[2]
	SS.ScreenBounds = function() return 0, w, 0, 768 end
	for _, p in ipairs(SS.BUILTIN_PRESETS) do
		local _, placed = SS.BuildPresetLayout(p[3])
		local where = "pass " .. pass .. " (" .. scr[3] .. ") " .. p[1] .. ": "
		local spot = {}; for _, at in ipairs(p[3].places) do spot[at[1]] = at end
		local aw = math.min(w, 768 * 16 / 9); local al = (w - aw) / 2
		for i, r in ipairs(placed) do
			if not r.reserved then
				check(where .. r.name .. " on screen", r.x >= 0 and r.y >= 0 and r.x + r.w <= w and r.y + r.h <= 768)
				for j = 1, table.getn(placed) do
					local o = placed[j]
					if o ~= r then check(where .. r.name .. " clear of " .. o.name, not (r.x < o.x + o.w and o.x < r.x + r.w and r.y < o.y + o.h and o.y < r.y + r.h)) end
				end
				local at = spot[r.name]
				local dx = at.fromCentre and math.abs((r.x + r.w / 2 - w / 2 - at[2]) / aw) or math.abs((r.x + r.w / 2 - al) / aw - at[2]); local dy = math.abs((r.y + r.h / 2) / 768 - at[3])
				-- on 4:3 the game's buffs reach the top middle, so top elements may step aside a little further
				local reach = (w / 768 < 1.4) and 0.12 or 0.08
				check(where .. r.name .. " near its spot (" .. string.format("%.2f, %.2f off", dx, dy) .. ")", dx < reach and dy < reach)
				-- the middle of the screen is where your hero fights: nothing sits in it
				local cx0, cx1, cy0, cy1 = w / 2 - aw * 0.18, w / 2 + aw * 0.18, 768 * 0.3, 768 * 0.7
				check(where .. r.name .. " keeps the middle clear", not (r.x < cx1 and cx0 < r.x + r.w and r.y < cy1 and cy0 < r.y + r.h))
			end
		end
		-- looks: the action bar centred, player and target mirror each other, and sit within easy eye reach
		local by = {}; for _, r in ipairs(placed) do by[r.name] = r end
		local bar = by.MainMenuBar
		if bar and not (p[3].orientations and p[3].orientations.MainMenuBar == "vertical") then check(where .. "action bar centred", math.abs(bar.x + bar.w / 2 - w / 2) < 2) end
		local pc, tc = by.SlimSuitePlayerCard, by.SlimSuiteTargetCard
		if pc and tc then
			check(where .. "player and target mirror each other", math.abs((pc.x + pc.w / 2) + (tc.x + tc.w / 2) - w) < 2 and math.abs(pc.y - tc.y) < 1)
			check(where .. "player and target within eye reach", (tc.x - (pc.x + pc.w)) < 760)
			if bar and not (p[3].orientations and p[3].orientations.MainMenuBar == "vertical") and pc.y < 300 then check(where .. "cards close above the bar", pc.y - (bar.y + bar.h) < 200) end
		end
	end
end
SS.ScreenBounds = real
if os.getenv("MAP") then
	local W = 768 * tonumber(os.getenv("MAP")) ; local cols, rows = 96, 30
	SS.ScreenBounds = function() return 0, W, 0, 768 end
	for _, p in ipairs(SS.BUILTIN_PRESETS) do
		local _, placed = SS.BuildPresetLayout(p[3])
		local g = {}; for y = 1, rows do g[y] = {}; for x = 1, cols do g[y][x] = "." end end
		for i, r in ipairs(placed) do
			local ch = r.reserved and "#" or string.char(64 + i)
			for y = math.floor(r.y / 768 * rows) + 1, math.min(rows, math.ceil((r.y + r.h) / 768 * rows)) do
				for x = math.floor(r.x / W * cols) + 1, math.min(cols, math.ceil((r.x + r.w) / W * cols)) do g[rows - y + 1][x] = ch end
			end
		end
		print("== " .. p[1]); for y = 1, rows do print(table.concat(g[y])) end
		for i, r in ipairs(placed) do print((r.reserved and "#" or string.char(64 + i)) .. " " .. r.name) end
	end
	SS.ScreenBounds = real
end
print("preset review problems: " .. bad)
if bad > 0 then error("preset review") end
