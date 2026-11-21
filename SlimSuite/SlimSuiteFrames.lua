-- Slim Suite: the HUD elements: level-up button, encounter bars, announcements, buffs, XP bar, party and target frames.
local K, SU, NAME = SS.Kit, SS.SU, SS.NAME;   -- the three names every Slim Suite file uses (SlimSuiteCore.lua)

-- AZS_SetHudShown stores native HUD visibility in the game's saved interface settings. Every part Slim Suite hid is
-- put back before a clean logout or reload, so disabling Slim Suite in the AddOns screen cannot leave the game's own
-- controls hidden on the next launch (SS.RestoreNatives, in SlimSuiteCore.lua).
SS.nativeHudShutdown = CreateFrame("Frame");
SS.nativeHudShutdown:RegisterEvent("PLAYER_LOGOUT");
SS.nativeHudShutdown:SetScript("OnEvent", function() SS.Safe(SS.RestoreNatives); end);

-- The native Level Up control uses the class symbol from WoW's character-create atlas.
-- Keep this 1.12 mapping local because CLASS_ICON_TCOORDS is not consistently global in
-- Vanilla clients/addon environments.
SS.LEVEL_CLASS_ICON_COORDS = {
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
	return SS.LEVEL_CLASS_ICON_COORDS[key];
end

function SS.CreateLevelButton()
	SS.levelButton = CreateFrame("Button", "SlimSuiteStoredLevelsButton", UIParent);
	SS.levelButton:SetWidth(184);
	SS.levelButton:SetHeight(58);
	SS.levelButton:SetFrameStrata("MEDIUM");
	SS.OwnLook(SS.levelButton, function()
	SS.levelButton:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	SS.levelButton:SetBackdropColor(0.055, 0.035, 0.025, 0.96);
	SS.levelButton:SetBackdropBorderColor(0.82, 0.61, 0.24, 1);
	end);
	SS.levelButton.panel = SS.levelButton:CreateTexture(nil,"BACKGROUND");
	SS.levelButton.panel:SetPoint("TOPLEFT",SS.levelButton,"TOPLEFT",3,-3); SS.levelButton.panel:SetPoint("BOTTOMRIGHT",SS.levelButton,"BOTTOMRIGHT",-3,3);
	SS.levelButton.panel:SetTexture(.12,.055,.025,.9);
	if ( SS.levelButton.panel.SetGradient ) then SS.levelButton.panel:SetGradient("VERTICAL",.045,.025,.015,.20,.09,.035); end
	SS.ThemePanel(SS.levelButton, nil, { SS.levelButton.panel });
	SS.levelButton:EnableMouse(true);
	-- Keep a faint gold halo behind the button, like the game's own level-up control.
	-- This is a region of the button itself, so it follows saved position, scale, and hover growth.
	SS.levelButton.glow = SS.levelButton:CreateTexture(nil, "BACKGROUND");
	SS.levelButton.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border");
	if ( SS.levelButton.glow.SetBlendMode ) then SS.levelButton.glow:SetBlendMode("ADD"); end
	SS.levelButton.glow:SetVertexColor(1, 0.72, 0.22, 0.16);
	SS.levelButton.glow:SetPoint("CENTER", SS.levelButton, "CENTER", 0, 0);
	SS.levelButton.glow:SetWidth(228);
	SS.levelButton.glow:SetHeight(82);
	SS.levelButton.glow:SetAlpha(0.16);
	SS.levelButton.classIcon = SS.levelButton:CreateTexture(nil, "ARTWORK");
	SS.levelButton.classIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes");
	SS.levelButton.classIcon:SetPoint("LEFT", SS.levelButton, "LEFT", 10, 0);
	SS.levelButton.classIcon:SetWidth(40);
	SS.levelButton.classIcon:SetHeight(40);
	local classCoords = SS.PlayerClassIconCoords();
	if ( classCoords ) then
		SS.levelButton.classIcon:SetTexCoord(classCoords[1], classCoords[2], classCoords[3], classCoords[4]);
	else
		SS.levelButton.classIcon:Hide();
	end
	SS.levelButton.level = SS.levelButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	SS.levelButton.level:SetPoint("TOPLEFT", SS.levelButton, "TOPLEFT", 58, -10);
	SS.levelButton.level:SetTextColor(1, 0.78, 0.22);
	SS.levelButton.text = SS.levelButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	SS.levelButton.text:SetPoint("BOTTOMLEFT", SS.levelButton, "BOTTOMLEFT", 58, 8);
	SS.levelButton.text:SetText(SS.T("LEVEL UP!"));
	SS.levelButton:SetScript("OnClick", function()
		if ( type(AZS_OpenStoredLevels) == "function" ) then SS.Safe(AZS_OpenStoredLevels); end
	end);
	SS.levelButton.count = SS.levelButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	SS.levelButton.count:SetPoint("TOPRIGHT", SS.levelButton.classIcon, "TOPRIGHT", -2, -2);
	SS.levelButton.count:SetTextColor(1, 0.78, 0.18);
	SS.levelButton:SetScript("OnEnter", function()
		-- Highlight inside the existing rectangle; do not move or enlarge the button.
		SS.levelButton.glow:SetAlpha(0.24);
	end);
	SS.levelButton:SetScript("OnLeave", function()
		SS.levelButton.glow:SetAlpha(0.16);
	end);
	SS.levelButton:SetScript("OnHide", function()
		SS.levelButton.glow:SetAlpha(0.16);
	end);
	-- Above the default action bar, centered near the bottom as in the supplied reference.
	SS.levelButton:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190);
	SS.levelButton:Hide();

