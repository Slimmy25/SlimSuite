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
		if ( name == "CharacterFrame" ) then SS.Safe(SS.ApplyCharacterLayout); end
		if ( name == "TalentFrame" ) then SS.Safe(SS.ApplyTalentTrees); end
	end);
end

-- Character window, vertical layout: the equipment slots stand in one column down the left edge, smaller, and the
-- character model keeps its place to their right. Original and Horizontal put every slot back where the game had it.
local COLUMN = { "CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot", "CharacterBackSlot", "CharacterChestSlot",
 "CharacterShirtSlot", "CharacterTabardSlot", "CharacterWristSlot", "CharacterHandsSlot", "CharacterWaistSlot", "CharacterLegsSlot",
 "CharacterFeetSlot", "CharacterFinger0Slot", "CharacterFinger1Slot", "CharacterTrinket0Slot", "CharacterTrinket1Slot",
 "CharacterMainHandSlot", "CharacterSecondaryHandSlot", "CharacterRangedSlot", "CharacterAmmoSlot" };
local COLUMN_SCALE, COLUMN_LEFT, COLUMN_TOP, COLUMN_STEP = 0.5, 14, 44, 19;   -- scale, then offsets in screen pixels
local stock = {};   -- each slot's game placement, kept before the first change

function SS.ApplyCharacterLayout()
	local f = getglobal("CharacterFrame");
	if ( not f ) then return; end
	local vertical = SU.Mode("CharacterFrame") == "enabled" and SS.CurrentOrientation("CharacterFrame") == "vertical";
	for i = 1, table.getn(COLUMN) do
		local s = getglobal(COLUMN[i]);
		if ( s ) then
			if ( not stock[COLUMN[i]] ) then
				local point, rel, relPoint, x, y = s:GetPoint(1);
				stock[COLUMN[i]] = { point = point, rel = rel, relPoint = relPoint, x = x, y = y, scale = s:GetScale() };
			end
			if ( vertical ) then
				-- offsets are in the slot's own scale, so divide the screen offset by it
				s:ClearAllPoints();
				s:SetScale(COLUMN_SCALE);
				s:SetPoint("TOPLEFT", f, "TOPLEFT", COLUMN_LEFT / COLUMN_SCALE, -(COLUMN_TOP + (i - 1) * COLUMN_STEP) / COLUMN_SCALE);
			else
				local o = stock[COLUMN[i]];
				s:ClearAllPoints();
				if ( o.point ) then s:SetPoint(o.point, o.rel, o.relPoint, o.x, o.y); end
				s:SetScale(o.scale or 1);
			end
		end
	end
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
Hook("CharacterFrame");
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
