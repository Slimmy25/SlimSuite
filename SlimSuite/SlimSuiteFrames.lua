-- Slim Suite: the HUD elements: level-up button, encounter bars, announcements, buffs, XP bar, party and target frames.
if ( setfenv ) then setfenv(1, SS.ENV); end   -- Slim Suite's files share one set of private names (SS.ENV, in SlimSuiteCore.lua)

-- AZS_SetHudShown stores native HUD visibility in the game's saved interface settings. Every part Slim Suite hid is
-- put back before a clean logout or reload, so disabling Slim Suite in the AddOns screen cannot leave the game's own
-- controls hidden on the next launch (SS.RestoreNatives, in SlimSuiteCore.lua).
nativeHudShutdown = CreateFrame("Frame");
nativeHudShutdown:RegisterEvent("PLAYER_LOGOUT");
nativeHudShutdown:SetScript("OnEvent", function() SS.Safe(SS.RestoreNatives); end);

-- The native Level Up control uses the class symbol from WoW's character-create atlas.
-- Keep this 1.12 mapping local because CLASS_ICON_TCOORDS is not consistently global in
-- Vanilla clients/addon environments.
LEVEL_CLASS_ICON_COORDS = {
	WARRIOR = { 0, 0.25, 0, 0.25 },
	MAGE = { 0.25, 0.5, 0, 0.25 },
	ROGUE = { 0.5, 0.75, 0, 0.25 },
	DRUID = { 0.75, 1, 0, 0.25 },
	HUNTER = { 0, 0.25, 0.25, 0.5 },
	SHAMAN = { 0.25, 0.5, 0.25, 0.5 },
	PRIEST = { 0.5, 0.75, 0.25, 0.5 },
	WARLOCK = { 0.75, 1, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 }
};

function SS.PlayerClassIconCoords()
	if ( type(UnitClass) ~= "function" ) then return nil; end
	local localized, english = UnitClass("player");
	local key = string.upper(tostring(english or localized or ""));
	return LEVEL_CLASS_ICON_COORDS[key];
end