end

function SS.ClockText(seconds)
	if ( type(seconds) ~= "number" or seconds < 0 ) then return "--:--"; end
	seconds = math.floor(seconds);
	return string.format("%02d:%02d", math.floor(seconds / 60), math.mod(seconds, 60));
end

function SS.ApplyClockLayout()
	if ( not SS.clockFrame or not SS.clockFrame.time or not SS.clockFrame.next or not SS.clockFrame.zone ) then return; end
	local d=SS.DB(); local vertical=d.orientations.SlimSuiteClockFrame~="horizontal";
	local w,h=SS.clockFrame:GetWidth(),SS.clockFrame:GetHeight(); local pad=math.min(4+SS.FramePadding("SlimSuiteClockFrame"),w/8,h/8);
	local context=d.zoneLine and 14 or 0; local gap=context>0 and 2 or 0;
	local above=d.clockContextAbove~=false;
	local contentTop=pad+(above and context+gap or 0);
	local contentHeight=math.max(1,h-pad*2-context-gap);
	local line=vertical and math.max(1,(contentHeight-2)/2) or contentHeight;
	SS.clockFrame.zone:ClearAllPoints(); SS.clockFrame.zone:SetWidth(math.max(1,w-pad*2)); SS.clockFrame.zone:SetHeight(14);
	if ( above ) then SS.clockFrame.zone:SetPoint("TOP",SS.clockFrame,"TOP",0,-pad);
	else SS.clockFrame.zone:SetPoint("BOTTOM",SS.clockFrame,"BOTTOM",0,pad); end
	SS.clockFrame.time:ClearAllPoints(); SS.clockFrame.next:ClearAllPoints();
	SS.clockFrame.timeH,SS.clockFrame.nextH=line,line;
	if ( vertical ) then
		SS.clockFrame.timeW,SS.clockFrame.nextW=w-pad*2,w-pad*2;
		SS.clockFrame.time:SetPoint("TOP",SS.clockFrame,"TOP",0,-contentTop);
		SS.clockFrame.next:SetPoint("TOP",SS.clockFrame,"TOP",0,-contentTop-line-2);
		SS.clockFrame.time:SetJustifyH("CENTER"); SS.clockFrame.next:SetJustifyH("CENTER");
	else
		SS.clockFrame.timeW=math.max(1,(w-pad*2)*.34);
		SS.clockFrame.nextW=math.max(1,w-pad*2-SS.clockFrame.timeW-8);
		SS.clockFrame.time:SetPoint("TOPLEFT",SS.clockFrame,"TOPLEFT",pad,-contentTop);
		SS.clockFrame.next:SetPoint("TOPRIGHT",SS.clockFrame,"TOPRIGHT",-pad,-contentTop);
		SS.clockFrame.time:SetJustifyH("RIGHT"); SS.clockFrame.next:SetJustifyH("LEFT");
	end
	SS.clockFrame.time:SetWidth(SS.clockFrame.timeW); SS.clockFrame.time:SetHeight(line);
	SS.clockFrame.next:SetWidth(SS.clockFrame.nextW); SS.clockFrame.next:SetHeight(line);
end

