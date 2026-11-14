-- Focused Slim Suite module; loaded in manifest order.
if ( setfenv ) then setfenv(1, SS.ENV); end
-- Let the client measure wrapped translated text; retain the established font size.
function SS.WrappedLabelHeight(label, width)
	label:SetWidth(math.max(40, width)); label:SetHeight(0);
	local height = label:GetHeight() or 0;
	if ( height <= 0 ) then
		local _, size = label:GetFont();
		height = math.ceil((label:GetStringWidth() or 0) / math.max(40, width)) * ((size or 12) + 2);
	end
	height = math.max(20, height); label:SetHeight(height); return height;
end
function SS.LayoutPage(page)
	local rows, parent = page.rows, page.parent;
	local show = {};
	for i = 1, table.getn(rows) do
		local r = rows[i];
		show[i] = not (r.up and not r.up());
	end
	local y = page.startY;
	for i = 1, table.getn(rows) do
		local r = rows[i];
		if ( r.kind == "head" ) then
			local any = false;
			for j = i + 1, table.getn(rows) do
				if ( rows[j].kind == "head" ) then break; end
				if ( show[j] ) then any = true; break; end
			end
			r.fs:ClearAllPoints(); r.fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y);
			if ( any ) then r.fs:Show(); y = y - 24; else r.fs:Hide(); end
		elseif ( show[i] ) then
			local rowHeight = 28;
			if ( r.kind == "button" ) then
				r.b:ClearAllPoints(); r.b:SetPoint("TOPLEFT", parent, "TOPLEFT", 26, y + 2);
				r.b:Show();
				rowHeight = 30;
			elseif ( r.kind == "choice" ) then
				r.fs:ClearAllPoints(); r.fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 30 + r.lead, y - 6);
				rowHeight = math.max(28, SS.WrappedLabelHeight(r.fs, 140 - r.lead) + 10);
				r.fs:Show(); r.b:Show();
			else
				r.cb:ClearAllPoints(); r.cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 26 + r.lead, y);
				rowHeight = math.max(28, SS.WrappedLabelHeight(r.cb.label, 350 - r.lead) + 8);
				r.cb:Show(); r.cb.label:Show();
			end
			y = y - rowHeight;
		else
			if ( r.kind == "button" ) then r.b:Hide();
			elseif ( r.kind == "choice" ) then r.fs:Hide(); r.b:Hide(); else r.cb:Hide(); r.cb.label:Hide(); end
		end
	end
	parent:SetHeight(math.max(20, -y + 12));
	if ( page.after ) then page.after(y); end
	return y;
end