function SS.CreateLevelButton()
	levelButton = CreateFrame("Button", "SlimSuiteStoredLevelsButton", UIParent);
	levelButton:SetWidth(184);
	levelButton:SetHeight(58);
	levelButton:SetFrameStrata("MEDIUM");
	levelButton:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	levelButton:SetBackdropColor(0.13, 0.055, 0.025, 0.98);
	levelButton:SetBackdropBorderColor(0.82, 0.61, 0.24, 1);
	levelButton:EnableMouse(true);
	-- Keep a faint gold halo behind the button, like the game's own level-up control.
	-- This is a region of the button itself, so it follows saved position, scale, and hover growth.
	levelButton.glow = levelButton:CreateTexture(nil, "BACKGROUND");
	levelButton.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border");
	if ( levelButton.glow.SetBlendMode ) then levelButton.glow:SetBlendMode("ADD"); end
	levelButton.glow:SetVertexColor(1, 0.72, 0.22, 0.16);
	levelButton.glow:SetPoint("CENTER", levelButton, "CENTER", 0, 0);
	levelButton.glow:SetWidth(228);
	levelButton.glow:SetHeight(82);
	levelButton.glow:SetAlpha(0.16);
	levelButton.classIcon = levelButton:CreateTexture(nil, "ARTWORK");
	levelButton.classIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes");
	levelButton.classIcon:SetPoint("LEFT", levelButton, "LEFT", 10, 0);
	levelButton.classIcon:SetWidth(40);
	levelButton.classIcon:SetHeight(40);
	local classCoords = SS.PlayerClassIconCoords();
	if ( classCoords ) then
		levelButton.classIcon:SetTexCoord(classCoords[1], classCoords[2], classCoords[3], classCoords[4]);
	else
		levelButton.classIcon:Hide();
	end
	levelButton.level = levelButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	levelButton.level:SetPoint("TOPLEFT", levelButton, "TOPLEFT", 58, -10);
	levelButton.level:SetTextColor(1, 0.78, 0.22);
	levelButton.text = levelButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	levelButton.text:SetPoint("BOTTOMLEFT", levelButton, "BOTTOMLEFT", 58, 8);
	levelButton.text:SetText(SS.T("LEVEL UP!"));
	levelButton:SetScript("OnClick", function()
		if ( type(AZS_OpenStoredLevels) == "function" ) then SS.Safe(AZS_OpenStoredLevels); end
	end);
	levelButton.count = levelButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	levelButton.count:SetPoint("TOPRIGHT", levelButton.classIcon, "TOPRIGHT", 7, 7);
	levelButton.count:SetTextColor(1, 0.78, 0.18);
	local function LevelButtonBaseScale()
		local base = type(SS.DB().scales.SlimSuiteStoredLevelsButton) == "number" and SS.DB().scales.SlimSuiteStoredLevelsButton or 1;
		return SS.DisplayElementScale and SS.DisplayElementScale("SlimSuiteStoredLevelsButton", base) or base;
	end
	local function CaptureLevelButtonPoints()
		local points = {};
		for i = 1, levelButton:GetNumPoints() do
			local point, relative, relativePoint, x, y = levelButton:GetPoint(i);
			points[i] = { point, relative, relativePoint, x, y };
		end
		return points;
	end
	local function RestoreLevelButtonPoints(points)
		levelButton:ClearAllPoints();
		for i = 1, table.getn(points or {}) do
			local p = points[i]; levelButton:SetPoint(p[1], p[2], p[3], p[4], p[5]);
		end
	end
	local function GrowLevelButtonInPlace()
		-- SetScale grows from the frame's anchor, which made the button appear to slide away
		-- from its resting location. Preserve its visual center while the hover scale changes.
		if ( not levelButton.hoverPoints ) then levelButton.hoverPoints = CaptureLevelButtonPoints(); end
		local left, right, bottom, top = RootBounds(levelButton);
		if ( not left or not right or not bottom or not top ) then return; end
		local centerX, centerY = (left + right) / 2, (bottom + top) / 2;
		levelButton:SetScale(LevelButtonBaseScale() * 1.06);
		local newLeft, newRight, newBottom, newTop = RootBounds(levelButton);
		if ( newLeft and newRight and newBottom and newTop ) then
			SetRootPosition(levelButton, centerX - (newRight - newLeft) / 2, centerY - (newTop - newBottom) / 2);
		end
	end
	local function RestoreLevelButtonAfterHover()
		levelButton:SetScale(LevelButtonBaseScale());
		if ( levelButton.hoverPoints ) then
			RestoreLevelButtonPoints(levelButton.hoverPoints);
			levelButton.hoverPoints = nil;
		end
	end
	levelButton:SetScript("OnEnter", function()
		GrowLevelButtonInPlace();
		levelButton.glow:SetAlpha(0.24);
	end);
	levelButton:SetScript("OnLeave", function()
		RestoreLevelButtonAfterHover();
		levelButton.glow:SetAlpha(0.16);
	end);
	levelButton:SetScript("OnHide", function()
		RestoreLevelButtonAfterHover();
		levelButton.glow:SetAlpha(0.16);
	end);
	-- Above the default action bar, centered near the bottom as in the supplied reference.
	levelButton:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190);
	levelButton:Hide();
	-- A tiny toggle to the right of the button: store level-ups or take them as they come (AZS_SetStoringLevels).
	-- It is its own frame, anchored to the button: it shows in a run while there are points to spend (a choice open, or
	-- levels stored) and while the button is being placed.
	local store = CreateFrame("CheckButton", "SlimSuiteStoreLevelsToggle", UIParent, "UICheckButtonTemplate");
	store:SetWidth(20); store:SetHeight(20);
	store:SetPoint("LEFT", levelButton, "RIGHT", 2, 0);
	store:SetFrameStrata("MEDIUM");
	store:SetScript("OnClick", function()
		if ( type(AZS_SetStoringLevels) == "function" ) then SS.Safe(AZS_SetStoringLevels, this:GetChecked() and true or false); end
		SS.Safe(SS.UpdateLevelButton);
	end);
	store:SetScript("OnEnter", function()
		if ( not GameTooltip ) then return; end
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
		GameTooltip:AddLine("Store level-ups", 1, 0.82, 0);
		GameTooltip:AddLine(this:GetChecked() and "On: level-ups wait here until you spend them." or "Off: level-up choices open as soon as you level.", 1, 1, 1, 1);
		GameTooltip:Show();
	end);
	store:SetScript("OnLeave", function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
	store:Hide();
	levelButton.store = store;
end

function SS.ClockText(seconds)
	if ( type(seconds) ~= "number" or seconds < 0 ) then return "--:--"; end
	seconds = math.floor(seconds);
	return string.format("%02d:%02d", math.floor(seconds / 60), math.mod(seconds, 60));
end

function SS.ApplyClockLayout()
	if ( not clockFrame or not clockFrame.time or not clockFrame.next ) then return; end
	local orientation = SS.DB().orientations.SlimSuiteClockFrame;
	if ( orientation ~= "horizontal" ) then orientation = "vertical"; end
	local padding = SS.FramePadding("SlimSuiteClockFrame");
	if ( orientation == "vertical" ) then
		clockFrame.time:ClearAllPoints();
		clockFrame.time:SetPoint("TOP", clockFrame, "TOP", 0, -padding);
		clockFrame.timeW = math.max(10, clockFrame:GetWidth() - (padding * 2));
		clockFrame.nextW = clockFrame.timeW;
		clockFrame.time:SetWidth(clockFrame.timeW);
		clockFrame.time:SetJustifyH("CENTER");
		clockFrame.next:ClearAllPoints();
		clockFrame.next:SetPoint("TOP", clockFrame.time, "BOTTOM", 0, -(2 + padding));
		clockFrame.next:SetWidth(clockFrame.nextW);
		clockFrame.next:SetJustifyH("CENTER");
	else
		clockFrame.time:ClearAllPoints();
		clockFrame.time:SetPoint("LEFT", clockFrame, "LEFT", 4 + padding, 0);
		clockFrame.timeW = math.max(30, (clockFrame:GetWidth() - (padding * 2)) * 0.34);
		clockFrame.nextW = math.max(10, clockFrame:GetWidth() - (4 + padding) * 2 - clockFrame.timeW - (8 + padding));
		clockFrame.time:SetWidth(clockFrame.timeW);
		clockFrame.time:SetJustifyH("RIGHT");
		clockFrame.next:ClearAllPoints();
		clockFrame.next:SetPoint("LEFT", clockFrame.time, "RIGHT", 8 + padding, 0);
		clockFrame.next:SetPoint("RIGHT", clockFrame, "RIGHT", -(4 + padding), 0);
		clockFrame.next:SetJustifyH("LEFT");
	end
end

function SS.CreateClockFrame()
	clockFrame = CreateFrame("Frame", "SlimSuiteClockFrame", UIParent);
	clockFrame:SetWidth(220);
	clockFrame:SetHeight(54);
	clockFrame:SetPoint("TOP", UIParent, "TOP", 0, -6);
	clockFrame:SetFrameStrata("MEDIUM");
	clockFrame:EnableMouse(false);
	clockFrame.time = clockFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	clockFrame.time:SetPoint("TOP", clockFrame, "TOP", 0, 0);
	clockFrame.time:SetWidth(220);
	clockFrame.time:SetJustifyH("CENTER");
	clockFrame.time:SetTextColor(1, 0.82, 0.28);
	clockFrame.next = clockFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	clockFrame.next:SetPoint("TOP", clockFrame.time, "BOTTOM", 0, -2);
	clockFrame.next:SetWidth(220);
	clockFrame.next:SetJustifyH("CENTER");
	clockFrame.next:SetTextColor(0.74, 0.72, 0.66);
	-- The zone line (AZS_ZONE): where you are and the run's Heroic affixes, just under the clock.
	clockFrame.zone = clockFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	clockFrame.zone:SetPoint("TOP", clockFrame, "BOTTOM", 0, -1);
	clockFrame.zone:SetTextColor(0.85, 0.75, 0.55);
	-- Both lines share one parent and one movement handle; they cannot be separated while repositioning.
	SS.ApplyClockLayout();
	clockFrame:Hide();
end

function SS.BossPriority(unit)
	local kind = UnitKind(unit);
	if ( kind == "final" ) then return 1; end
	if ( kind == "boss" ) then return 2; end
	if ( kind == "guardian" ) then return 3; end
	if ( kind == "elite" ) then return 4; end
	return nil;
end

function SS.EncounterVertical()
	return SS.DB().orientations.SlimSuiteBossFrames == "vertical";
end

function SS.EncounterBarThickness()
	local value = SS.DB().encounterBarThickness;
	if ( value == "compact" ) then return 8; end
	if ( value == "thick" ) then return 16; end
	return 12;
end

function SS.SetGameDefaultFont(fontString, size)
	-- Slim Suite uses WoW's standard 1.12 UI typeface throughout, including custom HUD labels.
	local defaultFont = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF";
	if ( fontString.slimFontSize == size ) then return; end   -- set already
	fontString.slimFontSize = size;
	local ok, result = SS.Safe(fontString.SetFont, fontString, defaultFont, size);
	if ( not ok or result == false ) then SS.Safe(fontString.SetFont, fontString, "Fonts\\FRIZQT__.TTF", size); end
end

function SS.EncounterList()
	-- AZS_UNITS carries live hp/hpm for bosses, guardians and elites; the game updates it before the AZSUNITS event.
	local units = type(AZS_UNITS) == "table" and AZS_UNITS or {};
	local list = {};
	for i = 1, table.getn(units) do
		local unit = units[i];
		local priority = type(unit) == "table" and SS.BossPriority(unit) or nil;
		local awake = type(unit) == "table" and (UnitKind(unit) ~= "guardian" or unit.state == 1);
		if ( priority and awake and type(unit.id) == "number" and type(unit.name) == "string"
			and type(unit.hp) == "number" and type(unit.hpm) == "number" and unit.hp > 0 and unit.hpm > 0 ) then
			table.insert(list, { id = unit.id, name = unit.name, kind = UnitKind(unit), hp = unit.hp, hpm = unit.hpm, priority = priority, order = i });
		end
	end
	table.sort(list, function(a, b)
		if ( a.priority ~= b.priority ) then return a.priority < b.priority; end
		return a.order < b.order;
	end);
	return list;
end

function SS.ClampAbsoluteFrame(name, f)
	if ( not f or SS.DB().unlocked ) then return; end
	local saved = SS.DB().places[name];
	if ( type(saved) == "table" and saved.relative ) then return; end
	local x, right, y = RootBounds(f);
	if ( x == nil and type(saved) == "table" ) then x = saved.x; end
	if ( y == nil and type(saved) == "table" ) then y = saved.y; end
	if ( type(x) ~= "number" or type(y) ~= "number" ) then return; end
	local nx, ny = SS.ClampPosition(f, x, y);
	if ( nx ~= x or ny ~= y ) then
		SetRootPosition(f, nx, ny);
	end
end

function SS.EncounterRow(index)
	if ( encounterRows[index] ) then return encounterRows[index]; end
	local row = CreateFrame("Button", nil, bossFrame);
	row:SetWidth(520);
	row:SetHeight(48);
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -2);
	-- the boss's raid mark (the same one over its head and on the minimap), left of its name
	row.mark = row:CreateTexture(nil, "OVERLAY");
	row.mark:SetWidth(18); row.mark:SetHeight(18);
	row.mark:SetPoint("RIGHT", row.name, "LEFT", -2, 0);
	row.mark:Hide();
	row.name:SetWidth(176);
	row.name:SetHeight(22);
	row.name:SetJustifyH("LEFT");
	row.name:SetJustifyV("TOP");
	row.name:SetNonSpaceWrap(true);
	SS.SetGameDefaultFont(row.name, 10);
	row.name:SetTextColor(1, 0.22, 0.16);
	row.bar = CreateFrame("StatusBar", nil, row);
	row.bar:SetWidth(176);
	row.bar:SetHeight(8);
	row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -28);
	row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
	row.bar:SetStatusBarColor(0.9, 0.06, 0.025, 1);
	row.bar:SetMinMaxValues(0, 1);
	row.bar:SetValue(1);
	row.bar.background = row.bar:CreateTexture(nil, "BACKGROUND");
	row.bar.background:SetTexture("Interface\\TargetingFrame\\UI-StatusBar");
	row.bar.background:SetAllPoints(row.bar);
	row.bar.background:SetVertexColor(0.04, 0.015, 0.01, 0.9);
	row:EnableMouse(true);
	row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square");
	row:SetScript("OnClick", function()
		local unit = this.unit;
		if ( not unit or not unit.name or not TargetByName ) then return; end
		-- The encounter API exposes stable IDs for health tracking, but the client target API
		-- selects visible units by name. Ask it for this exact name and leave range/visibility
		-- rejection to the game; never retarget a different nearby enemy as a fallback.
		SS.Safe(TargetByName, unit.name, true);
	end);
	row:SetScript("OnEnter", function()
		if ( not this.unit or not GameTooltip ) then return; end
		if ( GameTooltip.SetClampedToScreen ) then GameTooltip:SetClampedToScreen(true); end
		local center = this:GetCenter();
		local onRight = center and center * RootFactor(this) > (UIParent:GetWidth() / 2);
		GameTooltip:SetOwner(this, onRight and "ANCHOR_LEFT" or "ANCHOR_RIGHT");
		GameTooltip:AddLine(this.unit.name .. "  [" .. (this.unit.kind == "guardian" and "Guardian" or (this.unit.kind == "elite" and "Elite" or "Boss")) .. "]");
		GameTooltip:AddLine("Health: " .. tostring(math.floor(this.unit.hp)) .. " / " .. tostring(math.floor(this.unit.hpm)), 1, 0.82, 0);
		GameTooltip:AddLine("Click to target", 0.75, 0.75, 0.75);
		GameTooltip:Show();
	end);
	row:SetScript("OnLeave", function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
	encounterRows[index] = row;
	return row;
end

function SS.UpdateEncounterRows(list)
	local count = table.getn(list);
	if ( count == 0 ) then return 0; end
	local vertical = SS.EncounterVertical();
	local padding = SS.FramePadding("SlimSuiteBossFrames");
	local gap = (vertical and 10 or 8) + padding;
	local configured = SS.DB().sizes.SlimSuiteBossFrames;
	local barThickness = SS.EncounterBarThickness();
	-- Match the default boss target-frame scale shown in the reference: a readable, substantial
	-- nameplate and health bar rather than a tiny floating strip. Cards still distribute evenly
	-- when several enemies are active.
	local defaultCardWidth = vertical and 48 or 520;
	local cardMinW, cardMinH = SS.MinSize("SlimSuiteBossFrames");
	local minCardWidth = cardMinW;   -- a floor only: the default width is still 520 per boss
	-- side by side (vertical cards) the width holds every card; as rows (one under the other) each row is the whole
	-- width, so the width is one card's, not one per boss (that made the frame and its handle run off the screen)
	local across = vertical and count or 1;
	local minimumFrameWidth = across * minCardWidth + ((across - 1) * gap) + (padding * 2);
	local frameWidth = type(configured) == "table" and configured.w or (across * defaultCardWidth + ((across - 1) * gap) + (padding * 2));
	local screen = (UIParent and UIParent:GetWidth()) or 1024;
	if ( frameWidth > screen * 0.9 ) then frameWidth = across * defaultCardWidth + ((across - 1) * gap) + (padding * 2); end   -- an old, too-wide saved size
	frameWidth = math.min(math.max(minimumFrameWidth, frameWidth), screen * 0.9);
	local cardWidth = math.max(minCardWidth, (frameWidth - (padding * 2) - ((across - 1) * gap)) / across);
	frameWidth = across * cardWidth + ((across - 1) * gap) + (padding * 2);
	local frameHeight = type(configured) == "table" and configured.h or (vertical and 252 or (count * 48));
	local minimumHeight = vertical and cardMinH or math.max(count * (24 + padding + barThickness + 4) + padding * 2, cardMinH);
	frameHeight = math.max(minimumHeight, frameHeight);
	bossFrame:SetWidth(frameWidth);
	bossFrame:SetHeight(frameHeight);
	local rowHeight = vertical and math.max(58, frameHeight - (padding * 2)) or math.max(42, (frameHeight - (padding * 2)) / count);
	-- the rows are laid out again only when what decides their places changes (the bosses, their kinds, the size or
	-- layout); otherwise only health and debuffs are drawn
	local d = SS.DB();
	local nameAlign = d.encounterNameAlign == "left" and "LEFT" or (d.encounterNameAlign == "right" and "RIGHT" or "CENTER");
	local largeNames = d.accessibilityLargeText and true or false;
	local highContrast = d.accessibilityContrast and true or false;
	local sig = (vertical and "v" or "h") .. padding .. "|" .. cardWidth .. "|" .. rowHeight .. "|" .. nameAlign .. "|" .. barThickness .. "|" .. tostring(largeNames);
	for i = 1, count do sig = sig .. "|" .. tostring(list[i].name) .. tostring(list[i].kind); end
	local relayout = bossFrame.sig ~= sig;
	bossFrame.sig = sig;
	for i = 1, table.getn(list) do
		local unit = list[i];
		local row = SS.EncounterRow(i);
		row.unit = unit;
		if ( relayout ) then
		row:SetWidth(cardWidth);
		row:SetHeight(rowHeight);
		row.name:ClearAllPoints();
		row.bar:ClearAllPoints();
		row:ClearAllPoints();
		row:SetPoint("TOPLEFT", bossFrame, "TOPLEFT", vertical and (padding + ((i - 1) * (cardWidth + gap))) or padding, -(padding + (vertical and 0 or ((i - 1) * rowHeight))));
		row.name:SetText(unit.name);
		if ( vertical ) then
			SS.SetGameDefaultFont(row.name, largeNames and 10.5 or 8.5);
			local barTopOffset = 34 + padding;
			-- Match the narrow, evenly spaced columns in the reference. Each boss name stays above its own bar.
			row.name:SetWidth(cardWidth);
			row.name:SetHeight(30);
			row.name:SetJustifyH(nameAlign);
			row.name:SetPoint("TOP", row, "TOP", 0, -(2 + padding));
			if ( row.bar.SetOrientation ) then SS.Safe(row.bar.SetOrientation, row.bar, "VERTICAL"); end
			row.bar:SetWidth(barThickness);
			row.bar:SetHeight(math.max(18, rowHeight - barTopOffset - padding));
			row.bar:SetPoint("TOP", row, "TOP", 0, -barTopOffset);
		else
			SS.SetGameDefaultFont(row.name, largeNames and 16 or 14);
			row.name:SetWidth(cardWidth - 8 - (padding * 2));
			row.name:SetHeight(22);
			row.name:SetJustifyH(nameAlign);
			row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 4 + padding, -(2 + padding));
			if ( row.bar.SetOrientation ) then SS.Safe(row.bar.SetOrientation, row.bar, "HORIZONTAL"); end
			local width = math.max(20, cardWidth - 8 - (padding * 2));
			row.bar:SetWidth(unit.kind == "guardian" and math.max(20, width * 0.78) or width);
			row.bar:SetHeight(barThickness);
			row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 4 + padding, -(24 + padding));
		end
		end
		-- Keep the StatusBar range small and stable. Raw boss HP can be very large, and using it as
		-- the range can hide small health changes at the UI's numeric precision; show the live fraction.
		local mark = SlimSuiteWorld and SlimSuiteWorld.MarkFor and SlimSuiteWorld.MarkFor(unit.id);
		if ( mark and SlimSuiteWorld.SetRaidIcon ) then
			SlimSuiteWorld.SetRaidIcon(row.mark, mark);
			row.mark:ClearAllPoints();
			if ( vertical ) then row.mark:SetPoint("BOTTOM", row.name, "TOP", 0, 0);
			else
				-- Keep the horizontal marker completely above the health bar. The previous center-relative
				-- offset placed its lower half over the bar, especially on short rows.
				row.mark:SetPoint("BOTTOMLEFT", row, "TOPLEFT", 4 + padding, -(23 + padding));
			end
			row.mark:Show();
		else row.mark:Hide(); end
		local health = math.max(0, math.min(1, unit.hp / unit.hpm));
		if ( highContrast ) then
			row.bar:SetStatusBarColor(1, 0.82, 0.12, 1);
			row.bar.background:SetVertexColor(0.01, 0.01, 0.04, 1);
			row.name:SetTextColor(1, 1, 1);
		else
			row.bar:SetStatusBarColor(0.9, 0.06, 0.025, 1);
			row.bar.background:SetVertexColor(0.04, 0.015, 0.01, 0.9);
			row.name:SetTextColor(1, 0.22, 0.16);
		end
		row.bar:SetMinMaxValues(0, 1);
		row.bar:SetValue(health);
		if ( SlimSuiteWorld and SlimSuiteWorld.DrawDebuffs ) then
			SS.Safe(SlimSuiteWorld.DrawDebuffs, row, unit, vertical, SS.DB().encounterDebuffs);
		end
		row:Show();
	end
	for i = table.getn(list) + 1, table.getn(encounterRows) do encounterRows[i]:Hide(); end
	return frameHeight;
end

