-- Slim Suite: starting up, the slash commands, Demo Mode and raid marks.
if ( setfenv ) then setfenv(1, SS.ENV); end   -- Slim Suite's files share one set of private names (SS.ENV, in SlimSuiteCore.lua)

loader = CreateFrame("Frame");
loader:RegisterEvent("VARIABLES_LOADED");
loader:RegisterEvent("PLAYER_ENTERING_WORLD");
-- The game's Interface settings (Show Run Clock, Show Boss Bars ...) can be turned off by the player. A part that is
-- off when the game loads, and that Slim Suite did not turn off itself, was turned off by the player: Slim Suite's own
-- movable version is switched on in its place, once (turning Slim Suite's version off afterwards is respected).
SS.NATIVE_REPLACEMENTS = {
	clock = { "replaceClock", "Run clock", function() SS.UpdateClock(); end },
	bosses = { "replaceEncounters", "Encounter bars", function() SS.UpdateBossFrames(); end },
	tally = { "replaceTally", "Kills / Gold / Cache", function() SS.UpdateTally(); end },
	build = { "replaceBuildRows", "Build rows", function() SS.ApplyBuildRowReplacement(); end },
	banners = { "replaceBanners", "Announcements", function() SS.UpdateAnnouncementFrame(); end },
	meter = { "moveMeter", "Damage meter", function() SS.SetMeterReplacement(true); end },
	localClock = { "replaceLocalClock", "Local clock", function() SS.SetLocalClockOn(true); end },
	levels = { "moveLevelButton", "Level Up button", function() SS.UpdateLevelButton(); end },
	revive = { "replaceRevive", "Revive bar", function() end },
};
function SS.NativeIsOff(part)
	if ( type(AZS_IsHudShown) ~= "function" ) then return nil; end
	local ok, v = SS.Safe(AZS_IsHudShown, part);
	if ( not ok or v == nil ) then return nil; end
	return not SS.HudShown(v);
end
function SS.AdoptHiddenNatives()
	local d = SS.DB();
	d.nativeAdopted = type(d.nativeAdopted) == "table" and d.nativeAdopted or {};
	local turned = {};
	for part, r in pairs(SS.NATIVE_REPLACEMENTS) do
		local key = SS.NATIVE_KEYS[part];
		local ours = key and d[key] ~= nil;                      -- Slim Suite hid it (and has not put it back yet)
		if ( not ours and not d.nativeAdopted[part] and SS.NativeIsOff(part) and not d[r[1]] ) then
			d[r[1]] = true; d.nativeAdopted[part] = true;
			SS.Safe(r[3]);
			table.insert(turned, r[2]);
		end
	end
	if ( table.getn(turned) > 0 and SS.Notice ) then
		SS.Notice("The game's own " .. table.concat(turned, ", ") .. " " .. (table.getn(turned) == 1 and "is" or "are") .. " off in its Interface settings, so Slim Suite's movable version is on instead.");
	end
end

function SS.Startup(entering, loaded)
	SS.Safe(SS.RegisterAnnouncementHandler);
	local ok, err = SS.Safe(HookChat);
	if ( not ok ) then K.Print(NAME, "|cffff4040the chat could not be changed:|r " .. tostring(err)); end
	-- The editor state is a user choice, not a leftover from an earlier session. Clear legacy
	-- unlocked saves at load; only the explicit startup option may reopen the mover after login.
	if ( loaded ) then
		SS.DB().unlocked = false;
		SS.Safe(SS.RestoreNatives);
		SS.Safe(SS.AdoptHiddenNatives);
	end
	if ( entering ) then SS.Safe(SS.LayoutLogin); end        -- this character's own layout, if they are kept apart
	SS.Safe(SS.Camera, entering);
	SS.Safe(SS.ApplyGuardianFlag);
	-- the frames back where they were put (the game places some of them again as it loads), and the target frame
	if ( SS.DB().unlocked or type(SS.DB().places.MainMenuExpBar) == "table"
		or type(SS.DB().sizes.MainMenuExpBar) == "table" or type(SS.DB().scales.MainMenuExpBar) == "number"
		or SS.DB().orientations.MainMenuExpBar ~= nil ) then SS.Safe(SS.DetachExperienceBar); end
	if ( type(SS.DB().places.ChatFrame1) == "table" ) then SS.Safe(SS.PrepareChatWindow); end
	SS.Safe(SS.ApplyTallyLayout, false);
	SS.Safe(PlaceAll);
	SS.Safe(SS.TargetFrameHidden, SS.DB().hideTarget);
	if ( SS.DB().partyIncludesSelf ) then SS.Safe(SS.PlayerFrameHidden, true);
	elseif ( SS.playerShow ) then SS.Safe(SS.PlayerFrameHidden, false); end
	if ( SS.DB().plainBar ) then SS.Safe(SS.PlainBar, true); end
	SS.Safe(ApplyMovableOrientation, "MainMenuBar");
	SS.Safe(ApplyMovableOrientation, "MainMenuExpBar");
	SS.Safe(ApplyMovableOrientation, "BuffFrame");

	SS.Safe(ApplyMovableOrientation, "PartyMemberFrame1");
	SS.Safe(ApplyActionSlotGrid);
	SS.Safe(SS.HookTooltipOwner);
	SS.Safe(PlaceAll);
	SS.Safe(UpdateMeter);
	if ( entering ) then SS.Safe(SS.SetUnlocked, false, true); SS.Safe(SS.ApplyMinimapShape); SS.Safe(SS.LayoutGather); SS.Safe(SS.LayoutMinimapBar); SS.Safe(SS.LayoutXpSegments); SS.Safe(SS.MakeCards); SS.Safe(SS.ApplyNewFrames); SS.Safe(SS.GuardTargetTooltips); SS.Safe(ApplyMovableOrientation, "PartyMemberFrame1"); end
end
loader:RegisterEvent("PLAYER_LOGOUT");
loader:SetScript("OnEvent", function()
	if ( event == "PLAYER_LOGOUT" ) then SS.Safe(SS.LayoutLogout); return; end
	SS.Startup(event == "PLAYER_ENTERING_WORLD", event == "VARIABLES_LOADED");
end);

-- ---------------------------------------------------------------- layouts
-- A layout is everything about where the UI sits and how it looks: places, sizes, scales, padding, layouts, hidden
-- elements and the frame looks. Layouts are saved by name (/slim layout save <name>), loaded again, shared as one line
-- of text (the Layouts window), and can be kept apart for each character.
SS.LAYOUT_TABLES = { "places", "sizes", "scales", "padding", "orientations", "muted", "chatOffsets" };
SS.LAYOUT_KEYS = { "playerLook", "targetLook", "partyLook", "partyIncludesSelf", "combineTarget", "mirrorTarget", "mirrorSameScale",
	"hideTarget", "buffsOnTarget", "buffsOnTargetSide", "buffsOnPlayer", "buffsOnPlayerSide", "partyLocked", "partyLockAbove",
	"partyFaces", "cardPortraits", "tallyVertical", "buffCustomLayout", "buffGrowthDirection", "buildRowsAttached", "minimapSquare",
	"gatherButtons", "gatherSide", "minimapBar", "tooltipCustom", "plainBar", "showRacialAbility", "xpSegments" };
function SS.CopyTable(t)
	local out = {};
	for k, v in pairs(t) do
		if ( type(v) == "table" ) then out[k] = SS.CopyTable(v); else out[k] = v; end
	end
	return out;
end
function SS.LayoutSnapshot()
	local d, out = SS.DB(), {};
	for i = 1, table.getn(SS.LAYOUT_TABLES) do
		local key = SS.LAYOUT_TABLES[i];
		out[key] = SS.CopyTable(type(d[key]) == "table" and d[key] or {});
	end
	for i = 1, table.getn(SS.LAYOUT_KEYS) do
		local key = SS.LAYOUT_KEYS[i];
		out[key] = d[key];
	end
	return out;
end
-- puts a layout in place of the current one and draws everything again from it
function SS.LayoutApply(layout, quiet)
	if ( type(layout) ~= "table" ) then return false; end
	if ( setupActive ) then SS.SetupEnd(true); end
	if ( SS.demoRunning ) then SS.StopDemoMode(); end
	local d = SS.DB();
	for i = 1, table.getn(SS.LAYOUT_TABLES) do
		local key = SS.LAYOUT_TABLES[i];
		d[key] = SS.CopyTable(type(layout[key]) == "table" and layout[key] or {});
	end
	for i = 1, table.getn(SS.LAYOUT_KEYS) do
		local key = SS.LAYOUT_KEYS[i];
		d[key] = layout[key];
	end
	d.frameDefault = nil;
	SS.PrepareDB(d);                                       -- anything the layout did not carry gets its default
	if ( not quiet ) then
		-- elements with no place in this layout go back to where they started
		for i = 1, table.getn(MOVABLE) do
			local name = MOVABLE[i][1];
			local frame, points, base = getglobal(name), basePoints[name], baseSizes[name];
			if ( frame and name ~= "GameTooltip" ) then
				if ( points and type(d.places[name]) ~= "table" ) then
					frame:ClearAllPoints();
					for j = 1, table.getn(points) do local p = points[j]; frame:SetPoint(p[1], p[2], p[3], p[4], p[5]); end
				end
				if ( base and type(d.sizes[name]) ~= "table" ) then frame:SetWidth(base.w); frame:SetHeight(base.h); end
				if ( frame.SetScale and type(d.scales[name]) ~= "number" ) then frame:SetScale(1); end
			end
		end
		SS.Startup(false, false);
		SS.Safe(SS.SetUnlocked, false, true);
		SS.Safe(SS.ApplyMinimapShape); SS.Safe(SS.LayoutGather); SS.Safe(SS.LayoutMinimapBar); SS.Safe(SS.LayoutXpSegments);
		SS.Safe(SS.ApplyNewFrames); SS.Safe(SS.PlainBar, d.plainBar and true or false);
		for i = 1, table.getn(MOVABLE) do SS.Safe(ApplyFeatureMute, MOVABLE[i][1]); end
		SS.Safe(SS.UpdateTally); SS.Safe(SS.UpdateClock); SS.Safe(SS.UpdateBossFrames); SS.Safe(SS.ApplyBuffOrientation);
		SS.Safe(PlaceAll);
		SS.RefreshToggles();
	end
	return true;
end
-- a layout as one line of text: "SSL1;places.PlayerFrame.x=n12.5;playerLook=sclassic;..." (n number, s text, b yes/no)
function SS.LayoutText(layout)
	local parts = { "SSL1" };
	local function Add(path, v)
		if ( type(v) == "table" ) then
			for k, inner in pairs(v) do
				if ( type(k) == "string" or type(k) == "number" ) then Add(path .. "." .. tostring(k), inner); end
			end
		elseif ( type(v) == "number" ) then table.insert(parts, path .. "=n" .. (math.floor(v * 100 + 0.5) / 100));
		elseif ( type(v) == "boolean" ) then table.insert(parts, path .. "=b" .. (v and "1" or "0"));
		elseif ( type(v) == "string" and not string.find(v, "[;=]") ) then table.insert(parts, path .. "=s" .. v);
		end
	end
	for i = 1, table.getn(SS.LAYOUT_TABLES) do Add(SS.LAYOUT_TABLES[i], layout[SS.LAYOUT_TABLES[i]]); end
	for i = 1, table.getn(SS.LAYOUT_KEYS) do Add(SS.LAYOUT_KEYS[i], layout[SS.LAYOUT_KEYS[i]]); end
	return table.concat(parts, ";");
end
-- reads that text back; only the parts a layout is made of are taken (nil if it is not a layout)
function SS.LayoutFromText(text)
	text = string.gsub(tostring(text or ""), "%s+", "");
	if ( string.sub(text, 1, 5) ~= "SSL1;" ) then return nil; end
	local allowed = {};
	for i = 1, table.getn(SS.LAYOUT_TABLES) do allowed[SS.LAYOUT_TABLES[i]] = "table"; end
	for i = 1, table.getn(SS.LAYOUT_KEYS) do allowed[SS.LAYOUT_KEYS[i]] = "value"; end
	local out, count = {}, 0;
	for i = 1, table.getn(SS.LAYOUT_TABLES) do out[SS.LAYOUT_TABLES[i]] = {}; end
	for path, kind, raw in string.gfind(string.sub(text, 6), "([^;=]+)=([nsb])([^;]*)") do
		local value;
		if ( kind == "n" ) then value = tonumber(raw); elseif ( kind == "b" ) then value = raw == "1"; else value = raw; end
		local keys = {};
		for key in string.gfind(path, "[^%.]+") do table.insert(keys, key); end
		local root = keys[1];
		if ( value ~= nil and allowed[root] == "value" and table.getn(keys) == 1 ) then
			out[root] = value; count = count + 1;
		elseif ( value ~= nil and allowed[root] == "table" and table.getn(keys) >= 2 and table.getn(keys) <= 4 ) then
			local t = out[root];
			for k = 2, table.getn(keys) - 1 do
				if ( type(t[keys[k]]) ~= "table" ) then t[keys[k]] = {}; end
				t = t[keys[k]];
			end
			t[keys[table.getn(keys)]] = value; count = count + 1;
		end
	end
	if ( count == 0 ) then return nil; end
	return out;
end
function SS.LayoutNames()
	local names = {};
	for name in pairs(SS.DB().layouts) do
		if ( type(name) == "string" and string.sub(name, 1, 5) ~= "char:" ) then table.insert(names, name); end
	end
	table.sort(names);
	return names;
end
-- each character's own layout: kept when that character logs out, put back when it logs in
function SS.LayoutCharacter()
	local who = UnitName and UnitName("player");
	if ( type(who) ~= "string" or who == "" ) then return nil; end
	return "char:" .. who;
end
function SS.LayoutLogin()
	local d = SS.DB();
	if ( SS.layoutLoggedIn or not d.layoutPerCharacter ) then return; end
	local key = SS.LayoutCharacter();
	if ( not key ) then return; end
	SS.layoutLoggedIn = true;
	if ( d.layoutOwner ~= key and type(d.layouts[key]) == "table" ) then SS.LayoutApply(d.layouts[key], true); end
	d.layoutOwner = key;
end
function SS.LayoutLogout()
	local d = SS.DB();
	if ( not d.layoutPerCharacter ) then return; end
	local key = d.layoutOwner or SS.LayoutCharacter();
	if ( key ) then d.layouts[key] = SS.LayoutSnapshot(); end
end
function SS.SetLayoutPerCharacter(on)
	local d = SS.DB();
	d.layoutPerCharacter = on and true or false;
	if ( on ) then d.layoutOwner = SS.LayoutCharacter(); SS.layoutLoggedIn = true; end
end
-- the Layouts window: the current layout as text to copy, and a place to paste one in
function SS.ShowLayoutWindow()
	local f = getglobal("SlimSuiteLayoutFrame");
	if ( not f ) then
		f = K.Window("SlimSuiteLayoutFrame", "Slim Suite layouts", 520, 250);
		local note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		note:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -34); note:SetWidth(470); note:SetJustifyH("LEFT");
		note:SetText("This is your layout as text. Copy it (Ctrl+C) to share it, or paste a layout over it (Ctrl+V) and press Use this layout. Saved layouts: /slim layout save <name>, load <name>, list, delete <name>.");
		local scroll = CreateFrame("ScrollFrame", "SlimSuiteLayoutScroll", f, "UIPanelScrollFrameTemplate");
		scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -78);
		scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -42, 50);
		local box = CreateFrame("EditBox", "SlimSuiteLayoutBox", scroll);
		box:SetMultiLine(true); box:SetAutoFocus(false); box:SetFontObject(GameFontHighlightSmall);
		box:SetWidth(450); box:SetMaxLetters(0);
		box:SetScript("OnEscapePressed", function() this:ClearFocus(); end);
		scroll:SetScrollChild(box);
		f.box = box;
		local use = K.Button(f, "Use this layout", 130, function()
			local layout = SS.LayoutFromText(f.box:GetText());
			if ( not layout ) then K.Print(NAME, "that text is not a Slim Suite layout."); return; end
			SS.LayoutApply(layout);
			K.Print(NAME, "the pasted layout is in use.");
		end);
		use:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 22, 18);
		local mine = K.Button(f, "Show my layout", 130, function()
			f.box:SetText(SS.LayoutText(SS.LayoutSnapshot()));
			f.box:SetFocus(); if ( f.box.HighlightText ) then f.box:HighlightText(); end
		end);
		mine:SetPoint("LEFT", use, "RIGHT", 8, 0);
	end
	f.box:SetText(SS.LayoutText(SS.LayoutSnapshot()));
	f:Show();
	f.box:SetFocus(); if ( f.box.HighlightText ) then f.box:HighlightText(); end
