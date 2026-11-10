-- Slim Suite's error log, in the style of Bug Grabber: every Lua error the game reports is kept in
-- SlimSuiteDB.errorLog, which the game saves between logins. /slimsuite errors opens it.
-- recording lives in SlimSuiteCore.lua (SS.LogError); SS.ErrorLog() returns the current log

-- the game calls _ERRORMESSAGE for every Lua error; keep the game's own handling too
local previousHandler = _ERRORMESSAGE;
function _ERRORMESSAGE(msg)
	if ( SS and SS.LogError ) then pcall(SS.LogError, msg); end
	if ( previousHandler ) then previousHandler(msg); end
end

local frame;

local function Refresh()
	if ( not frame ) then return; end
	local log = SS.ErrorLog();
	local lines = {};
	for i = 1, table.getn(log) do
		local e = log[i];
		table.insert(lines, "[" .. (e.at or "?") .. "]" .. ((e.count or 1) > 1 and (" x" .. e.count) or "") .. "  " .. (e.msg or ""));
	end
	if ( table.getn(lines) == 0 ) then lines[1] = "No errors logged. Errors are kept here between logins."; end
	frame.box:SetText(table.concat(lines, "\n"));
	frame.box:SetHeight(math.max(20, (frame.box.GetHeight and frame.box:GetHeight() or 0), table.getn(lines) * 14));   -- the list scrolls to its end
end

local function Build()
	frame = CreateFrame("Frame", "SlimSuiteErrorFrame", UIParent);
	frame:SetWidth(580); frame:SetHeight(380);
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
	title:SetText("Slim Suite error log");

	local scroll = CreateFrame("ScrollFrame", "SlimSuiteErrorScroll", frame, "UIPanelScrollFrameTemplate");
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -40);
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 44);
	local box = CreateFrame("EditBox", "SlimSuiteErrorBox", scroll);
	box:SetMultiLine(true); box:SetAutoFocus(false);
	box:SetFontObject(GameFontHighlightSmall);
	box:SetWidth(530);
	box:SetScript("OnEscapePressed", function() this:ClearFocus(); end);
	scroll:SetScrollChild(box);
	frame.box = box;

	local clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	clear:SetWidth(90); clear:SetHeight(22); clear:SetText("Clear");
	clear:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12);
	clear:SetScript("OnClick", function()
		local log = SS.ErrorLog();
		for i = table.getn(log), 1, -1 do table.remove(log, i); end
		Refresh();
	end);

	local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	close:SetWidth(90); close:SetHeight(22); close:SetText("Close");
	close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12);
	close:SetScript("OnClick", function() frame:Hide(); end);

	frame:SetScript("OnShow", Refresh);
	table.insert(UISpecialFrames, "SlimSuiteErrorFrame");   -- Escape closes it
	frame:Hide();
end

function SS.ShowErrors()
	if ( not frame ) then Build(); end
	Refresh();
	frame:Show();
end