-- AZS_ZONE (0.87; affixes added in 0.124): the zone, how long it lasts, and the run's Heroic affixes as lowercase
-- English words ("sanguine,explosive"). Shown as "Zone  -  Sanguine, Explosive".
function SS.ZoneText()
	local z = type(AZS_ZONE) == "table" and AZS_ZONE or nil;
	if ( not z ) then return nil; end
	local name = z.name or z.zone or z.title;
	local affixes = z.affixes;
	local list = {};
	if ( type(affixes) == "string" ) then
		for word in string.gfind(affixes, "[^,%s]+") do table.insert(list, word); end
	elseif ( type(affixes) == "table" ) then
		for i = 1, table.getn(affixes) do if ( type(affixes[i]) == "string" ) then table.insert(list, affixes[i]); end end
	end
	for i = 1, table.getn(list) do list[i] = string.upper(string.sub(list[i], 1, 1)) .. string.sub(list[i], 2); end
	local text = type(name) == "string" and name or "";
	if ( table.getn(list) > 0 ) then text = (text ~= "" and (text .. "  -  ") or "") .. table.concat(list, ", "); end
	if ( text == "" ) then return nil; end
	return text;
end

function SS.UpdateClock()
	if not SS.DB().replaceClock then if clockFrame then clockFrame:Hide();end;SS.HideNative("clock", false);return;end
	if ( not clockFrame ) then return; end
	local phase = type(AZS_GetPhase) == "function" and AZS_GetPhase() or nil;
	local live = phase == "ready" or phase == "playing" or phase == "choosing" or phase == "paused";
	-- This movable replacement must not inherit the native clock's independent HUD visibility flag.
	local showClock = live;
	local preview = not showClock;
	if ( showClock ) then
		local elapsed = type(AZS_GetRunTime) == "function" and AZS_GetRunTime() or nil;
		if ( phase == "ready" ) then elapsed = 0; end
		clockFrame.time:SetText(SS.ClockText(elapsed));
		local upcoming = {};
		if ( type(AZS_GetUpcomingBosses) == "function" ) then
			local ok, value = SS.Safe(AZS_GetUpcomingBosses);
			if ( ok and type(value) == "table" ) then upcoming = value; end
		end
		local left = type(upcoming[1]) == "table" and upcoming[1].left or nil;
		local run = type(AZS_RUN) == "table" and AZS_RUN or nil;
		if ( type(left) ~= "number" and run and type(run.nb) == "number" and run.nb >= 0 ) then left = run.nb; end
		if ( type(left) == "number" and left >= 0 ) then
			clockFrame.next:SetText(SS.T("next boss in") .. " " .. SS.ClockText(math.ceil(left)));
		else
			clockFrame.next:SetText(SS.T("next boss in") .. " --:--");
		end
		SS.HideNative("clock", true);
		clockFrame.time:Show();
		clockFrame.next:Show();
	else
		SS.HideNative("clock", false);
		if ( preview and SS.Demoing("SlimSuiteClockFrame") and SS.demoClock ) then
			-- Demo Mode: the run time counts up from a random start; the (made-up) next boss counts down and starts over
			clockFrame.time:SetText(SS.ClockText(math.floor(SS.demoClock.run)));
			clockFrame.next:SetText(SS.T("next boss in") .. " " .. SS.ClockText(math.ceil(SS.demoClock.nextBoss)));
			clockFrame.time:Show(); clockFrame.next:Show();
		elseif ( preview ) then
			clockFrame.time:SetText("00:00");
			clockFrame.next:SetText(SS.T("next boss in") .. " --:--");
			clockFrame.time:Show();
			clockFrame.next:Show();
		else
			clockFrame.time:Hide();
			clockFrame.next:Hide();
		end
	end
	if ( clockFrame.zone ) then
		-- the sample zone line only while the clock is being placed or in Demo Mode; otherwise only the game's own
		local zone = SS.DB().zoneLine and (SS.ZoneText() or (SS.Previewing("SlimSuiteClockFrame") and "Scholomance  -  Sanguine, Explosive")) or nil;
		if ( zone and (showClock or preview) ) then clockFrame.zone:SetText(zone); clockFrame.zone:Show(); else clockFrame.zone:Hide(); end
	end
	SS.FitText(clockFrame.time, clockFrame.timeW);
	SS.FitText(clockFrame.next, clockFrame.nextW);
	if ( clockFrame.zone ) then SS.FitText(clockFrame.zone, math.max(clockFrame:GetWidth() or 0, 60)); end
	if ( showClock or preview ) then
		clockFrame:Show();
		SS.ClampAbsoluteFrame("SlimSuiteClockFrame", clockFrame);
	else clockFrame:Hide(); end
end

function SS.UpdateBossFrames()
	if not SS.DB().replaceEncounters then if bossFrame then bossFrame:Hide();end;SS.HideNative("bosses", false);return;end
	if ( not bossFrame ) then return; end
	local phase = type(AZS_GetPhase) == "function" and AZS_GetPhase() or nil;
	local live = phase == "playing" or phase == "choosing" or phase == "paused";
	-- The replacement is driven by the documented AZS_UNITS data, independently of whether the
	-- player had the native boss frames enabled. Visibility of the original HUD must not gate ours.
	if ( live ) then
		local list = SS.EncounterList();
		local height = SS.UpdateEncounterRows(list);
		if ( height > 0 ) then
			bossFrame:SetHeight(height);
			SS.ClampAbsoluteFrame("SlimSuiteBossFrames", bossFrame);
			SS.HideNative("bosses", true);
			bossFrame:Show();
		else
			SS.HideNative("bosses", false);
			bossFrame:Hide();
		end
	elseif ( SS.Previewing("SlimSuiteBossFrames") ) then
		-- while it is placed, or in Demo Mode, it shows the sample bosses, so the frame is there to see and move
		SS.bossSample = SS.bossSample or {};                   -- made once, its health refreshed each time
		local sample = SS.bossSample;
		for i = 1, table.getn(SS.BOSS_SAMPLE) do
			local b = SS.BOSS_SAMPLE[i];
			local s = sample[i];
			if ( not s ) then s = { id = -i, kind = "boss", hpm = 100, priority = i, order = i }; sample[i] = s; end
			s.name, s.hp = b[1], b[2];
		end
		local height = SS.UpdateEncounterRows(sample);
		if ( height > 0 ) then bossFrame:SetHeight(height); end
		SS.ClampAbsoluteFrame("SlimSuiteBossFrames", bossFrame);
		SS.HideNative("bosses", false);
		bossFrame:Show();
	else
		-- before a run there is nothing to show
		for i = 1, table.getn(encounterRows) do encounterRows[i]:Hide(); end
		SS.HideNative("bosses", false);
		bossFrame:Hide();
	end
end

encounterUpdates = CreateFrame("Frame");
encounterUpdates:RegisterEvent("CHAT_MSG_ADDON");
encounterUpdates:SetScript("OnEvent", function()
	if ( arg1 == "AZSUNITS" ) then SS.Safe(SS.UpdateBossFrames); end
end);

SS.CreateClockFrame();
bossFrame = CreateFrame("Frame", "SlimSuiteBossFrames", UIParent);
bossFrame:SetWidth(520);
bossFrame:SetHeight(48);
-- Match the game's centered encounter nameplate, with the independent run clock above it.
bossFrame:SetPoint("TOP", UIParent, "TOP", 0, -76);
bossFrame:SetFrameStrata("MEDIUM");
bossFrame:EnableMouse(false);
bossFrame:Hide();

function SS.CreateAnnouncementFrame()
	announcementFrame = CreateFrame("Frame", "SlimSuiteAnnouncementFrame", UIParent);
	local bannerWidth = math.max(280, math.min(920, UIParent:GetWidth() - 24));
	announcementFrame:SetWidth(bannerWidth);
	announcementFrame:SetHeight(60);
	announcementFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 112);
	announcementFrame:SetFrameStrata("HIGH");
	announcementFrame:EnableMouse(false);
	announcementFrame.text = announcementFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	announcementFrame.text:SetPoint("CENTER", announcementFrame, "CENTER", 0, 0);
	announcementFrame.text:SetWidth(bannerWidth - 20);
	announcementFrame.text:SetHeight(60);
	announcementFrame.text:SetJustifyH("CENTER");
	announcementFrame.text:SetJustifyV("MIDDLE");
	announcementFrame.text:SetNonSpaceWrap(true);
	SS.SetGameDefaultFont(announcementFrame.text, 22);
	announcementFrame.text:SetTextColor(0.96, 0.82, 0.52);
	announcementFrame:Hide();
end

local function SyncAnnouncementNative()
	local d = SS.DB();
	-- Disabled hides both versions; Default alone gives the native announcements back.
	local disabled = d.elementModes and d.elementModes.SlimSuiteAnnouncementFrame == "disabled";
	SS.HideNative("banners", d.replaceBanners or disabled);
end

function SS.ShowAnnouncement(banner)
	SyncAnnouncementNative();
	if ( not SS.DB().replaceBanners ) then
		if ( announcementFrame ) then announcementFrame:Hide(); end
		return;
	end
	if ( type(banner) ~= "table" ) then return; end
	if ( banner.id ~= nil and banner.id == lastBannerId ) then return; end
	local text = type(banner.text) == "string" and banner.text or "";
	if ( text == "" and type(AZS_BANNER) == "table" and type(AZS_BANNER.text) == "string" ) then
		text = AZS_BANNER.text;
	end
	if ( text == "" and type(banner.name) == "string" and banner.name ~= "" ) then text = banner.name; end
	if ( text == "" ) then return; end
	lastBannerId = banner.id;
	announcementFrame.text:SetText(text);
	if ( banner.boss ) then announcementFrame.text:SetTextColor(1, 0.24, 0.13);
	else announcementFrame.text:SetTextColor(0.96, 0.82, 0.52); end
	announcementStarted = GetTime();
	announcementFrame:SetAlpha(0);
	announcementFrame:Show();
	SS.ClampAbsoluteFrame("SlimSuiteAnnouncementFrame", announcementFrame);
	SS.HideNative("banners", true);
end

function SS.UpdateAnnouncementFrame()
	SyncAnnouncementNative();
	if not SS.DB().replaceBanners then if announcementFrame then announcementFrame:Hide();end;return;end
	if ( not announcementFrame ) then return; end
	local maxWidth = math.max(40, UIParent:GetWidth() - 24);
	if ( announcementFrame:GetWidth() > maxWidth ) then announcementFrame:SetWidth(maxWidth); end
	announcementFrame.text:SetWidth(math.max(40, announcementFrame:GetWidth() - 20));
	announcementFrame.text:SetHeight(announcementFrame:GetHeight());
	if ( announcementStarted ) then
		local elapsed = GetTime() - announcementStarted;
		if ( elapsed >= announcementDuration ) then
			announcementStarted = nil;
			announcementFrame:Hide();
			return;
		end
		local alpha = 1;
		if ( elapsed < announcementFade ) then alpha = elapsed / announcementFade;
		elseif ( elapsed > announcementDuration - announcementFade ) then
			alpha = (announcementDuration - elapsed) / announcementFade;
		end
		announcementFrame:SetAlpha(math.max(0, math.min(1, alpha)));
	elseif ( SS.Previewing("SlimSuiteAnnouncementFrame") ) then
		announcementFrame.text:SetText("Hogger enters the battlefield!");
		announcementFrame.text:SetTextColor(1, 0.24, 0.13);
		announcementFrame:SetAlpha(1);
		announcementFrame:Show();
		SS.ClampAbsoluteFrame("SlimSuiteAnnouncementFrame", announcementFrame);
	else
		announcementFrame:Hide();
	end
end

SS.CreateAnnouncementFrame();
SS.Every("announcement", 0, function()
	if ( announcementStarted ) then SS.Safe(SS.UpdateAnnouncementFrame); end
end, announcementFrame);
bannerHandler = function(banner) SS.Safe(SS.ShowAnnouncement, banner); end;
bannerHandlerRegistered = false;
function SS.RegisterAnnouncementHandler()
	if ( bannerHandlerRegistered ) then return true; end
	if ( type(AZS_RegisterBannerHandler) ~= "function" ) then return false; end
	local ok = SS.Safe(AZS_RegisterBannerHandler, bannerHandler);
	if ( ok ) then
		bannerHandlerRegistered = true;
		SyncAnnouncementNative();
	end
	return bannerHandlerRegistered;
end
SS.Safe(SS.RegisterAnnouncementHandler);
SS.CreateLevelButton();
SS.Safe(SS.UpdateLevelButton);
SS.Every("tally", 0.25, function()
		SS.Safe(SS.UpdateTally);
		SS.Safe(SS.UpdateClock);
		SS.Safe(SS.UpdateBossFrames);
		SS.Safe(SS.UpdateAnnouncementFrame);
		SS.Safe(SS.UpdateLevelButton);
		SS.Safe(ApplyActionSlotGrid);
		local rowPreview = SS.Previewing("SlimSuiteItemRowFrame") or SS.Previewing("SlimSuiteSpellRowFrame");
		if ( rowPreview ~= SS.rowPreviewWas ) then SS.rowPreviewWas = rowPreview; SS.Safe(SS.RefreshItemRow); SS.Safe(SS.RefreshSpellRow); end
		SS.Safe(SS.UpdateTooltipPreview);
		local tooltipHandle = handles.GameTooltip;
		if ( tooltipHandle ) then
			if ( SS.IsEditing("GameTooltip") ) then tooltipHandle:Show();
			else tooltipHandle:Hide(); end
		end
		for i = 1, table.getn(MOVABLE) do
			local name = MOVABLE[i][1];
			if ( SS.DB().muted[name] ) then SS.Safe(ApplyFeatureMute, name); end
		end
end);