end

buffLayoutUpdater = CreateFrame("Frame");
buffLayoutUpdater:RegisterEvent("UNIT_AURA");
buffLayoutUpdater:SetScript("OnEvent", function()
	if ( arg1 == "player" ) then SS.buffDirty = true; end
end);
SS.Every("buffLayout", 0.1, function()
	local preview = SS.Previewing("BuffFrame");
	if ( preview ~= SS.buffPreviewWas ) then SS.buffPreviewWas = preview; SS.buffDirty = true; end
	if ( SS.buffDirty ) then SS.buffDirty = false; SS.Safe(SS.ApplyBuffOrientation); end
end);
SS.Safe(HookChat);                                          -- right away too, so lines printed while loading are caught

-- Gather the minimap buttons: Slim Suite's own button and the small named buttons other addons put on the minimap
-- are lined up in one column or row on the chosen side. Each one's old anchor is kept so it goes back on release.
function SS.GatherRelease(f)
	if ( f.slimOrig ) then
		local o = f.slimOrig;
		f.slimOrig = nil;
		f:ClearAllPoints();
		if ( o[2] ) then f:SetPoint(o[1], o[2], o[3], o[4], o[5]); else f:SetPoint("CENTER", UIParent, "CENTER"); end
	end
end

function SS.LayoutGather()
	if ( not Minimap ) then return; end
	local d = SS.DB();
	local ours = SS.Mini;
	local want, wantSet = {}, {};
	if ( d.gatherButtons ) then
		local ourShown = ours and not (d.minimap and d.minimap.hide);
		if ( ourShown ) then table.insert(want, ours); wantSet[ours] = true; end
		local kids = { Minimap:GetChildren() };
		for i = 1, table.getn(kids) do
			local f = kids[i];
			local name = f and f.GetName and f:GetName();
			if ( name and f ~= ours and f.IsShown and f:IsShown() and string.sub(name, 1, 7) ~= "Minimap"
				and string.sub(name, 1, 9) ~= "SlimSuite" and string.sub(name, 1, 10) ~= "MiniMapTra" ) then
				local w, h = f:GetWidth() or 0, f:GetHeight() or 0;
				if ( w > 0 and w <= 40 and h > 0 and h <= 40 ) then table.insert(want, f); wantSet[f] = true; end
			end
		end
	end
	-- release everything gathered last time that is not gathered now
	local old = SlimSuiteGatheredList or {};
	for i = 1, table.getn(old) do if ( not wantSet[old[i]] ) then SS.GatherRelease(old[i]); end end
	-- line the wanted ones up on the chosen side, centred on the minimap
	local side = d.gatherSide or "left";
	local n = table.getn(want);
	local W, H = Minimap:GetWidth() or 140, Minimap:GetHeight() or 140;
	local gap, edge = 36, 22;
	for i = 1, n do
		local f = want[i];
		if ( not f.slimOrig ) then
			local p, rel, rp, x, y = f:GetPoint(1);
			f.slimOrig = { p, rel, rp, x or 0, y or 0 };
		end
		local off = (i - 1 - (n - 1) / 2) * gap;
		local dx, dy = 0, 0;
		if ( side == "left" ) then dx, dy = -(W / 2 + edge), off;
		elseif ( side == "right" ) then dx, dy = W / 2 + edge, off;
		elseif ( side == "above" ) then dx, dy = off, H / 2 + edge;
		else dx, dy = off, -(H / 2 + edge); end
		f:ClearAllPoints();
		f:SetPoint("CENTER", Minimap, "CENTER", dx, dy);
	end
	if ( ours and not wantSet[ours] and ours.Place ) then SS.Safe(ours.Place); end   -- back to its own spot
	SlimSuiteGatheredList = want;