function SS.Check(parent, label, y, get, set, indent)
	local cb, ok = K.Templated("CheckButton", nil, parent, "UICheckButtonTemplate");
	if ( not ok or not cb.SetChecked ) then
		cb = CreateFrame("CheckButton", nil, parent);
		cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up");
		cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down");
		cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight");
		cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check");
	end
	cb:SetWidth(26);
	cb:SetHeight(26);
	cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 26 + (indent or 0), y);
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	fs:SetPoint("TOPLEFT", cb, "TOPRIGHT", 4, -4);
	fs:SetWidth(350); fs:SetHeight(28); fs:SetJustifyH("LEFT"); fs:SetText(SS.T(label));
	cb.label = fs;
	cb:SetScript("OnShow", function() this:SetChecked(get() and 1 or nil); end);
	cb.get = get;
	SS.TrackToggle(cb);
	cb:SetScript("OnClick", function()
		local v = not (get() and true or false);
		SS.ChangeSetting(get, set, v);
		K.Sound(v and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff");
		SS.RefreshToggles();
	end);
	return cb;
end

function SS.WinBuild()
	win = K.Window("SlimSuiteFrame", "Slim Suite", 470, 560);
	local hero = K.Hero(win, 380);
	hero:SetWidth(430);
	hero:SetPoint("TOPLEFT", win, "TOPLEFT", 20, -30);
	K.Icon(hero.icon, "INV_Misc_Gear_02");
	hero.heading:SetText("Slim Suite");
	hero.line:SetText(SS.T("A Swiss-army knife of useful tools and UI controls."));
	hero.version=hero:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
	hero.version:SetPoint("TOPRIGHT",hero,"TOPRIGHT",-9,-8); hero.version:SetText("v"..SS.AddonVersion()); hero.version:SetTextColor(0.95,0.76,0.3);
	local tabUi = K.Button(win, "Modifying the User Interface", 210, nil);
	tabUi:SetPoint("TOPLEFT", win, "TOPLEFT", 20, -101);
	local tabOther = K.Button(win, "New/Unique, But Minor Features", 210, nil);
	tabOther:SetPoint("TOPLEFT", tabUi, "TOPRIGHT", 4, 0);
	local bodyTop = -132;
	local uiScroll, uiChild = K.Scroll("SlimSuiteUiScroll", win, 422);
	uiScroll:SetPoint("TOPLEFT", win, "TOPLEFT", 20, bodyTop);
	uiScroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -30, 48);
	local otherScroll, otherChild = K.Scroll("SlimSuiteOtherScroll", win, 422);
	otherScroll:SetPoint("TOPLEFT", win, "TOPLEFT", 20, bodyTop);
	otherScroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -30, 48);
	local addonsScroll, addonsChild = K.Scroll("SlimSuiteAddonsScroll", win, 422);
	addonsScroll:SetPoint("TOPLEFT", win, "TOPLEFT", 20, bodyTop);
	addonsScroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -30, 48);
	-- A page is a list of groups: {head="Name"} starts one. A row whose label starts with spaces is a sub-setting: it
	-- shows only while the setting above it (the one it belongs to) is on.
	local function AddRows(parent, entries, startY, after)
		SS.pages = SS.pages or {};
		local page = { parent = parent, rows = {}, startY = startY, after = after };
		local up = nil;
		for i = 1, table.getn(entries) do
			local row = entries[i];
			if ( row.head ) then
				local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal");
				fs:SetText(SS.T(row.head)); fs:SetTextColor(1, 0.82, 0);
				table.insert(page.rows, { kind = "head", fs = fs });
				up = nil;
			elseif ( row.button ) then
				local b = K.Button(parent, row.button, 150, row.onClick);
				table.insert(page.rows, { kind = "button", b = b });
				up = nil;
			else
				local label, lead = row[1], 0;
				if ( string.find(label, "^%s") ) then lead = 22; label = string.gsub(label, "^%s+", ""); end
				local r = { lead = lead, up = (lead > 0) and up or nil };
				if ( row.choice ) then
					r.kind = "choice";
					r.fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
					r.fs:SetText(SS.T(label));
					r.b = SS.ChoiceButton(parent, 200);
					r.b.entry = row; r.b:SetPoint("LEFT", r.fs, "RIGHT", 10, 0);
					r.b:SetText(SS.ChoiceText(row) .. "  v");
					r.b:SetScript("OnShow", function() if ( this.entry ) then this:SetText(SS.ChoiceText(this.entry) .. "  v"); end end);
					if ( lead == 0 ) then up = nil; end
				else
					r.kind = "check";
					r.cb = SS.Check(parent, label, startY, row[2], row[3], lead);
					up = row[2];
				end
				table.insert(page.rows, r);
			end
		end
		table.insert(SS.pages, page);
		SS.LayoutPage(page);
		return page;
	end
	local tooltipTitle, tooltipSmaller, tooltipLarger, reset, resetAll, addonsTab, uiLastY, otherLastY;
	-- the tooltip-size and reset controls sit under the last row of the UI page
	local function PlaceTail()
		if ( not tooltipTitle or not uiLastY ) then return; end
		local y0 = uiLastY - 14;
		tooltipTitle:ClearAllPoints(); tooltipTitle:SetPoint("TOPLEFT", uiChild, "TOPLEFT", 10, y0);
		tooltipSmaller:ClearAllPoints(); tooltipSmaller:SetPoint("TOPLEFT", uiChild, "TOPLEFT", 10, y0 - 18);
		reset:ClearAllPoints(); reset:SetPoint("TOPLEFT", uiChild, "TOPLEFT", 10, y0 - 52);
		uiChild:SetHeight(-(y0 - 52) + 44);
	end
	-- the Manage Addons button sits under the last row of the Other page
	local function PlaceAddons()
		if ( not addonsTab or not otherLastY ) then return; end
		addonsTab:ClearAllPoints(); addonsTab:SetPoint("TOPLEFT", otherChild, "TOPLEFT", 10, otherLastY - 12);
		otherChild:SetHeight(-(otherLastY - 12) + 44);
	end
	local function CheckboxRows()
		local noteTitle = uiChild:CreateFontString(nil, "OVERLAY", "GameFontNormal");
		noteTitle:SetPoint("TOPLEFT", uiChild, "TOPLEFT", 10, -8); noteTitle:SetText(SS.T("Moving the game's UI"));
		local note = uiChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		note:SetPoint("TOPLEFT", noteTitle, "BOTTOMLEFT", 0, -3); note:SetWidth(390); note:SetHeight(38);
		note:SetJustifyH("LEFT"); note:SetJustifyV("TOP"); note:SetHeight(52); note:SetText(SS.T("The game's own versions of these parts can't be moved. To move one, say yes below: Slim Suite swaps in its own movable copy. Each copy's other settings are in its menu: right-click it in Toggle UI Settings."));
		AddRows(uiChild, {
			{head="Setup"},
			{"Toggle UI Settings (drag, resize and scale)", function() return SS.DB().unlocked; end, function(v) SS.SetUnlocked(v); end},
			{button = "Demo Mode", onClick = function() SS.ToggleDemoMode(); end},
			{button = "Profiles & import/export", onClick = function() SS.ShowLayoutWindow(); end},
			{button = "Recommended HUD preset", onClick = function() SS.ShowHUDRecommendation(); end},
			{button = "Diagnostics & compatibility", onClick = function() SS.ShowDiagnosticsWindow(); end},
			{"Keep a separate layout for each character", function() return SS.DB().layoutPerCharacter; end, function(v) SS.SetLayoutPerCharacter(v); end},
			{head="Make the game's UI movable"},
			{"Replace Default Level Up with Movable Version?", function() return SS.DB().moveLevelButton; end, function(v) SS.DB().moveLevelButton = v; SS.Safe(SS.UpdateLevelButton); end},
			{"Replace Default Build Rows with Movable Versions?", function() return SS.DB().replaceBuildRows; end, function(v) SS.DB().replaceBuildRows = v; SS.ApplyBuildRowReplacement(); end},
			{"Replace Default Damage Meter with Movable Version?", function() return SS.DB().moveMeter; end, function(v) SS.SetMeterReplacement(v); end},
			{"Replace Default Run Clock with Movable Version?", function() return SS.DB().replaceClock;end,function(v) SS.DB().replaceClock=v;SS.UpdateClock();end},
			{"Replace Default Encounter Bars with Movable Versions?", function() return SS.DB().replaceEncounters;end,function(v) SS.DB().replaceEncounters=v;SS.UpdateBossFrames();end},
			{"Replace Default Kills / Gold / Cache with Movable Version?", function() return SS.DB().replaceTally;end,function(v) SS.DB().replaceTally=v;SS.UpdateTally();end},
			{"Replace Default Announcements with Movable Version?", function() return SS.DB().replaceBanners;end,function(v) SS.DB().replaceBanners=v;SS.UpdateAnnouncementFrame();end},
			{"Replace Default Revive Bar with Movable Version?", function() return SS.DB().replaceRevive; end, function(v) SS.DB().replaceRevive = v; end},
			{"Replace Default Local Clock with Movable Version?", function() return SS.DB().replaceLocalClock; end, function(v) SS.SetLocalClockOn(v); end},
			{"Replace Default Action Bar Art with Plain Version?", function() return SS.DB().plainBar; end, function(v) SS.DB().plainBar = v; SS.PlainBar(v); end},
			{"Replace Default Combat Text with Movable Box?", function() return SS.DB().combatTextBox; end, function(v) SU.FEATURES.SlimSuiteCombatTextFrame(v and true or false); if ( SS.DB().unlocked ) then SS.SetUnlocked(true, true); end SU.Rebuild(); end},
			{"Replace Default Minimap Buttons with a Movable Row? (optional)", function() return SS.DB().minimapBar; end, function(v) SS.SetMinimapBar(v); end},
			{head="Everywhere"},
			{"Show green absorb amounts on player and party frames (when the client exposes them)", function() return SS.DB().showAbsorbs; end, function(v) SS.DB().showAbsorbs = v and true or false; SS.Safe(SS.UpdateAbsorbMarkers); end},
			{"Floating combat text over enemies (Slim Suite's own)", function() return SS.DB().floatingText; end, function(v) SS.DB().floatingText = v; end},
			{"Show Slim Suite above the level-up and new-item cards", function() return SS.DB().onTopOfScreens; end, function(v) SS.DB().onTopOfScreens = v; if ( SlimSuiteWorld ) then SlimSuiteWorld.ApplyOnTop(); end end}
		}, -86, function(y) uiLastY = y; PlaceTail(); end);
	end
	local function BuildOther()
		local purpose=otherChild:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
		purpose:SetPoint("TOPLEFT",otherChild,"TOPLEFT",10,-8);purpose:SetWidth(390);purpose:SetHeight(32);
		purpose:SetJustifyH("LEFT");purpose:SetJustifyV("TOP");purpose:SetText(SS.T("The goal of clearing up chat is to see your friends' chat better in multiplayer."));
		AddRows(otherChild, {
			{"Language (reload UI)", function() return SS.DB().language or "auto"; end,
			 function(v) SS.DB().language = v; end,
			 choice={{"auto","auto"},{"English","enUS"},{"Español","esES"},{"Français","frFR"},{"Deutsch","deDE"},{"Português (Brasil)","ptBR"},{"Italiano","itIT"}} },
			{button="Reload for changes", onClick=function() if ( ReloadUI ) then ReloadUI(); end end},
			{head="Chat mods"},
			{"No level-up stat bonuses in chat", function() return SS.DB().hideLevel;end,function(v) SS.DB().hideLevel=v;end},
			{"No new spell lines in chat", function() return SS.DB().hideNewSpells;end,function(v) SS.DB().hideNewSpells=v;end},
			{"Hide racial buff information in chat", function() return SS.DB().hideRacialInfo;end,function(v) SS.DB().hideRacialInfo=v;end},
			{"Hide the Oogax Q opening line (English game text only)", function() return SS.DB().hideOpeningLine;end,function(v) SS.DB().hideOpeningLine=v;end},
			{"Hide 'Who dares to enter my lair' (English game text only)", function() return SS.DB().hideLairLine;end,function(v) SS.DB().hideLairLine=v;end},
			{"Hide in-game roleplay lines from chat", function() return SS.DB().hideRP;end,function(v) SS.DB().hideRP=v;end},
			{head="Enemy frames"},
			{"Show native enemy nameplates", function() return SS.NativeEnemyNameplatesEnabled and SS.NativeEnemyNameplatesEnabled(); end, function(v) SS.SetNativeEnemyNameplates(v); end},
			{"Use modern Slim Suite enemy frames", function() return SS.DB().modernEnemyFrames; end, function(v) SS.SetModernEnemyFrames(v); end},
			{"Only show bosses and lair guardians on modern enemy frames", function() return SS.DB().enemyBossesOnly; end, function(v) SS.SetEnemyPlateBossesOnly(v); end},
			{"Show boss and lair debuffs and remaining time on enemy nameplates (native or modern)", function() return SS.DB().enemyPlateDebuffs; end, function(v) SS.SetEnemyPlateDebuffs(v); end},
			{head="Camera and marks"},
			{"Camera as far out as it goes (50)", function() return SS.DB().camera; end, function(v) SS.DB().camera = v; SS.Camera(v); end},
			{"Mark pulled bosses and Guardians (Skull, X, Circle, Star)", function() return SS.DB().bossMarks; end, function(v) SS.DB().bossMarks = v; end},
			{"   ...and Guardians and lairs before they're pulled", function() return SS.DB().prePullMarks; end, function(v) SS.DB().prePullMarks = v; end},
			{"Raid-mark row when the mouse is over a party member (in a group)", function() return SS.DB().raidRow; end, function(v) SS.DB().raidRow = v and true or false; end},
			{head="Minimap"},
			{"Show caches on the minimap", function() return SS.DB().minimapCaches; end, function(v) SS.DB().minimapCaches = v; end},
			{"Show bosses on the minimap", function() return SS.DB().minimapBosses; end, function(v) SS.DB().minimapBosses = v; end},
			{"Show lairs on the minimap, with their 3:00 refill timer", function() return SS.DB().minimapLairs; end, function(v) SS.DB().minimapLairs = v; end},
			{"Show the game's nearest Guardian lair flag on minimap", function() return SS.DB().showGuardianFlag; end, function(v) SS.DB().showGuardianFlag = v; SS.ApplyGuardianFlag(); end},
			{"Square minimap (off: round)", function() return SS.DB().minimapSquare; end, function(v) SS.SetMinimapSquare(v); end},
			{"Transparent minimap (round or square, no borders)", function() return SS.DB().minimapTransparent; end, function(v) SS.SetMinimapTransparent(v); end},
			SS.MinimapButtonsEntry(),
			{"Minimap button", function() local m = SS.DB().minimap; return not (m and m.hide); end, function(v) if ( SS.Mini ) then local m = SS.DB().minimap; if ( (m and m.hide and true or false) == v ) then SS.Mini.Toggle(); end end end},
			{head="Deaths and spells"},
			{"Mark where a downed friend can be revived", function() return SS.DB().deathMarks; end, function(v) SS.DB().deathMarks = v; end},
			{"Play a sound when you or a teammate dies", function() return SS.DB().deathSound; end, function(v) SS.DB().deathSound = v; end},
			{"   Use LEGO die instead of Baby Crying", function() return SS.DB().legoDeathSound; end, function(v) SS.DB().legoDeathSound = v and true or false; end},
			{button = "Preview: Baby Crying (death)", onClick = function() SS.PreviewSound("death"); end},
			{button = "Preview: LEGO die", onClick = function() SS.PreviewSound("legoDeath"); end},
			{"Play Low Health Sound at 30% health or lower (1 second, every 5 seconds)", function() return SS.DB().lowHealthSound; end, function(v) SS.DB().lowHealthSound = v and true or false; end},
			{button = "Preview: Low Health Sound", onClick = function() SS.PreviewSound("lowHealth"); end},
			{"Play hitmarker when a boss, Guardian, or lair owner is killed", function() return SS.DB().bossHitmarkerSound; end, function(v) SS.DB().bossHitmarkerSound = v and true or false; end},
			{button = "Preview: Hitmarker", onClick = function() SS.PreviewSound("bossHitmarker"); end},
			{"Play whip crack when a boss, Guardian, or lair owner is killed", function() return SS.DB().bossWhipSound; end, function(v) SS.DB().bossWhipSound = v and true or false; end},
			{button = "Preview: Whip Crack", onClick = function() SS.PreviewSound("bossWhip"); end},
			{"Play a sound when opening a cache", function() return SS.DB().chestOpenSound; end, function(v) SS.DB().chestOpenSound = v and true or false; end},
			{button = "Preview: Zelda chest opening", onClick = function() SS.PreviewSound("chestOpen"); end},
			{"Cooldown numbers on the spell squares", function() return SS.DB().cooldowns; end, function(v) SS.DB().cooldowns = v; end},
			{head="Accessibility"},
			{"High-contrast encounter bars", function() return SS.DB().accessibilityContrast; end, function(v) SS.DB().accessibilityContrast = v and true or false; SS.Safe(SS.UpdateBossFrames); end},
			{"Larger encounter names", function() return SS.DB().accessibilityLargeText; end, function(v) SS.DB().accessibilityLargeText = v and true or false; SS.Safe(SS.UpdateBossFrames); end},
			{"Reduce floating combat-text motion", function() return SS.DB().accessibilityReduceMotion; end, function(v) SS.DB().accessibilityReduceMotion = v and true or false; end},
			{head="Support"},
			{button = "View diagnostics & compatibility", onClick = function() SS.ShowDiagnosticsWindow(); end},
		}, -48, function(y) otherLastY = y; PlaceAddons(); end);
	end
	local function BuildAddonManager()
		local title = addonsChild:CreateFontString(nil, "OVERLAY", "GameFontNormal");
		title:SetPoint("TOPLEFT", addonsChild, "TOPLEFT", 8, -8); title:SetText(SS.T("Enabled game addons"));
		local note = addonsChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6); note:SetText(SS.T("Changes apply after reload. Uncheck to disable an addon."));
		local n = (GetNumAddOns and GetNumAddOns()) or 0;
		local y = -48;
		for index = 1, n do
			local name, addonTitle, addonNotes, enabled = GetAddOnInfo(index);
			local state = GetAddOnEnableState and GetAddOnEnableState(nil, index) or (enabled and 1 or 0);
			if ( name and string.sub(string.lower(name), 1, 9) ~= "blizzard_" and name ~= "SlimSuite" ) then
				local cb = CreateFrame("CheckButton", nil, addonsChild, "UICheckButtonTemplate");
				cb:SetPoint("TOPLEFT", addonsChild, "TOPLEFT", 6, y); cb:SetWidth(24); cb:SetHeight(24);
				cb:SetChecked((state or 0) > 0 and 1 or nil);
				cb:SetScript("OnClick", function()
					if ( this:GetChecked() ) then EnableAddOn(name); else DisableAddOn(name); end
				end);
				local label = addonsChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
				label:SetPoint("LEFT", cb, "RIGHT", 4, 0); label:SetWidth(372); label:SetJustifyH("LEFT"); label:SetText(addonTitle or name);
				y = y - 26;
			end
		end
		addonsChild:SetHeight(math.max(64, -y + 12));
		local reload = K.Button(win, "Reload for changes", 160, function() if ( ReloadUI ) then ReloadUI(); end end);
		reload:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 28, 17);
		win.reloadButton = reload;
		local errors = K.Button(win, "Error log", 120, function() SS.ShowErrors(); end);
		errors:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 198, 17);
	end
	tooltipTitle = uiChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	tooltipTitle:SetPoint("TOPLEFT", uiChild, "TOPLEFT", 10, -732);
	tooltipTitle:SetText(SS.T("Tooltip width"));
	local function AdjustTooltipSize(delta)
		local size = SS.DB().sizes.GameTooltip;
		if ( type(size) ~= "table" ) then size = { w = 260, h = 140 }; SS.DB().sizes.GameTooltip = size; end   -- the player's own size from now on
		SS.DB().tooltipCustom = true;
		size.w = math.max(160, math.min(600, size.w + delta));
		if ( GameTooltip ) then GameTooltip:SetWidth(size.w); end
		PlaceAll();
	end
	tooltipSmaller = K.Button(uiChild, "Smaller", 82, function() AdjustTooltipSize(-20); end);
	tooltipSmaller:SetPoint("TOPLEFT", uiChild, "TOPLEFT", 10, -750);
	tooltipLarger = K.Button(uiChild, "Larger", 82, function() AdjustTooltipSize(20); end);
	tooltipLarger:SetPoint("LEFT", tooltipSmaller, "RIGHT", 6, 0);
	reset = K.Button(uiChild, "Reset positions", 140, function() SS.ResetPlaces(); end);
	reset:SetPoint("TOPLEFT", uiChild, "TOPLEFT", 10, -784);
	resetAll = K.Button(uiChild, "Reset all UI", 126, function() SS.ResetUI(); end);
	resetAll:SetPoint("LEFT", reset, "RIGHT", 8, 0);
	uiChild:SetHeight(818);
	CheckboxRows(); BuildOther(); BuildAddonManager();
	local function SelectPage(which)
		uiScroll:Hide(); otherScroll:Hide(); addonsScroll:Hide();
		if ( win.reloadButton ) then win.reloadButton:Hide(); end
		if ( which == "ui" ) then uiScroll:Show(); tabUi:LockHighlight(); tabOther:UnlockHighlight();
		elseif ( which == "other" ) then otherScroll:Show(); tabUi:UnlockHighlight(); tabOther:LockHighlight();
		else addonsScroll:Show(); if ( win.reloadButton ) then win.reloadButton:Show(); end end
	end
	tabUi:SetScript("OnClick", function() SelectPage("ui"); end);
	tabOther:SetScript("OnClick", function() SelectPage("other"); end);
	addonsTab = K.Button(otherChild, "Manage Addons", 132, function() SelectPage("addons"); end);
	PlaceTail(); PlaceAddons();
	SelectPage("other");
