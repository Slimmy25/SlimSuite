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

-- Vertical Character: only the model box stays (the model, its turn buttons and the stats), the gear stands in one
-- column to its right, the necklace, rings and trinkets show their names, and the set bonus shows beside them.
local SLOT_NAME = {};
for i = 1, table.getn(COLUMN) do SLOT_NAME[COLUMN[i]] = true; end
local KEEP = { "CharacterModelFrame", "CharacterStat", "PaperDollFrame" };   -- kept by name; PaperDollFrame is only searched
local hidden = {};
local labels, panel;
local NAMED = { CharacterNeckSlot = 1, CharacterFinger0Slot = 2, CharacterFinger1Slot = 3, CharacterTrinket0Slot = 4, CharacterTrinket1Slot = 5 };
local GEAR_LEFT = 10;   -- gap between the model box and the gear column, in screen pixels

local function Kept(name)
	if ( not name ) then return false; end
	if ( SLOT_NAME[name] ) then return true; end
	for i = 1, table.getn(KEEP) do if ( string.find(name, "^" .. KEEP[i]) ) then return true; end end
	return false;
end

-- Hides the extra pieces of the window, and searches inside the PaperDollFrame, so the stats stay.
local function Strip(f, vertical)
	local kids = { f:GetChildren() };
	for i = 1, table.getn(kids) do
		local k = kids[i];
		local name = k.GetName and k:GetName();
		if ( vertical and not Kept(name) ) then
			if ( name == "PaperDollFrame" ) then Strip(k, true); end
			if ( name ~= "PaperDollFrame" and k:IsShown() ) then k:Hide(); hidden[k] = true; end
		elseif ( not vertical and hidden[k] ) then
			k:Show(); hidden[k] = nil;
		end
	end
end

-- Reads one equipped item's tooltip: its name, and any set name and set bonus lines.
local scan;
local function ReadSlot(slotName)
	local id = GetInventorySlotInfo and GetInventorySlotInfo(string.gsub(slotName, "^Character", ""));
	if ( not id or not GetInventoryItemLink("player", id) ) then return nil; end
	if ( not scan ) then scan = CreateFrame("GameTooltip", "SlimSuiteGearScan", UIParent, "GameTooltipTemplate"); end
	scan:SetOwner(UIParent, "ANCHOR_NONE");
	scan:ClearLines();
	scan:SetInventoryItem("player", id);
	local out = { name = nil, set = nil, bonus = {} };
	for i = 1, 30 do
		local fs = getglobal("SlimSuiteGearScanTextLeft" .. i);
		local text = fs and fs:GetText();
		if ( text ) then
			if ( i == 1 ) then out.name = text; end
			local _, _, set = string.find(text, "^Set: (.+)$");
			if ( set ) then out.set = string.gsub(set, "%s*%(%d+/%d+%)$", ""); end
			local _, _, n, bonus = string.find(text, "^%((%d+)%) Set: (.+)$");
			if ( n ) then out.bonus[tonumber(n)] = bonus; end
		end
	end
	return out;
end

-- The set summary: each set you wear, how many of its pieces are on, and its 4 and 8 piece bonuses.
local function SetSummary(items)
	local sets, order = {}, {};
	for i = 1, table.getn(items) do
		local it = items[i];
		if ( it and it.set ) then
			if ( not sets[it.set] ) then sets[it.set] = { count = 0, bonus = {} }; table.insert(order, it.set); end
			sets[it.set].count = sets[it.set].count + 1;
			for n, text in pairs(it.bonus) do sets[it.set].bonus[n] = text; end
		end
	end
	local lines = {};
	for _, name in ipairs(order) do
		local set = sets[name];
		table.insert(lines, name .. "  (" .. set.count .. "/8)");
		for _, n in ipairs({ 4, 8 }) do
			if ( set.bonus[n] ) then
				local on = set.count >= n;
				table.insert(lines, (on and "|cff33ff33" or "|cff888888") .. n .. "p: " .. set.bonus[n] .. "|r");
			end
		end
	end
	if ( table.getn(lines) == 0 ) then return "No set gear equipped."; end
	return table.concat(lines, "\n");
end

local function RefreshGear()
	local f = getglobal("CharacterFrame");
	if ( not f or not panel ) then return; end
	local items = {};
	for slot, idx in pairs(NAMED) do
		local it = ReadSlot(slot);
		labels[slot]:SetText(it and it.name or "");
		items[table.getn(items) + 1] = it;
	end
	local all = {};
	for i = 1, table.getn(COLUMN) do all[i] = ReadSlot(COLUMN[i]); end
	panel:SetText(SetSummary(all));
end

function SS.ApplyCharacterLayout()
	local f = getglobal("CharacterFrame");
	if ( not f ) then return; end
	local vertical = SU.Mode("CharacterFrame") == "enabled" and SS.CurrentOrientation("CharacterFrame") == "vertical";
	Strip(f, vertical);
	local rightX = (f:GetWidth() or 340) + GEAR_LEFT;
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
				s:SetPoint("TOPLEFT", f, "TOPLEFT", rightX / COLUMN_SCALE, -(COLUMN_TOP + (i - 1) * COLUMN_STEP) / COLUMN_SCALE);
			else
				local o = stock[COLUMN[i]];
				s:ClearAllPoints();
				if ( o.point ) then s:SetPoint(o.point, o.rel, o.relPoint, o.x, o.y); end
				s:SetScale(o.scale or 1);
			end
		end
	end
	if ( vertical ) then
		if ( not panel ) then
			labels = {};
			for slot, idx in pairs(NAMED) do
				local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
				fs:SetJustifyH("LEFT"); fs:SetWidth(150);
				labels[slot] = fs;
			end
			panel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
			panel:SetJustifyH("LEFT"); panel:SetWidth(180);
		end
		for i = 1, table.getn(COLUMN) do
			local fs = labels[COLUMN[i]];
			if ( fs ) then
				fs:ClearAllPoints();
				fs:SetPoint("TOPLEFT", f, "TOPLEFT", rightX + 22, -(COLUMN_TOP + (i - 1) * COLUMN_STEP));
			end
		end
		panel:ClearAllPoints();
		panel:SetPoint("TOPLEFT", f, "TOPLEFT", rightX, -(COLUMN_TOP + table.getn(COLUMN) * COLUMN_STEP + 10));
		SS.Every("characterGear", 0.5, RefreshGear, f);
		RefreshGear();
	elseif ( panel ) then
		for _, fs in pairs(labels) do fs:SetText(""); end
		panel:SetText("");
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