end

-- "Minimap buttons": one choice for where the buttons around the minimap go
SS.MINIMAP_BUTTON_PLACES = { { "Around the minimap", "ring" }, { "Gathered above it", "above" }, { "Gathered below it", "below" },
	{ "Gathered to its left", "left" }, { "Gathered to its right", "right" }, { "In their own movable row", "row" } };
function SS.MinimapButtonPlace()
	local d = SS.DB();
	if ( d.minimapBar ) then return "row"; end
	if ( d.gatherButtons ) then return d.gatherSide or "left"; end
	return "ring";
end
function SS.SetMinimapButtonPlace(v)
	local d = SS.DB();
	if ( v == "row" ) then
		if ( not d.minimapBar ) then SS.SetMinimapBar(true, true); end
	elseif ( v == "ring" ) then
		if ( d.minimapBar ) then SS.SetMinimapBar(false, true); end
		if ( d.gatherButtons ) then SS.SetGather(false, nil, true); end
	else
		if ( d.minimapBar ) then SS.SetMinimapBar(false, true); end
		SS.SetGather(true, v, true);
	end
end
-- the setting as a menu row, in the setup, the right-click menus and the settings window
function SS.MinimapButtonsEntry()
	return { "Minimap buttons", function() return SS.MinimapButtonPlace(); end, function(v) SS.SetMinimapButtonPlace(v); end,
		choice = SS.MINIMAP_BUTTON_PLACES, xref = true, short = "Minimap buttons" };
