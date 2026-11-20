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
		if ( name == "TalentFrame" ) then SS.Safe(SS.ApplyTalentTrees); end
	end);
end
-- Talent window, as an element: only the trees you have points in show as tabs. One tree (a single spec, or
-- points in one tree only) hides the tab row altogether, so the window is just that tree. Original shows them all.
local TALENT_TABS = 3;
function SS.ApplyTalentTrees()
	local trees = (GetNumTalentTabs and GetNumTalentTabs()) or TALENT_TABS;
	local spent = {};
	local shown = 0;
	for i = 1, trees do
		local _, _, points = GetTalentTabInfo(i);
		spent[i] = (points or 0) > 0;
		if ( spent[i] ) then shown = shown + 1; end
	end
	local filter = SU.Mode("TalentFrame") == "enabled";
	local tabBar = shown > 1 or not filter;   -- one tree left: no tab row
	for i = 1, TALENT_TABS do
		local tab = getglobal("TalentFrameTab" .. i);
		if ( tab ) then
			local keep = not filter or spent[i] or (shown == 0 and i == 1);
			if ( keep and tabBar ) then tab:Show(); else tab:Hide(); end
		end
	end
end
-- The Character sheet follows the theme: its own art shows for Original. RPG and Modern make that art transparent and
-- draw their panel behind it. Transparency is changed, never Hide, so the art always comes back.
local characterArt = nil;
function SS.ThemeCharacter(f)
	if ( not f or not f.GetRegions ) then return; end
	if ( not characterArt ) then
		characterArt = {};
		local regions = { f:GetRegions() };
		for i = 1, table.getn(regions) do
			local r = regions[i];
			if ( r and r.GetObjectType and r:GetObjectType() == "Texture" ) then
				table.insert(characterArt, { tex = r, alpha = r:GetAlpha() or 1 });
			end
		end
	end
	local styled = SS.StyleKeyFor("CharacterFrame") ~= "original";
	for i = 1, table.getn(characterArt) do
		local a = characterArt[i];
		a.tex:SetAlpha(styled and 0 or a.alpha);
	end
	if ( styled ) then SS.ApplyPanelStyle(f); elseif ( f.panelStyle ~= nil ) then f:SetBackdrop(nil); f.panelStyle = nil; end
end
Hook("CharacterFrame");
SS.Safe(SS.ThemeCharacter, getglobal("CharacterFrame"));
SS.AddThemeHook(function() SS.Safe(SS.ThemeCharacter, getglobal("CharacterFrame")); end, "CharacterFrame");
Hook("TalentFrame");

-- Optional Gameplay buttons: hide the Bag buttons and the world Map button on the minimap. The game shows them again on
-- its own schedule, so each one also hides itself when the game shows it while the option is on.
local BAG_BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot" };
local MAP_BUTTONS = { "MiniMapWorldMapButton" };
local hooked = {};
local function HideWhile(name, flag)
	local f = getglobal(name);
	if ( not f or not f.SetScript or not f.GetScript or hooked[name] ) then return; end
	hooked[name] = true;
	local old = f:GetScript("OnShow");
	f:SetScript("OnShow", function()
		if ( old ) then old(); end
		if ( SS.DB()[flag] ) then this:Hide(); end
	end);
end
local function SetButtons(list, flag, hidden)
	for i = 1, table.getn(list) do
		local f = getglobal(list[i]);
		if ( f ) then
			HideWhile(list[i], flag);
			if ( hidden ) then f:Hide(); else f:Show(); end
		end
	end
end
function SS.ApplyBagMapButtons()
	local d = SS.DB();
	SetButtons(BAG_BUTTONS, "hideBagButton", d.hideBagButton and true or false);
	SetButtons(MAP_BUTTONS, "hideMapButton", d.hideMapButton and true or false);
end

-- Big map: Ctrl-click the minimap to enlarge it on top of the UI, and again to shrink it back. It keeps its place and
-- its element settings; only its size changes for as long as it is on. Not saved, so it starts small after a login.
SS.BIG_MAP_SCALE = 2.5;
function SS.ToggleBigMap()
	SS.bigMapOn = not SS.bigMapOn;
	SS.Safe(SS.Place, "MinimapCluster", false);
end

local startup = CreateFrame("Frame");
startup:RegisterEvent("PLAYER_ENTERING_WORLD");
startup:SetScript("OnEvent", function()
	SS.Safe(SS.ApplyBagMapButtons);
	-- Saved anchors that loop back on themselves (from an earlier snap) are dropped, so each frame returns to its default place
	if ( not SS.loopsRepaired ) then
		SS.loopsRepaired = true;
		for name, p in pairs(SS.DB().places) do
			if ( type(p) == "table" and p.relative and SS.DependsOn(name, name) ) then
				p.relative, p.point, p.relativePoint, p.dx, p.dy = nil, nil, nil, nil, nil;
			end
		end
	end
	if ( Minimap and not SS.bigMapHooked ) then
		SS.bigMapHooked = true;
		local old = Minimap:GetScript("OnMouseUp");
		Minimap:SetScript("OnMouseUp", function()
			if ( IsControlKeyDown() and arg1 == "LeftButton" ) then SS.ToggleBigMap(); return; end
			if ( old ) then old(); end
		end);
	end
end);
