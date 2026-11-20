-- The companion: a small 3D copy of your character on the screen, movable and able to dance (the game's animation). It is separate from the
-- Character sheet and from your real character. /slimsuite companion shows or hides it.
if ( setfenv ) then setfenv(1, SS.ENV); end
local frame, danceButton;

local function Store()
	if ( type(SlimSuiteDB) ~= "table" ) then SlimSuiteDB = {}; end
	if ( type(SlimSuiteDB.companion) ~= "table" ) then SlimSuiteDB.companion = { shown = false }; end
	return SlimSuiteDB.companion;
end

local function Load()
	if ( frame ) then return; end
	frame = CreateFrame("PlayerModel", "SlimSuiteCompanionFrame", UIParent);   -- PlayerModel is the type that has SetUnit
	frame:SetWidth(120); frame:SetHeight(160);
	local store = Store();
	if ( not (store.x and store.y) ) then store.x = (UIParent:GetWidth() or 1024) - 160; store.y = 160; end
	frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", store.x, store.y);
	frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton");
	frame:SetScript("OnDragStart", function() this:StartMoving(); end);
	frame:SetScript("OnDragStop", function()
		this:StopMovingOrSizing();
		local left, bottom = this:GetLeft(), this:GetBottom();
		if ( left and bottom ) then Store().x = left; Store().y = bottom; end
	end);
	-- full body: zoom 0 is the whole figure; the portrait zoom is only for the head
	frame:SetScript("OnShow", function()
		SS.Safe(function()
			frame:ClearModel(); frame:SetUnit("player"); frame:SetCamera(0);
			if ( frame.SetPortraitZoom ) then frame:SetPortraitZoom(0); end
		end);
	end);
	frame:Hide();

	-- The game's own animations, by number: 69 dance, 68 cheer, 72 sit on the ground, 0 stand.
	danceButton = K.Button(frame, "Dance", 80, function()
		if ( not frame.SetAnimation ) then
			K.Print(NAME, "This client does not let the companion's model play animations, so it cannot dance yet.");
			return;
		end
		local ok = SS.Safe(frame.SetAnimation, frame, 69);
		if ( not ok ) then K.Print(NAME, "The companion's dance animation failed. Send /slimsuite log."); end
	end);
	danceButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, -26);
end

function SS.ShowCompanion(on)
	Load();
	Store().shown = on and true or false;
	if ( on ) then frame:Show(); else frame:Hide(); end
end

function SS.ToggleCompanion()
	SS.ShowCompanion(not frame or not frame:IsShown());
end

-- Shown again at login when it was on last time.
SS.Every("companionStart", 0, function()
	SS.Stop("companionStart");
	if ( Store().shown ) then SS.ShowCompanion(true); end
end);