end

function SS.SetGather(on, side, quiet)
	SS.DB().gatherButtons = on and true or false;
	if ( side ) then SS.DB().gatherButtons = true; SS.DB().gatherSide = side; end
	if ( SS.DB().gatherButtons and SS.DB().minimapBar ) then   -- the newest choice wins: the row lets its buttons go
		if ( not quiet ) then SS.Notice("The minimap buttons' own row turned off: they are gathered by the minimap now."); end
		SS.DB().minimapBar = false; SS.Safe(SS.LayoutMinimapBar); SU.Rebuild();
	end
	SS.Safe(SS.LayoutGather);
end

-- "Minimap buttons in their own row": the small buttons around the minimap (other addons', Slim Suite's gear, the
-- game's tracking, mail, battleground and meeting-stone icons) and the day/night moon line up in one movable row.
-- The zoom buttons stay on the map. Turning it off puts every button back where it was (round or square).
SS.BAR_BLIZZARD = { "GameTimeFrame", "MiniMapTrackingFrame", "MiniMapMailFrame", "MiniMapBattlefieldFrame", "MiniMapMeetingStoneFrame" };
SlimSuiteMinimapBarList = {};
do
	local bar = CreateFrame("Frame", "SlimSuiteMinimapBar", UIParent);
	bar:SetWidth(44); bar:SetHeight(44);
	bar:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -16, -210);   -- under the minimap until it is moved
	bar:SetFrameStrata("BACKGROUND");
	bar:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	bar:SetBackdropColor(0, 0, 0, 0.55);
	bar:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8);
	bar:Hide();
end

-- a button leaving the row goes back to the frame it belonged to (the minimap) and its old place
function SS.ReleaseFromBar(f)
	if ( not f or not f.slimBarOrig ) then return; end
	local o = f.slimBarOrig;
	f.slimBarOrig = nil;
	if ( f.slimBarParent and f.SetParent ) then f:SetParent(f.slimBarParent); end
	if ( f.slimBarStrata and f.SetFrameStrata ) then f:SetFrameStrata(f.slimBarStrata); end
	f.slimBarParent, f.slimBarStrata = nil, nil;
	if ( f.SetAlpha ) then f:SetAlpha(1); end
	if ( f == SS.Mini and SS.Mini.Place ) then SS.Safe(SS.Mini.Place); return; end
	f:ClearAllPoints();
	if ( o[2] ) then f:SetPoint(o[1], o[2], o[3], o[4], o[5]); end
end

function SS.LayoutMinimapBar()
	local bar = getglobal("SlimSuiteMinimapBar");
	if ( not bar or not Minimap ) then return; end
	local d = SS.DB();
	local list = SlimSuiteMinimapBarList;
	if ( not d.minimapBar ) then
		for i = 1, table.getn(list) do SS.ReleaseFromBar(list[i]); end
		SlimSuiteMinimapBarList = {};
		bar:Hide();
		return;
	end
	-- who belongs: the ones already in the row, Slim Suite's gear, the game's icons, and other addons' buttons found
	-- around the minimap's edge (small, named, and out at the rim, so the map's own pins are never taken)
	local inBar = {};
	for i = 1, table.getn(list) do inBar[list[i]] = true; end
	local function Add(f) if ( f and not inBar[f] ) then table.insert(list, f); inBar[f] = true; end end
	if ( SS.Mini ) then Add(SS.Mini); end
	for _, n in ipairs(SS.BAR_BLIZZARD) do Add(getglobal(n)); end
	local mx, my = Minimap:GetCenter();
	local ms = Minimap:GetEffectiveScale() or 1;
	local half = (Minimap:GetWidth() or 140) * ms / 2;
	local kids = { Minimap:GetChildren() };
	for i = 1, table.getn(kids) do
		local f = kids[i];
		local name = f and f.GetName and f:GetName();
		if ( name and mx and string.sub(name, 1, 7) ~= "Minimap" and string.sub(name, 1, 7) ~= "MiniMap" and string.sub(name, 1, 9) ~= "SlimSuite" ) then
			local w, h = f:GetWidth() or 0, f:GetHeight() or 0;
			local fx, fy = f:GetCenter();
			if ( w >= 18 and w <= 40 and h >= 18 and h <= 40 and fx ) then
				local fs = f:GetEffectiveScale() or 1;
				local dx, dy = fx * fs - mx * ms, fy * fs - my * ms;
				if ( math.sqrt(dx * dx + dy * dy) >= half * 0.9 ) then Add(f); end
			end
		end
	end
	SlimSuiteMinimapBarList = list;
	-- the row takes each button over (so hiding or scaling the minimap no longer touches them, and they scale with the
	-- row) and lines them up; a hidden one (mail with no mail) takes no place until it shows
	local vertical = d.orientations and d.orientations.SlimSuiteMinimapBar == "vertical";
	local slot, pad, n = 34, 5, 0;
	for i = 1, table.getn(list) do
		local f = list[i];
		if ( not f.slimBarOrig ) then
			local p, rel, rp, x, y = f:GetPoint(1);
			f.slimBarOrig = { p, rel, rp, x or 0, y or 0 };
			f.slimBarParent = f.GetParent and f:GetParent();
			f.slimBarStrata = f.GetFrameStrata and f:GetFrameStrata();
			if ( f.SetParent ) then f:SetParent(bar); end
			if ( f.SetFrameStrata ) then f:SetFrameStrata("MEDIUM"); end   -- above the row's dark background
		end
		local wanted = f:IsShown();
		if ( f == SS.Mini ) then wanted = not (d.minimap and d.minimap.hide); end
		if ( wanted ) then
			-- the setup hides the minimap's buttons by making them see-through; in the row they must be seen again
			if ( f.SetAlpha ) then f:SetAlpha(1); end
			if ( f.SetFrameLevel and bar.GetFrameLevel ) then f:SetFrameLevel((bar:GetFrameLevel() or 1) + 2); end
			local own = (f.GetScale and f:GetScale()) or 1;
			local along = pad + slot / 2 + n * slot;
			f:ClearAllPoints();
			if ( vertical ) then f:SetPoint("CENTER", bar, "TOP", 0, -along / own);
			else f:SetPoint("CENTER", bar, "LEFT", along / own, 0); end
			n = n + 1;
		end
	end
	local length = math.max(1, n) * slot + pad * 2;
	if ( vertical ) then bar:SetWidth(slot + pad * 2); bar:SetHeight(length);
	else bar:SetWidth(length); bar:SetHeight(slot + pad * 2); end
	if ( not setupActive ) then bar:Show(); end
