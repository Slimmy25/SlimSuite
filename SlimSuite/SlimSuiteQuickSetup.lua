-- Quick setup: six plain questions about how you play. Finishing applies each answer ONCE to the ordinary settings;
-- nothing is remembered as a rule afterwards, so any single setting can still be changed by hand later and stays changed.
-- When preset designs are filled in (SlimSuitePresets.lua), it first offers those.
-- Open it from HUD Edit's "Quick" button or with /slimsuite quick.
if ( setfenv ) then setfenv(1, SS.ENV); end

-- Quick setup and the preset designs are put away for now: no button or command opens them. The code stays so they
-- can come back by setting this to true.
SS.QUICK_SETUP_ON = false;

local EXTRAS = { "SlimSuiteCompassFrame", "SlimSuiteLuckFrame", "SlimSuiteAchievementsButton", "SlimSuiteStatCounterFrame" };
local SOME_SOUNDS = { "deathSound", "reviveSound", "finalBossSound", "matchVictorySound" };
local MORE_SOUNDS = { "lowHealthSound", "bossHitmarkerSound", "chestOpenSound", "matchStartSound", "matchLossSound" };

local function SetElement(name, on)
	if ( not SS.ELEMENTS or not SS.ELEMENTS[name] or not SU or not SU.SetMode ) then return; end
	SS.Safe(SU.SetMode, name, on and "enabled" or "default", SS.ELEMENTS[name].title);
end
local function SetKeys(keys, value) local d = SS.DB(); for _, k in ipairs(keys) do d[k] = value; end end

-- each question: its text, and its answers { label, what it does (one line), apply function }
SS.QUICK_QUESTIONS = {
	{ "Which look do you like?", {
		{ "Classic WoW", "The game's own panels and borders.", function() SS.SetPanelStyle("original"); end },
		{ "RPG", "Darker panels with gold trim.", function() SS.SetPanelStyle("meter"); end },
		{ "Modern", "Clean, flat panels.", function() SS.SetPanelStyle("tooltip"); end } } },
	{ "How much do you want on screen?", {
		{ "Minimal", "Only what you need: no compass, luck, stats or achievements panels.", function() for _, n in ipairs(EXTRAS) do SetElement(n, false); end end },
		{ "Balanced", "Adds the compass to point you at bosses and lairs.", function() SetElement("SlimSuiteCompassFrame", true); end },
		{ "Everything", "Compass, luck, live stats and side achievements.", function() for _, n in ipairs(EXTRAS) do SetElement(n, true); end end } } },
	{ "Do you play with a group?", {
		{ "Yes", "Party frames grey out when someone is down, show distance and dim when out of range.",
			function() local d = SS.DB(); d.partyGreyDead, d.partyDistance, d.partyDimFar, d.partyMemberBuffs = true, true, true, true; end },
		{ "Mostly solo", "Party extras stay quiet: no distance or dimming.",
			function() local d = SS.DB(); d.partyGreyDead, d.partyDistance, d.partyDimFar = true, false, false; end } } },
	{ "Which enemies get health plates?", {
		{ "None", "The game's own nameplates only.", function() SS.DB().modernEnemyFrames = false; end },
		{ "Bosses only", "Plates over bosses and guardians.", function() local d = SS.DB(); d.modernEnemyFrames, d.enemyBossesOnly = true, true; end },
		{ "All enemies", "Plates over everything; groups of the same monster share one box.",
			function() local d = SS.DB(); d.modernEnemyFrames, d.enemyBossesOnly, d.enemyPlateGroup = true, false, true; end } } },
	{ "Sounds?", {
		{ "Off", "No Slim Suite sounds.", function() SetKeys(SOME_SOUNDS, false); SetKeys(MORE_SOUNDS, false); end },
		{ "A few", "Deaths, revives, the final boss and victory.", function() SetKeys(SOME_SOUNDS, true); SetKeys(MORE_SOUNDS, false); end },
		{ "All", "Also low health, boss hits, chests and match start and loss.", function() SetKeys(SOME_SOUNDS, true); SetKeys(MORE_SOUNDS, true); end } } },
	{ "Text size?", {
		{ "Normal", "The usual size.", function() local d = SS.DB(); d.accessibilityLargeText, d.accessibilityContrast = false, false; end },
		{ "Large", "Bigger encounter names.", function() local d = SS.DB(); d.accessibilityLargeText, d.accessibilityContrast = true, false; end },
		{ "Large, high contrast", "Bigger names and stronger bar colours.", function() local d = SS.DB(); d.accessibilityLargeText, d.accessibilityContrast = true, true; end } } },
};

