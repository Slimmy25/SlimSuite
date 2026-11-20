-- Slim Suite: starting up, the slash commands, Demo Mode and raid marks.
if ( setfenv ) then setfenv(1, SS.ENV); end   -- Slim Suite's files share one set of private names (SS.ENV, in SlimSuiteCore.lua)

loader = CreateFrame("Frame");
loader:RegisterEvent("VARIABLES_LOADED");
loader:RegisterEvent("PLAYER_ENTERING_WORLD");
local firstRunSetupPending = false;
-- The game's Interface settings (Show Run Clock, Show Boss Bars ...) can be turned off by the player. A part that is
-- off when the game loads, and that Slim Suite did not turn off itself, was turned off by the player: Slim Suite's own
-- movable version is switched on in its place, once (turning Slim Suite's version off afterwards is respected).
SS.NATIVE_REPLACEMENTS = {};
for name, element in pairs(SS.ELEMENTS) do
 if ( element.part and element.feature ) then
  local frame, title = name, element.title;
  SS.NATIVE_REPLACEMENTS[element.part] = { element.feature, title, function() SU.SetOn(frame, true, title); end };
 end
end
function SS.NativeIsOff(part)
	if ( type(AZS_IsHudShown) ~= "function" ) then return nil; end
	local ok, v = SS.Safe(AZS_IsHudShown, part);
	if ( not ok or v == nil ) then return nil; end
	return not SS.HudShown(v);
end
function SS.AdoptHiddenNatives()
	local d = SS.DB();
	if ( SS.firstRunSetupPending and not d.setupDone ) then return; end
	d.nativeAdopted = type(d.nativeAdopted) == "table" and d.nativeAdopted or {};
	local turned = {};
	for part, r in pairs(SS.NATIVE_REPLACEMENTS) do
		local key = SS.NATIVE_KEYS[part];
		local ours = key and d[key] ~= nil;                      -- Slim Suite hid it (and has not put it back yet)
		local explicit;
		for frame, nativePart in pairs(SU.NATIVE_PARTS) do
			if ( nativePart == part and d.elementModes[frame] ~= nil ) then explicit = true; break; end
		end
		if ( not explicit and not ours and not d.nativeAdopted[part] and SS.NativeIsOff(part) and not d[r[1]] ) then
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
		if ( not SS.firstRunSetupPending ) then SS.MigrateElementModes(); end
	end
	if ( entering ) then SS.Safe(SS.LayoutLogin); end        -- this character's own layout, if they are kept apart
	SS.Safe(SS.Camera, entering);
	SS.Safe(SS.ApplyGuardianFlag);
	-- the frames back where they were put (the game places some of them again as it loads), and the target frame
	if ( SS.DB().unlocked or type(SS.DB().places.MainMenuExpBar) == "table"
		or type(SS.DB().sizes.MainMenuExpBar) == "table" or type(SS.DB().scales.MainMenuExpBar) == "number"
		or SS.DB().orientations.MainMenuExpBar ~= nil ) then SS.Safe(SS.DetachExperienceBar); end
	if ( SS.DB().elementModes.ChatFrame1 == "default" ) then
		SS.Safe(SS.RestoreChatLayout, false);
	elseif ( SS.ChatIsCustom and SS.ChatIsCustom() ) then SS.Safe(SS.PrepareChatWindow); end
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
	SS.Safe(SS.UpdateEnemyNameplates);
	if ( entering ) then SS.Safe(SS.SetUnlocked, false, true); SS.Safe(SS.ApplyMinimapShape); SS.Safe(SS.LayoutGather); SS.Safe(SS.LayoutMinimapBar); SS.Safe(SS.LayoutXpSegments); SS.Safe(SS.MakeCards); SS.Safe(SS.ApplyNewFrames); SS.Safe(SS.GuardTargetTooltips); SS.Safe(ApplyMovableOrientation, "PartyMemberFrame1"); end
	SS.Safe(SS.ApplyElementModes);
	SS.Safe(SS.RefreshChatDock);
 if SS.EnforcePausedModules then SS.EnforcePausedModules(false); end
end
loader:RegisterEvent("PLAYER_LOGOUT");
loader:SetScript("OnEvent", function()
	if ( event == "PLAYER_LOGOUT" ) then SS.Safe(SS.LayoutLogout); return; end
	if ( event == "VARIABLES_LOADED" ) then
		local d = SS.DB();
		local unfinished = not d.setupDone and (tonumber(d.firstSetupDefaultsVersion) or 0) >= 1;
		firstRunSetupPending = not d.setupDone and (unfinished or not SS.HasPriorUISetup(d));
		SS.firstRunSetupPending = firstRunSetupPending;
	end
	SS.Startup(event == "PLAYER_ENTERING_WORLD", event == "VARIABLES_LOADED");
	if ( event == "PLAYER_ENTERING_WORLD" and firstRunSetupPending and not SU.autoStartedFirstRun ) then
		SU.autoStartedFirstRun = true;
		SS.StartSetup(true); SS.SetupEnd(true); SS.Toggle();
	end
end);

-- ---------------------------------------------------------------- layouts
-- A layout is everything about where the UI sits and how it looks: places, sizes, scales, padding, layouts, hidden
-- elements and the frame looks. Layouts are saved by name (/slim layout save <name>), loaded again, shared as one line
-- of text (the Layouts window), and can be kept apart for each character.
SS.LAYOUT_TABLES = { "places", "sizes", "scales", "padding", "orientations", "muted", "chatOffsets", "enabledElements", "elementModes", "frameDefault", "minimap", "statHidden" };
SS.LAYOUT_KEYS = { "playerLook", "targetLook", "partyLook", "partyIncludesSelf", "combineTarget", "mirrorTarget",
	"hideTarget", "buffsOnTarget", "buffsOnTargetSide", "buffsOnPlayer", "buffsOnPlayerSide", "partyLocked", "partyLockAbove",
	"partyFaces", "cardPortraits", "tallyVertical", "tallyContext", "buffCustomLayout", "buffGrowthDirection", "buildRowsAttached", "matchBuildSizes", "hideBuildSpells", "hideBuildItems", "xpHideBorder", "statCounter", "statDisplayMode", "clockContextAbove", "worldCombatMode", "keepCombatLog", "cardEdgeHUD", "compassOn", "luckPanel", "achievementButton", "compassStyle", "compassBosses", "compassLairs", "compassCaches", "minimapSquare", "minimapTransparent",
	"tooltipCustom", "plainBar", "showRacialAbility", "xpSegments", "showAbsorbs",
	"enemyNameplates", "modernEnemyFrames", "enemyBossesOnly", "enemyPlateDebuffs",
	"encounterBarThickness", "encounterNameAlign", "accessibilityContrast", "accessibilityLargeText", "accessibilityReduceMotion",
	"targetAuraSide", "targetDebuffs", "clockDetached", "showEmptyActionSlots", "cooldowns",
	"partyMemberBuffs", "localClock24", "localClockBackground", "showGuardianFlag",
	"tallyBossKills", "tallyBackground", "zoneLine", "encounterDebuffs", "procMeter",
	"minimapCaches", "minimapBosses", "minimapLairs", "combatTextBox", "ctHeals", "ctCrits", "ctIcons", "ctLong", "ctPop",
	"replaceClock", "replaceEncounters", "replaceTally", "replaceBanners", "replaceBuildRows", "replaceRevive", "replaceLocalClock", "moveLevelButton", "moveMeter" };
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
	if SS.ModuleLayoutPreferences then SS.ModuleLayoutPreferences(out); end
 return out;
end
-- puts a layout in place of the current one and draws everything again from it
function SS.LayoutApply(layout, quiet)
	if ( type(layout) ~= "table" ) then return false; end
	SS.activeCustomProfile = nil;
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
	SS.PrepareDB(d);                                       -- anything the layout did not carry gets its default
 if SS.EnforcePausedModules then SS.EnforcePausedModules(true); end
	-- Older profile strings omitted this derived native-layout state.
	for frame, mode in pairs(d.elementModes) do
		if ( SU and SU.NATIVE[frame] ) then d.frameDefault[frame] = mode == "default" and true or nil; end
	end
	for frame, native in pairs(d.frameDefault) do
		if ( native and SU and SU.NATIVE[frame] ) then SS.Safe(SU.SetMovable, frame, false); end
	end
	if ( not quiet ) then
		-- elements with no place in this layout go back to where they started
		for i = 1, table.getn(MOVABLE) do
			local name = MOVABLE[i][1];
			local frame, points, base = getglobal(name), basePoints[name], baseSizes[name];
			if ( frame and name ~= "GameTooltip" and not d.frameDefault[name] ) then
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
		if ( SS.Mini ) then SS.Safe(SS.Mini.Place); end
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
	-- A stable order makes exports comparable and avoids false changes in automatic profile saves.
	table.remove(parts, 1); table.sort(parts); table.insert(parts, 1, "SSL1");
	return table.concat(parts, ";");
end
local layoutStrings = { worldCombatMode=true, compassStyle=true, statDisplayMode=true, playerLook=true, targetLook=true, partyLook=true, buffsOnTargetSide=true,
	buffsOnPlayerSide=true, buffGrowthDirection=true, encounterBarThickness=true,
	encounterNameAlign=true, targetAuraSide=true };
local function ValidLayoutLeaf(root, keys, value)
	local depth = table.getn(keys);
	if ( depth == 1 ) then return type(value) == (layoutStrings[root] and "string" or "boolean"); end
	if ( root == "elementModes" ) then return depth == 2 and (value == "enabled" or value == "disabled" or value == "default"); end
	if ( root == "orientations" ) then return depth == 2 and (value == "horizontal" or value == "vertical"); end
	if ( root == "muted" or root == "enabledElements" or root == "frameDefault" or root == "statHidden" ) then return depth == 2 and type(value) == "boolean"; end
	if ( root == "scales" or root == "padding" ) then return depth == 2 and type(value) == "number" and (root == "scales" and value > 0 and value <= 10 or root == "padding" and value >= 0 and value <= 1000); end
	if ( root == "sizes" ) then return depth == 3 and (keys[3] == "w" or keys[3] == "h") and type(value) == "number" and value > 0 and value <= 100000; end
	if ( root == "minimap" ) then
		if ( depth ~= 2 ) then return false; end
		if ( keys[2] == "hide" or keys[2] == "detached" ) then return type(value) == "boolean"; end
		return (keys[2] == "angle" or keys[2] == "x" or keys[2] == "y") and type(value) == "number" and math.abs(value) <= 10000000;
	end
	if ( root == "places" or root == "chatOffsets" ) then
		local field = keys[3];
		if ( depth == 4 and field == "screen" ) then
			local key = keys[4];
			return type(value) == "number" and ((key == "width" or key == "height") and value > 0 or key == "left" or key == "bottom");
		end
		if ( depth ~= 3 ) then return false; end
		if ( field == "displayDefault" ) then return type(value) == "boolean"; end
		if ( field == "coordinateSpace" ) then return value == "uiParent"; end
		if ( field == "relative" ) then return type(value) == "string" and value ~= keys[2]; end
		if ( field == "point" or field == "relativePoint" ) then
			return type(value) == "string" and (value == "CENTER" or value == "TOP" or value == "BOTTOM" or value == "LEFT" or value == "RIGHT" or value == "TOPLEFT" or value == "TOPRIGHT" or value == "BOTTOMLEFT" or value == "BOTTOMRIGHT");
		end
		return (field == "x" or field == "y" or field == "dx" or field == "dy") and type(value) == "number" and math.abs(value) <= 10000000;
	end
	return false;
end
-- Read only the profile schema, rejecting wrong types before they can reach native frame APIs.
function SS.LayoutFromText(text)
	if ( type(text) ~= "string" or string.len(text) > 500000 ) then return nil; end
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
		if ( (kind == "n" and (not value or value-value ~= 0)) or (kind == "b" and raw ~= "0" and raw ~= "1") ) then return nil; end
		local keys = {};
		for key in string.gfind(path, "[^%.]+") do table.insert(keys, key); end
		local root = keys[1];
		if ( allowed[root] and not ValidLayoutLeaf(root, keys, value) ) then return nil; end
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
	for _, size in pairs(out.sizes) do if ( not size.w or not size.h ) then return nil; end end
	-- Native SetPoint rejects indirect self-anchors too.
	for name in pairs(out.places) do
		local seen, current = {}, name;
		while ( current and out.places[current] ) do
			if ( seen[current] ) then return nil; end
			seen[current] = true; current = out.places[current].relative;
		end
	end
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
-- Creator-authored profiles live in code and are read-only. Applying one always makes a saved
-- user copy first, so later layout edits can never write back into the shipped preset.
SS.DEFAULT_PROFILES = SS.DEFAULT_PROFILES or {};
function SS.IsDefaultProfile(name)
	return type(name) == "string" and type(SS.DEFAULT_PROFILES[name]) == "table";
end
function SS.NextCustomProfileName()
	local highest = 0;
	for name in pairs(SS.DB().layouts or {}) do
		local _, _, number = string.find(tostring(name), "^My Custom Profile #(%d+)$");
		if ( number and tonumber(number) > highest ) then highest = tonumber(number); end
	end
	return "My Custom Profile #" .. (highest + 1);
end
function SS.ApplyDefaultProfile(name)
	local preset = SS.DEFAULT_PROFILES[name];
	if ( type(preset) ~= "table" ) then return false; end
	local custom = SS.NextCustomProfileName();
	SS.DB().layouts[custom] = SS.CopyTable(preset);
	SS.LayoutApply(SS.DB().layouts[custom]);
	SS.activeCustomProfile = custom;
	SS.profileDirty = nil;
	local f = getglobal("SlimSuiteLayoutFrame");
	if ( f ) then f.selectedProfile = custom; if ( f.RefreshProfiles ) then f.RefreshProfiles(); end end
	K.Print(NAME, "read-only preset copied to \"" .. custom .. "\". Your changes are saved to that copy.");
	return true, custom;
end
function SS.MarkProfileDirty()
 if ( SS.activeCustomProfile ) then SS.profileDirty = true; end
end
function SS.TrackActiveCustomProfile()
 local name = SS.activeCustomProfile;
 if ( not name or type(SS.DB().layouts[name]) ~= "table" ) then SS.profileDirty = nil; return; end
 SS.DB().layouts[name] = SS.LayoutSnapshot();
 SS.profileDirty = nil;
end
SS.Every("trackCustomProfile", 0.25, function()
 if ( SS.profileDirty ) then SS.Safe(SS.TrackActiveCustomProfile); end
end);
function SS.LayoutBundleText()
	local names=SS.LayoutNames();
	if ( table.getn(names)==0 ) then return nil; end
	local parts={"SSP1"};
	for i=1,table.getn(names) do
		local name=names[i];
		if ( not string.find(name,"\n",1,true) and type(SS.DB().layouts[name])=="table" ) then
			table.insert(parts,name); table.insert(parts,SS.LayoutText(SS.DB().layouts[name]));
		end
	end
	return table.concat(parts,"\n");
end
function SS.LayoutBundleFromText(text)
	text=tostring(text or "");
	text=string.gsub(text,"\r\n","\n"); text=string.gsub(text,"\r","\n");
	if ( string.len(text)>500000 or string.sub(text,1,5)~="SSP1\n" ) then return nil; end
	local imported,cursor={},6;
	while ( cursor<=string.len(text) ) do
		local nameEnd=string.find(text,"\n",cursor,true);
		if ( not nameEnd ) then return nil; end
		local name=string.sub(text,cursor,nameEnd-1);
		local dataStart=nameEnd+1;
		local dataEnd=string.find(text,"\n",dataStart,true) or (string.len(text)+1);
		local serialized=string.sub(text,dataStart,dataEnd-1);
		local layout=SS.LayoutFromText(serialized);
		if ( name=="" or string.sub(name,1,5)=="char:" or not layout ) then return nil; end
		imported[name]=layout;
		cursor=dataEnd+1;
	end
	if ( next(imported)==nil ) then return nil; end
	return imported;
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
	SS.Safe(SS.TrackActiveCustomProfile); -- Flush edits made since the last one-second autosave tick.
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
		f = K.Window("SlimSuiteLayoutFrame", "Profiles & import/export", 650, 430);
		local note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		note:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -36); note:SetWidth(600); note:SetJustifyH("LEFT");
		note:SetText(SS.T("Save named HUD profiles, apply one later, or copy a layout string to share it. Per-character layouts can be enabled in Settings."));
		local profileTitle=f:CreateFontString(nil,"OVERLAY","GameFontNormal");
		profileTitle:SetPoint("TOPLEFT",f,"TOPLEFT",24,-68); profileTitle:SetText(SS.T("Saved profiles"));
		f.profileName=CreateFrame("EditBox","SlimSuiteProfileName",f);
		f.profileName:SetPoint("TOPLEFT",f,"TOPLEFT",24,-90); f.profileName:SetWidth(165); f.profileName:SetHeight(22);
		f.profileName:SetAutoFocus(false); f.profileName:SetFontObject(GameFontHighlightSmall); f.profileName:SetMaxLetters(32);
		f.profileName:SetTextInsets(5,5,2,2); f.profileName:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}});
		f.profileName:SetBackdropColor(0.03,0.03,0.05,1);
		f.profileName:SetScript("OnEscapePressed",function() this:ClearFocus(); end);
		local scroll = CreateFrame("ScrollFrame", "SlimSuiteLayoutScroll", f, "UIPanelScrollFrameTemplate");
		scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 212, -68);
		scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -40, 65);
		local box = CreateFrame("EditBox", "SlimSuiteLayoutBox", scroll);
		box:SetMultiLine(true); box:SetAutoFocus(false); box:SetFontObject(GameFontHighlightSmall);
		box:SetWidth(390); box:SetHeight(700); box:SetMaxLetters(0);
		box:SetScript("OnEscapePressed", function() this:ClearFocus(); end);
		scroll:SetScrollChild(box);
		f.box = box;
		local profileScroll=CreateFrame("ScrollFrame","SlimSuiteProfileScroll",f,"UIPanelScrollFrameTemplate");
		profileScroll:SetPoint("TOPLEFT",f,"TOPLEFT",24,-164); profileScroll:SetPoint("BOTTOMRIGHT",f,"BOTTOMLEFT",194,62);
		local profileChild=CreateFrame("Frame",nil,profileScroll); profileChild:SetWidth(160); profileChild:SetHeight(20); profileScroll:SetScrollChild(profileChild);
		f.profileButtons={};
		f.RefreshProfiles=function()
			for i=1,table.getn(f.profileButtons) do f.profileButtons[i]:Hide(); end
			local names=SS.LayoutNames();
			for i=1,table.getn(names) do
				local name=names[i]; local b=f.profileButtons[i];
				if ( not b ) then b=K.Button(profileChild,"",158,function()
					f.selectedProfile=this.profileName;
					f.profileName:SetText(this.profileName);
					f.box:SetText(SS.LayoutText(SS.DB().layouts[this.profileName]));
				end); f.profileButtons[i]=b; end
				b.profileName=name; b:SetText(name); b:ClearAllPoints(); b:SetPoint("TOPLEFT",profileChild,"TOPLEFT",0,-((i-1)*23)); b:Show();
			end
			profileChild:SetHeight(math.max(20,table.getn(names)*23));
			if ( profileScroll.UpdateScrollChildRect ) then profileScroll:UpdateScrollChildRect(); end
		end;
		local save=K.Button(f,"Save current as profile",158,function()
			local name=string.gsub(f.profileName:GetText() or "","^%s*(.-)%s*$","%1");
			if ( name=="" or string.sub(name,1,5)=="char:" ) then K.Print(NAME,"enter a profile name (char: names are reserved). "); return; end
			if ( SS.IsDefaultProfile(name) ) then K.Print(NAME,"that is a read-only default profile. Apply it to create a My Custom Profile copy first."); return; end
			SS.DB().layouts[name]=SS.LayoutSnapshot(); f.selectedProfile=name; f.box:SetText(SS.LayoutText(SS.DB().layouts[name])); f.RefreshProfiles();
			K.Print(NAME,"profile \""..name.."\" saved.");
		end);
		save:SetPoint("TOPLEFT",f,"TOPLEFT",26,-115);
		local exportAll=K.Button(f,"Export all profiles",158,function()
			local bundle=SS.LayoutBundleText();
			if ( not bundle ) then K.Print(NAME,"there are no named profiles to export yet."); return; end
			f.box:SetText(bundle); f.box:SetFocus(); if ( f.box.HighlightText ) then f.box:HighlightText(); end
		end);
		exportAll:SetPoint("TOPLEFT",f,"TOPLEFT",26,-139);
		local apply=K.Button(f,"Apply selected",112,function()
			local name=f.selectedProfile;
			if ( not name or type(SS.DB().layouts[name])~="table" ) then K.Print(NAME,"select a saved profile first."); return; end
			SS.LayoutApply(SS.DB().layouts[name]); K.Print(NAME,"profile \""..name.."\" applied.");
		end);
		apply:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",24,20);
		local del=K.Button(f,"Delete",72,function()
			local name=f.selectedProfile;
			if ( name and SS.DB().layouts[name] ) then SS.DB().layouts[name]=nil; f.selectedProfile=nil; f.RefreshProfiles(); f.box:SetText(""); K.Print(NAME,"profile deleted."); end
		end);
		del:SetPoint("LEFT",apply,"RIGHT",6,0);
		local export=K.Button(f,"Export current",105,function()
			f.box:SetText(SS.LayoutText(SS.LayoutSnapshot())); f.box:SetFocus(); if ( f.box.HighlightText ) then f.box:HighlightText(); end
		end);
		export:SetPoint("LEFT",del,"RIGHT",6,0);
		local exportSelected=K.Button(f,"Export selected",104,function()
			local name=f.selectedProfile;
			if ( not name or type(SS.DB().layouts[name])~="table" ) then K.Print(NAME,"select a saved profile first."); return; end
			f.box:SetText(SS.LayoutText(SS.DB().layouts[name])); f.box:SetFocus(); if ( f.box.HighlightText ) then f.box:HighlightText(); end
		end);
		exportSelected:SetPoint("LEFT",export,"RIGHT",6,0);
		local use=K.Button(f,"Import / apply",120,function()
			local bundle=SS.LayoutBundleFromText(f.box:GetText());
			if ( bundle ) then
				for name,layout in pairs(bundle) do
					if ( SS.IsDefaultProfile(name) ) then name = SS.NextCustomProfileName(); end
					SS.DB().layouts[name]=layout;
				end
				f.RefreshProfiles(); K.Print(NAME,"the imported profile bundle is saved. Select a profile to apply it."); return;
			end
			local layout=SS.LayoutFromText(f.box:GetText());
			if ( not layout ) then K.Print(NAME,"that text is not a Slim Suite layout."); return; end
			SS.LayoutApply(layout);
			local name=string.gsub(f.profileName:GetText() or "","^%s*(.-)%s*$","%1");
			if ( name~="" and string.sub(name,1,5)~="char:" ) then
				if ( SS.IsDefaultProfile(name) ) then name=SS.NextCustomProfileName(); end
				SS.DB().layouts[name]=layout; f.selectedProfile=name; f.profileName:SetText(name); f.RefreshProfiles(); K.Print(NAME,"layout imported, applied and saved as profile \""..name.."\".");
			else K.Print(NAME,"the imported layout is now in use. Enter a profile name and import again to save it."); end
		end);
		use:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-24,20);
	end
	f.RefreshProfiles();
	if ( f.selectedProfile and SS.DB().layouts[f.selectedProfile] ) then f.box:SetText(SS.LayoutText(SS.DB().layouts[f.selectedProfile]));
	else f.box:SetText(SS.LayoutText(SS.LayoutSnapshot())); end
	f:Show();
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