end

function SS.Toggle()
	if ( not win ) then
		local ok, err = SS.Safe(SS.WinBuild);
		if ( not ok ) then K.Print(NAME, "|cffff4040the settings window could not be made:|r " .. tostring(err)); win = nil; return; end
	end
	if ( win:IsShown() ) then win:Hide(); else win:Show(); end
end

-- "/slimsuite mouse": a small label by the cursor names the frame under it (and the frame that frame belongs to), so a
-- click that does nothing can be traced to whatever is catching it. Type it again to turn the label off.
function SS.ToggleMouseProbe()
	local probe = getglobal("SlimSuiteMouseProbe");
	if ( not probe ) then
		probe = CreateFrame("Frame", "SlimSuiteMouseProbe", UIParent);
		probe:SetFrameStrata("TOOLTIP");
		probe:SetWidth(10); probe:SetHeight(10);
		probe.text = probe:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		probe.text:SetPoint("BOTTOMLEFT", probe, "TOPRIGHT", 4, 4);
		probe.text:SetJustifyH("LEFT");
		probe:Hide();
	end
	if ( probe:IsShown() ) then
		probe:Hide(); SS.Stop("mouseProbe");
		K.Print(NAME, "the frame label is off.");
		return;
	end
	probe:Show();
	SS.Every("mouseProbe", 0.1, function()
		local f = GetMouseFocus and GetMouseFocus();
		local x, y = GetCursorPosition();
		local scale = SS.EffectiveScale(UIParent);
		probe:ClearAllPoints();
		probe:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale);
		if ( not f ) then probe.text:SetText("|cffaaaaaa(the game world)|r"); return; end
		local name = (f.GetName and f:GetName()) or "(no name)";
		local parent = f.GetParent and f:GetParent();
		local pname = parent and parent.GetName and parent:GetName() or "(no name)";
		probe.text:SetText("|cffffd100" .. name .. "|r\n|cffaaaaaain " .. pname .. "|r");
	end);
	K.Print(NAME, "the frame under your cursor is named next to it. /slimsuite mouse turns it off.");
