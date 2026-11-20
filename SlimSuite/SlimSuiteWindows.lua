-- Blizzard's Character and Talent windows as Slim Suite elements, each starting as the game's Original.
--   Original: untouched, the game opens and places it.
--   On: Slim Suite places it, and the saved place is applied again each time it opens.
--   Off: it stays hidden, even when its key (C or N) is pressed.
if ( setfenv ) then setfenv(1, SS.ENV); end
local function Hook(name)
	local f = getglobal(name);
	if ( not f or not f.SetScript or not f.GetScript ) then return; end
	local old = f:GetScript("OnShow");
	f:SetScript("OnShow", function()
		if ( old ) then old(); end
		local mode = SU.Mode(name);
		if ( mode == "disabled" ) then this:Hide(); return; end
		if ( mode == "enabled" and not (SS.DB().frameDefault and SS.DB().frameDefault[name]) ) then SS.Safe(SS.Place, name, false); end
	end);
end
Hook("CharacterFrame");
Hook("TalentFrame");