end
SS.Every("minimapBar", 1, function() if ( SS.DB().minimapBar ) then SS.LayoutMinimapBar(); end end);   -- late buttons, new mail

function SS.SetMinimapBar(on, quiet)
	SS.DB().minimapBar = on and true or false;
	if ( on and SS.DB().gatherButtons ) then   -- the newest choice wins
		if ( not quiet ) then SS.Notice("Gather the minimap buttons turned off: they are in their own row now."); end
		SS.DB().gatherButtons = false; SS.Safe(SS.LayoutGather);
	end
	SS.Safe(SS.LayoutMinimapBar);
	if ( not on ) then SS.Safe(SS.ApplyMinimapShape); end   -- the returned buttons follow the round or square edge
	SU.Rebuild();                                            -- the row gets (or loses) its own button up top
end

-- the minimap button: a gear, at the left of the minimap (AZS Stats' is at the bottom, AZS Handbook's at the top
-- left)
okMini, errMini = SS.Safe(function()
	SS.Mini = K.Minimap({ name = "SlimSuiteMinimapButton", icon = "INV_Misc_Gear_02", angle = 190, db = SS.DB,
		click = function() SS.Toggle(); end,
		tooltip = function(tt)
			tt:AddLine(NAME);
			tt:AddLine("Gameplay helpers and UI controls.", 1, 1, 1);
			tt:AddLine(" ");
			tt:AddLine("Click: the settings. /slimsuite minimap hides this button.", 0.6, 0.6, 0.6);
		end });
end);
if ( not okMini ) then K.Print(NAME, "|cffff4040the minimap button could not be made:|r " .. tostring(errMini)); end