function SS.CreateClockFrame()
	SS.clockFrame = CreateFrame("Frame", "SlimSuiteClockFrame", UIParent);
	SS.clockFrame:SetWidth(220);
	SS.clockFrame:SetHeight(54);
	SS.clockFrame:SetPoint("TOP", UIParent, "TOP", 0, -6);
	SS.clockFrame:SetFrameStrata("MEDIUM");
	SS.clockFrame:EnableMouse(false);
	SS.clockFrame.time = SS.clockFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	SS.clockFrame.time:SetPoint("TOP", SS.clockFrame, "TOP", 0, 0);
	SS.clockFrame.time:SetWidth(220);
	SS.clockFrame.time:SetJustifyH("CENTER");
	SS.clockFrame.time:SetTextColor(1, 0.82, 0.28);
	SS.clockFrame.next = SS.clockFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	SS.clockFrame.next:SetPoint("TOP", SS.clockFrame.time, "BOTTOM", 0, -2);
	SS.clockFrame.next:SetWidth(220);
	SS.clockFrame.next:SetJustifyH("CENTER");
	SS.clockFrame.next:SetTextColor(0.74, 0.72, 0.66);
	-- The zone line (AZS_ZONE): where you are and the run's Heroic affixes, just under the clock.
	SS.clockFrame.zone = SS.clockFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	SS.clockFrame.zone:SetPoint("TOP", SS.clockFrame, "BOTTOM", 0, -1);
	SS.clockFrame.zone:SetTextColor(0.85, 0.75, 0.55);
	-- Both lines share one parent and one movement handle; they cannot be separated while repositioning.
	SS.ApplyClockLayout();
	SS.clockFrame:Hide();
end

function SS.IsExplosiveOrb(unit)
	if ( type(unit)~="table" or type(unit.name)~="string" ) then return false; end
	local kind=SS.UnitKind(unit);
	return string.lower(unit.name)=="explosive orb" and (kind=="normal" or kind=="elite" or kind=="guardian" or kind=="boss");
end

function SS.BossPriority(unit)
	if SS.IsExplosiveOrb(unit) then return 0; end
	local kind = SS.UnitKind(unit);
	if ( kind == "final" ) then return 1; end
	if ( kind == "boss" ) then return 2; end
	if ( kind == "guardian" ) then return 3; end
	-- Ordinary elites are not encounters, even when they share a guardian name.
	return nil;
end

function SS.EncounterVertical()
	return SS.DB().orientations.SlimSuiteBossFrames == "vertical";
end

-- the most encounter bars shown at once (Most bars shown): nil shows every one
function SS.EncounterMost()
	local most = tonumber(SS.DB().encounterMax);
	if ( most and most >= 1 ) then return math.floor(most); end
	return nil;
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
	local list,seen = {},{};
	for i = 1, table.getn(units) do
		local unit = units[i];
		local priority = type(unit) == "table" and SS.BossPriority(unit) or nil;
		local awake = type(unit) == "table" and (SS.IsExplosiveOrb(unit) or SS.UnitKind(unit) ~= "guardian" or unit.state == 1);
		if ( priority and awake and type(unit.id) == "number" and type(unit.name) == "string"
			and type(unit.hp) == "number" and type(unit.hpm) == "number" and unit.hp > 0 and unit.hpm > 0 ) then
			table.insert(list, { id = unit.id, name = unit.name, kind = SS.UnitKind(unit), hp = unit.hp, hpm = unit.hpm, priority = priority, order = i });
			seen[unit.id]=true;
		end
	end
	if SlimSuiteWorld and SlimSuiteWorld.ExplosiveOrbs then
		for _,orb in ipairs(SlimSuiteWorld.ExplosiveOrbs()) do
			if not seen[orb.id] then
				table.insert(list,{id=orb.id,name=orb.name,kind="normal",hp=orb.hp,hpm=orb.hpm,
					unknownHealth=not orb.hp or not orb.hpm,priority=0,order=table.getn(units)+table.getn(list)+1});
			end
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
	local x, right, y = SS.RootBounds(f);
	if ( x == nil and type(saved) == "table" ) then x = saved.x; end
	if ( y == nil and type(saved) == "table" ) then y = saved.y; end
	if ( type(x) ~= "number" or type(y) ~= "number" ) then return; end
	local nx, ny = SS.ClampPosition(f, x, y);
	if ( nx ~= x or ny ~= y ) then
		SS.SetRootPosition(f, nx, ny);
	end
end