-- GetLeft/GetRight are in the queried frame's effective-scale units. All movement state
-- and comparisons below use UIParent units; SetPoint offsets must be converted back.
RootFactor = function(frame)
	return SS.EffectiveScale(frame) / SS.EffectiveScale(UIParent);
end

RootBounds = function(frame)
	local l, r, b, t = frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop();
	if ( not l or not r or not b or not t ) then return nil; end
	local factor = RootFactor(frame);
	-- All saved positions and UIParent anchors use coordinates from its bottom-left, even
	-- on clients where UIParent itself is inset from the physical screen origin.
	local originX, originY = UIParent:GetLeft() or 0, UIParent:GetBottom() or 0;
	return l * factor - originX, r * factor - originX, b * factor - originY, t * factor - originY;
end

SetRootPosition = function(frame, x, y)
	local factor = RootFactor(frame);
	frame:ClearAllPoints();
	frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / factor, y / factor);
end

-- Use resolved edges, in the same units as RootBounds and saved places. A scaled or
-- inset UIParent is not necessarily the whole client viewport. WorldFrame supplies
-- the remaining screen area; taking the union also handles a reduced world viewport
-- without cutting off UI space. Never change either root frame's scale or anchors.
function SS.ScreenBounds()
	local left, right, bottom, top = RootBounds(UIParent);
	if ( not left or not right or not bottom or not top or right <= left or top <= bottom ) then
		left, right, bottom, top = 0, UIParent:GetWidth(), 0, UIParent:GetHeight();
	end
	if ( WorldFrame ) then
		local l, r, b, t = RootBounds(WorldFrame);
		if ( l and r and b and t and r > l and t > b ) then
			left, right = math.min(left, l), math.max(right, r);
			bottom, top = math.min(bottom, b), math.max(top, t);
		end
	end
	return left, right, bottom, top;
end

function SS.ClampPosition(frame, x, y)
	local left, right, bottom, top = SS.ScreenBounds();
	local minX, minY, maxX, maxY = VisualInsets(frame);
	return math.max(left - minX, math.min(right - maxX, x)),
		math.max(bottom - minY, math.min(top - maxY, y));
end

function SS.SavePlace(name, f)
	local p = SS.DB().places[name];
	if ( type(p) ~= "table" ) then p = {}; SS.DB().places[name] = p; end
	local left, right, bottom = RootBounds(f);
	p.x, p.y, p.coordinateSpace = left, bottom, "uiParent";
	p.displayDefault = nil;
	local sl, sr, sb, st = SS.ScreenBounds();
	if ( left and bottom and sr > sl and st > sb ) then
		p.screen = { left=sl, bottom=sb, width=sr-sl, height=st-sb };
	end
end
SS.SavePosition = function(name, f)
	SS.SavePlace(name, f);
	if ( name == "MinimapCluster" ) then SS.Safe(SS.ClockFollowsMap); end   -- a moved map takes Slim Suite's clock with it
	local p = SS.DB().places[name];
	if ( p ) then p.relative, p.point, p.relativePoint, p.dx, p.dy = nil, nil, nil, nil, nil; end
end

-- Resize, scale and snapped anchors can all push visible child controls past a screen edge.
-- Clamp the drawn bounds (not just the parent frame) and convert a clipped relative anchor to
-- a stable absolute location. Save the corrected place immediately so it survives /reload.
function SS.ClampToClient(name, frame)
	if ( not frame or not UIParent ) then return; end
	if ( name == "SlimSuiteItemRowFrame" and SS.DB().buildRowsAttached ) then return; end   -- the spell row is clamped for both
	local left, right, bottom = RootBounds(frame);
	if ( not left or not bottom ) then return; end
	local x, y = SS.ClampPosition(frame, left, bottom);
	if ( math.abs(x - left) > 0.01 or math.abs(y - bottom) > 0.01 ) then
		SetRootPosition(frame, x, y);
		local stored = SS.DB().places[name];
		if ( SS.displayReflow or (stored and stored.screen and not stored.relative)
			or (SS.DISPLAY_ANCHORS and SS.DISPLAY_ANCHORS[name] and (not stored or stored.displayDefault)) ) then return; end
		SS.SavePlace(name, frame);
		local p = SS.DB().places[name];
		p.relative, p.point, p.relativePoint, p.dx, p.dy = nil, nil, nil, nil, nil;
	end
end

-- The smallest size each element can be sized to. The size menu and the boss layout both read it, so they agree.
function SS.MinSize(name)
	local vertical = SS.CurrentOrientation(name) == "vertical";
	if ( name == "SlimSuiteClockFrame" ) then
		if ( vertical ) then return 90, 36 + SS.FramePadding(name) * 3; end
		return 200, 24;
	elseif ( name == "SlimSuiteItemRowFrame" ) then
		if ( vertical ) then return 36, 76; end
		return 76, 24;
	elseif ( name == "SlimSuiteSpellRowFrame" ) then
		if ( vertical ) then return 36, 92; end
		return 92, 24;
	elseif ( name == "SlimSuiteMeterFrame" ) then
		return 210, 110;                                   -- the same as the meter's own corner grip
	elseif ( name == "GameTooltip" ) then
		return 160, 80;
	elseif ( name == "SlimSuiteCombatTextFrame" ) then
		return 120, 60;
	elseif ( name == "SlimSuitePartyLines" ) then
		local slots = SS.DB().partyIncludesSelf and 5 or 4;
		if ( SS.CurrentOrientation("PartyMemberFrame1") ~= "horizontal" ) then return 40, slots * 5 + (slots - 1) * 2; end
		return slots * 30 + (slots - 1) * 4, 5;
	elseif ( name == "SlimSuiteBossFrames" ) then
		-- one enemy card: the narrowest card and the shortest one that still reads
		local pad = SS.FramePadding(name);
		if ( vertical ) then return 34, math.max(60, 52 + pad * 3); end
		return 40, 42 + pad * 2;
	end
	return 40, 24;
end

SS.nativeScales = {};
function SS.ApplySize(name, f)
	if ( SS.nativeScales[name] == nil and f.GetScale ) then SS.nativeScales[name] = f:GetScale(); end
	if ( name == "PartyMemberFrame1" ) then
		for i = 1, 4 do
			local memberName = "PartyMemberFrame" .. i;
			local member = getglobal(memberName);
			if ( member and member.GetScale and SS.nativeScales[memberName] == nil ) then SS.nativeScales[memberName] = member:GetScale(); end
		end
	end
	if ( name == "ChatFrame1" and SS.CaptureChatLayout ) then SS.CaptureChatLayout(); end
	local s = SS.DB().sizes[name];
	if ( name == "GameTooltip" and type(s) ~= "table" ) then
		s = { w = 260, h = 140 };
	end
	if ( type(s) == "table" and s.w and s.h and s.w > 0 and s.h > 0 ) then
		f:SetWidth(s.w);
		f:SetHeight(s.h);
	end
	if ( name == "SlimSuiteClockFrame" ) then SS.ApplyClockLayout(); end
	if ( name == "MainMenuBar" and ApplyMovableOrientation ) then ApplyMovableOrientation(name); end
	if ( name == "SlimSuiteItemRowFrame" ) then SS.LayoutItemRow(); end
	if ( name == "SlimSuiteSpellRowFrame" ) then SS.LayoutSpellRow(); end
	if ( name == "SlimSuitePartyLines" and SS.UpdatePartyLines ) then SS.Safe(SS.UpdatePartyLines); end
	local scale = SS.DB().scales[name];
	if ( SS.DisplayElementScale ) then scale = SS.DisplayElementScale(name, type(scale) == "number" and scale or 1); end
	if ( type(scale) == "number" ) then
		if ( name == "PartyMemberFrame1" ) then
			for i = 1, 4 do local party = getglobal("PartyMemberFrame" .. i); if ( party and party.SetScale ) then party:SetScale(scale); end end
		elseif ( f.SetScale ) then f:SetScale(scale); end
	end
	if ( name == "ChatFrame1" and SS.SyncChatLayout ) then SS.SyncChatLayout(); end
end

-- Include visible child frames in edge clamping. Some Blizzard bars draw their buttons a few
-- logical pixels outside the parent frame, so clamping only the parent's rectangle leaves a gap.
VisualInsets = function(frame)
	local baseLeft, baseRight, baseBottom = RootBounds(frame);
	if ( not baseLeft or not baseBottom ) then return 0, 0, 0, 0; end
	local uiScale = SS.EffectiveScale(UIParent);
	local frameScale = SS.EffectiveScale(frame);
	local factor = frameScale / uiScale;
	-- MainMenuExpBar's child textures retain their old horizontal extents after the native
	-- status bar is rotated. Its own bounds are the visible/movable bounds in either layout.
	if ( frame == MainMenuExpBar ) then
		return 0, 0, (frame:GetWidth() or 0) * factor, (frame:GetHeight() or 0) * factor;
	end
	if ( frame == MainMenuBar or frame == PartyMemberFrame1 or frame == BuffFrame ) then
		-- These Blizzard groups have unused parent padding or detached siblings. Clamp their
		-- actual visible controls as a group so scale cannot leave a gap or clip a companion.
		local minX, minY, maxX, maxY;
		local function Include(child)
			if ( not child or (child.IsShown and not child:IsShown()) ) then return; end
			local left, right, bottom, top = RootBounds(child);
			if ( left and right and bottom and top ) then
				local l, r, b, t = left - baseLeft, right - baseLeft, bottom - baseBottom, top - baseBottom;
				minX = minX and math.min(minX, l) or l; maxX = maxX and math.max(maxX, r) or r;
				minY = minY and math.min(minY, b) or b; maxY = maxY and math.max(maxY, t) or t;
			end
		end
		if ( frame == MainMenuBar ) then
			for i = 1, 6 do Include(getglobal("ActionButton" .. i)); end
			Include(ActionButton12);
			if ( ActionButton12 ) then Include(ActionButton12.slimRacialBorder); end
			Include(ActionBarUpButton); Include(ActionBarDownButton);
		elseif ( frame == BuffFrame ) then
			for i = 0, (MAX_PLAYER_BUFFS or 32) do Include(getglobal("BuffButton" .. i)); end
			if ( SS.BuffSamples ) then for _, s in pairs(SS.BuffSamples()) do Include(s); end end
		else
			for i = 1, 4 do Include(getglobal("PartyMemberFrame" .. i)); end
			Include(getglobal("SlimSuitePartySelfFrame"));          -- your plate, before the first member
		end
		if ( minX and minY and maxX and maxY ) then return minX, minY, maxX, maxY; end
	end
	local minX, minY = 0, 0;
	local maxX = (frame:GetWidth() or 0) * factor;
	local maxY = (frame:GetHeight() or 0) * factor;
	-- Generic recursive child bounds can include detached/hidden Blizzard art and stale
	-- child anchors outside Slim Suite's custom frame. That falsely shrinks the usable
	-- screen area. Native composite frames above are handled explicitly; custom elements
	-- are clamped to their own visible rectangle.
	if ( frame == spellRow and itemRow and SS.DB().buildRowsAttached and itemRow:IsShown() ) then
		local l, r, b, t = RootBounds(itemRow);
		if ( l and r and b and t ) then
			minX = math.min(minX, l - baseLeft); maxX = math.max(maxX, r - baseLeft);
			minY = math.min(minY, b - baseBottom); maxY = math.max(maxY, t - baseBottom);
		end
	end
	return minX, minY, maxX, maxY;
end;

function SS.CollectFeatureFrames(frame, list, seen, depth)
	if ( not frame or seen[frame] or depth > 4 ) then return; end
	seen[frame] = true;
	table.insert(list, frame);
	if ( not frame.GetChildren ) then return; end
	local ok, children = SS.Safe(function() return { frame:GetChildren() }; end);
	if ( not ok or type(children) ~= "table" ) then return; end
	for i = 1, table.getn(children) do SS.CollectFeatureFrames(children[i], list, seen, depth + 1); end
end

