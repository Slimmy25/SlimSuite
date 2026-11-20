-- The action log: the last 100 things Slim Suite did (element changes, HUD Edit, target requests, errors), kept between
-- logins. /slimsuite log opens it; Copy selects all of it, then Ctrl+C copies it to paste into a message.
if ( setfenv ) then setfenv(1, SS.ENV); end
local MAX_ACTIONS = 100;
local frame, box;

local function Entries()
	if ( type(SlimSuiteDB) ~= "table" ) then SlimSuiteDB = {}; end
	if ( type(SlimSuiteDB.actionLog) ~= "table" ) then SlimSuiteDB.actionLog = {}; end
	return SlimSuiteDB.actionLog;
end

function SS.LogAction(text)
	local log = Entries();
	table.insert(log, date("%H:%M:%S") .. "  " .. tostring(text or ""));
	while ( table.getn(log) > MAX_ACTIONS ) do table.remove(log, 1); end
end

local function Refresh()
	if ( not box ) then return; end
	local log = Entries();
	if ( table.getn(log) == 0 ) then box:SetText("No actions logged yet."); return; end
	box:SetText(table.concat(log, "\n"));
end

local function Build()
	frame = CreateFrame("Frame", "SlimSuiteActionFrame", UIParent);
	frame:SetWidth(580); frame:SetHeight(400);
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
	frame:SetFrameStrata("DIALOG");
	frame:SetMovable(true); frame:EnableMouse(true);
	frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	frame:SetBackdropColor(0.04, 0.035, 0.07, 0.97);
	frame:SetBackdropBorderColor(0.85, 0.65, 0.2, 1);
	frame:RegisterForDrag("LeftButton");
	frame:SetScript("OnDragStart", function() this:StartMoving(); end);
	frame:SetScript("OnDragStop", function() this:StopMovingOrSizing(); end);

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10);
	title:SetText("Slim Suite action log (last " .. MAX_ACTIONS .. ")");

	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -32);
	hint:SetText("Press Copy, then Ctrl+C, and paste it here.");

	local scroll = CreateFrame("ScrollFrame", "SlimSuiteActionScroll", frame, "UIPanelScrollFrameTemplate");
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -52);
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 44);
	box = CreateFrame("EditBox", "SlimSuiteActionBox", scroll);
	box:SetMultiLine(true); box:SetAutoFocus(false);
	box:SetFontObject(GameFontHighlightSmall);
	box:SetWidth(530);
	box:SetScript("OnEscapePressed", function() this:ClearFocus(); end);
	scroll:SetScrollChild(box);

	local copy = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	copy:SetWidth(90); copy:SetHeight(22); copy:SetText("Copy");
	copy:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12);
	copy:SetScript("OnClick", function() Refresh(); box:SetFocus(); box:HighlightText(); end);

	local clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	clear:SetWidth(90); clear:SetHeight(22); clear:SetText("Clear");
	clear:SetPoint("LEFT", copy, "RIGHT", 8, 0);
	clear:SetScript("OnClick", function()
		local log = Entries();
		for i = table.getn(log), 1, -1 do table.remove(log, i); end
		Refresh();
	end);

	local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	close:SetWidth(90); close:SetHeight(22); close:SetText("Close");
	close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12);
	close:SetScript("OnClick", function() frame:Hide(); end);

	frame:SetScript("OnShow", Refresh);
	table.insert(UISpecialFrames, "SlimSuiteActionFrame");
	frame:Hide();
end

function SS.ShowActionLog()
	if ( not frame ) then Build(); end
	Refresh();
	frame:Show();
end

-- Record the actions as they happen. Each wrapper calls the original and then logs.
local function Wrap(name, describe)
	local original = SS[name];
	if ( type(original) ~= "function" ) then return; end
	SS[name] = function(a, b, c)
		local ok, r1, r2 = pcall(original, a, b, c);
		local text = describe(a, b, c);
		if ( text ) then SS.LogAction(text); end
		if ( not ok ) then error(r1, 0); end
		return r1, r2;
	end
end
Wrap("OpenHUDEdit", function() return "HUD Edit opened"; end);
Wrap("CloseHUDEdit", function() return "HUD Edit closed"; end);
-- only a real change is logged (the same state set again is not news)
local setUnlocked = SS.SetUnlocked;
if ( type(setUnlocked) == "function" ) then
	SS.SetUnlocked = function(on, quiet)
		local was = SS.DB().unlocked and true or false;
		local result = setUnlocked(on, quiet);
		if ( was ~= (on and true or false) ) then SS.LogAction("UI " .. (on and "unlocked" or "locked")); end
		return result;
	end
end
Wrap("TargetEncounter", function(unit) return "Encounter target: " .. tostring(unit and unit.name or "?"); end);
Wrap("LogError", function(msg) return "ERROR: " .. tostring(msg); end);
Wrap("SetSnap", function(on) return "Snap to elements " .. (on and "on" or "off"); end);
if ( type(SU) == "table" and SU.SetMode ) then
	local setMode = SU.SetMode;
	SU.SetMode = function(name, mode, title)
		local was = SU.Mode(name);
		local result = setMode(name, mode, title);
		if ( was ~= mode ) then SS.LogAction("Element " .. tostring(name) .. " set to " .. tostring(mode)); end
		return result;
	end
end