-- Target identity arrives in AZSTGT after the native selection changes. Never spin
-- through enemies against the previous server snapshot in a single click handler.
local targetRequest;
local function FinishEncounterTarget(success)
	SS.encounterTargetResult=success;
	targetRequest=nil; SS.Stop("encounterTarget");
end
local function RestoreEncounterTarget()
	local request=targetRequest; if not request then return; end
	if ( type(AZS_TARGET)=="table" and AZS_TARGET.id==request.previousId ) then FinishEncounterTarget(false); return; end
	if ( request.previousName and TargetByName ) then
		request.restoring=true; request.waitUntil=GetTime()+1;
		SS.Safe(TargetByName,request.previousName,true);
	else
		FinishEncounterTarget(false);
		if ClearTarget then SS.Safe(ClearTarget); end
	end
end
local function StepEncounterTarget()
	local request=targetRequest; if not request then return; end
	if request.restoring then
		if GetTime()>=request.waitUntil then
			FinishEncounterTarget(false);
			if ClearTarget then SS.Safe(ClearTarget); end
		end
		return;
	end
	if GetTime()>=request.deadline or request.attempts>=40 then RestoreEncounterTarget(); return; end
	if request.waitUntil then
		if GetTime()>=request.waitUntil then
			-- no answer to the by-name try: go on to cycling instead of giving up
			if request.byName then request.byName=nil; request.waitUntil=nil; return; end
			RestoreEncounterTarget();
		end
		return;
	end
	request.attempts=request.attempts+1; request.waitUntil=GetTime()+1;
	-- first try the clicked enemy's exact name (bosses and guardians are almost always unique); cycling
	-- through the nearest enemies only reaches enemies close to you and is the fallback for namesakes
	if request.attempts==1 and request.name and TargetByName then
		request.byName=true;
		SS.Safe(TargetByName,request.name,true);
		return;
	end
	local ok=SS.Safe(TargetNearestEnemy);
	if not ok then RestoreEncounterTarget(); end
end
function SS.TargetEncounter(unit)
	if ( not unit or not unit.id or not TargetNearestEnemy ) then return false; end
	if ( type(AZS_TARGET)=="table" and AZS_TARGET.id==unit.id and
		(not UnitCanAttack or UnitCanAttack("player","target")) ) then return true; end
	targetRequest={id=unit.id,previousId=type(AZS_TARGET)=="table" and AZS_TARGET.id,
		previousName=type(AZS_TARGET)=="table" and AZS_TARGET.name,name=unit.name,seen={},attempts=0,deadline=GetTime()+6};
	SS.encounterTargetResult=nil;
	SS.Every("encounterTarget",.05,StepEncounterTarget);
	StepEncounterTarget();
	return true; -- accepted; success is established only by the subsequent authoritative event
end
local encounterTargetEvents=CreateFrame("Frame");
encounterTargetEvents:RegisterEvent("CHAT_MSG_ADDON");
encounterTargetEvents:RegisterEvent("PLAYER_ENTERING_WORLD");
encounterTargetEvents:SetScript("OnEvent",function()
	if event=="PLAYER_ENTERING_WORLD" then FinishEncounterTarget(false); return; end
	if arg1~="AZSTGT" or not targetRequest or type(AZS_TARGET)~="table" then return; end
	local request=targetRequest;
	if not request.waitUntil then return; end
	if request.restoring then
		local clear=AZS_TARGET.id~=request.previousId;
		FinishEncounterTarget(false);
		if clear and ClearTarget then SS.Safe(ClearTarget); end
		return;
	end
	if AZS_TARGET.id==request.id and (not UnitCanAttack or UnitCanAttack("player","target")) then FinishEncounterTarget(true); return; end
	if request.byName then request.byName=nil; request.waitUntil=nil; return; end -- a namesake: cycle from here
	local key=tostring(AZS_TARGET.id)..":"..tostring(AZS_TARGET.kind)..":"..tostring(AZS_TARGET.name);
	if request.seen[key] then RestoreEncounterTarget(); return; end
	request.seen[key]=true; request.waitUntil=nil; -- one more enemy on the next UI tick
end);