ApplyFeatureMute = function(name)
	local frame = getglobal(name);
	if ( not frame ) then return; end
	local list, seen = {}, {};
	SS.CollectFeatureFrames(frame, list, seen, 0);
	if ( name == "PartyMemberFrame1" ) then
		for i = 2, 4 do SS.CollectFeatureFrames(getglobal("PartyMemberFrame" .. i), list, seen, 0); end
		SS.CollectFeatureFrames(getglobal("SlimSuitePartySelfFrame"), list, seen, 0);
	elseif ( name == "ChatFrame1" ) then
		local companions = SS.ChatCompanions and SS.ChatCompanions() or { "ChatFrame1Tab", "ChatFrameEditBox", "ChatFrame1EditBox" };
		for _, companion in ipairs(companions) do SS.CollectFeatureFrames(getglobal(companion), list, seen, 0); end
	end
	local muted = SS.DB().muted[name] and true or false;
	if ( name == "ChatFrame1" and not setupActive and SS.DB().elementModes.ChatFrame1 == "disabled" ) then muted = true; end
	for i = 1, table.getn(list) do
		local target = list[i];
		if ( target and target.GetAlpha and target.SetAlpha ) then
			if ( muted ) then
				if ( mutedBaseAlphas[target] == nil ) then
					local ok, alpha = SS.Safe(target.GetAlpha, target);
					mutedBaseAlphas[target] = ok and alpha or 1;
				end
				if ( mutedBaseMouse[target] == nil and target.IsMouseEnabled ) then
					local ok, enabled = SS.Safe(target.IsMouseEnabled, target);
					if ( ok ) then mutedBaseMouse[target] = enabled and true or false; end
				end
				SS.Safe(target.SetAlpha, target, 0);
				if ( target.EnableMouse and mutedBaseMouse[target] ~= nil ) then SS.Safe(target.EnableMouse, target, false); end
			else
				local alpha = mutedBaseAlphas[target];
				if ( alpha ~= nil ) then SS.Safe(target.SetAlpha, target, alpha); mutedBaseAlphas[target] = nil; end
				local enabled = mutedBaseMouse[target];
				if ( enabled ~= nil and target.EnableMouse ) then SS.Safe(target.EnableMouse, target, enabled); mutedBaseMouse[target] = nil; end
			end
		end
	end
	local handle = handles[name];
	if ( handle ) then
		if ( muted ) then
			handle:SetBackdropColor(0.22, 0.22, 0.24, 0.58);
			handle:SetBackdropBorderColor(0.6, 0.6, 0.62, 0.85);
			if ( handle.text and name ~= "GameTooltip" ) then handle.text:SetTextColor(0.72, 0.72, 0.74); end
		elseif ( handle.quiet ) then
			handle:SetBackdropColor(0, 0, 0, 0); handle:SetBackdropBorderColor(0.3, 1, 0.3, 0);
			if ( handle.text ) then handle.text:SetTextColor(1, 1, 1); end
		else
			handle:SetBackdropColor(0.1, 0.6, 0.1, 0.45);
			handle:SetBackdropBorderColor(0.3, 1, 0.3, 0.9);
			if ( handle.text and name ~= "GameTooltip" ) then handle.text:SetTextColor(1, 1, 1); end
		end
	end
end;

function SS.ToggleFeatureMute(name)
	SS.DB().muted[name] = not SS.DB().muted[name];
	ApplyFeatureMute(name);
	if ( sizeMenu and sizeMenu.muteButton ) then
		sizeMenu.muteButton:SetText(SS.DB().muted[name] and "Show feature" or "Hide feature");
	end
end

function SS.CurrentOrientation(name)
	if ( SS.DB().frameDefault and SS.DB().frameDefault[name] ) then
		return name == "PartyMemberFrame1" and "vertical" or "horizontal";
	end
	if ( name == "PartyMemberFrame1" and SS.Demoing("PartyMemberFrame1") and SS.demoPartyOrient ) then return SS.demoPartyOrient; end
	local orientation = SS.DB().orientations[name];
	if ( orientation == "vertical" or orientation == "horizontal" ) then return orientation; end
	if ( name == "SlimSuiteClockFrame" ) then return "vertical"; end
	if ( name == "PartyMemberFrame1" ) then return "vertical"; end
	return "horizontal";
end

function SS.BuffGrowthDirection()
	return SS.DB().buffGrowthDirection == "up" and "up" or "down";
end

-- Sample buffs and debuffs: shown on the real buff frame while it is being placed or in Demo Mode, after your own buffs
-- and laid out by the same rules (row or column, growth, padding, size and scale). In Demo Mode each comes and goes.
SS.BUFF_SAMPLES = { "Spell_Holy_WordFortitude", "Spell_Arcane_ArcaneIntellect", "Spell_Nature_RavenForm", "Ability_Warrior_BattleShout",
	"Spell_Shadow_ShadowWordPain", "Spell_Frost_FrostBolt02", "Ability_Hunter_SniperShot", "Ability_Warrior_Sunder" };
SS.demoBuffOn = {};
buffSamples = {};
function SS.BuffSample(i)
	local b = buffSamples[i];
	if ( b ) then return b; end
	b = CreateFrame("Frame", nil, BuffFrame);
	b:SetWidth(32); b:SetHeight(32);
	b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(b);
	b.icon:SetTexture("Interface\\Icons\\" .. SS.BUFF_SAMPLES[i]);
	if ( i > 4 ) then b.icon:SetVertexColor(1, 0.45, 0.45); end   -- the last four are debuffs
	b.time = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	b.time:SetPoint("TOP", b, "BOTTOM", 0, -1); b.time:SetText((i * 3) .. " m");
	b:Hide();
	buffSamples[i] = b;
	return b;
end
function SS.BuffSamples() return buffSamples; end

-- the game's buff buttons: BuffButton0 (1.12) or BuffButton1 onwards
function BuffButtons()
	local list = {};
	for i = 0, (MAX_PLAYER_BUFFS or 32) do
		local button = getglobal("BuffButton" .. i);
		if ( button ) then table.insert(list, { i, button }); end
	end
	return list;
end
SS.BuffButtons = BuffButtons;

function SS.ApplyBuffOrientation()
	if ( not BuffFrame or buffLayoutApplying ) then return; end
	local orientation = SS.CurrentOrientation("BuffFrame");
	local attached;
	if ( SS.Pair and SS.DB().buffsOnTarget ) then local _, target = SS.Pair(); attached = target;
	elseif ( SS.Pair and SS.DB().buffsOnPlayer ) then local player = SS.Pair(); attached = player; end
	local buttons = BuffButtons();
	local visible, real, iconW, iconH, durationW, durationH = {}, 0, nil, nil, 0, 0;
	for k = 1, table.getn(buttons) do
		local i, button = buttons[k][1], buttons[k][2];
		if ( not buffButtonOriginalPoints[i] and button.GetNumPoints ) then
			local points = {};
			for p = 1, button:GetNumPoints() do
				local a, relative, relativePoint, x, y = button:GetPoint(p);
				points[p] = { a, relative, relativePoint, x, y };
			end
			buffButtonOriginalPoints[i] = points;
		end
		if ( button:IsShown() ) then
			table.insert(visible, button); real = real + 1;
			iconW = iconW or button:GetWidth(); iconH = iconH or button:GetHeight();
			local duration = getglobal("BuffButton" .. i .. "Duration");
			if ( duration and duration:IsShown() ) then
				durationW = math.max(durationW, (duration.GetStringWidth and duration:GetStringWidth()) or 0);
				durationH = math.max(durationH, (duration.GetHeight and duration:GetHeight()) or 0);
			end
		end
	end
	-- the samples, after your own buffs
	local preview = SS.Previewing("BuffFrame");
	if ( not iconW ) then
		local first = buttons[1] and buttons[1][2];
		iconW, iconH = first and first:GetWidth() or 32, first and first:GetHeight() or 32;
		if ( not iconW or iconW <= 0 ) then iconW, iconH = 32, 32; end
	end
	local samples = {};
	for i = 1, table.getn(SS.BUFF_SAMPLES) do
		local on = preview and (not SS.Demoing("BuffFrame") or SS.demoBuffOn[i]);
		if ( on ) then
			local s = SS.BuffSample(i);
			s:SetWidth(iconW); s:SetHeight(iconH); s:Show();
			durationW = math.max(durationW, s.time:GetStringWidth() or 0);
			durationH = math.max(durationH, s.time:GetHeight() or 12);
			table.insert(samples, s); table.insert(visible, s);
		elseif ( buffSamples[i] ) then
			buffSamples[i]:Hide();
		end
	end
	local saved = SS.DB().sizes.BuffFrame;
	if ( table.getn(visible) == 0 ) then
		-- nothing to lay out; a size set by the player still applies to the frame
		if ( type(saved) == "table" and saved.w and saved.h ) then BuffFrame:SetWidth(saved.w); BuffFrame:SetHeight(saved.h); end
		return;
	end
	buffLayoutApplying = true;
	if ( (SS.DB().frameDefault and SS.DB().frameDefault.BuffFrame) or (orientation == "horizontal" and not SS.DB().buffCustomLayout) ) then
		-- the game's own layout: its buttons go back where the game puts them
		local prev;
		for k = 1, table.getn(buttons) do
			local i, button = buttons[k][1], buttons[k][2];
			local points = buffButtonOriginalPoints[i];
			if ( points and table.getn(points) > 0 ) then
				button:ClearAllPoints();
				for p = 1, table.getn(points) do
					local a = points[p];
					button:SetPoint(a[1], a[2], a[3], a[4], a[5]);
				end
			end
			if ( button:IsShown() ) then prev = button; end
		end
		-- the samples carry on the game's row, right to left, after your last buff
		for i = 1, table.getn(samples) do
			local s = samples[i];
			s:ClearAllPoints();
			if ( prev ) then s:SetPoint("RIGHT", prev, "LEFT", -5, 0); else s:SetPoint("TOPRIGHT", BuffFrame, "TOPRIGHT", 0, 0); end
			prev = s;
		end
		local base = baseSizes.BuffFrame;
		if ( type(saved) == "table" and saved.w and saved.h ) then BuffFrame:SetWidth(saved.w); BuffFrame:SetHeight(saved.h);
		elseif ( base ) then BuffFrame:SetWidth(base.w); BuffFrame:SetHeight(base.h); end
		buffLayoutApplying = false;
		return;
	end
	-- Treat each icon and its cooldown text as one cell. The text's measured size is used instead of a fixed guessed
	-- gap, so long durations never collide with the next buff.
	local gap, count = 4 + SS.FramePadding("BuffFrame"), table.getn(visible);
	local cellW = math.max(iconW, durationW) + 4;
	local cellH = iconH + durationH + 4;
	local customSize = saved;
	local columns, rows;
	if ( orientation == "vertical" ) then
		local maxRows = count;
		if ( type(customSize) == "table" and customSize.h and customSize.h > 0 ) then
			maxRows = math.max(1, math.floor((customSize.h + gap) / (cellH + gap)));
		end
		-- When attached to a unit frame, a column stays inside that frame's height; additional
		-- columns grow away from the selected edge instead of spilling over the unit frame itself.
		if ( attached and attached.GetHeight ) then
			local limit = math.max(1, math.floor((attached:GetHeight() + gap) / (cellH + gap)));
			maxRows = math.min(maxRows, limit);
		end
		rows = math.min(count, maxRows);
		columns = math.ceil(count / rows);
	else
		local base = baseSizes.BuffFrame;
		local maxWidth = type(customSize) == "table" and customSize.w or (base and base.w) or (iconW * 10);
		-- Attached horizontal rows stay within the unit frame's width and wrap outward from it.
		if ( attached and attached.GetWidth ) then maxWidth = math.min(maxWidth, attached:GetWidth()); end
		columns = math.max(1, math.min(count, math.floor((maxWidth + gap) / (cellW + gap))));
		rows = math.ceil(count / columns);
	end
	local direction = SS.BuffGrowthDirection();
	if ( attached ) then
		local side = SS.DB().buffsOnTarget and SS.DB().buffsOnTargetSide or SS.DB().buffsOnPlayerSide;
		if ( side == "above" ) then direction = "up"; end
	end
	local verticalOffset = direction == "up" and 1 or -1;
	for i = 1, count do
		local column, row;
		if ( orientation == "vertical" ) then
			column = math.floor((i - 1) / rows);
			row = math.mod(i - 1, rows);
		else
			column = math.mod(i - 1, columns);
			row = math.floor((i - 1) / columns);
		end
		local button = visible[i];
		button:ClearAllPoints();
		-- Keep the first icon at the anchor. New rows/vertical icons extend in the selected direction.
		button:SetPoint("BOTTOMLEFT", BuffFrame, "BOTTOMLEFT",
			column * (cellW + gap) + (cellW - iconW) / 2,
			verticalOffset * row * (cellH + gap));
	end
	local requiredWidth = columns * (cellW + gap) - gap;
	local requiredHeight = rows * (cellH + gap) - gap;
	-- a size set by the player is the size (1.12 does not clip, so icons past its edge still draw); otherwise it fits them
	BuffFrame:SetWidth(type(customSize) == "table" and customSize.w or requiredWidth);
	BuffFrame:SetHeight(type(customSize) == "table" and customSize.h or requiredHeight);
	buffLayoutApplying = false;
end

