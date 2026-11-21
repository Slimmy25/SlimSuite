-- Preset designs offered first in Quick setup ("Would you like to use a pre-set design?"). Up to 5 are shown.
-- To add one: arrange the HUD the way you want, open /slim layout, export the layout and paste its text
-- (it starts with "SSL1;") as the third value below. Name and description are what players see.
-- Its picture is textures/quick/preset<n>.tga (n = its place among the filled-in presets): python3 tools/quick-image.py shot.jpg preset1
-- A preset with no text is skipped; the built-in designs below fill the remaining places.
if ( setfenv ) then setfenv(1, SS.ENV); end

-- Built-in designs, used until you add your own (yours go first; at most 5 are offered in all).
-- "places" lists elements in order of importance as { name, x, y }: x, y is where the CENTRE of the element goes, in
-- fractions of the screen (0,0 bottom left; 1,1 top right; across a centred 16:9 area on wider screens), so the
-- design fits any resolution. When the real sizes make two elements overlap on a screen, the less important one
-- (later in the list) is moved clear of it.
-- These five are AI-generated demo designs, made to show what Slim Suite can do. To decide what a typical UI should
-- feature, common layouts from WoW Forever, retail WoW and Azeroth Survivors were cross-referenced; the designs and
-- all of this code are new and Slim Suite's own.
SS.BUILTIN_PRESETS = {
	{ "Classic Plus", "The game's own layout, with the encounter bars, run clock and tally added.", {
		style = "original",
		keys = { replaceEncounters = true, replaceClock = true, replaceTally = true, modernEnemyFrames = true, enemyBossesOnly = true },
		places = { { "SlimSuiteBossFrames", 0.5, 0.83 }, { "SlimSuiteClockFrame", 0.27, 0.95 }, { "SlimSuiteTallyFrame", 0.86, 0.6 } } } },
	{ "Centered", "Player and target side by side over the action bars, enemies' bars across the top.", {
		style = "tooltip",
		keys = { playerLook = "new", targetLook = "new", replaceEncounters = true, replaceClock = true, replaceTally = true,
			modernEnemyFrames = true, enemyBossesOnly = false, mirrorTarget = false },
		scales = { ChatFrame1 = 0.8 },
		places = { { "MainMenuBar", 0.5, 0.05 }, { "SlimSuitePlayerCard", 0.36, 0.225 }, { "SlimSuiteTargetCard", 0.64, 0.225 },
			{ "SlimSuiteBossFrames", 0.5, 0.83 }, { "SlimSuiteClockFrame", 0.27, 0.95 }, { "SlimSuiteTallyFrame", 0.27, 0.88 },
			{ "PartyMemberFrame1", 0.08, 0.6 }, { "ChatFrame1", 0.12, 0.09 } } } },
	{ "Info Column", "Everything about the run stacked down the right side; the middle stays clear for the fight.", {
		style = "meter",
		keys = { playerLook = "new", targetLook = "new", replaceEncounters = true, replaceClock = true, replaceTally = true,
			moveMeter = true, modernEnemyFrames = true, enemyBossesOnly = true },
		scales = { ChatFrame1 = 0.8 },
		places = { { "MainMenuBar", 0.5, 0.05 }, { "SlimSuitePlayerCard", 0.38, 0.225 }, { "SlimSuiteTargetCard", 0.62, 0.225 },
			{ "ChatFrame1", 0.12, 0.09 },
			{ "SlimSuiteClockFrame", 0.91, 0.7 }, { "SlimSuiteBossFrames", 0.91, 0.47 }, { "SlimSuiteTallyFrame", 0.91, 0.31 },
			{ "SlimSuiteMeterFrame", 0.91, 0.14 }, { "PartyMemberFrame1", 0.08, 0.6 } } } },
	{ "Minimal", "As little on screen as possible: small frames low and out of the way, no extra panels.", {
		style = "tooltip",
		keys = { playerLook = "new", targetLook = "new", replaceEncounters = true, modernEnemyFrames = true, enemyBossesOnly = true,
			replaceTally = false, xpHideBorder = true, compassOn = false, luckPanel = false, statCounter = false, achievementButton = false },
		scales = { SlimSuitePlayerCard = 0.85, SlimSuiteTargetCard = 0.85, MainMenuBar = 0.85, ChatFrame1 = 0.7 },
		places = { { "MainMenuBar", 0.5, 0.04 }, { "SlimSuitePlayerCard", 0.4, 0.16 }, { "SlimSuiteTargetCard", 0.6, 0.16 },
			{ "SlimSuiteBossFrames", 0.5, 0.86 }, { "ChatFrame1", 0.12, 0.08 } },
		off = { "SlimSuiteCompassFrame", "SlimSuiteLuckFrame", "SlimSuiteStatCounterFrame", "SlimSuiteAchievementsButton" } } },
	{ "Controller / Handheld", "Big, high-contrast frames grouped low and central for a handheld screen or the couch.", {
		style = "tooltip",
		keys = { playerLook = "new", targetLook = "new", partyLook = "thin", replaceEncounters = true, replaceClock = true,
			modernEnemyFrames = true, enemyBossesOnly = false, accessibilityLargeText = true, accessibilityContrast = true,
			partyGreyDead = true, partyDistance = true, partyDimFar = true, compassOn = true, encounterBarThickness = "thick" },
		orientations = { PartyMemberFrame1 = "vertical" },
		scales = { SlimSuitePlayerCard = 1.2, SlimSuiteTargetCard = 1.2, MainMenuBar = 1.2, SlimSuitePartyLines = 1.4,
			SlimSuiteBossFrames = 1.15, ChatFrame1 = 0.7 },
		places = { { "MainMenuBar", 0.5, 0.06 }, { "SlimSuitePlayerCard", 0.34, 0.22 }, { "SlimSuiteTargetCard", 0.66, 0.22 },
			{ "SlimSuiteCompassFrame", 0.5, 0.95 }, { "BuffFrame", 0.85, 0.72 }, { "SlimSuiteBossFrames", 0.88, 0.47 }, { "SlimSuitePartyLines", 0.1, 0.5 },
			{ "SlimSuiteClockFrame", 0.2, 0.95 }, { "ChatFrame1", 0.1, 0.07 } },
		on = { "SlimSuiteCompassFrame" } } },
};