function SS.EncounterRow(index)
	if ( SS.encounterRows[index] ) then return SS.encounterRows[index]; end
	local row = CreateFrame("Button", nil, SS.bossFrame);
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
	-- an encounter row has no backdrop in Original; the chosen panel is drawn behind it in the other two styles
	row.slimName = "SlimSuiteBossFrames";
	SS.OwnLook(row, function() row:SetBackdrop(nil); end);
	row:SetScript("OnClick", function()
		local unit = this.unit;
		SS.TargetEncounter(unit);
	end);
	row:SetScript("OnEnter", function()
		if ( not this.unit or not GameTooltip ) then return; end
		if ( GameTooltip.SetClampedToScreen ) then GameTooltip:SetClampedToScreen(true); end
		local center = this:GetCenter();
		local onRight = center and center * SS.RootFactor(this) > (UIParent:GetWidth() / 2);
		GameTooltip:SetOwner(this, onRight and "ANCHOR_LEFT" or "ANCHOR_RIGHT");
		GameTooltip:AddLine(this.unit.name .. "  [" .. (SS.IsExplosiveOrb(this.unit) and this.unit.name or (this.unit.kind == "guardian" and "Guardian" or (this.unit.kind == "elite" and "Elite" or "Boss"))) .. "]");
		if this.unit.unknownHealth then GameTooltip:AddLine(SS.T("Health unavailable"),1,.82,0);
		else GameTooltip:AddLine("Health: " .. tostring(math.floor(this.unit.hp)) .. " / " .. tostring(math.floor(this.unit.hpm)), 1, 0.82, 0); end
		GameTooltip:AddLine("Click to target", 0.75, 0.75, 0.75);
		GameTooltip:Show();
	end);
	row:SetScript("OnLeave", function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
	SS.encounterRows[index] = row;
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
	-- upright cards with a most-bars limit: every card is sized for that many, so the limit fits in the room four
	-- default cards (or the saved width) take; fewer bosses just leave the later places empty
	local mostAcross = SS.EncounterMost();
	if ( vertical and mostAcross ) then
		local room = type(configured) == "table" and configured.w or (4 * defaultCardWidth + 3 * gap + padding * 2);
		cardWidth = math.max(minCardWidth, (room - padding * 2 - (mostAcross - 1) * gap) / mostAcross);
	end
	frameWidth = across * cardWidth + ((across - 1) * gap) + (padding * 2);
	local frameHeight = type(configured) == "table" and configured.h or (vertical and 252 or (count * 48));
	-- with a most-bars limit, the saved height is the room for that many rows: each row keeps its share, so one boss
	-- takes one row's height and the frame grows (down from where it is pinned) as more arrive
	local most = SS.EncounterMost();
	if ( most and not vertical and type(configured) == "table" and configured.h ) then
		frameHeight = math.max(42, (configured.h - padding * 2) / most) * count + padding * 2;
	end
	local minimumHeight = vertical and cardMinH or math.max(count * (24 + padding + barThickness + 4) + padding * 2, cardMinH);
	frameHeight = math.max(minimumHeight, frameHeight);
	SS.bossFrame:SetWidth(frameWidth);
	SS.bossFrame:SetHeight(frameHeight);
	local rowHeight = vertical and math.max(58, frameHeight - (padding * 2)) or math.max(42, (frameHeight - (padding * 2)) / count);
	-- the rows are laid out again only when what decides their places changes (the bosses, their kinds, the size or
	-- layout); otherwise only health and debuffs are drawn
	local d = SS.DB();
	local nameAlign = d.encounterNameAlign == "left" and "LEFT" or (d.encounterNameAlign == "right" and "RIGHT" or "CENTER");
	local largeNames = d.accessibilityLargeText and true or false;
	local highContrast = d.accessibilityContrast and true or false;
	local sig = (vertical and "v" or "h") .. padding .. "|" .. cardWidth .. "|" .. rowHeight .. "|" .. nameAlign .. "|" .. barThickness .. "|" .. tostring(largeNames);
	for i = 1, count do sig = sig .. "|" .. tostring(list[i].name) .. tostring(list[i].kind)..tostring(list[i].unknownHealth); end
	local relayout = SS.bossFrame.sig ~= sig;
	SS.bossFrame.sig = sig;
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
		row:SetPoint("TOPLEFT", SS.bossFrame, "TOPLEFT", vertical and (padding + ((i - 1) * (cardWidth + gap))) or padding, -(padding + (vertical and 0 or ((i - 1) * rowHeight))));
		row.name:SetText(unit.name..(unit.unknownHealth and (" ("..SS.T("Health unavailable")..")") or ""));
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
		local health = unit.unknownHealth and 0 or math.max(0, math.min(1, unit.hp / unit.hpm));
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
	for i = table.getn(list) + 1, table.getn(SS.encounterRows) do SS.encounterRows[i]:Hide(); end
	return frameHeight;
end


function SS.UpdateClock()
	if not SS.FeatureEnabled("SlimSuiteClockFrame") then if SS.clockFrame then SS.clockFrame:Hide();end;SS.HideNative("clock", false);return;end
	if ( not SS.clockFrame ) then return; end
	local phase = type(AZS_GetPhase) == "function" and AZS_GetPhase() or nil;
	local live = phase == "ready" or phase == "playing" or phase == "choosing" or phase == "paused";
	-- This movable replacement must not inherit the native clock's independent HUD visibility flag.
	local showClock = live;
	local preview = not showClock;
	if ( showClock ) then
		local elapsed = type(AZS_GetRunTime) == "function" and AZS_GetRunTime() or nil;
		if ( phase == "ready" ) then elapsed = 0; end
		SS.clockFrame.time:SetText(SS.ClockText(elapsed));
		local upcoming = {};
		if ( type(AZS_GetUpcomingBosses) == "function" ) then
			local ok, value = SS.Safe(AZS_GetUpcomingBosses);
			if ( ok and type(value) == "table" ) then upcoming = value; end
		end
		local left = type(upcoming[1]) == "table" and upcoming[1].left or nil;
		local run = type(AZS_RUN) == "table" and AZS_RUN or nil;
		if ( type(left) ~= "number" and run and type(run.nb) == "number" and run.nb >= 0 ) then left = run.nb; end
		if ( type(left) == "number" and left >= 0 ) then
			SS.clockFrame.next:SetText(SS.T("next boss in") .. " " .. SS.ClockText(math.ceil(left)));
		else
			SS.clockFrame.next:SetText(SS.T("next boss in") .. " --:--");
		end
		SS.HideNative("clock", true);
		SS.clockFrame.time:Show();
		SS.clockFrame.next:Show();
	else
		SS.HideNative("clock", false);
		if ( preview and SS.Demoing("SlimSuiteClockFrame") and SS.demoClock ) then
			-- Demo Mode: the run time counts up from a random start; the (made-up) next boss counts down and starts over
			SS.clockFrame.time:SetText(SS.ClockText(math.floor(SS.demoClock.run)));
			SS.clockFrame.next:SetText(SS.T("next boss in") .. " " .. SS.ClockText(math.ceil(SS.demoClock.nextBoss)));
			SS.clockFrame.time:Show(); SS.clockFrame.next:Show();
		elseif ( preview ) then
			SS.clockFrame.time:SetText("00:00");
			SS.clockFrame.next:SetText(SS.T("next boss in") .. " --:--");
			SS.clockFrame.time:Show();
			SS.clockFrame.next:Show();
		else
			SS.clockFrame.time:Hide();
			SS.clockFrame.next:Hide();
		end
	end
	if ( SS.clockFrame.zone ) then
		-- the sample zone line only while the clock is being placed or in Demo Mode; otherwise only the game's own
		local zone = SS.DB().zoneLine and SS.LocationContext(SS.Previewing("SlimSuiteClockFrame")) or nil;
		if ( zone and (showClock or preview) ) then SS.clockFrame.zone:SetText(zone); SS.clockFrame.zone:Show(); else SS.clockFrame.zone:Hide(); end
	end
	SS.ApplyClockLayout();
	SS.FitText(SS.clockFrame.time, SS.clockFrame.timeW,7,SS.clockFrame.timeH);
	SS.FitText(SS.clockFrame.next, SS.clockFrame.nextW,7,SS.clockFrame.nextH);
	if ( SS.clockFrame.zone ) then SS.FitText(SS.clockFrame.zone, math.max(1,(SS.clockFrame:GetWidth() or 0)-8),7,14); end
	if ( SS.EnforceElementBounds ) then SS.EnforceElementBounds(SS.clockFrame); end
	if ( showClock or preview ) then
		SS.clockFrame:Show();
		SS.ClampAbsoluteFrame("SlimSuiteClockFrame", SS.clockFrame);
	else SS.clockFrame:Hide(); end
end

function SS.UpdateBossFrames()
	if not SS.FeatureEnabled("SlimSuiteBossFrames") then if SS.bossFrame then SS.bossFrame:Hide();end;SS.HideNative("bosses", false);return;end
	if ( not SS.bossFrame ) then return; end
	local phase = type(AZS_GetPhase) == "function" and AZS_GetPhase() or nil;
	local live = phase == "playing" or phase == "choosing" or phase == "paused";
	-- The replacement is driven by the documented AZS_UNITS data, independently of whether the
	-- player had the native boss frames enabled. Visibility of the original HUD must not gate ours.
	if ( live ) then
		local list = SS.EncounterList();
		local most = SS.EncounterMost();
		if ( most and table.getn(list) > most ) then
			local kept = {}; for i = 1, most do kept[i] = list[i]; end
			for i = most + 1, table.getn(SS.encounterRows) do if ( SS.encounterRows[i] ) then SS.encounterRows[i]:Hide(); end end
			list = kept;
		end
		local height = SS.UpdateEncounterRows(list);
		if ( height > 0 ) then
			SS.bossFrame:SetHeight(height);
			SS.ClampAbsoluteFrame("SlimSuiteBossFrames", SS.bossFrame);
			SS.HideNative("bosses", true);
			SS.bossFrame:Show();
		else
			SS.HideNative("bosses", false);
			SS.bossFrame:Hide();
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
		if ( height > 0 ) then SS.bossFrame:SetHeight(height); end
		SS.ClampAbsoluteFrame("SlimSuiteBossFrames", SS.bossFrame);
		SS.HideNative("bosses", false);
		SS.bossFrame:Show();
	else
		-- before a run there is nothing to show
		for i = 1, table.getn(SS.encounterRows) do SS.encounterRows[i]:Hide(); end
		SS.HideNative("bosses", false);
		SS.bossFrame:Hide();
	end
end

SS.encounterUpdates = CreateFrame("Frame");
SS.encounterUpdates:RegisterEvent("CHAT_MSG_ADDON");
SS.encounterUpdates:SetScript("OnEvent", function()
	if ( arg1 == "AZSUNITS" ) then SS.Safe(SS.UpdateBossFrames); end
end);

SS.CreateClockFrame();
SS.bossFrame = CreateFrame("Frame", "SlimSuiteBossFrames", UIParent);
SS.bossFrame:SetWidth(520);
SS.bossFrame:SetHeight(48);
-- Match the game's centered encounter nameplate, with the independent run clock above it.
SS.bossFrame:SetPoint("TOP", UIParent, "TOP", 0, -76);
SS.bossFrame:SetFrameStrata("MEDIUM");
SS.bossFrame:EnableMouse(false);
SS.bossFrame:Hide();

function SS.CreateAnnouncementFrame()
	SS.announcementFrame = CreateFrame("Frame", "SlimSuiteAnnouncementFrame", UIParent);
	local bannerWidth = math.max(280, math.min(920, UIParent:GetWidth() - 24));
	SS.announcementFrame:SetWidth(bannerWidth);
	SS.announcementFrame:SetHeight(60);
	SS.announcementFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 112);
	SS.announcementFrame:SetFrameStrata("HIGH");
	SS.announcementFrame:EnableMouse(false);
	SS.announcementFrame.text = SS.announcementFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	SS.announcementFrame.text:SetPoint("CENTER", SS.announcementFrame, "CENTER", 0, 0);
	SS.announcementFrame.text:SetWidth(bannerWidth - 20);
	SS.announcementFrame.text:SetHeight(60);
	SS.announcementFrame.text:SetJustifyH("CENTER");
	SS.announcementFrame.text:SetJustifyV("MIDDLE");
	SS.announcementFrame.text:SetNonSpaceWrap(true);
	SS.SetGameDefaultFont(SS.announcementFrame.text, 22);
	SS.announcementFrame.text:SetTextColor(0.96, 0.82, 0.52);
	SS.OwnLook(SS.announcementFrame, function() SS.announcementFrame:SetBackdrop(nil); end);
	SS.announcementFrame:Hide();
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
		if ( SS.announcementFrame ) then SS.announcementFrame:Hide(); end
		return;
	end
	if ( type(banner) ~= "table" ) then return; end
	if ( banner.id ~= nil and banner.id == SS.lastBannerId ) then return; end
	local text = type(banner.text) == "string" and banner.text or "";
	if ( text == "" and type(AZS_BANNER) == "table" and type(AZS_BANNER.text) == "string" ) then
		text = AZS_BANNER.text;
	end
	if ( text == "" and type(banner.name) == "string" and banner.name ~= "" ) then text = banner.name; end
	if ( text == "" ) then return; end
	SS.lastBannerId = banner.id;
	SS.announcementFrame.text:SetText(text);
	if ( banner.boss ) then SS.announcementFrame.text:SetTextColor(1, 0.24, 0.13);
	else SS.announcementFrame.text:SetTextColor(0.96, 0.82, 0.52); end
	SS.announcementStarted = GetTime();
	SS.announcementFrame:SetAlpha(0);
	SS.announcementFrame:Show();
	SS.ClampAbsoluteFrame("SlimSuiteAnnouncementFrame", SS.announcementFrame);
	SS.HideNative("banners", true);