-- AZSKit (the shared look every AZS addon carries, the same file in each) places the button on the round minimap's
-- ring. Slim Suite adds its own rules here, so they work whichever addon's copy of that file loaded first: the button
-- is left alone while the minimap-buttons row or the square minimap's column holds it, and on a square minimap it
-- sits on the square's edge.
-- how far the game's own minimap buttons sit from the map's centre on the round map (measured once, in the map's scale)
function SS.RoundRingRadius()
	if ( SS.roundRing ) then return SS.roundRing; end
	local mx, my = Minimap:GetCenter();
	local ms = Minimap:GetEffectiveScale() or 1;
	for _, n in ipairs({ "MiniMapTrackingFrame", "MinimapZoomIn", "MiniMapMailFrame" }) do
		local f = getglobal(n);
		if ( f and not f.slimSquareOrig and not f.slimBarOrig and mx ) then
			local fx, fy = f:GetCenter();
			if ( fx ) then
				local fs = f:GetEffectiveScale() or 1;
				local dx, dy = fx * fs / ms - mx, fy * fs / ms - my;
				local r = math.sqrt(dx * dx + dy * dy);
				if ( r > 50 and r < 110 ) then SS.roundRing = r; return r; end
			end
		end
	end
	return 80;
end
if ( SS.Mini and SS.Mini.Place ) then
	local mini, ringPlace = SS.Mini, SS.Mini.Place;
	local function Docked()
		local m = SS.DB().minimap;
		return SS.DB().minimapBar;
	end
	mini.Place = function()
		if ( Docked() ) then
			local m = SS.DB().minimap;
			if ( type(m) == "table" and m.hide ) then mini:Hide(); else mini:Show(); end
			return;
		end
		ringPlace();
		local m = SS.DB().minimap;
		if ( Minimap and not (type(m) == "table" and m.detached) ) then
			-- on the ring exactly as the game's own buttons sit: the same distance from the centre as its tracking or
			-- zoom button on the round map, and on the square's gold ring when square. The offsets are worked out in
			-- the minimap's own scale, so a scaled minimap or button no longer pushes the gear off the ring.
			local a = math.rad(K.Num(type(m) == "table" and m.angle or 190));
			local x, y = math.cos(a), math.sin(a);
			local k = (Minimap:GetEffectiveScale() or 1) / (mini:GetEffectiveScale() or 1);
			if ( SS.squareActive ) then
				local most = math.max(math.abs(x), math.abs(y));
				if ( most > 0 ) then x, y = x / most, y / most; end
				x, y = x * ((Minimap:GetWidth() or 140) / 2 + 3), y * ((Minimap:GetHeight() or 140) / 2 + 3);
			else
				local r = SS.RoundRingRadius();
				x, y = x * r, y * r;
			end
			mini:ClearAllPoints();
			mini:SetPoint("CENTER", Minimap, "CENTER", x * k, y * k);
		end
	end
	-- dragging it does nothing while the row or the column holds it (they are moved by their own handle)
	local drag = mini:GetScript("OnUpdate");
	mini:SetScript("OnUpdate", function() if ( not Docked() and drag ) then drag(); end end);
end

-- Demo Mode: every Slim Suite element shows sample data on its own frame, moving and changing in real time, with its own
-- size, scale and layout. Nothing is saved: the party's row/column switch is the demo's own, and everything the demo
-- shows goes away when it stops.
demoT = 0;
DEMO_HITS = { { 412, "Fireball", "Spell_Fire_Fireball02", true }, { 96, "Frostbolt", "Spell_Frost_FrostBolt02", false },
	{ 180, "Smite", "Spell_Holy_Smite", false }, { 55, "Mend", "Spell_Holy_Heal", false, true }, { 233, "Arcane Missiles", "Spell_Nature_StarFall", false },
	{ 310, "Shadow Bolt", "Spell_Shadow_ShadowBolt", true } };
demoHitIndex = 1;
demoHitClock = 0;
-- sample minimap pins and an XP-bar glint, drawn on the real frames and removed when the demo stops
demoPins, demoGlint = {}, nil;

function DemoTick(dt)
	demoT = demoT + dt;
	demoHitClock = demoHitClock + dt;
	-- target and party health rise and fall (the sample values the previews read)
	SU.SAMPLE_TARGET.hp = 40 + math.floor(35 * (1 + math.sin(demoT * 0.9)) / 2);
	for i = 1, table.getn(SU.PARTY_SAMPLE) do
		local s = SU.PARTY_SAMPLE[i];
		s[3] = 35 + math.floor(60 * (1 + math.sin(demoT * (0.6 + i * 0.25) + i)) / 2);
	end
	-- the encounter bars: the three sample bosses lose and regain health
	for i = 1, table.getn(SS.BOSS_SAMPLE) do
		SS.BOSS_SAMPLE[i][2] = 25 + math.floor(70 * (1 + math.sin(demoT * (0.35 + i * 0.12) + i)) / 2);
	end
	SS.Safe(SS.UpdateBossFrames);
	-- the party keeps the column or row you chose
	SS.Safe(SU.PreviewTarget);
	SS.Safe(SU.PreviewParty);
	-- damage meter: the sample numbers climb
	if ( SlimSuiteMeter and SlimSuiteMeter.demoSnapshot ) then SlimSuiteMeter.demoSnapshot = SS.DemoMeterSnapshot(demoT); end
	-- minimap pins circle the map inside its edge
	local mm = Minimap and Minimap.GetWidth and (Minimap:GetWidth() or 140) / 2 - 10 or 60;
	for i = 1, table.getn(demoPins) do
		local a = demoT * (0.5 + i * 0.2) + i * 1.6;
		demoPins[i]:ClearAllPoints();
		demoPins[i]:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * mm * (0.4 + 0.15 * i), math.sin(a) * mm * (0.4 + 0.15 * i));
	end
	-- XP bar: a glint sweeps across it
	if ( demoGlint and MainMenuExpBar ) then
		local w = MainMenuExpBar:GetWidth() or 100;
		demoGlint:ClearAllPoints();
		demoGlint:SetPoint("LEFT", MainMenuExpBar, "LEFT", math.mod(demoT * 70, math.max(1, w)), 0);
	end
	-- buffs: each sample comes and goes on its own rhythm, on the real buff frame
	local changed = false;
	for i = 1, table.getn(SS.BUFF_SAMPLES) do
		local on = math.mod(math.floor(demoT / (1.5 + i * 0.4)) + i, 2) == 0;
		if ( (SS.demoBuffOn[i] and true or false) ~= on ) then SS.demoBuffOn[i] = on; changed = true; end
	end
	if ( changed ) then SS.buffDirty = true; end
	-- combat text: a hit or heal arrives every 0.9 seconds
	if ( demoHitClock >= 0.9 and SlimSuiteWorld and SlimSuiteWorld.DemoHit ) then
		demoHitClock = 0;
		local h = DEMO_HITS[demoHitIndex];
		SS.Safe(SlimSuiteWorld.DemoHit, h[1], h[2], "Interface\\Icons\\" .. h[3], h[4], h[5]);
		demoHitIndex = math.mod(demoHitIndex, table.getn(DEMO_HITS)) + 1;
	end
end

-- sample meter rows: the party's names and WoW spells, with damage that grows over time
DEMO_METER = {
	{ "Slimjim", "Shadow Bolt", "Spell_Shadow_ShadowBolt", 3900, 1.7, nil, "shadow" },
	{ "Voidwalker", "Melee", "Ability_MeleeDamage", 2600, 1, "pet" },
	{ "Voidwalker", "Torment", "Spell_Shadow_GatherShadows", 1200, 0.5, "pet" },
	{ "Slimjim", "Firebolt", "Spell_Fire_FireBolt", 1500, 0.8, nil, "fire", true },
	{ "Imp", "Firebolt", "Spell_Fire_FireBolt", 1400, 0.9, "pet" },
};
function SS.DemoMeterSnapshot(t)
	local snap = { actors = {}, sources = {}, rows = {}, totals = { displayRate = { status = "ready", value = math.floor(1400 + 120 * math.sin(t)) } } };
	for i = 1, table.getn(DEMO_METER) do
		local d = DEMO_METER[i];
		local amount = math.floor(d[4] + t * 210 * d[5]);
		snap.actors["a" .. i] = { name = d[1], kind = d[6] or "hero" };
		snap.sources["s" .. i] = { name = d[2], school = d[7], proc = d[8], icon = { status = "ready", path = "Interface\\Icons\\" .. d[3] } };
		snap.rows[i] = { rowId = "r" .. i, sourceKey = "s" .. i, ownerId = "a" .. i, displayAmount = amount,
			displayRate = { status = "ready", value = math.floor(d[5] * 210) } };
	end
	return snap;
end

-- every element that shows samples is told to draw again (starting or stopping)
function DemoRedraw()
	SS.Safe(SS.UpdateBossFrames); SS.Safe(SS.UpdateTally); SS.Safe(SS.UpdateClock); SS.Safe(SS.UpdateAnnouncementFrame);
	SS.Safe(SS.UpdateLevelButton); SS.Safe(SS.RefreshItemRow); SS.Safe(SS.RefreshSpellRow);
	SS.buffDirty = true;
end