-- Compatibility cleanup for retired minimap-button collectors. No buttons are collected,
-- sorted or reparented by Slim Suite; older callers only release previously owned buttons.
SlimSuiteMinimapBarList = {};
function SS.GatherRelease(f)
 if ( not f or not f.slimOrig ) then return; end
 local o=f.slimOrig; f.slimOrig=nil; f:ClearAllPoints();
 if ( o[2] ) then f:SetPoint(o[1],o[2],o[3],o[4],o[5]); end
end
function SS.ReleaseFromBar(f)
 if ( not f or not f.slimBarOrig ) then return; end
 local o=f.slimBarOrig; f.slimBarOrig=nil;
 if ( f.slimBarParent and f.SetParent ) then f:SetParent(f.slimBarParent); end
 if ( f.slimBarStrata and f.SetFrameStrata ) then f:SetFrameStrata(f.slimBarStrata); end
 f.slimBarParent,f.slimBarStrata=nil,nil;
 f:ClearAllPoints(); if ( o[2] ) then f:SetPoint(o[1],o[2],o[3],o[4],o[5]); end
end
function SS.LayoutGather()
 local d=SS.DB(); d.gatherButtons=false; d.gatherSide=nil;
 for _,f in ipairs(SlimSuiteGatheredList or {}) do SS.GatherRelease(f); end
 SlimSuiteGatheredList={};