end

function SS.UpdateAnnouncementFrame()
	SyncAnnouncementNative();
	if not SS.FeatureEnabled("SlimSuiteAnnouncementFrame") then if SS.announcementFrame then SS.announcementFrame:Hide();end;return;end
	if ( not SS.announcementFrame ) then return; end
	local maxWidth = math.max(40, UIParent:GetWidth() - 24);
	if ( SS.announcementFrame:GetWidth() > maxWidth ) then SS.announcementFrame:SetWidth(maxWidth); end
	SS.announcementFrame.text:SetWidth(math.max(40, SS.announcementFrame:GetWidth() - 20));
	SS.announcementFrame.text:SetHeight(SS.announcementFrame:GetHeight());
	if ( SS.announcementStarted ) then
		local elapsed = GetTime() - SS.announcementStarted;
		if ( elapsed >= SS.announcementDuration ) then
			SS.announcementStarted = nil;
			SS.announcementFrame:Hide();
			return;
		end
		local alpha = 1;
		if ( elapsed < SS.announcementFade ) then alpha = elapsed / SS.announcementFade;
		elseif ( elapsed > SS.announcementDuration - SS.announcementFade ) then
			alpha = (SS.announcementDuration - elapsed) / SS.announcementFade;
		end
		SS.announcementFrame:SetAlpha(math.max(0, math.min(1, alpha)));
	elseif ( SS.Previewing("SlimSuiteAnnouncementFrame") ) then
		SS.announcementFrame.text:SetText("Hogger enters the battlefield!");
		SS.announcementFrame.text:SetTextColor(1, 0.24, 0.13);
		SS.announcementFrame:SetAlpha(1);
		SS.announcementFrame:Show();
		SS.ClampAbsoluteFrame("SlimSuiteAnnouncementFrame", SS.announcementFrame);
	else
		SS.announcementFrame:Hide();
	end