function SS.StartDemoMode()
	if ( SS.demoRunning ) then return; end
	SS.demoRunning = true;
	demoT = 0; demoHitClock = 0;
	SS.demoBuffOn = {};
	if ( SlimSuiteMeter ) then SlimSuiteMeter.demoSnapshot = SS.DemoMeterSnapshot(0); end
	if ( Minimap and Minimap.CreateTexture and table.getn(demoPins) == 0 ) then
		for i = 1, 4 do
			local p = Minimap:CreateTexture(nil, "OVERLAY");
			p:SetWidth(6); p:SetHeight(6); p:SetTexture(i == 1 and 1 or 0.9, i == 2 and 0.8 or 0.4, 0.2, 1);
			demoPins[i] = p;
		end
	end
	for i = 1, table.getn(demoPins) do demoPins[i]:Show(); end
	if ( MainMenuExpBar and MainMenuExpBar.CreateTexture ) then
		if ( not demoGlint ) then demoGlint = MainMenuExpBar:CreateTexture(nil, "OVERLAY"); demoGlint:SetWidth(16); demoGlint:SetTexture(1, 1, 1, 0.35); end
		demoGlint:SetHeight(MainMenuExpBar:GetHeight() or 12); demoGlint:Show();
	end
	SS.Safe(SU.UpdateDemo);
	DemoRedraw();
	SS.Every("demoMode", 0.25, function() SS.Safe(DemoTick, 0.25); end);
	SS.Safe(SS.ShowDemoBox, true);
end

function SS.StopDemoMode()
	if ( not SS.demoRunning ) then return; end
	SS.demoRunning = false;
	SS.Stop("demoMode");
	if ( SlimSuiteMeter ) then SlimSuiteMeter.demoSnapshot = nil; end
	for i = 1, table.getn(demoPins) do demoPins[i]:Hide(); end
	if ( demoGlint ) then demoGlint:Hide(); end
	SS.demoPartyOrient = nil;
	SS.demoBuffOn = {};
	-- the sample row may have stepped the party aside for your plate (not saved): back to its own place
	if ( SS.DB().partyIncludesSelf ) then SS.Safe(SS.Place, "PartyMemberFrame1"); end
	SS.Safe(ApplyMovableOrientation, "PartyMemberFrame1");   -- the party's own layout again
	SS.Safe(SS.EndPreviewsIfDone);                           -- the sample party and target go
	SS.Safe(SS.ApplyNewFrames);
	DemoRedraw();
	SS.Safe(SS.ShowDemoBox, false);
end

-- While Demo Mode runs, Slim Suite's menus are put away so the samples can be seen, and a small "DEMO MODE" box
-- stands in for them: "On" is lit while it runs, "Off" stops it and brings back the menus that were open.
SS.DEMO_HIDES = { "SlimSuiteFrame", "SlimSuiteLayoutFrame", "SlimSuiteSetupPanel", "SlimSuiteSetupGlow",
	"SlimSuiteMovePanel", "SlimSuiteChoiceMenu", "SlimSuiteRaidIconPanel" };
demoHidden = {};
function DemoBox()
	local box = getglobal("SlimSuiteDemoBox");
	if ( box ) then return box; end
	box = CreateFrame("Frame", "SlimSuiteDemoBox", UIParent);
	box:SetWidth(132); box:SetHeight(52); box:SetFrameStrata("DIALOG");
	box:SetPoint("TOP", UIParent, "TOP", 0, -90);
	box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	box:SetBackdropColor(0.05, 0.04, 0.02, 0.92); box:SetBackdropBorderColor(0.83, 0.66, 0.26, 1);
	box:EnableMouse(true); box:SetMovable(true); box:RegisterForDrag("LeftButton");
	box:SetScript("OnDragStart", function() this:StartMoving(); end);
	box:SetScript("OnDragStop", function() this:StopMovingOrSizing(); end);
	box.title = box:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	box.title:SetPoint("TOP", box, "TOP", 0, -7); box.title:SetText("DEMO MODE");
	box.on = K.Button(box, "On", 54, function() SS.StartDemoMode(); end);
	box.on:SetHeight(18); box.on:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 8, 7);
	box.off = K.Button(box, "Off", 54, function() SS.StopDemoMode(); end);
	box.off:SetHeight(18); box.off:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 7);
	return box;
end
function SS.ShowDemoBox(on)
	if ( on ) then
		demoHidden = {};
		for _, name in ipairs(SS.DEMO_HIDES) do
			local f = getglobal(name);
			if ( f and f:IsShown() ) then demoHidden[name] = true; f:Hide(); end
		end
		-- the element list has its own On/Off beside the grid: it stays, and the small box is only for elsewhere
		local list = getglobal("SlimSuiteSetupBar");
		if ( not (list and list:IsShown()) ) then local box = DemoBox(); box:Show(); box.on:LockHighlight(); box.off:UnlockHighlight(); end
	else
		local box = getglobal("SlimSuiteDemoBox");
		if ( box ) then box:Hide(); end
		if ( SU and SU.RefreshDemoButtons ) then SU.RefreshDemoButtons(); end
		for name in pairs(demoHidden) do local f = getglobal(name); if ( f ) then f:Show(); end end
		demoHidden = {};
	end
end

function SS.ToggleDemoMode()
	if ( SS.demoRunning ) then SS.StopDemoMode(); else SS.StartDemoMode(); end
end

-- Raid target icons: hover a party member or yourself and a row of markers opens above that frame.
-- Click a marker to put it on that unit; the X clears it. The row stays open while the cursor is on it.
raidPanel, raidOver = nil, nil;

function RaidCursor()
	local s = UIParent:GetEffectiveScale() or 1;
	local x, y = GetCursorPosition();
	return (x or 0) / s, (y or 0) / s;
end

function RaidWithin(f, x, y)
	if ( not f or not f.IsShown or not f:IsShown() or (f.GetAlpha and (f:GetAlpha() or 1) < 0.05) ) then return false; end
	local l, r, b, t = RootBounds(f);                       -- in the screen's units, whatever the frame's scale
	return l ~= nil and x >= l and x <= r and y >= b and y <= t;
end

-- the frames that stand for a unit a marker can go on: the four party members and yourself
function RaidTargets()
	local list = {};
	for i = 1, 4 do
		local f = getglobal("PartyMemberFrame" .. i);
		if ( f and UnitExists("party" .. i) ) then table.insert(list, { f = f, unit = "party" .. i }); end
	end
	local lines = getglobal("SlimSuitePartyLines");
	if ( lines and lines.lines ) then
		for i = 1, table.getn(lines.lines) do
			local l = lines.lines[i];
			if ( l.unit and UnitExists(l.unit) ) then table.insert(list, { f = l, unit = l.unit }); end
		end
	end
	if ( UnitExists("player") ) then
		for _, name in ipairs({ "PlayerFrame", "SlimSuitePlayerCard", "SlimSuitePartySelfFrame" }) do
			local f = getglobal(name);
			if ( f ) then table.insert(list, { f = f, unit = "player" }); end
		end
	end
	return list;
end

-- The raid mark on each unit frame, so a mark placed from the row (or by anyone in the party) shows on the frames too,
-- not only over the heads in the world: a small icon just above a frame's top-left corner, and just right of a thin
-- line or of your own plate in the party (your buffs line up above your plate). The game's target frame keeps its own icon where it has one.
function SS.IsPartyLine(f)
	local c = getglobal("SlimSuitePartyLines");
	return c and f and f.GetParent and f:GetParent() == c and true or false;