ApplyActionSlotGrid = function()
	local on = SS.DB().showEmptyActionSlots and true or false;
	if ( on == actionSlotsGridApplied ) then return; end
	local action = on and ActionButton_ShowGrid or ActionButton_HideGrid;
	if ( type(action) ~= "function" ) then return; end -- retry later once the game action buttons are available
	local found = false;
	for i = 1, 6 do
		local button = getglobal("ActionButton" .. i);
		if ( button ) then SS.Safe(action, button); found = true; end
	end
	if ( found ) then actionSlotsGridApplied = on; end
end

CaptureActionBarLayout = function()
	if ( actionBarOriginal or not MainMenuBar ) then return; end
	local saved = SS.DB().actionBarHorizontalSize;
	local w, h = MainMenuBar:GetWidth(), MainMenuBar:GetHeight();
	if ( type(saved) == "table" and saved.w and saved.h ) then w, h = saved.w, saved.h;
	else SS.DB().actionBarHorizontalSize = { w = w, h = h }; end
	actionBarOriginal = { w = w, h = h, buttonSize = nil, buttons = {}, racial = nil, arrows = {} };
	for i = 1, 6 do
		local button = getglobal("ActionButton" .. i);
		if ( button and button.GetNumPoints ) then
			actionBarOriginal.buttonSize = actionBarOriginal.buttonSize or button:GetWidth();
			local points = {};
			for p = 1, button:GetNumPoints() do
				local point, relative, relativePoint, x, y = button:GetPoint(p);
				points[p] = { point, relative, relativePoint, x, y };
			end
			actionBarOriginal.buttons[i] = points;
		end
	end
	if ( ActionButton12 and ActionButton12.GetNumPoints ) then
		local points = {};
		for p = 1, ActionButton12:GetNumPoints() do
			local point, relative, relativePoint, x, y = ActionButton12:GetPoint(p);
			points[p] = { point, relative, relativePoint, x, y };
		end
		actionBarOriginal.racial = { w = ActionButton12:GetWidth(), h = ActionButton12:GetHeight(), points = points,
			shown = ActionButton12.IsShown and ActionButton12:IsShown() or false };
	end
	for _, name in ipairs({ "ActionBarUpButton", "ActionBarDownButton" }) do
		local arrow = getglobal(name);
		if ( arrow and arrow.GetNumPoints ) then
			local points = {};
			for p = 1, arrow:GetNumPoints() do
				local point, relative, relativePoint, x, y = arrow:GetPoint(p);
				points[p] = { point, relative, relativePoint, x, y };
			end
			actionBarOriginal.arrows[name] = { w = arrow:GetWidth(), h = arrow:GetHeight(), points = points };
		end
	end
	if ( AZS_RacialRim and AZS_RacialRim.GetNumPoints ) then
		local points = {};
		for p = 1, AZS_RacialRim:GetNumPoints() do
			local point, relative, relativePoint, x, y = AZS_RacialRim:GetPoint(p);
			points[p] = { point, relative, relativePoint, x, y };
		end
		actionBarOriginal.rim = points;
	end
end

function SS.RestoreRacialActionButtonLayout()
	local original = actionBarOriginal;
	if ( not original or not original.racial or not ActionButton12 ) then return; end
	ActionButton12:SetWidth(original.racial.w); ActionButton12:SetHeight(original.racial.h);
	ActionButton12:ClearAllPoints();
	for p = 1, table.getn(original.racial.points) do
		local a = original.racial.points[p]; ActionButton12:SetPoint(a[1], a[2], a[3], a[4], a[5]);
	end
	local id = (ActionButton_GetPagedID and ActionButton_GetPagedID(ActionButton12)) or 12;
	local ok, has = SS.Safe(HasAction, id);
	if ( original.racial.shown or (ok and has) ) then ActionButton12:Show();
	elseif ( ActionButton12.slimShownByUs ) then ActionButton12:Hide(); end
	ActionButton12.slimShownByUs = nil;
	if ( ActionButton12.slimRacialBorder ) then ActionButton12.slimRacialBorder:Hide(); end
	if ( AZS_RacialRim and original.rim ) then
		AZS_RacialRim:ClearAllPoints();
		for p = 1, table.getn(original.rim) do local a = original.rim[p]; AZS_RacialRim:SetPoint(a[1], a[2], a[3], a[4], a[5]); end
	end
end

-- The XP bar keeps the game's own border in every layout. The game draws that border as four art pieces at a fixed
-- size along the bar where it first sits, so once Slim Suite moves, resizes or turns the bar it draws copies of the
-- same pieces (the same picture, read from the game's own) that follow the bar's size and turn with it when it stands
-- upright; the game's pieces step aside. The pieces are read once at load, while the bar is still the game's own. A
-- client that can't read or turn them keeps the older upright look (a thin gold border) there.
SS.XP_POINT = { CENTER = { 0, 0 }, TOP = { 0, 0.5 }, BOTTOM = { 0, -0.5 }, LEFT = { -0.5, 0 }, RIGHT = { 0.5, 0 },
	TOPLEFT = { -0.5, 0.5 }, TOPRIGHT = { 0.5, 0.5 }, BOTTOMLEFT = { -0.5, -0.5 }, BOTTOMRIGHT = { 0.5, -0.5 } };
SS.xpArt = {};
function SS.CaptureXpArt()
	local xp = MainMenuExpBar;
	if ( SS.xpArt.pieces or SS.xpArt.tried or not xp ) then return; end
	SS.xpArt.tried = true;
	local W, H = xp:GetWidth(), xp:GetHeight();
	if ( not W or not H or W <= 0 or H <= 0 ) then return; end
	local pieces = {};
	for i = 0, 3 do
		local t = getglobal("MainMenuXPBarTexture" .. i);
		if ( not t or type(t.GetTexCoord) ~= "function" or type(t.GetPoint) ~= "function" or type(t.GetTexture) ~= "function" ) then return; end
		if ( t.GetNumPoints and t:GetNumPoints() ~= 1 ) then return; end
		local ok, c1, c2, c3, c4, c5, c6, c7, c8 = pcall(t.GetTexCoord, t);
		if ( not ok or type(c8) ~= "number" ) then return; end
		local okPoint, p, rel, rp, x, y = pcall(t.GetPoint, t, 1);
		local w, h, file = t:GetWidth(), t:GetHeight(), t:GetTexture();
		if ( not okPoint or rel ~= xp or not file or not w or not h or w <= 0 or h <= 0 ) then return; end
		local a, b = SS.XP_POINT[p or ""], SS.XP_POINT[rp or p or ""];
		if ( not a or not b ) then return; end
		-- the piece's centre from the bar's centre, in parts of the bar's length (u) and thickness (v)
		local cx = b[1] * W + (x or 0) - a[1] * w;
		local cy = b[2] * H + (y or 0) - a[2] * h;
		pieces[i + 1] = { file = file, c = { c1, c2, c3, c4, c5, c6, c7, c8 }, u = cx / W, v = cy / H, w = w / W, h = h / H };
	end
	SS.xpArt.pieces = pieces;
end
SS.Safe(SS.CaptureXpArt);

-- true while Slim Suite's copies draw the border (the bar is Slim Suite's to move); upright needs the copies turned
function SS.XpArtShown()
	local xp, pieces = MainMenuExpBar, SS.xpArt.pieces;
	if ( not xp or not pieces or not xpBarDetached ) then return false; end
	if ( SS.DB().orientations.MainMenuExpBar == "vertical" and SS.xpArt.noTurn ) then return false; end
	return true;
end

function SS.LayoutXpArt()
	local xp, pieces = MainMenuExpBar, SS.xpArt.pieces;
	if ( not xp or not pieces ) then return; end
	local f = SS.xpArt.frame;
	if ( not SS.XpArtShown() ) then
		if ( f ) then f:Hide(); end
		return;
	end
	if ( not f ) then
		f = CreateFrame("Frame", "SlimSuiteXpArt", xp);
		f:SetAllPoints(xp);
		f:EnableMouse(false);
		f.tex = {};
		for k = 1, table.getn(pieces) do f.tex[k] = f:CreateTexture(nil, "OVERLAY"); end
		SS.xpArt.frame = f;
	end
	f:SetFrameLevel((xp:GetFrameLevel() or 1) + 2);         -- over the fill, under the 20-segment dividers
	for i = 0, 3 do                                        -- the game's own pieces step aside for the copies
		local g = getglobal("MainMenuXPBarTexture" .. i);
		if ( g and g.SetAlpha ) then g:SetAlpha(0); end
	end
	local vertical = SS.DB().orientations.MainMenuExpBar == "vertical";
	local len, thick = xp:GetWidth() or 0, xp:GetHeight() or 0;
	if ( vertical ) then len, thick = xp:GetHeight() or 0, xp:GetWidth() or 0; end
	for k = 1, table.getn(pieces) do
		local p, t = pieces[k], f.tex[k];
		local c = p.c;
		t:SetTexture(p.file);
		t:ClearAllPoints();
		if ( vertical ) then
			-- a quarter turn to the left: the bar's start (its left end) at the bottom, as the upright bar fills
			t:SetWidth(math.max(1, p.h * thick)); t:SetHeight(math.max(1, p.w * len));
			t:SetPoint("CENTER", xp, "CENTER", -p.v * thick, p.u * len);
			if ( not pcall(t.SetTexCoord, t, c[5], c[6], c[1], c[2], c[7], c[8], c[3], c[4]) ) then
				SS.xpArt.noTurn = true;                        -- this client can't turn art: the older upright look
				f:Hide();
				SS.Safe(SS.StyleExpBar, true);
				return;
			end
		else
			t:SetWidth(math.max(1, p.w * len)); t:SetHeight(math.max(1, p.h * thick));
			t:SetPoint("CENTER", xp, "CENTER", p.u * len, p.v * thick);
			t:SetTexCoord(c[1], c[5], c[2], c[4]);             -- left, right, top, bottom
		end
		t:Show();
	end
	f:Show();
end

-- "Split into 20 segments": 19 thin dividers over the XP bar, each 5% of a level apart. They sit on the bar, follow its
-- size, and lie across it when the bar stands upright. On unless turned off.
function SS.LayoutXpSegments()
	local xp = MainMenuExpBar;
	if ( not xp ) then return; end
	local seg = getglobal("SlimSuiteXpSegments");
	if ( SS.DB().frameDefault and SS.DB().frameDefault.MainMenuExpBar ) then
		if ( seg ) then seg:Hide(); end
		return;
	end
	if ( not seg ) then
		seg = CreateFrame("Frame", "SlimSuiteXpSegments", xp);
		seg:SetAllPoints(xp);
		seg:SetFrameStrata("HIGH");
		seg:EnableMouse(false);
		seg.ticks = {};
		for i = 1, 19 do
			local t = seg:CreateTexture(nil, "OVERLAY");
			t:SetTexture(0, 0, 0, 0.65);
			seg.ticks[i] = t;
		end
		seg:SetScript("OnSizeChanged", function() SS.Safe(SS.LayoutXpSegments); end);
	end
	SS.Safe(SS.LayoutXpArt);                               -- the game's border follows the bar's size and turn
	seg:SetAllPoints(xp);
	seg:SetFrameLevel((xp:GetFrameLevel() or 1) + 3);      -- over the fill and the upright bar's border
	if ( SS.DB().xpSegments == false ) then seg:Hide(); return; end
	seg:Show();
	local vertical = SS.DB().orientations.MainMenuExpBar == "vertical";
	local w, h = xp:GetWidth() or 0, xp:GetHeight() or 0;
	for i = 1, 19 do
		local t = seg.ticks[i];
		t:ClearAllPoints();
		if ( vertical ) then
			local y = h * i / 20;
			t:SetPoint("BOTTOMLEFT", seg, "BOTTOMLEFT", 0, y); t:SetPoint("BOTTOMRIGHT", seg, "BOTTOMRIGHT", 0, y);
			t:SetHeight(1);
		else
			local x = w * i / 20;
			t:SetPoint("TOPLEFT", seg, "TOPLEFT", x, 0); t:SetPoint("BOTTOMLEFT", seg, "BOTTOMLEFT", x, 0);
			t:SetWidth(1);
		end
	end
end

