-- The companion: a small 3D copy of your character on the screen, movable and able to dance. It is separate from the
-- Character sheet and from your real character. /slimsuite companion shows or hides it.
if ( setfenv ) then setfenv(1, SS.ENV); end
local DANCE_ANIMATION = 69;   -- the game's dance animation number; checked in game (change here if it is wrong)
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
	if ( store.x and store.y ) then
		frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", store.x, store.y);
	else
		frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -40, 160);
	end
	frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton");
	frame:SetScript("OnDragStart", function() this:StartMoving(); end);
	frame:SetScript("OnDragStop", function()
		this:StopMovingOrSizing();
		local left, bottom = this:GetLeft(), this:GetBottom();
		if ( left and bottom ) then Store().x = left; Store().y = bottom; end
	end);
	frame:SetScript("OnShow", function() SS.Safe(function() frame:ClearModel(); frame:SetUnit("player"); frame:SetCamera(0); end); end);
	frame:Hide();

	danceButton = K.Button(frame, "Dance", 80, function()
		if ( frame.SetAnimation ) then
			local ok = SS.Safe(frame.SetAnimation, frame, DANCE_ANIMATION);
			if ( not ok ) then K.Print(NAME, "The companion could not dance. Tell Slimjim the animation call failed."); end
		else
			K.Print(NAME, "This client has no animation call for the companion yet.");
		end
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