local win, step, picks, presets, preset;

-- applies every answer once, then refreshes what they touch
function SS.ApplyQuickAnswers(answers)
	if ( SU ) then SU.batching = true; end
	for i, q in ipairs(SS.QUICK_QUESTIONS) do
		local a = answers[i] and q[2][answers[i]];
		if ( a ) then SS.Safe(a[3]); end
	end
	if ( SU ) then SU.batching = false; end
	if ( PlaceAll ) then SS.Safe(PlaceAll); end
	for _, fn in ipairs({ SS.RefreshLooks, SS.UpdateEnemyNameplates, SS.UpdateBossFrames, SS.UpdatePartyStatus }) do if ( fn ) then SS.Safe(fn); end end
	if ( SS.RefreshHudThemeButtons ) then SS.Safe(SS.RefreshHudThemeButtons); end
	if ( SS.LogAction ) then SS.LogAction("Quick setup applied"); end
end

local PICTURES = "Interface\\AddOns\\SlimSuite\\textures\\quick\\";
-- shows one picture by name (q<question>_<answer> or preset<n>); a missing file shows "No picture yet"
function SS.QuickPicture(name)
	if ( not win ) then return; end
	local ok = name and win.pic:SetTexture(PICTURES .. name);
	if ( ok ) then win.pic:Show(); win.noPic:Hide(); else win.pic:Hide(); win.noPic:Show(); end
	if ( name ) then win.picFrame:Show(); else win.picFrame:Hide(); win.noPic:Hide(); end
end

local Show;
local function Build()
	win = K.Window("SlimSuiteQuickSetup", "Slim Suite quick setup", 600, 340);
	win.count = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
	win.count:SetPoint("TOPRIGHT", win, "TOPRIGHT", -34, -16);
	win.question = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	win.question:SetPoint("TOP", win, "TOP", 0, -40); win.question:SetWidth(560);
	win.note = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
	win.note:SetPoint("BOTTOM", win, "BOTTOM", 0, 48); win.note:SetWidth(540);
	win.note:SetText("Change anything afterwards in HUD Edit.");
	win.note:Hide();
	win.answers = {};
	for i = 1, 6 do
		local b = K.Button(win, "", 150, function()
			if ( step == 0 ) then
				preset = presets[this.index];        -- nil: "No, set it up myself"
				step = preset and (table.getn(SS.QUICK_QUESTIONS) + 1) or 1;
			else picks[step] = this.index; step = step + 1; end
			Show();
		end);
		b:SetPoint("TOPLEFT", win, "TOPLEFT", 24, -72 - (i - 1) * 40);
		b.index = i;
		b:SetScript("OnEnter", function() SS.QuickPicture(this.picture); end);
		b:SetScript("OnLeave", function() SS.QuickPicture(win.restPicture); end);
		b.help = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		b.help:SetPoint("LEFT", b, "RIGHT", 8, 0); b.help:SetWidth(170); b.help:SetJustifyH("LEFT");
		win.answers[i] = b;
	end
	-- the picture of the hovered (or chosen) answer: an in-game screenshot made with tools/quick-image.py
	win.pic = win:CreateTexture(nil, "ARTWORK");
	win.pic:SetWidth(240); win.pic:SetHeight(120);
	win.pic:SetPoint("TOPRIGHT", win, "TOPRIGHT", -20, -74);
	win.picFrame = win:CreateTexture(nil, "BORDER");
	win.picFrame:SetTexture(0, 0, 0, 0.6);
	win.picFrame:SetPoint("TOPLEFT", win.pic, "TOPLEFT", -2, 2); win.picFrame:SetPoint("BOTTOMRIGHT", win.pic, "BOTTOMRIGHT", 2, -2);
	win.noPic = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
	win.noPic:SetPoint("CENTER", win.pic, "CENTER", 0, 0); win.noPic:SetText("No picture yet");
	win.summary = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	win.summary:SetPoint("TOPLEFT", win, "TOPLEFT", 28, -70); win.summary:SetWidth(300); win.summary:SetJustifyH("LEFT");
	win.back = K.Button(win, SS.T("Back"), 90, function()
		if ( preset ) then preset = nil; step = 0;
		elseif ( step > 1 ) then step = step - 1;
		elseif ( table.getn(presets) > 0 ) then step = 0; end
		Show();
	end);
	win.back:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 20, 18);
	win.finish = K.Button(win, "Apply", 110, function()
		win:Hide();
		if ( preset ) then
			if ( SS.ApplyPreset(preset) ) then K.Print(NAME, "preset design \"" .. preset[1] .. "\" applied. Change anything you like in HUD Edit.");
			else K.Print(NAME, "that preset design could not be read."); end
			return;
		end
		SS.ApplyQuickAnswers(picks);
		K.Print(NAME, "quick setup applied. Every setting can still be changed one by one in HUD Edit.");
	end);
	win.finish:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -20, 18);