end

SS.HELP = {
	"/slim: the settings window.  /slim edit: move and size the UI (/slim lock when done).  /slim setup: the guided setup.",
	"/slim demo: Demo Mode on or off.  /slim levelup: Slim Suite's Level Up button or the game's own.",
	"/slim layout: manage named profiles and import/export layouts.  /slim layout save <name>, load <name>, delete <name>, list.",
	"/slim hud: recommended positions for this display.  /slim diagnostics: client and game compatibility details.",
	"/slim reset places, /slim reset all: back to where everything started.",
	"/slim hide <words>, /slim unhide <words>, /slim hide: chat lines with those words.",
	"/slim minimap: the gear button.  /slim errors: the error log.  /slim mouse: names the frame under the cursor.",
};
SLASH_SLIMSUITE1 = "/slimsuite";
SLASH_SLIMSUITE2 = "/slim";
SlashCmdList["SLIMSUITE"] = function(msg)
	msg = msg or "";
	local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.-)$");
	cmd = string.lower(cmd or "");
	rest = string.lower(rest or "");
	local d = SS.DB();
	if ( cmd == "help" or cmd == "?" ) then
		for _, line in ipairs(SS.HELP) do K.Print(NAME, line); end
	elseif ( cmd == "hide" and rest == "" ) then
		if ( table.getn(d.words) == 0 ) then K.Print(NAME, "no words are hidden. /slim hide <words> hides chat lines with them.");
		else K.Print(NAME, "hidden in chat: \"" .. table.concat(d.words, "\", \"") .. "\". /slim unhide <words> shows them again."); end
	elseif ( cmd == "hide" ) then
		for i = 1, table.getn(d.words) do
			if ( d.words[i] == rest ) then K.Print(NAME, "\"" .. rest .. "\" is hidden already."); return; end
		end
		table.insert(d.words, rest);
		K.Print(NAME, "chat lines with \"" .. rest .. "\" are hidden now.");
	elseif ( cmd == "unhide" and rest ~= "" ) then
		for i = table.getn(d.words), 1, -1 do if ( d.words[i] == rest ) then table.remove(d.words, i); end end
		K.Print(NAME, "chat lines with \"" .. rest .. "\" are shown again.");
	elseif ( cmd == "errors" ) then
		SS.ShowErrors();
	elseif ( cmd == "diagnostics" or cmd == "compatibility" ) then
		SS.ShowDiagnosticsWindow();
	elseif ( cmd == "hud" or cmd == "recommend" ) then
		SS.ShowHUDRecommendation();
	elseif ( cmd == "mouse" ) then
		SS.ToggleMouseProbe();
	elseif ( cmd == "minimap" ) then
		local shown = SS.Mini and SS.Mini.Toggle();
		K.Print(NAME, shown and "the minimap button is back." or "the minimap button is hidden. /slimsuite minimap brings it back.");
	elseif ( cmd == "unlock" or cmd == "move" or cmd == "edit" ) then
		SS.SetUnlocked(true);
	elseif ( cmd == "lock" ) then
		SS.SetUnlocked(false);
	elseif ( cmd == "setup" ) then
		SS.StartSetup(true);
	elseif ( cmd == "demo" ) then
		SS.ToggleDemoMode();
		K.Print(NAME, SS.demoRunning and "Demo Mode is on. /slim demo turns it off." or "Demo Mode is off.");
	elseif ( cmd == "levelup" ) then
		d.moveLevelButton = not d.moveLevelButton;
		SS.Safe(SS.UpdateLevelButton); SS.RefreshToggles();
		K.Print(NAME, d.moveLevelButton and "Slim Suite's movable Level Up button is on." or "the game's own Level Up button is back.");
	elseif ( cmd == "reset" ) then
		if ( rest == "all" ) then SS.ResetUI(); elseif ( rest == "places" ) then SS.ResetPlaces();
		else K.Print(NAME, "/slim reset places puts every element back where it started; /slim reset all also resets sizes, scales and layouts."); end
	elseif ( cmd == "layout" or cmd == "layouts" ) then
		local _, _, action, name = string.find(rest, "^(%S*)%s*(.-)$");
		if ( action == "save" and name ~= "" ) then
			d.layouts[name] = SS.LayoutSnapshot();
			K.Print(NAME, "layout \"" .. name .. "\" saved.");
		elseif ( action == "load" and name ~= "" ) then
			if ( type(d.layouts[name]) == "table" and string.sub(name, 1, 5) ~= "char:" ) then SS.LayoutApply(d.layouts[name]); K.Print(NAME, "layout \"" .. name .. "\" is in use.");
			else K.Print(NAME, "there is no layout called \"" .. name .. "\". /slim layout list shows them."); end
		elseif ( action == "delete" and name ~= "" ) then
			if ( d.layouts[name] and string.sub(name, 1, 5) ~= "char:" ) then d.layouts[name] = nil; K.Print(NAME, "layout \"" .. name .. "\" deleted.");
			else K.Print(NAME, "there is no layout called \"" .. name .. "\"."); end
		elseif ( action == "list" ) then
			local names = SS.LayoutNames();
			K.Print(NAME, table.getn(names) > 0 and ("saved layouts: " .. table.concat(names, ", ")) or "no layouts saved yet. /slim layout save <name> saves this one.");
		else
			SS.ShowLayoutWindow();
			K.Print(NAME, "/slim layout save <name>, load <name>, delete <name>, list. The window shares a layout as text.");
		end
	else
		SS.Toggle();
	end
end