-- where the game's own frames sit when a design does not move them: designs keep clear of these
-- { name, width, height, corner } with corner "TOPRIGHT", "BOTTOMLEFT" or "BOTTOM"
SS.PRESET_RESERVED = { { "MinimapCluster", 200, 200, "TOPRIGHT" }, { "BuffFrame", 320, 110, "TOPRIGHT", 205 },
	{ "ChatFrame1", 440, 130, "BOTTOMLEFT", 0, 90 }, { "MainMenuBar", 620, 60, "BOTTOM" } };

-- your own designs: exported layout text from /slim layout (starts with "SSL1;"). These come before the built-in ones.
SS.PRESETS = {
	-- { "Name", "One line about this design.", "SSL1;..." },
	-- { "Name", "One line about this design.", "SSL1;..." },
	-- { "Name", "One line about this design.", "SSL1;..." },
	-- { "Name", "One line about this design.", "SSL1;..." },
	-- { "Name", "One line about this design.", "SSL1;..." },
};

-- the size an element takes on screen at the design's scale
function SS.PresetElementSize(name, scale)
	local f = getglobal(name);
	return (f and f.GetWidth and f:GetWidth() or 100) * scale, (f and f.GetHeight and f:GetHeight() or 40) * scale;
end

-- a built-in design turned into a full layout for this screen: everything else goes back to the game's own place
function SS.BuildPresetLayout(spec)
	local layout = {};
	for _, key in ipairs(SS.LAYOUT_TABLES) do layout[key] = {}; end
	for k, v in pairs(spec.keys or {}) do layout[k] = v; end
	for k, v in pairs(spec.orientations or {}) do layout.orientations[k] = v; end
	for k, v in pairs(spec.scales or {}) do layout.scales[k] = v; end
	local sl, sr, sb, st = SS.ScreenBounds();
	local sw, sh = sr - sl, st - sb;
	-- x is measured across a centred 16:9 area, so on ultrawide screens the HUD stays together in the middle
	-- instead of stretching to the far edges; narrower screens use their full width
	local aw = math.min(sw, sh * 16 / 9);
	local al = sl + (sw - aw) / 2;
	local margin = 4;
	local placed = {};
	local function Clamp(r)
		r.x = math.max(sl + margin, math.min(sr - margin - r.w, r.x));
		r.y = math.max(sb + margin, math.min(st - margin - r.h, r.y));
	end
	local function Hits(r)
		for j = 1, table.getn(placed) do
			local o = placed[j];
			if ( r.x < o.x + o.w + margin and o.x < r.x + r.w + margin and r.y < o.y + o.h + margin and o.y < r.y + r.h + margin ) then return o; end
		end
	end
	-- the middle of the screen, where your hero fights
	local function Middle(c)
		return c.x < sl + sw / 2 + aw * 0.18 and sl + sw / 2 - aw * 0.18 < c.x + c.w and c.y < sb + sh * 0.7 and sb + sh * 0.3 < c.y + c.h;
	end
	-- the game's own frames that this design leaves where they are
	local moved = {};
	for _, at in ipairs(spec.places or {}) do moved[at[1]] = true; end
	for _, res in ipairs(SS.PRESET_RESERVED) do
		if ( not moved[res[1]] ) then
			local w, h, dx, dy = res[2], res[3], res[5] or 0, res[6] or 0;
			local r = { name = res[1], w = w, h = h, reserved = true };
			if ( res[4] == "TOPRIGHT" ) then r.x, r.y = sr - w - dx, st - h - dy;
			elseif ( res[4] == "BOTTOMLEFT" ) then r.x, r.y = sl + dx, sb + dy;
			else r.x, r.y = sl + (sw - w) / 2, sb; end
			table.insert(placed, r);
		end
	end
	for _, at in ipairs(spec.places or {}) do
		local name = at[1];
		local w, h = SS.PresetElementSize(name, spec.scales and spec.scales[name] or 1);
		local r = { name = name, w = w, h = h, x = al + at[2] * aw - w / 2, y = sb + at[3] * sh - h / 2 };
		Clamp(r);
		-- clear of anything more important: of the spots just past the obstacle (above, below, left, right), take the
		-- nearest one that is on screen and keeps out of the middle
		local wantX, wantY = r.x, r.y;
		local tries = 0;
		local o = Hits(r);
		while ( o and tries < 40 ) do
			tries = tries + 1;
			local best, bestCost;
			for _, c in ipairs({ { r.x, o.y + o.h + margin }, { r.x, o.y - r.h - margin }, { o.x - r.w - margin, r.y }, { o.x + o.w + margin, r.y } }) do
				local cand = { w = r.w, h = r.h, x = c[1], y = c[2] };
				if ( cand.x >= sl + margin and cand.x + cand.w <= sr - margin and cand.y >= sb + margin and cand.y + cand.h <= st - margin ) then
					local cost = math.abs(cand.x - wantX) + math.abs(cand.y - wantY) + (Middle(cand) and 100000 or 0);
					if ( not bestCost or cost < bestCost ) then best, bestCost = cand, cost; end
				end
			end
			if ( not best ) then break; end
			r.x, r.y = best.x, best.y;
			o = Hits(r);
		end
		table.insert(placed, r);
		layout.places[name] = { x = r.x, y = r.y, coordinateSpace = "uiParent", screen = { left = sl, bottom = sb, width = sw, height = sh } };
		layout.elementModes[name] = "enabled";
	end
	for _, name in ipairs(spec.on or {}) do layout.elementModes[name] = "enabled"; end
	for _, name in ipairs(spec.off or {}) do layout.elementModes[name] = "default"; end
	return layout, placed;