end
function SS.LayoutMinimapBar()
 local d=SS.DB(); d.minimapBar=false;
 for _,key in ipairs({"elementModes","enabledElements","places","sizes","scales","orientations","muted","frameDefault"}) do
  if ( type(d[key])=="table" ) then d[key].SlimSuiteMinimapBar=nil; end
 end
 for _,f in ipairs(SlimSuiteMinimapBarList) do SS.ReleaseFromBar(f); end
 SlimSuiteMinimapBarList={};
 local bar=getglobal("SlimSuiteMinimapBar"); if ( bar ) then bar:Hide(); end
 SS.LayoutGather();
 if ( SS.Mini and SS.Mini.Place ) then SS.Safe(SS.Mini.Place); end
end
function SS.MinimapButtonPlace() return "ring"; end
function SS.SetMinimapButtonPlace() SS.LayoutMinimapBar(); end
function SS.SetGather() SS.LayoutMinimapBar(); end
function SS.SetMinimapBar() SS.LayoutMinimapBar(); end

-- the minimap button: a gear, at the left of the minimap (AZS Stats' is at the bottom, AZS Handbook's at the top
-- left)
okMini, errMini = SS.Safe(function()
	SS.Mini = K.Minimap({ name = "SlimSuiteMinimapButton", icon = "INV_Misc_Gear_02", angle = 190, db = SS.DB,
		click = function() SS.Toggle(); end,
		tooltip = function(tt)
			tt:AddLine(NAME);
			tt:AddLine(SS.T("Addon version") .. " " .. SS.AddonVersion(), 0.95, 0.76, 0.3);
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
	local ms = SS.EffectiveScale(Minimap);
	for _, n in ipairs({ "MiniMapTrackingFrame", "MinimapZoomIn", "MiniMapMailFrame" }) do
		local f = getglobal(n);
		if ( f and not f.slimSquareOrig and not f.slimBarOrig and mx ) then
			local fx, fy = f:GetCenter();
			if ( fx ) then
				local fs = SS.EffectiveScale(f);
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
		return false;
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
			local k = (SS.EffectiveScale(Minimap)) / (SS.EffectiveScale(mini));
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
	-- Blizzard and other addons occasionally hide or reanchor minimap children while changing
	-- map state. Reapply Slim Suite's selected placement so its gear stays on the ring/square.
	SS.Every("minimapButtonGuard", 1, function()
		local d = SS.DB();
		if ( d.minimap and d.minimap.hide ) then mini:Hide(); return; end
		mini:SetAlpha(1);
		SS.Safe(mini.Place);
	end, Minimap);
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
local demoXPOriginal;

local function SetDemoXP(on)
	local xp = MainMenuExpBar;
	if ( not xp or not xp.GetValue or not xp.SetMinMaxValues or not xp.SetValue ) then return; end
	if ( on ) then
		if ( not demoXPOriginal ) then
			local lo, hi = xp:GetMinMaxValues();
			local r, g, b;
			if ( xp.GetStatusBarColor ) then r, g, b = xp:GetStatusBarColor(); end
			demoXPOriginal = { lo = lo, hi = hi, value = xp:GetValue(), r = r, g = g, b = b };
		end
		xp:SetMinMaxValues(0, 100); xp:SetValue(0);
		if ( xp.SetStatusBarColor ) then xp:SetStatusBarColor(0.64, 0.22, 0.9); end
	else
		local old = demoXPOriginal;
		if ( old ) then
			xp:SetMinMaxValues(old.lo or 0, old.hi or 1); xp:SetValue(old.value or 0);
			if ( old.r and xp.SetStatusBarColor ) then xp:SetStatusBarColor(old.r, old.g, old.b); end
		end
		demoXPOriginal = nil;
	end
end

function DemoTick(dt)
	demoT = demoT + dt;
	demoHitClock = demoHitClock + dt;
	SS.Safe(SS.DemoWorld, dt);
	-- the party keeps the column or row you chose
	if ( SS.Demoing("TargetFrame") ) then SS.Safe(SU.PreviewTarget); end
	if ( SS.Demoing("PartyMemberFrame1") ) then SS.Safe(SU.PreviewParty); end
	-- damage meter: the sample numbers climb
	if ( SS.Demoing("SlimSuiteMeterFrame") and SlimSuiteMeter and SlimSuiteMeter.demoSnapshot ) then SlimSuiteMeter.demoSnapshot = SS.DemoMeterSnapshot(demoT); end
	-- Demo XP: purple progress climbs evenly and returns to empty at 100%, without changing saved XP.
	if ( SS.Demoing("MainMenuExpBar") and MainMenuExpBar and demoXPOriginal ) then
		MainMenuExpBar:SetValue(math.mod(demoT * 8, 100));
	end
	-- buffs: each sample comes and goes on its own rhythm, on the real buff frame
	if ( SS.Demoing("BuffFrame") ) then
		local changed = false;
		for i = 1, table.getn(SS.BUFF_SAMPLES) do
			local on = math.mod(math.floor(demoT / (1.5 + i * 0.4)) + i, 2) == 0;
			if ( (SS.demoBuffOn[i] and true or false) ~= on ) then SS.demoBuffOn[i] = on; changed = true; end
		end
		if ( changed ) then SS.buffDirty = true; end
	end
	-- combat text: a hit or heal arrives every 0.9 seconds
	if ( SS.Demoing("SlimSuiteCombatTextFrame") and demoHitClock >= 0.9 and SlimSuiteWorld and SlimSuiteWorld.DemoHit ) then
		demoHitClock = 0;
		local h = DEMO_HITS[demoHitIndex];
		SS.Safe(SlimSuiteWorld.DemoHit, h[1], h[2], "Interface\\Icons\\" .. h[3], h[4], h[5]);
		demoHitIndex = math.mod(demoHitIndex, table.getn(DEMO_HITS)) + 1;
	end
end

-- Demo Mode's world: everything the elements show moves the way a real run would.
--   bosses and the target only ever lose health, and start again full when they reach the bottom
--   the party takes ticking damage, heals and big hits in short bursts
--   the revive bar fills, starts over and fills again
--   kills, gold and the next cache's price only climb; after a while they go back to 0 and climb again
--   the run clock counts up from a random time; the next boss counts down and starts over
--   the announcements show the game's kinds of messages, short and long, every few seconds
--   the minimap shows sample caches sitting still and the sample bosses, with their marks, walking about
local DEMO_NEWS = {
	{ "Hogger enters the battlefield!", true },
	{ "A Guardian stirs in its lair." },
	{ "Edwin VanCleef has been slain!", true },
	{ "Level up!" },
	{ "The cache is ready to open." },
	{ "Heroic: Sanguine, Explosive. Enemies leave pools of blood and some explode when they die." },
	{ "Mr. Smite calls for his crew!", true },
	{ "Your party revived Brann." },
	{ "Next zone: Westfall. The Defias Brotherhood waits for you there." },
	{ "Cookie is enraged!", true },
};
function SS.DemoWorld(dt)
	local D = SS.demoState;
	if ( not D ) then
		D = { news = 0, newsIndex = 1, cycle = 0, party = {} };
		SS.demoState = D;
		SS.demoClock = { run = 60 * math.random(3, 14) + math.random(0, 59), nextBoss = math.random(40, 150) };
		SS.demoRevive = 0;
		SS.TALLY_SAMPLE.kills, SS.TALLY_SAMPLE.gold, SS.TALLY_SAMPLE.chest = 0, 0, 25;
		SS.TALLY_SAMPLE.bosses, SS.TALLY_SAMPLE.guardians = 0, 0;
	end
	-- Each sample source advances only when its own element was enabled before Demo began.
	if ( SS.Demoing("SlimSuiteBossFrames") ) then
		for i = 1, table.getn(SS.BOSS_SAMPLE) do
			local b = SS.BOSS_SAMPLE[i];
			b[2] = b[2] - dt * (1.2 + i * 0.7);
			if ( b[2] <= 0 ) then b[2] = 100; end
		end
		SS.Safe(SS.UpdateBossFrames);
	end
	-- the target: down only, full again at the bottom
	if ( SS.Demoing("TargetFrame") ) then
		SU.SAMPLE_TARGET.hp = SU.SAMPLE_TARGET.hp - dt * 4;
		if ( SU.SAMPLE_TARGET.hp <= 0 ) then SU.SAMPLE_TARGET.hp = 100; end
	end
	-- the party: each member gets a burst now and then (ticking damage, a heal, or a big hit) that plays out slowly
	if ( SS.Demoing("PartyMemberFrame1") ) then
		for i = 1, table.getn(SU.PARTY_SAMPLE) do
			local s, p = SU.PARTY_SAMPLE[i], D.party[i];
			if ( not p ) then p = { left = 0, rate = 0, wait = math.random() * 2 }; D.party[i] = p; end
			if ( p.left > 0 ) then
				s[3] = math.max(5, math.min(100, s[3] + p.rate * dt));
				p.left = p.left - dt;
			else
				p.wait = p.wait - dt;
				if ( p.wait <= 0 ) then
					local roll = math.random();
					if ( s[3] < 35 or (roll < 0.35 and s[3] < 90) ) then p.rate, p.left = 18, 1 + math.random();            -- a heal
					elseif ( roll < 0.55 ) then p.rate, p.left = -45, 0.5;                                                -- a big hit
					else p.rate, p.left = -6, 1.5 + math.random() * 1.5; end                                              -- ticking damage
					p.wait = 0.8 + math.random() * 2;
				end
			end
		end
	end
	-- the revive bar: fills over about five seconds, then starts again
	if ( SS.Demoing("SlimSuiteReviveFrame") ) then
		SS.demoRevive = SS.demoRevive + dt / 5;
		if ( SS.demoRevive > 1 ) then SS.demoRevive = 0; end
		SS.Safe(SlimSuiteWorld.UpdateRevive);
	end
	-- the tally: only climbs; after about 90 seconds it goes back to 0 and climbs again
	local T = SS.TALLY_SAMPLE;
	if ( SS.Demoing("SlimSuiteTallyFrame") ) then
		D.cycle = D.cycle + dt;
		if ( D.cycle > 90 ) then
			D.cycle = 0; T.kills, T.gold, T.chest, T.bosses, T.guardians = 0, 0, 25, 0, 0;
		else
			T.kills = T.kills + math.random(0, 3);
			if ( math.random() < 0.3 ) then T.gold = T.gold + math.random(1, 4); end
			if ( math.random() < 0.02 ) then T.chest = T.chest + 25; end
			if ( math.random() < 0.006 ) then T.bosses = T.bosses + 1; end
			if ( math.random() < 0.01 ) then T.guardians = T.guardians + 1; end
		end
		SS.Safe(SS.UpdateTally);
	end
	-- the clocks
	if ( SS.Demoing("SlimSuiteClockFrame") ) then
		local C = SS.demoClock;
		C.run = C.run + dt;
		C.nextBoss = C.nextBoss - dt;
		if ( C.nextBoss <= 0 ) then C.nextBoss = math.random(60, 180); end
		SS.Safe(SS.UpdateClock);
	end
	-- announcements: one every 6 seconds, in turn
	if ( SS.Demoing("SlimSuiteAnnouncementFrame") ) then
		D.news = D.news - dt;
		if ( D.news <= 0 ) then
			D.news = 6;
			local n = DEMO_NEWS[D.newsIndex];
			D.newsIndex = math.mod(D.newsIndex, table.getn(DEMO_NEWS)) + 1;
			SS.Safe(SS.ShowAnnouncement, { id = "demo" .. D.newsIndex .. "-" .. math.floor(demoT), text = n[1], boss = n[2] });
		end
	end
	-- the minimap: caches sit still, the bosses walk slowly around you with their marks
	if ( SS.Demoing("MinimapCluster") ) then
		local pins = {};
		local caches = { { 60, 40 }, { -90, 20 }, { 30, -110 } };
		for i = 1, table.getn(caches) do
			table.insert(pins, { x = caches[i][1], y = caches[i][2], size = 13, rim = true, crop = true, texture = "Interface\\Icons\\INV_Box_02", tip = "Cache (sample)" });
		end
		for i = 1, table.getn(SS.BOSS_SAMPLE) do
			local a = demoT * (0.08 + i * 0.03) + i * 1.6;
			local r = 70 + i * 25;
			table.insert(pins, { x = math.cos(a) * r, y = math.sin(a) * r, size = 15, rim = true, texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcons",
				raid = SlimSuiteWorld.BOSS_ICONS and SlimSuiteWorld.BOSS_ICONS[i] or 8, tip = SS.BOSS_SAMPLE[i][1] .. " (sample)" });
		end
		SlimSuiteWorld.demoPins = pins;
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
		local actorId="demo:"..d[1];
		snap.actors[actorId] = { name = d[1], kind = d[6] or "hero" };
		snap.sources["s" .. i] = { name = d[2], school = d[7], proc = d[8], icon = { status = "ready", path = "Interface\\Icons\\" .. d[3] } };
		snap.rows[i] = { rowId = "r" .. i, sourceKey = "s" .. i, ownerId = "demo:hero", actorId = actorId, displayAmount = amount,
			displayRate = { status = "ready", value = math.floor(d[5] * 210) } };
	end
	return snap;
end

-- every element that shows samples is told to draw again (starting or stopping)
function DemoRedraw()
	-- Refreshers own their enabled/default checks; call them after stop to restore live data or setup previews.
	SS.Safe(SS.UpdateBossFrames); SS.Safe(SS.UpdateTally); SS.Safe(SS.UpdateClock); SS.Safe(SS.UpdateAnnouncementFrame);
	SS.Safe(SS.UpdateLevelButton); SS.Safe(SS.RefreshItemRow); SS.Safe(SS.RefreshSpellRow);
	SS.buffDirty = true;
end

function SS.StartDemoMode()
	if ( SS.demoRunning ) then return; end
	local enabled, list = {}, SU and SU.elements or {};
	if ( table.getn(list) == 0 and SU and SU.Steps ) then
		local steps = SU.Steps();
		for i = 1, table.getn(steps) do if ( steps[i].frame ) then table.insert(list, steps[i]); end end
	end
	local hasMeter = false;
	for i = 1, table.getn(list) do if ( list[i].frame == "SlimSuiteMeterFrame" ) then hasMeter = true; end end
	if ( not hasMeter and getglobal("SlimSuiteMeterFrame") ) then table.insert(list, { frame = "SlimSuiteMeterFrame" }); end
	for i = 1, table.getn(list) do
		local frame = list[i].frame;
		if ( frame and SU.Mode(frame) == "enabled" ) then enabled[frame] = true; end
	end
	if ( not next(enabled) ) then
		if ( SU and SU.RefreshDemoButtons ) then SU.RefreshDemoButtons(); end
		return false;
	end
	SS.demoElements = enabled;
	SS.demoRunning = true;
 SS.RefreshEditHandles();
	demoT = 0; demoHitClock = 0;
	SS.demoBuffOn = {};
	if ( SS.Demoing("SlimSuiteMeterFrame") and SlimSuiteMeter ) then SlimSuiteMeter.demoSnapshot = SS.DemoMeterSnapshot(0); end
	if ( SS.Demoing("MinimapCluster") and Minimap and Minimap.CreateTexture and table.getn(demoPins) == 0 ) then
		for i = 1, 4 do
			local p = Minimap:CreateTexture(nil, "OVERLAY");
			p:SetWidth(6); p:SetHeight(6); p:SetTexture(i == 1 and 1 or 0.9, i == 2 and 0.8 or 0.4, 0.2, 1);
			demoPins[i] = p;
		end
	end
	for i = 1, table.getn(demoPins) do demoPins[i]:Hide(); end   -- the minimap's samples are real pins now (SS.DemoWorld)
	SetDemoXP(SS.Demoing("MainMenuExpBar"));
	if ( demoGlint ) then demoGlint:Hide(); end
	SS.Safe(SU.UpdateDemo);
	DemoRedraw();
	SS.Every("demoMode", 0.25, function() SS.Safe(DemoTick, 0.25); end);
	SS.Safe(SS.ShowDemoBox, true);
end

function SS.StopDemoMode()
	if ( not SS.demoRunning ) then return; end
	SS.demoRunning = false;
	SS.demoElements = nil;
	SS.Stop("demoMode");
	if ( SlimSuiteMeter ) then SlimSuiteMeter.demoSnapshot = nil; end
	for i = 1, table.getn(demoPins) do demoPins[i]:Hide(); end
	SS.demoState, SS.demoClock = nil, nil;
	if ( SlimSuiteWorld ) then SlimSuiteWorld.demoPins = nil; end
	SS.TALLY_SAMPLE.kills, SS.TALLY_SAMPLE.gold, SS.TALLY_SAMPLE.chest, SS.TALLY_SAMPLE.bosses, SS.TALLY_SAMPLE.guardians = 1284, 356, 120, 2, 3;
	SS.BOSS_SAMPLE[1][2], SS.BOSS_SAMPLE[2][2], SS.BOSS_SAMPLE[3][2], SS.BOSS_SAMPLE[4][2] = 60, 40, 85, 100;
	if ( demoGlint ) then demoGlint:Hide(); end
	SetDemoXP(false);
	SS.demoPartyOrient = nil;
	SS.demoBuffOn = {};
	-- the sample row may have stepped the party aside for your plate (not saved): back to its own place
	if ( SS.DB().partyIncludesSelf ) then SS.Safe(SS.Place, "PartyMemberFrame1"); end
	SS.Safe(ApplyMovableOrientation, "PartyMemberFrame1");   -- the party's own layout again
	SS.Safe(SS.EndPreviewsIfDone);                           -- the sample party and target go
	SS.Safe(SS.ApplyNewFrames);
	DemoRedraw();
	SS.Safe(SS.ShowDemoBox, false);
 SS.RefreshEditHandles();
end

-- While Demo Mode runs, Slim Suite's menus are put away so the samples can be seen, and a small "DEMO MODE" box
-- stands in for them: "On" is lit while it runs, "Off" stops it and brings back the menus that were open.
-- The setup bar, element menu and move panel stay up during Demo Mode, so the UI can still be changed while it runs.
SS.DEMO_HIDES = { "SlimSuiteFrame", "SlimSuiteLayoutFrame", "SlimSuiteRaidIconPanel" };
demoHidden = {};
function DemoBox()
	local box = getglobal("SlimSuiteDemoBox");
	if ( box ) then return box; end
	box = CreateFrame("Frame", "SlimSuiteDemoBox", UIParent);
	box:SetWidth(132); box:SetHeight(52); box:SetFrameStrata("DIALOG");
	box:SetPoint("TOP", UIParent, "TOP", 0, -90);
	SS.OwnLook(box, function()
	box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	box:SetBackdropColor(0.05, 0.04, 0.02, 0.92); box:SetBackdropBorderColor(0.83, 0.66, 0.26, 1);
	end);
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
		-- the Demo On / Off buttons on the edit bar replace the old floating box, so no box is shown
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
	local s = SS.EffectiveScale(UIParent);
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
	SS.OwnLook(p, function()
	p:SetBackdrop(SU.CARD_BACKDROP);
	p:SetBackdropColor(0.05, 0.05, 0.05, 0.95);
	p:SetBackdropBorderColor(0.85, 0.65, 0.2, 1);
	end);
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