end
function SS.RaidMarkSize(f)
	local h = (f and f.GetHeight and f:GetHeight()) or 0;
	if ( SS.IsPartyLine(f) ) then return math.max(8, h + 2); end
	return math.max(12, math.min(20, h * 0.32));
end
SS.raidMarked = {};
function SS.UpdateRaidMarks()
	local list = RaidTargets();
	local count = table.getn(list);
	local card, classic;
	if ( UnitExists("target") ) then
		card = getglobal("SlimSuiteTargetCard");
		if ( TargetFrame and not getglobal("TargetRaidTargetIcon") ) then classic = TargetFrame; end
	end
	local now = {};
	for i = 1, count + 2 do
		local f, unit;
		if ( i <= count ) then f, unit = list[i].f, list[i].unit;
		elseif ( i == count + 1 ) then f, unit = card, "target";
		else f, unit = classic, "target"; end
		local index = GetRaidTargetIndex and GetRaidTargetIndex(unit);
		if ( f and f.CreateTexture and type(index) == "number" and index >= 1 and index <= 8 ) then
			local t = f.slimRaidMark;
			if ( not t ) then t = f:CreateTexture(nil, "OVERLAY"); f.slimRaidMark = t; end
			local size = SS.RaidMarkSize(f);
			t:SetWidth(size); t:SetHeight(size);
			t:ClearAllPoints();
			if ( SS.IsPartyLine(f) or f == getglobal("SlimSuitePartySelfFrame") ) then t:SetPoint("LEFT", f, "RIGHT", 2, 0);
			else t:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 2, 1); end
			local col, row = math.mod(index - 1, 4), math.floor((index - 1) / 4);
			t:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons");
			t:SetTexCoord(col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25);
			t:Show();
			now[f] = true;
		end
	end
	for f in pairs(SS.raidMarked) do if ( not now[f] and f.slimRaidMark ) then f.slimRaidMark:Hide(); end end
	SS.raidMarked = now;
end
SS.Every("raidMarks", 1, function() SS.Safe(SS.UpdateRaidMarks); end);

-- Unit frames follow the game's events: a change in health, power, level, name, target, party or marks redraws the
-- cards, the party's lines and your plate, and the marks, right away (once per frame however many events come). The
-- timed redraws above stay as a slow safety net, for anything this game changes without an event.
local unitEvents = CreateFrame("Frame");
for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_MANA", "UNIT_MAXMANA", "UNIT_RAGE", "UNIT_MAXRAGE", "UNIT_ENERGY",
	"UNIT_MAXENERGY", "UNIT_AURA", "UNIT_LEVEL", "UNIT_NAME_UPDATE", "UNIT_PORTRAIT_UPDATE", "UNIT_DISPLAYPOWER", "PLAYER_TARGET_CHANGED",
	"PARTY_MEMBERS_CHANGED", "PARTY_LEADER_CHANGED", "RAID_TARGET_UPDATE" }) do unitEvents:RegisterEvent(e); end
local unitsDirty, marksDirty = false, false;
unitEvents:SetScript("OnEvent", function()
	if ( event == "RAID_TARGET_UPDATE" ) then marksDirty = true; return; end
	unitsDirty = true;
	if ( event == "PARTY_MEMBERS_CHANGED" or event == "PLAYER_TARGET_CHANGED" ) then marksDirty = true; end
end);
SS.Every("unitEvents", 0, function()
	if ( unitsDirty ) then
		unitsDirty = false;
		for i = 1, table.getn(SS.cardFrames or {}) do SS.Safe(SS.RefreshCard, SS.cardFrames[i]); end
		SS.Safe(SS.UpdatePartyLines); SS.Safe(SS.UpdatePartySelf); SS.Safe(SS.UpdateFriendBuffs);
	end
	if ( marksDirty ) then marksDirty = false; SS.Safe(SS.UpdateRaidMarks); end
end);

function BuildRaidPanel()
	local p = CreateFrame("Frame", "SlimSuiteRaidIconPanel", UIParent);
	p:SetWidth(9 * 22 + 6); p:SetHeight(28); p:SetFrameStrata("DIALOG");
	p:SetBackdrop(SU.CARD_BACKDROP);
	p:SetBackdropColor(0.05, 0.05, 0.05, 0.95);
	p:SetBackdropBorderColor(0.85, 0.65, 0.2, 1);
	for i = 1, 9 do
		local b = CreateFrame("Button", nil, p);
		b:SetWidth(20); b:SetHeight(20);
		b:SetPoint("LEFT", p, "LEFT", 4 + (i - 1) * 22, 0);
		if ( i <= 8 ) then
			b.index = i;
			local tex = b:CreateTexture(nil, "ARTWORK"); tex:SetAllPoints(b);
			tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i);
		else
			b.index = 0;
			b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal");
			b.text:SetPoint("CENTER", b, "CENTER", 0, 0); b.text:SetText("X");
		end
		b:SetScript("OnClick", function()
			if ( raidOver and raidOver.unit and SetRaidTarget ) then SS.Safe(SetRaidTarget, raidOver.unit, this.index); end
		end);
	end
	p:Hide();
	return p;
end

raidPanel = BuildRaidPanel();                            -- made at load, so "above the level-up cards" can include it
SS.Every("raidIcons", 0.1, function()
	if ( not raidPanel ) then raidPanel = BuildRaidPanel(); end
	-- not while the UI is being placed (it would sit over the handles) or in Demo Mode
	-- nor when it is turned off, or alone (marks are a group's)
	local grouped = (GetNumPartyMembers and (GetNumPartyMembers() or 0) > 0) or (GetNumRaidMembers and (GetNumRaidMembers() or 0) > 0);
	if ( SS.DB().unlocked or setupActive or SS.demoRunning or not SS.DB().raidRow or not grouped ) then
		if ( raidPanel:IsShown() ) then raidPanel:Hide(); raidOver = nil; end
		return;
	end
	local x, y = RaidCursor();
	local over = nil;
	if ( raidPanel:IsShown() and RaidWithin(raidPanel, x, y) ) then over = raidOver; end
	if ( not over ) then
		local list = RaidTargets();
		for i = 1, table.getn(list) do
			if ( RaidWithin(list[i].f, x, y) ) then over = list[i]; break; end
		end
	end
	if ( over ) then
		raidOver = over;
		raidPanel:ClearAllPoints();
		raidPanel:SetPoint("BOTTOM", over.f, "TOP", 0, 2);
		raidPanel:Show();
	elseif ( raidPanel:IsShown() ) then
		raidPanel:Hide(); raidOver = nil;
	end
end);