-- Upright, the rested-XP marker (ExhaustionTick, the diamond "end point") is drawn for a flat bar and looks broken,
-- so it is hidden; the bar gets a dark background and a smooth fill. Laid flat again, all of that comes back.
xpStyle = { shows = {} };
function SS.StyleExpBar(on)
	local xp = MainMenuExpBar;
	if ( not xp ) then return; end
	SS.Safe(SS.LayoutXpArt);
	local copies = SS.XpArtShown();
	for i = 0, 3 do
		local t = getglobal("MainMenuXPBarTexture" .. i);
		if ( t and t.SetAlpha ) then t:SetAlpha((on or copies) and 0 or 1); end
	end
	for _, n in ipairs({ "ExhaustionTick", "ExhaustionLevelFillBar" }) do
		local f = getglobal(n);
		if ( f and f.Hide ) then
			if ( not xpStyle.shows[n] ) then xpStyle.shows[n] = f.Show; end
			if ( on ) then f.Show = function() end; f:Hide();
			elseif ( f.Show ~= xpStyle.shows[n] ) then f.Show = xpStyle.shows[n]; f:Show(); end
		end
	end
	local fill = xp.GetStatusBarTexture and xp:GetStatusBarTexture();
	if ( fill and xpStyle.texture == nil and fill.GetTexture ) then xpStyle.texture = fill:GetTexture() or false; end
	if ( on ) then
		if ( not xpStyle.bg ) then
			xpStyle.bg = xp:CreateTexture(nil, "BACKGROUND");
			xpStyle.bg:SetAllPoints(xp);
			xpStyle.bg:SetTexture(0.04, 0.035, 0.05, 0.85);
			xpStyle.border = CreateFrame("Frame", nil, xp);
			xpStyle.border:SetPoint("TOPLEFT", xp, "TOPLEFT", -3, 3);
			xpStyle.border:SetPoint("BOTTOMRIGHT", xp, "BOTTOMRIGHT", 3, -3);
			xpStyle.border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 });
			xpStyle.border:SetBackdropBorderColor(0.75, 0.58, 0.25, 0.9);
			xpStyle.border:EnableMouse(false);
		end
		xpStyle.bg:Show();
		if ( copies ) then xpStyle.border:Hide(); else xpStyle.border:Show(); end   -- the game's border when it can turn
		xpStyle.border:SetFrameLevel((xp:GetFrameLevel() or 1) + 2);
		if ( xp.SetStatusBarTexture ) then xp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); end
		-- keep the game's own XP text readable on the narrow bar
		for _, n in ipairs({ "MainMenuBarExpText", "MainMenuExpBarText" }) do
			local t = getglobal(n);
			if ( t and t.SetFont ) then
				local font, _, flags = t:GetFont();
				if ( font ) then t:SetFont(font, 10, "OUTLINE"); end
			end
		end
	elseif ( xpStyle.bg ) then
		xpStyle.bg:Hide(); xpStyle.border:Hide();
		if ( xpStyle.texture and xp.SetStatusBarTexture ) then xp:SetStatusBarTexture(xpStyle.texture); end
	end
	xpStyle.on = on;
end

