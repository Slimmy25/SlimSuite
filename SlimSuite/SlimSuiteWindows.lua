-- Blizzard's Character and Talent windows as movable Slim Suite elements. The game re-anchors these panels every time
-- they open, so the saved place is applied again on each show. Nothing is touched when they are absent.
if ( setfenv ) then setfenv(1, SS.ENV); end
local function Hook(name)
	local f = getglobal(name);
	if ( not f or not f.SetScript or not f.GetScript ) then return; end
	local old = f:GetScript("OnShow");
	f:SetScript("OnShow", function()
		if ( old ) then old(); end
		local d = SS.DB(); if ( d.places[name] ~= nil and not (d.frameDefault and d.frameDefault[name]) ) then SS.Safe(SS.Place, name, false); end
	end);
end
Hook("CharacterFrame");
Hook("TalentFrame");