end

Show = function()
	if ( win.note ) then win.note:Hide(); end
	local total = table.getn(SS.QUICK_QUESTIONS);
	if ( step == 0 ) then
		win.count:SetText(""); win.question:SetText("Would you like to use a pre-set design?"); win.note:Show();
		win.summary:Hide(); win.finish:Hide();
		local n = table.getn(presets);
		for i = 1, 6 do
			local b = win.answers[i];
			b.picture = nil;
			if ( i <= n ) then b:SetText(presets[i][1]); b.help:SetText(presets[i][2] or ""); b:Show(); b.help:Show(); b.picture = presets[i].picture;
			elseif ( i == n + 1 ) then b:SetText("No thanks"); b.help:SetText("Answer a few questions instead."); b:Show(); b.help:Show();
			else b:Hide(); b.help:Hide(); end
			b:UnlockHighlight();
		end
	elseif ( step > total and preset ) then
		win.count:SetText(""); win.question:SetText("Ready to apply");
		win.summary:SetText("Preset design: |cffffd100" .. preset[1] .. "|r\n\n" .. (preset[2] or "") ..
			"\n\nThis replaces your current layout: where elements sit, their sizes and their options.");
		win.summary:Show();
		for i = 1, 6 do win.answers[i]:Hide(); win.answers[i].help:Hide(); end
		win.finish:Show();
	elseif ( step > total ) then
		win.count:SetText(""); win.question:SetText("Ready to apply");
		local lines = {};
		for i, q in ipairs(SS.QUICK_QUESTIONS) do table.insert(lines, q[1] .. "  |cffffd100" .. q[2][picks[i]][1] .. "|r"); end
		table.insert(lines, ""); table.insert(lines, "This changes those settings once. Where your elements are placed stays as it is.");
		win.summary:SetText(table.concat(lines, "\n")); win.summary:Show();
		for i = 1, 6 do win.answers[i]:Hide(); win.answers[i].help:Hide(); end
		win.finish:Show();
	else
		local q = SS.QUICK_QUESTIONS[step];
		win.count:SetText(step .. " / " .. total);
		win.question:SetText(q[1]);
		win.summary:Hide(); win.finish:Hide();
		for i = 1, 6 do
			local b, a = win.answers[i], q[2][i];
			b.picture = "q" .. step .. "_" .. i;
			if ( a ) then
				b:SetText(a[1]); b.help:SetText(a[2]); b:Show(); b.help:Show();
				if ( picks[step] == i ) then b:LockHighlight(); else b:UnlockHighlight(); end
			else b:Hide(); b.help:Hide(); end
		end
	end
	if ( step > 1 or (step == 1 and table.getn(presets) > 0) ) then win.back:Show(); else win.back:Hide(); end
	-- at rest: the chosen answer's picture, else the first answer's; none on the summary pages
	if ( step == 0 ) then win.restPicture = win.answers[1].picture;
	elseif ( step > table.getn(SS.QUICK_QUESTIONS) ) then win.restPicture = preset and preset.picture or nil;
	else win.restPicture = "q" .. step .. "_" .. (picks[step] or 1); end
	SS.QuickPicture(win.restPicture);
end

function SS.OpenQuickSetup()
	if ( not win ) then Build(); end
	presets = SS.UsablePresets and SS.UsablePresets() or {};
	preset = nil; picks = {};
	step = table.getn(presets) > 0 and 0 or 1;
	Show(); win:Show();
end