end

SS.CreateAnnouncementFrame();
SS.Every("announcement", 0, function()
	if ( SS.announcementStarted ) then SS.Safe(SS.UpdateAnnouncementFrame); end
end, SS.announcementFrame);
SS.bannerHandler = function(banner)
	if SS.OnEncounterKillBanner then SS.Safe(SS.OnEncounterKillBanner,banner); end
	SS.Safe(SS.ShowAnnouncement,banner);
end;
SS.bannerHandlerRegistered = false;
function SS.RegisterAnnouncementHandler()
	if ( SS.bannerHandlerRegistered ) then return true; end
	if ( type(AZS_RegisterBannerHandler) ~= "function" ) then return false; end
	local ok = SS.Safe(AZS_RegisterBannerHandler, SS.bannerHandler);
	if ( ok ) then
		SS.bannerHandlerRegistered = true;
		SyncAnnouncementNative();
	end
	return SS.bannerHandlerRegistered;
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
		SS.Safe(SS.ApplyActionSlotGrid);
		local rowPreview = SS.Previewing("SlimSuiteItemRowFrame") or SS.Previewing("SlimSuiteSpellRowFrame");
		if ( rowPreview ~= SS.rowPreviewWas ) then SS.rowPreviewWas = rowPreview; SS.Safe(SS.RefreshItemRow); SS.Safe(SS.RefreshSpellRow); end
		SS.Safe(SS.UpdateTooltipPreview);
		local tooltipHandle = SS.handles.GameTooltip;
		if ( tooltipHandle ) then
			if ( SS.IsEditing("GameTooltip") ) then tooltipHandle:Show();
			else tooltipHandle:Hide(); end
		end
		for i = 1, table.getn(SS.MOVABLE) do
			local name = SS.MOVABLE[i][1];
			if ( SS.DB().muted[name] ) then SS.Safe(SS.ApplyFeatureMute, name); end
		end
end);