ApplyMovableOrientation = function(name)
	if ( SS.DB().frameDefault and SS.DB().frameDefault[name] and name ~= "BuffFrame" ) then return; end
	local orientation = SS.CurrentOrientation(name);
	if ( name == "MainMenuBar" ) then
		local d = SS.DB();
		if ( not d.unlocked and not d.showRacialAbility and not d.plainBar and orientation ~= "vertical" and type(d.sizes.MainMenuBar) ~= "table" ) then return; end
			local first = getglobal("ActionButton1");
			if ( not first ) then return; end
			local vertical = orientation == "vertical";
			local saved = SS.DB().sizes.MainMenuBar;
			local showRacial = d.showRacialAbility and true or false;
			local buttonCount = showRacial and 7 or 6;
			local gap, racialGap = 2, showRacial and 4 or 0;
			local side = first:GetWidth() or 36;
			if ( type(saved) == "table" ) then
			side = math.max(12, math.min(vertical and saved.w or saved.h,
			((vertical and saved.h or saved.w) - gap * (buttonCount - 1) - racialGap) / buttonCount));
			end
			for i = 1, buttonCount do
			local button = getglobal("ActionButton" .. (i == 7 and 12 or i));
			if ( button ) then
			button:SetWidth(side); button:SetHeight(side); button:ClearAllPoints();
			local offset = (i - 1) * (side + gap) + (showRacial and i == 7 and racialGap or 0);
			button:SetPoint("TOPLEFT", MainMenuBar, "TOPLEFT", vertical and 0 or offset, vertical and -offset or 0);
			if ( showRacial and i == 7 and AZS_RacialRim and AZS_RacialRim.SetAllPoints ) then AZS_RacialRim:ClearAllPoints(); AZS_RacialRim:SetAllPoints(button); end
			if ( showRacial and i == 7 and not button.slimRacialBorder ) then
			local rim = CreateFrame("Frame", nil, button);
			rim:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2);
			rim:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2);
			rim:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=8});
			rim:SetBackdropBorderColor(1, 0.78, 0.18, 1); rim:EnableMouse(false);
			button.slimRacialBorder = rim;
			end
			if ( showRacial and i == 7 ) then
			if ( not button:IsShown() ) then button.slimShownByUs = true; end   -- so it can be hidden again later
			button:Show();
			end
			end
			end
		if ( not showRacial ) then SS.RestoreRacialActionButtonLayout(); end
			MainMenuBar:SetWidth(vertical and side or side * buttonCount + gap * (buttonCount - 1) + racialGap);
			MainMenuBar:SetHeight(vertical and side * buttonCount + gap * (buttonCount - 1) + racialGap or side);
			if ( ActionBarUpButton ) then
			ActionBarUpButton:ClearAllPoints(); ActionBarUpButton:SetWidth(12); ActionBarUpButton:SetHeight(12);
			ActionBarUpButton:SetPoint("TOPRIGHT", first, "TOPLEFT", -2, 0);
			end
			if ( ActionBarDownButton ) then
			ActionBarDownButton:ClearAllPoints(); ActionBarDownButton:SetWidth(12); ActionBarDownButton:SetHeight(12);
			ActionBarDownButton:SetPoint("TOPRIGHT", first, "TOPLEFT", -2, -14);
			end
	elseif ( name == "MainMenuExpBar" ) then
		local d = SS.DB();
		if ( not d.unlocked and type(d.places.MainMenuExpBar) ~= "table" and type(d.sizes.MainMenuExpBar) ~= "table"
			and type(d.scales.MainMenuExpBar) ~= "number" and d.orientations.MainMenuExpBar == nil ) then return; end
		local xp = MainMenuExpBar;
		-- Some client builds keep rested-XP child textures anchored to the original horizontal
		-- extent after rotating the status bar. Clip children to the bar when this Frame API exists,
		-- so the movable handle and the rendered XP indicator share the same visible bounds.
		if ( xp and xp.SetClipsChildren ) then SS.Safe(xp.SetClipsChildren, xp, true); end
		if ( xp and xp.SetOrientation ) then SS.Safe(xp.SetOrientation, xp, string.upper(orientation)); end
		SS.Safe(SS.StyleExpBar, orientation == "vertical");
		SS.Safe(SS.LayoutXpSegments);                         -- the dividers turn with the bar
		local base = baseSizes.MainMenuExpBar;
		local saved = SS.DB().sizes.MainMenuExpBar;
		if ( xp and base and type(saved) ~= "table" ) then
			if ( orientation == "vertical" ) then xp:SetWidth(base.h); xp:SetHeight(base.w);
			else xp:SetWidth(base.w); xp:SetHeight(base.h); end
			SS.DB().sizes.MainMenuExpBar = { w = xp:GetWidth(), h = xp:GetHeight() };
		end
	elseif ( name == "BuffFrame" ) then
		SS.ApplyBuffOrientation();
	elseif ( name == "SlimSuiteBossFrames" ) then
		SS.UpdateBossFrames();
	elseif ( name == "PartyMemberFrame1" ) then
		local d = SS.DB();
		-- with yourself in the party the layout always runs, so your card joins the four members
		if ( not d.unlocked and not d.partyIncludesSelf and d.orientations.PartyMemberFrame1 == nil and not SS.demoRunning
			and type(d.places.PartyMemberFrame1) ~= "table" and type(d.sizes.PartyMemberFrame1) ~= "table"
			and type(d.scales.PartyMemberFrame1) ~= "number" ) then
			-- nothing to lay out: frames 2-4 go back to the game's own anchors (after Demo Mode or editing showed a row)
			for i = 2, 4 do
				local frame, points = getglobal("PartyMemberFrame" .. i), partyNativePoints[i];
				if ( frame and points ) then
					frame:ClearAllPoints();
					for p = 1, table.getn(points) do local a = points[p]; frame:SetPoint(a[1], a[2], a[3], a[4], a[5]); end
				end
			end
			return;
		end
		local root = PartyMemberFrame1;
		if ( not root ) then return; end
		for i = 2, 4 do
			local frame = getglobal("PartyMemberFrame" .. i);
			if ( frame and not partyNativePoints[i] and frame.GetNumPoints ) then
				local points = {};
				for p = 1, frame:GetNumPoints() do local a, r, rp, x, y = frame:GetPoint(p); points[p] = { a, r, rp, x, y }; end
				partyNativePoints[i] = points;
			end
			if ( frame ) then
				if ( frame.SetUserPlaced ) then SS.UserPlace(frame); end
				frame:ClearAllPoints();
				if ( orientation == "horizontal" ) then
					frame:SetPoint("LEFT", getglobal("PartyMemberFrame" .. (i - 1)), "RIGHT", 8, 0);
				else
					frame:SetPoint("TOP", getglobal("PartyMemberFrame" .. (i - 1)), "BOTTOM", 0, -4);
				end
				if ( frame.SetUserPlaced ) then SS.UserPlace(frame); end
			end
		end
		-- yourself, before the first member (in the party's own look), and the thin lines
		if ( SS.LayoutPartySelf ) then SS.Safe(SS.LayoutPartySelf, true); SS.Safe(SS.UpdatePartyLines); end
	end
end

function SS.RestoreNativeActionBarLayout()
	local original = actionBarOriginal;
	if ( not original or not MainMenuBar ) then return; end
	MainMenuBar:SetWidth(original.w); MainMenuBar:SetHeight(original.h);
	for i = 1, 6 do
		local button = getglobal("ActionButton" .. i);
		local points = original.buttons[i];
		if ( button ) then
			if ( original.buttonSize ) then button:SetWidth(original.buttonSize); button:SetHeight(original.buttonSize); end
			if ( points and table.getn(points) > 0 ) then
				button:ClearAllPoints();
				for p = 1, table.getn(points) do local a = points[p]; button:SetPoint(a[1], a[2], a[3], a[4], a[5]); end
			end
		end
	end
	SS.RestoreRacialActionButtonLayout();
	for name, layout in pairs(original.arrows or {}) do
		local arrow = getglobal(name);
		if ( arrow ) then
			arrow:SetWidth(layout.w); arrow:SetHeight(layout.h); arrow:ClearAllPoints();
			for p = 1, table.getn(layout.points) do local a = layout.points[p]; arrow:SetPoint(a[1], a[2], a[3], a[4], a[5]); end
		end
	end
end

function SS.SetRacialAbility(on)
	local d = SS.DB();
	d.showRacialAbility = on and true or false;
	if ( on and CaptureActionBarLayout ) then SS.Safe(CaptureActionBarLayout); end
	if ( not d.showRacialAbility and not d.unlocked and not d.plainBar and d.orientations.MainMenuBar ~= "vertical"
		and type(d.sizes.MainMenuBar) ~= "table" ) then
		SS.Safe(SS.RestoreNativeActionBarLayout);
	else
		SS.Safe(ApplyMovableOrientation, "MainMenuBar");
	end
	PlaceAll();
end

-- True when the worn-jewelry row is joined under the spell row. Only the player separates them, with the
-- "Detach build rows" button; nothing else in Slim Suite may break that join.
function SS.BuildRowsJoined(name)
	return name == "SlimSuiteItemRowFrame" and SS.DB().buildRowsAttached and true or false;
end

function SS.Place(name, ignoreAnchor)
	local f = getglobal(name);
	local p = SS.DB().places[name];
	if ( not f ) then return; end
	if ( name == "ChatFrame1" and SS.ChatIsCustom and not SS.ChatIsCustom() ) then return; end
	if ( SS.DB().frameDefault and SS.DB().frameDefault[name] ) then return; end   -- "Default": the game's own placement
	if ( (name == "SlimSuiteSpellRowFrame" and type(p) ~= "table") or (name == "SlimSuiteItemRowFrame" and
		(type(p) ~= "table" or (SS.BuildRowsJoined(name) and p.relative ~= "SlimSuiteSpellRowFrame"))) ) then
		p = SS.BuildRowDefaultPlace(name);
		SS.DB().places[name] = p;
	end
	local w, h = f:GetWidth(), f:GetHeight();
	if ( w and h and w > 0 and h > 0 and not baseSizes[name] ) then baseSizes[name] = { w = w, h = h }; end
	if ( name ~= "GameTooltip" and not basePoints[name] and f.GetNumPoints ) then
		local points = {};
		for i = 1, f:GetNumPoints() do
			local point, relative, relativePoint, x, y = f:GetPoint(i);
			points[i] = { point, relative, relativePoint, x, y };
		end
		if ( table.getn(points) > 0 ) then basePoints[name] = points; end
	end
	if ( name == "MainMenuBar" and CaptureActionBarLayout ) then CaptureActionBarLayout(); end
	SS.ApplySize(name, f);
	if ( name == "PartyMemberFrame1" ) then
		local saved = SS.DB().scales.PartyMemberFrame1;
		local sc = type(saved) == "number" and saved or 1;
		if ( SS.DisplayElementScale ) then sc = SS.DisplayElementScale(name, sc); end
		for i = 1, 4 do local pf = getglobal("PartyMemberFrame" .. i); if ( pf and pf.SetScale ) then pf:SetScale(sc); end end
		for i = 1, 4 do
			local portrait = getglobal("PartyMemberFrame" .. i .. "Portrait");
			if ( portrait ) then if ( SS.DB().partyFaces == false ) then portrait:Hide(); else portrait:Show(); end end
		end
	end
	if ( (name == "PartyMemberFrame1" or name == "SlimSuitePartyLines") and SS.Shown("PartyMemberFrame1") == name ) then
		local lockTo = getglobal(SS.Shown("PlayerFrame")) or PlayerFrame;
		if ( SS.DB().partyLocked and not SS.DB().partyIncludesSelf and lockTo ) then
			local pl, pr = RootBounds(SS.UnitPortrait(lockTo));
			local fl = RootBounds(f);
			local il, ir = RootBounds(SS.UnitPortrait(f));
			local ll = RootBounds(lockTo);
			local factor = RootFactor(f) or 1;
			local offset = (pl and pr and fl and il and ir and ll) and ((pl + pr) / 2 - ll - ((il + ir) / 2 - fl)) / factor or 0;
			f:ClearAllPoints();
			if ( SS.DB().partyLockAbove ) then
				-- the whole party block (all four places, filled or not, stacked or in a row) sits just above the player
				-- frame, so it never grows down over it when someone joins
				local factor = RootFactor(f);
				if ( not factor or factor <= 0 ) then factor = 1; end
				f:SetPoint("TOPLEFT", lockTo, "TOPLEFT", offset, (6 + SS.PartyBlockDepth(f)) / factor);
			else
				f:SetPoint("TOPLEFT", lockTo, "BOTTOMLEFT", offset, -6 / factor);
			end
			return;
		end
	end
	-- Our edge clamp uses visible child bounds; let it place an inset parent slightly outside the screen.
	if ( SS.DB().unlocked or type(p) == "table" ) then
		if ( f.SetClampedToScreen ) then f:SetClampedToScreen(false); end
		if ( (name == "BuffFrame" or name == "MainMenuBar" or name == "MinimapCluster") and f.SetUserPlaced ) then SS.UserPlace(f); end
	end
	if ( type(p) ~= "table" ) then
		if ( SS.PlaceDisplayDefault ) then SS.PlaceDisplayDefault(name, f); end
		return;
	end
	if ( p.coordinateSpace ~= "uiParent" ) then
		local factor = RootFactor(f);
		if ( p.x ) then p.x = p.x * factor; end
		if ( p.y ) then p.y = p.y * factor; end
		if ( p.dx ) then p.dx = p.dx * factor; end
		if ( p.dy ) then p.dy = p.dy * factor; end
		p.coordinateSpace = "uiParent";
	end
	if ( p.x and p.y and not p.screen and not p.displayDefault ) then
		local sl, sr, sb, st = SS.ScreenBounds();
		p.screen = { left=sl, bottom=sb, width=sr-sl, height=st-sb };
	end
	if ( p.displayDefault and not p.relative and SS.PlaceDisplayDefault ) then SS.PlaceDisplayDefault(name, f); return; end
	local relative = not ignoreAnchor and p.relative and getglobal(p.relative) or nil;
	if ( relative and p.point and p.relativePoint ) then
		f:ClearAllPoints();
		local factor = RootFactor(f);
		f:SetPoint(p.point, relative, p.relativePoint, K.Num(p.dx) / factor, K.Num(p.dy) / factor);
	elseif ( p.x and p.y ) then
		-- Saved coordinates can come from a taller or wider display. Clamp absolute restores to this screen
		-- without rewriting the saved location, so a later return to the larger display restores the user's layout.
		local px, py = K.Num(p.x), K.Num(p.y);
		if ( type(p.screen) == "table" and p.screen.width and p.screen.width > 0 and p.screen.height and p.screen.height > 0 ) then
			local sl, sr, sb, st = SS.ScreenBounds();
			px = sl + (px - (p.screen.left or 0)) * (sr-sl) / p.screen.width;
			py = sb + (py - (p.screen.bottom or 0)) * (st-sb) / p.screen.height;
		end
		local x, y = SS.ClampPosition(f, px, py);
		SetRootPosition(f, x, y);
	end
end

PlaceAll = function()
	for i = 1, table.getn(MOVABLE) do SS.Safe(SS.Place, MOVABLE[i][1], true); end
	-- Reapply saved frame-to-frame anchors after every movable frame has its stored size and base position.
	for pass = 1, 3 do                                   -- an anchor chain is at most three frames deep
		for i = 1, table.getn(MOVABLE) do SS.Safe(SS.Place, MOVABLE[i][1], false); end
	end
	-- Relative snaps and scale changes must not leave a frame clipped or padded away from the edge.
	for i = 1, table.getn(MOVABLE) do
		local name = MOVABLE[i][1];
		local frame = getglobal(name);
		if ( frame ) then SS.Safe(SS.ClampToClient, name, frame); end
	end
	if ( SS.DB().mirrorTarget ) then SS.Safe(SS.MirrorTarget); end
	if ( SS.DB().buffsOnTarget or SS.DB().buffsOnPlayer ) then SS.Safe(SS.AttachBuffs); end
end

-- "Mirror target": the target frame stands where the player frame would be if the screen were folded at its center
-- line: same height, same scale, the same distance from the right edge as the player frame is from the left.
-- Which look each unit frame shows. The player frame has its own (classic or new) until it joins another frame: in the
-- party it takes the party's look, combined with the target it takes the target's. The target always keeps its own.
function SS.Look(el)
	local d = SS.DB();
	if ( el == "TargetFrame" ) then return d.targetLook == "new" and "new" or "classic"; end
	if ( el == "PartyMemberFrame1" ) then return d.partyLook == "thin" and "thin" or "classic"; end
	if ( el == "PlayerFrame" ) then
		if ( d.partyIncludesSelf ) then return "party"; end
		if ( d.combineTarget ) then return SS.Look("TargetFrame"); end
		return d.playerLook == "new" and "new" or "classic";
	end
	return "classic";
end
function SS.UsesCard(el) return SS.Look(el) == "new"; end

-- The frame that shows an element now: a new-school card, the thin party lines, or the game's own frame. Every handle,
-- size, reset, hide and buff action goes to the frame the player can see; the others stay invisible underneath.
function SS.Shown(name)
	if ( name == "PlayerFrame" and SS.UsesCard("PlayerFrame") ) then return "SlimSuitePlayerCard"; end
	if ( name == "TargetFrame" and SS.UsesCard("TargetFrame") ) then return "SlimSuiteTargetCard"; end
	if ( name == "PartyMemberFrame1" and SS.Look("PartyMemberFrame1") == "thin" ) then return "SlimSuitePartyLines"; end
	return name;
end
function SS.Element(name)
	if ( name == "SlimSuitePlayerCard" ) then return "PlayerFrame"; end
	if ( name == "SlimSuiteTargetCard" ) then return "TargetFrame"; end
	if ( name == "SlimSuitePartyLines" ) then return "PartyMemberFrame1"; end
	return name;
end

-- where "the player frame" is for buffs and mirroring: your own plate or line while you are in the party
function SS.PlayerAnchor()
	if ( SS.DB().partyIncludesSelf ) then
		local c = getglobal("SlimSuitePartyLines");
		if ( SS.Look("PartyMemberFrame1") == "thin" and c ) then
			for i = 1, table.getn(c.lines or {}) do if ( c.lines[i].unit == "player" and c.lines[i]:IsShown() ) then return c.lines[i]; end end
			return c;
		end
		return getglobal("SlimSuitePartySelfFrame") or PlayerFrame;
	end
	return getglobal(SS.Shown("PlayerFrame"));
end
function SS.Pair()
	return SS.PlayerAnchor(), getglobal(SS.Shown("TargetFrame"));
end

-- Places "to" as the mirror image of "from" across the screen's vertical centre line. The pair always shares
-- scale, so there is no separate same-size setting to maintain.
function SS.MirrorFrames(from, to)
	if ( not from or not to ) then return; end
	local fromName, toName = from:GetName(), to:GetName();
	local scale = SS.DB().scales[fromName];
	SS.DB().scales[toName] = scale;
	if ( to.SetScale ) then
		local applied = type(scale) == "number" and scale or 1;
		if ( SS.DisplayElementScale ) then applied = SS.DisplayElementScale(toName, applied); end
		to:SetScale(applied);
	end
	local w, h = from:GetWidth(), from:GetHeight();
	if ( w and h and w > 0 and h > 0 and toName ~= "PlayerFrame" and toName ~= "TargetFrame" ) then   -- classic art: scale only
		to:SetWidth(w); to:SetHeight(h);
		SS.DB().sizes[toName] = { w = w, h = h };
	end
	local l, r, b, t = RootBounds(from);
	if ( not l or not t ) then return; end
	local factor = RootFactor(to);
	local tw, th = (to:GetWidth() or 0) * factor, (to:GetHeight() or 0) * factor;
	local screenLeft, screenRight = SS.ScreenBounds();
	local x = screenLeft + screenRight - l - tw;
	local y = (b + t) / 2 - th / 2;
	if ( to.SetUserPlaced ) then SS.UserPlace(to); end
	SetRootPosition(to, x, y);
	local p = SS.DB().places[toName];
	if ( type(p) ~= "table" ) then p = {}; SS.DB().places[toName] = p; end
	p.x, p.y, p.coordinateSpace = x, y, "uiParent";
	p.relative, p.point, p.relativePoint, p.dx, p.dy = nil, nil, nil, nil, nil;
end

-- the target placed as the player's mirror image (the player leads)
function SS.MirrorTarget()
	if ( not SS.DB().mirrorTarget ) then return; end
	local P, T = SS.Pair();
	SS.MirrorFrames(P, T);
end

-- the player placed as the target's mirror image (while the target is being dragged or resized)
function SS.MirrorPlayer()
	if ( not SS.DB().mirrorTarget ) then return; end
	local P, T = SS.Pair();
	SS.MirrorFrames(T, P);
end

-- "Buffs on the target frame": the buff frame joins the target frame, above or below it, at the target's scale, and
-- loses its own handle while joined. It is shown in both frames' right-click menus and in the setup's steps.
function SS.UnitPortrait(frame)
	if ( not frame ) then return nil; end
	local name = frame.GetName and frame:GetName();
	local native = name == "PlayerFrame" and getglobal("PlayerPortrait") or (type(name) == "string" and getglobal(name .. "Portrait"));
	for _, region in pairs({ frame.portrait, frame.model, native }) do
		if ( region and region.GetLeft and type(region:GetLeft()) == "number" and (not region.IsShown or region:IsShown()) ) then return region; end
	end
	return frame;
end

function SS.AttachBuffs()
	local P, T = SS.Pair();
	local anchor = SS.DB().buffsOnTarget and T or (SS.DB().buffsOnPlayer and P) or nil;
	if ( not anchor or not BuffFrame ) then return; end
	local side = SS.DB().buffsOnTarget and SS.DB().buffsOnTargetSide or SS.DB().buffsOnPlayerSide;
	local factor = RootFactor(anchor) or 1;
	local scale, x = factor, 6;                                -- the unit frame's size on screen
	if ( anchor == P and SS.DB().partyIncludesSelf and not SS.DB().buffsOnTarget ) then
		-- you in the party: the buffs are sized to your plate or line (about a third of a plate's height, a little taller
		-- than a line) and line up with its left edge; your raid mark sits beside your plate, so the row above is theirs
		local line = (SS.IsPartyLine and SS.IsPartyLine(anchor)) or anchor == getglobal("SlimSuitePartyLines");
		local h = anchor:GetHeight() or 9;
		local icon = line and math.max(10, h * 1.5) or math.max(12, math.min(20, h * 0.32));
		local button = getglobal("BuffButton0") or getglobal("BuffButton1");
		local bh = (button and button.GetHeight and button:GetHeight()) or 30;
		if ( not bh or bh <= 0 ) then bh = 30; end
		scale = factor * icon / bh;
		x = 0;
	end
	BuffFrame:ClearAllPoints();
	if ( SS.DB().partyIncludesSelf and (side == "left" or side == "right") ) then side = "above"; end   -- in the party: above your plate
	if ( side == "above" ) then
		local portrait = SS.DB().partyIncludesSelf and anchor or SS.UnitPortrait(anchor);
		BuffFrame:SetPoint("BOTTOMLEFT", portrait, "TOPLEFT", portrait == anchor and x or 0, 2);
	elseif ( side == "left" ) then BuffFrame:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -4, 0);
	elseif ( side == "right" ) then BuffFrame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0);
	else BuffFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, -2); end
	if ( BuffFrame.SetScale ) then BuffFrame:SetScale(scale); end
	SS.Safe(SS.LayoutPartyBuffs);
end