end

local function Parse(text)
	if ( not SS.LayoutFromText ) then return nil; end
	local ok, layout = SS.Safe(SS.LayoutFromText, text);
	return ok and type(layout) == "table" and layout or nil;
end

-- the presets that are filled in and can be read, at most 5
function SS.UsablePresets()
	local out = {};
	local function Add(p, builtin)
		if ( table.getn(out) >= 5 or type(p) ~= "table" or type(p[1]) ~= "string" ) then return; end
		if ( builtin and type(p[3]) ~= "table" ) then return; end
		if ( not builtin and (type(p[3]) ~= "string" or p[3] == "" or not Parse(p[3])) ) then return; end
		p.picture = "preset" .. (table.getn(out) + 1);   -- textures/quick/preset<n>.tga, made with tools/quick-image.py
		table.insert(out, p);
	end
	for _, p in ipairs(SS.PRESETS or {}) do Add(p, false); end
	for _, p in ipairs(SS.BUILTIN_PRESETS or {}) do Add(p, true); end
	return out;
end

function SS.ApplyPreset(p)
	if ( not p ) then return false; end
	local layout = type(p[3]) == "table" and SS.BuildPresetLayout(p[3]) or Parse(p[3]);
	if ( not layout ) then return false; end
	SS.LayoutApply(layout);
	if ( type(p[3]) == "table" ) then
		-- options a saved layout does not carry (party extras, compass, ...) are set as well, then drawn again
		local d = SS.DB();
		for k, v in pairs(p[3].keys or {}) do d[k] = v; end
		if ( PlaceAll ) then SS.Safe(PlaceAll); end
		for _, fn in ipairs({ SS.UpdateCompass, SS.UpdateLuck, SS.UpdateStats, SS.UpdateAchievementButton, SS.UpdateEnemyNameplates, SS.UpdatePartyStatus }) do
			if ( fn ) then SS.Safe(fn); end
		end
	end
	if ( type(p[3]) == "table" and p[3].style and SS.SetPanelStyle ) then SS.Safe(SS.SetPanelStyle, p[3].style); end
	if ( SS.LogAction ) then SS.LogAction("Preset design applied: " .. p[1]); end
	return true;
end
