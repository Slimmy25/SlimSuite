-- HUD Edit Mode: one dark window with every element in one ordered list. Each row has one tick box with three states:
-- ticked = On, empty = Off, "D" = Default (the game's own element, Original). Clicking the name opens that element's
-- panel: Chain to (a primary element), Ahead / Behind, Unchain, Revert Changes and Reset To Default Position.
-- A chain only changes the order of this list. Chained elements always stay next to each other: the partner moves
-- directly ahead of (above) or behind (below) its primary, and the other rows shift to make room.
if ( setfenv ) then setfenv(1, SS.ENV); end

local ROW = 20;
local hud, panel, picker, rows = nil, nil, nil, {};

local function ElementList()
 local out = {};
 for _, name in ipairs(SS.SETUP_ORDER) do
  if ( getglobal(name) or SS.ELEMENTS[name] ) then table.insert(out, name); end
 end
 return out;
end

local function Label(name)
 local e = SS.ELEMENTS[name];
 return SS.T((e and (e.label or e.title)) or name);
end

local function Position(list, name)
 for i = 1, table.getn(list) do if ( list[i] == name ) then return i; end end
 return nil;
end

-- The saved order, kept to the elements that exist now; anything new is added at its setup position.
function SS.HUDOrder()
 local d = SS.DB();
 local known, seen, out = {}, {}, {};
 local all = ElementList();
 for _, name in ipairs(all) do known[name] = true; end
 for _, name in ipairs(d.hudOrder or {}) do
  if ( known[name] and not seen[name] ) then table.insert(out, name); seen[name] = true; end
 end
 for _, name in ipairs(all) do if ( not seen[name] ) then table.insert(out, name); seen[name] = true; end end
 d.hudOrder = out;
 return out;
end

-- Moves each chained partner directly ahead of (above) or behind (below) its primary. Only the partner moves;
-- everything else keeps its order and shifts to make room.
function SS.HUDApplyChains()
 local d = SS.DB();
 local list = SS.HUDOrder();
 if ( d.hudChains ) then
  for _, partner in ipairs(list) do
   local link = d.hudChains[partner];
   if ( link and link.to and link.to ~= partner ) then
    local from = Position(list, partner);
    if ( from ) then
     table.remove(list, from);
     local at = Position(list, link.to);
     if ( at ) then
      if ( link.side == "behind" ) then table.insert(list, at + 1, partner); else table.insert(list, at, partner); end
     else
      table.insert(list, from, partner);
     end
    end
   end
  end
 end
 d.hudOrder = list;
end

-- True when chaining partner to primary would loop (the primary already leads back to the partner).
local function WouldLoop(partner, primary)
 local d = SS.DB(); local seen = {};
 local cur = primary;
 while ( cur and not seen[cur] ) do
  if ( cur == partner ) then return true; end
  seen[cur] = true;
  local link = d.hudChains and d.hudChains[cur];
  cur = link and link.to or nil;
 end
 return false;
end

function SS.HUDChain(partner, primary, side)
 local d = SS.DB();
 d.hudChains = d.hudChains or {};
 if ( not partner or not primary or partner == primary or WouldLoop(partner, primary) ) then return false; end
 d.hudChains[partner] = { to = primary, side = (side == "behind") and "behind" or "ahead" };
 SS.HUDApplyChains();
 return true;
end

function SS.HUDUnchain(partner)
 local d = SS.DB();
 if ( d.hudChains ) then d.hudChains[partner] = nil; end
end

-- The three states: Off (empty), On (ticked), Default ("D").
local function RefreshRow(r)
 local mode = SU.Mode(r.name);
 r.cb:SetChecked(mode == "enabled" and 1 or nil);
 if ( mode == "default" ) then r.cb.defaultText:Show(); else r.cb.defaultText:Hide(); end
 local link = SS.DB().hudChains and SS.DB().hudChains[r.name];
 if ( link and link.to ) then
  r.fs:SetText(Label(r.name) .. "  |cffaaaaaa(" .. (link.side == "behind" and "behind " or "ahead of ") .. Label(link.to) .. ")|r");
 else
  r.fs:SetText(Label(r.name));
 end
end

local searchText = "";

local function Matches(name)
 if ( searchText == "" ) then return true; end
 return string.find(string.lower(Label(name)), searchText, 1, true) ~= nil;
end

-- Lays the matching rows out in the saved order in two columns: the first half runs down the left, the rest down the right.
-- The element groups, in the order they are shown. Anything not listed falls into Other.
local SECTIONS = {
 { key = "original", title = "Original Unit Frames", names = { "CharacterFrame", "TalentFrame", "PlayerFrame", "PartyMemberFrame1", "MainMenuBar", "TargetFrame", "MainMenuExpBar", "BuffFrame", "MinimapCluster", "ChatFrame1", "GameTooltip" } },
 { key = "aethus", title = "Aethus Design", names = { "SlimSuiteStoredLevelsButton", "SlimSuiteSpellRowFrame", "SlimSuiteMeterFrame", "SlimSuiteClockFrame", "SlimSuiteBossFrames", "SlimSuiteAnnouncementFrame", "SlimSuiteTallyFrame", "SlimSuiteReviveFrame", "SlimSuiteLocalClockFrame" } },
 { key = "custom", title = "Custom Design", names = { "SlimSuiteCombatTextFrame", "SlimSuiteStatCounterFrame", "SlimSuiteLuckFrame", "SlimSuiteCompassFrame", "SlimSuiteAchievementsButton" } },
 { key = "other", title = "Other", names = {} },
};

-- Which section an element belongs to; anything not listed goes to Other.
local function SectionOf(name)
 for _, sec in ipairs(SECTIONS) do
  for _, n in ipairs(sec.names) do if ( n == name ) then return sec.key; end end
 end
 return "other";
end

function SS.HUDLayout()
 SS.HUDApplyChains();
 if ( not hud ) then return; end
 local d = SS.DB();
 d.hudSections = d.hudSections or {};
 -- group the visible rows by section, keeping the saved order inside each section
 local groups = {};
 for _, sec in ipairs(SECTIONS) do groups[sec.key] = {}; end
 for _, name in ipairs(SS.HUDOrder()) do
  if ( rows[name] ) then
   rows[name].frame:Hide();
   if ( Matches(name) ) then table.insert(groups[SectionOf(name)], name); end
  end
 end
 -- clickable section headers, created once
 hud.sections = hud.sections or {};
 local y = 4;
 for _, sec in ipairs(SECTIONS) do
  local open = d.hudSections[sec.key] ~= false;
  local list = groups[sec.key];
  local header = hud.sections[sec.key];
  -- Other only appears when an element is in none of the sections
  if ( sec.key == "other" and table.getn(list) == 0 ) then
   if ( header ) then header:Hide(); end
   break;
  end
  if ( not header ) then
   local key = sec.key;
   header = K.Button(hud.child, "", 116, function()
    SS.DB().hudSections[key] = (SS.DB().hudSections[key] == false);
    SS.HUDLayout();
   end);
   hud.sections[sec.key] = header;
  end
  header:Show();
  header:ClearAllPoints();
  header:SetHeight(16);
  header:SetPoint("TOPLEFT", hud.child, "TOPLEFT", 6, -y);
  header:SetText((open and "v  " or ">  ") .. SS.T(sec.title) .. "  (" .. table.getn(list) .. ")");
  y = y + 20;
  -- three columns of elements under the header, filled top to bottom
  local n = table.getn(list);
  local perCol = math.max(1, math.ceil(n / 3));
  for i, name in ipairs(list) do
   local r = rows[name];
   if ( open ) then
    local col = math.floor((i - 1) / perCol);
    local idx = (i - 1) - col * perCol;
    r.frame:ClearAllPoints();
    r.frame:SetPoint("TOPLEFT", hud.child, "TOPLEFT", 6 + col * 124, -(y + idx * ROW));
    r.frame:Show();
    RefreshRow(r);
   end
  end
  if ( open and n > 0 ) then y = y + perCol * ROW + 8; else y = y + 4; end
 end
 hud.child:SetHeight(math.max(20, y + 8));
end

local function RefreshAll()
 for _, r in pairs(rows) do RefreshRow(r); end
end

local function CycleElement(name)
 local mode = SU.Mode(name);
 local nextMode;
 if ( mode == "disabled" ) then nextMode = "enabled";
 elseif ( mode == "enabled" ) then nextMode = "default";
 else nextMode = "disabled"; end
 SU.SetMode(name, nextMode, SS.ELEMENTS[name] and SS.ELEMENTS[name].title);
 RefreshAll();
end

local function MakeTriBox(parent, name)
 local cb, ok = K.Templated("CheckButton", nil, parent, "UICheckButtonTemplate");
 if ( not ok or not cb.SetChecked ) then
  cb = CreateFrame("CheckButton", nil, parent);
  cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up");
  cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down");
  cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight");
  cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check");
 end
 cb:SetWidth(18); cb:SetHeight(18);
 cb.elementName = name;
 cb.defaultText = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal");
 cb.defaultText:SetPoint("CENTER", cb, "CENTER", 0, 0); cb.defaultText:SetText("D"); cb.defaultText:Hide();
 cb:SetScript("OnClick", function() CycleElement(this.elementName); end);
 return cb;
end

-- Dropdown of primaries for the Chain to button.
local function Picker()
 if ( picker ) then return picker; end
 picker = CreateFrame("Frame", "SlimSuiteHUDChainPicker", UIParent);
 picker:SetWidth(220); picker:SetHeight(210);
 picker:SetFrameStrata("TOOLTIP");
 picker:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
 picker:SetBackdropColor(0.03, 0.03, 0.05, 0.98);
 picker:EnableMouse(true);
 picker.scroll, picker.child = K.Scroll("SlimSuiteHUDChainScroll", picker, 190);
 picker.scroll:SetPoint("TOPLEFT", picker, "TOPLEFT", 8, -8);
 picker.scroll:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -24, 8);
 picker.items = {};
 picker:Hide();
 return picker;
end

local function ShowPicker(owner, partner)
 local p = Picker();
 for _, it in ipairs(p.items) do it:Hide(); end
 local choices = { { "None (unchained)", nil } };
 for _, name in ipairs(SS.HUDOrder()) do
  if ( name ~= partner and not WouldLoop(partner, name) ) then table.insert(choices, { Label(name), name }); end
 end
 for i, c in ipairs(choices) do
  local it = p.items[i];
  if ( not it ) then
   it = K.Button(p.child, "", 170, function()
    local v = this.primary;
    if ( v == nil ) then SS.HUDUnchain(p.partner);
    else
     local link = SS.DB().hudChains and SS.DB().hudChains[p.partner];
     SS.HUDChain(p.partner, v, link and link.side or "ahead");
    end
    p:Hide(); SS.HUDLayout();
    if ( panel and panel.Refresh ) then panel.Refresh(); end
    if ( SS.MarkProfileDirty ) then SS.MarkProfileDirty(); end
   end);
   p.items[i] = it;
  end
  it.primary = c[2]; it:SetText(SS.T(c[1])); it:ClearAllPoints();
  it:SetPoint("TOPLEFT", p.child, "TOPLEFT", 0, -(i - 1) * 24); it:Show();
 end
 p.child:SetHeight(math.max(20, table.getn(choices) * 24));
 p.partner = partner;
 p:ClearAllPoints(); p:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2); p:Show();
end

local function ElementPanel()
 if ( panel ) then return panel; end
 panel = CreateFrame("Frame", "SlimSuiteHUDElementPanel", UIParent);
 panel:SetWidth(240); panel:SetHeight(190);
 panel:SetFrameStrata("DIALOG");
 panel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
 panel:SetBackdropColor(0.04, 0.04, 0.06, 0.95);
 panel:SetBackdropBorderColor(0.6, 0.5, 0.25, 1);
 panel:EnableMouse(true);
 panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
 panel.title:SetPoint("TOP", panel, "TOP", 0, -12); panel.title:SetTextColor(1, 0.82, 0);
 panel.chain = K.Button(panel, "", 200, function()
  if ( panel.name ) then ShowPicker(this, panel.name); end
 end);
 panel.chain:SetPoint("TOP", panel, "TOP", 0, -40);
 panel.side = K.Button(panel, "", 96, function()
  local link = panel.name and SS.DB().hudChains and SS.DB().hudChains[panel.name];
  if ( link ) then
   link.side = (link.side == "behind") and "ahead" or "behind";
   SS.HUDLayout(); if ( SS.MarkProfileDirty ) then SS.MarkProfileDirty(); end
  end
  panel.Refresh();
 end);
 panel.side:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -76);
 panel.unchain = K.Button(panel, SS.T("Unchain"), 96, function()
  if ( panel.name ) then SS.HUDUnchain(panel.name); SS.HUDLayout(); if ( SS.MarkProfileDirty ) then SS.MarkProfileDirty(); end end
  panel.Refresh();
 end);
 panel.unchain:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -76);
 panel.revert = K.Button(panel, SS.T("Revert Changes"), 200, function()
  if ( panel.name ) then SU.SetMode(panel.name, "default", SS.ELEMENTS[panel.name] and SS.ELEMENTS[panel.name].title); RefreshAll(); end
 end);
 panel.revert:SetPoint("TOP", panel, "TOP", 0, -114);
 panel.reset = K.Button(panel, SS.T("Reset To Default Position"), 200, function()
  if ( panel.name ) then SS.ResetElement(panel.name); end
 end);
 panel.reset:SetPoint("TOP", panel, "TOP", 0, -146);
 panel.Refresh = function()
  local name = panel.name; if ( not name ) then return; end
  local link = SS.DB().hudChains and SS.DB().hudChains[name];
  panel.chain:SetText(SS.T("Chain to") .. ": " .. (link and Label(link.to) or SS.T("None")) .. "  v");
  panel.side:SetText(SS.T((link and link.side == "behind") and "Behind" or "Ahead"));
  if ( link ) then panel.side:Show(); panel.unchain:Show(); else panel.side:Hide(); panel.unchain:Hide(); end
 end;
 panel:Hide();
 return panel;
end

local function OpenElementPanel(name)
 local p = ElementPanel();
 p.name = name; p.title:SetText(Label(name));
 p.Refresh();
 p:ClearAllPoints(); p:SetPoint("TOPLEFT", hud, "TOPRIGHT", 8, -90);
 p:Show();
end

-- Rows are made once; the order, the chain text and the tick boxes are refreshed from the saved data.
local function BuildRow(child, name)
 local frame = CreateFrame("Frame", nil, child);
 frame:SetWidth(118); frame:SetHeight(ROW);
 local cb = MakeTriBox(frame, name);
 cb:SetPoint("LEFT", frame, "LEFT", 0, 0);
 local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
 fs:SetPoint("LEFT", cb, "RIGHT", 6, 0); fs:SetWidth(96); fs:SetJustifyH("LEFT");
 local hit = CreateFrame("Button", nil, frame);
 hit:SetPoint("LEFT", cb, "RIGHT", 6, 0); hit:SetWidth(96); hit:SetHeight(ROW);
 hit.elementName = name;
 -- the element panel (chain, revert, reset) is part of Advanced Options
 hit:SetScript("OnClick", function() if ( SS.DB().hudAdvanced ) then OpenElementPanel(this.elementName); end end);
 local r = { name = name, frame = frame, cb = cb, fs = fs };
 rows[name] = r;
 return r;
end

-- Closing the window locks the UI again, the same as turning Toggle UI Settings off.
function SS.CloseHUDEdit()
 if ( hud ) then hud:Hide(); end
 if ( panel ) then panel:Hide(); end
 if ( picker ) then picker:Hide(); end
 if ( SS.DB().unlocked ) then SS.SetUnlocked(false, true); end
end

-- The saved layouts, by name, in alphabetical order.
local function LayoutNames()
 local names = {};
 for name in pairs(SS.DB().layouts or {}) do table.insert(names, name); end
 table.sort(names);
 return names;
end

local function RefreshLayoutButton()
 if ( not hud or not hud.layoutButton ) then return; end
 local name = SS.DB().hudLayoutName;
 hud.layoutButton:SetText(SS.T("Layout") .. ": " .. (name or SS.T("Current")));
end

local function CycleLayout()
 local names = LayoutNames();
 local n = table.getn(names);
 if ( n == 0 ) then return; end
 local current = SS.DB().hudLayoutName;
 local next = 1;
 for i = 1, n do if ( names[i] == current ) then next = i + 1; end end
 if ( next > n ) then next = 1; end
 local name = names[next];
 SS.DB().hudLayoutName = name;
 SS.activeCustomProfile = name;
 SS.LayoutApply(SS.DB().layouts[name], true);
 RefreshLayoutButton();
 RefreshAll();
 SS.HUDLayout();
end

-- Opening the window unlocks the elements, so they can be dragged, right-clicked and chained straight away.
-- Opening the window unlocks the elements, so they can be dragged, right-clicked and chained straight away.
-- The HUD Edit window's own look: the plain dark window, or one of the panel styles (RPG, Modern).
function SS.ApplyHudTheme()
 if ( not hud or not hud.SetBackdrop ) then return; end
 local key = SS.DB().hudTheme;
 local s = key and SS.PANEL_STYLES[key];
 if ( not s ) then
  hud:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 20, insets = { left = 5, right = 5, top = 5, bottom = 5 } });
  hud:SetBackdropColor(0.03, 0.03, 0.05, 0.94);
  return;
 end
 hud:SetBackdrop({ bgFile = s.bg, edgeFile = s.edge, tile = true, tileSize = 8, edgeSize = s.edgeSize,
  insets = { left = 1, right = 1, top = 1, bottom = 1 } });
 hud:SetBackdropColor(s.color[1], s.color[2], s.color[3], s.color[4]);
 hud:SetBackdropBorderColor(s.border[1], s.border[2], s.border[3], s.border[4]);
end
function SS.RefreshHudThemeButtons()
 if ( not hud or not hud.themeRpg ) then return; end
 local key = SS.DB().hudTheme;
 hud.themeRpg:SetText(key == "meter" and "[RPG]" or "RPG");
 hud.themeModern:SetText(key == "tooltip" and "[Modern]" or "Modern");
end
function SS.SetHudTheme(key)
 local d = SS.DB();
 d.hudTheme = (d.hudTheme ~= key) and key or nil;
 SS.ApplyHudTheme();
 SS.RefreshHudThemeButtons();
end

function SS.OpenHUDEdit()
 if ( not SS.DB().unlocked ) then SS.SetUnlocked(true, true); end
 if ( hud ) then hud:Show(); SS.HUDLayout(); RefreshLayoutButton(); return; end
 hud = CreateFrame("Frame", "SlimSuiteHUDEditMode", UIParent);
 hud.building = true;
 hud:SetWidth(400); hud:SetHeight(340);   -- compact: well under the first version's size, with room for about eight rows
 hud:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
 hud:SetFrameStrata("DIALOG");
 hud:SetMovable(true); hud:RegisterForDrag("LeftButton");
 hud:SetScript("OnDragStart", function() this:StartMoving(); end);
 hud:SetScript("OnDragStop", function() this:StopMovingOrSizing(); end);
 hud:EnableMouse(true);
 hud:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 20, insets = { left = 5, right = 5, top = 5, bottom = 5 } });
 hud:SetBackdropColor(0.03, 0.03, 0.05, 0.94);
 SS.ApplyHudTheme();
 table.insert(UISpecialFrames, "SlimSuiteHUDEditMode");

 -- info icon: what the window does
 local info = CreateFrame("Button", nil, hud);
 info:SetWidth(16); info:SetHeight(16); info:SetPoint("TOPLEFT", hud, "TOPLEFT", 8, -8);
 local infoText = info:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
 infoText:SetPoint("CENTER", info, "CENTER", 0, 0); infoText:SetText("i"); infoText:SetTextColor(1, 0.82, 0);
 info:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
  GameTooltip:SetText(SS.T("Tick: On. Empty: Off. D: Default (the game's own). Click a name with Advanced Options on to chain it."));
  GameTooltip:Show();
 end);
 info:SetScript("OnLeave", function() GameTooltip:Hide(); end);

 local title = hud:CreateFontString(nil, "OVERLAY", "GameFontNormal");
 title:SetPoint("TOP", hud, "TOP", 0, -10); title:SetText(SS.T("HUD Edit Mode"));
 local close = CreateFrame("Button", nil, hud, "UIPanelCloseButton");
 close:SetWidth(24); close:SetHeight(24);
 close:SetPoint("TOPRIGHT", hud, "TOPRIGHT", -2, -2);
 close:SetScript("OnClick", function() SS.CloseHUDEdit(); end);

 -- themes: RPG and Modern (the New School look). Clicking the chosen one again goes back to the plain window.
 hud.themeRpg = K.Button(hud, "RPG", 80, function() SS.SetHudTheme("meter"); end);
 hud.themeRpg:SetPoint("TOPLEFT", hud, "TOPLEFT", 188, -30);
 hud.themeModern = K.Button(hud, "Modern", 80, function() SS.SetHudTheme("tooltip"); end);
 hud.themeModern:SetPoint("TOPLEFT", hud, "TOPLEFT", 274, -30);
 SS.RefreshHudThemeButtons();

 -- layout picker: cycles the saved layouts
 hud.layoutButton = K.Button(hud, "", 170, function() CycleLayout(); end);
 hud.layoutButton:SetPoint("TOPLEFT", hud, "TOPLEFT", 12, -30);
 RefreshLayoutButton();

 local grid = SS.Check(hud, "Show Grid", 0, function() return SS.DB().showEditGrid; end, function(v) SU.SetGridSetting(v); end, 0);
 grid:ClearAllPoints(); grid:SetPoint("TOPLEFT", hud, "TOPLEFT", 10, -58);
 grid:SetWidth(18); grid:SetHeight(18);

 -- grid scale slider: the grid's divisions, 8 (coarse) to 64 (fine)
 local slider = CreateFrame("Slider", "SlimSuiteHUDGridSlider", hud, "OptionsSliderTemplate");
 slider:SetWidth(160); slider:SetHeight(14);
 slider:SetPoint("TOPLEFT", hud, "TOPLEFT", 176, -62);
 slider:SetMinMaxValues(8, 64); slider:SetValueStep(1);
 local low, high = getglobal("SlimSuiteHUDGridSliderLow"), getglobal("SlimSuiteHUDGridSliderHigh");
 if ( low ) then low:SetText("8"); end
 if ( high ) then high:SetText("64"); end
 hud.gridValue = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
 hud.gridValue:SetPoint("TOPLEFT", hud, "TOPLEFT", 346, -62);
 slider:SetScript("OnValueChanged", function()
  local v = math.floor(this:GetValue() + 0.5);
  hud.gridValue:SetText(tostring(v));
  if ( hud.building ) then return; end
  SS.DB().gridDivisions = v;
  SU.SetGridSetting(SS.DB().showEditGrid and true or false);
 end);
 slider:SetValue(tonumber(SS.DB().gridDivisions) or 64);
 hud.gridValue:SetText(tostring(tonumber(SS.DB().gridDivisions) or 64));

 local snap = SS.Check(hud, "Snap to Elements", 0, function() return SS.DB().gridSnap; end, function(v) SS.SetSnap(v); end, 0);
 snap:ClearAllPoints(); snap:SetPoint("TOPLEFT", hud, "TOPLEFT", 10, -84);
 snap:SetWidth(18); snap:SetHeight(18);
 local advanced = SS.Check(hud, "Advanced Options", 0, function() return SS.DB().hudAdvanced; end,
  function(v) SS.DB().hudAdvanced = v and true or false; end, 0);
 advanced:ClearAllPoints(); advanced:SetPoint("TOPLEFT", hud, "TOPLEFT", 200, -84);
 advanced:SetWidth(18); advanced:SetHeight(18);
 
 -- search: filters the list as you type
 local searchLabel = hud:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
 searchLabel:SetPoint("TOPLEFT", hud, "TOPLEFT", 12, -136); searchLabel:SetText(SS.T("Search"));
 local search = CreateFrame("EditBox", "SlimSuiteHUDSearch", hud, "InputBoxTemplate");
 search:SetWidth(240); search:SetHeight(18);
 search:SetPoint("TOPLEFT", hud, "TOPLEFT", 64, -133);
 search:SetAutoFocus(false);
 search:SetScript("OnTextChanged", function()
  searchText = string.lower(this:GetText() or "");
  SS.HUDLayout();
 end);
 search:SetScript("OnEscapePressed", function() this:SetText(""); this:ClearFocus(); end);
 hud.search = search;

 -- the element list: a bordered box that the Collapse options button shows and hides
 local scroll, child = K.Scroll("SlimSuiteHUDEditScroll", hud, 380);
 scroll:SetPoint("TOPLEFT", hud, "TOPLEFT", 10, -158);
 scroll:SetPoint("BOTTOMRIGHT", hud, "BOTTOMRIGHT", -10, 66);
 hud.child = child;
 hud.box = scroll;

 rows = {};
 for _, name in ipairs(SS.HUDOrder()) do BuildRow(child, name); end

 hud.collapse = K.Button(hud, SS.T("Collapse options") .. "  ^", 130, function()
  if ( hud.box:IsShown() ) then
   hud.box:Hide(); this:SetText(SS.T("Expand options") .. "  v");
  else
   hud.box:Show(); this:SetText(SS.T("Collapse options") .. "  ^");
  end
 end);
 hud.collapse:SetPoint("BOTTOM", hud, "BOTTOM", 0, 40);

 local revertAll = K.Button(hud, SS.T("Revert All Changes"), 130, function()
  SU.batching = true;
  for _, name in ipairs(ElementList()) do SU.SetMode(name, "default", SS.ELEMENTS[name] and SS.ELEMENTS[name].title); end
  SU.batching = false;
  RefreshAll();
 end);
 revertAll:SetPoint("BOTTOMLEFT", hud, "BOTTOMLEFT", 12, 10);
 SS.hudRevertAll = revertAll;
 local save = K.Button(hud, SS.T("Save"), 130, function()
  -- Saves the current arrangement as the layout shown in the Layout button (created as "HUD edit" if there is none yet)
  local d = SS.DB();
  local name = d.hudLayoutName or SS.T("HUD edit");
  d.hudLayoutName = name;
  d.layouts[name] = SS.LayoutSnapshot();
  SS.activeCustomProfile = name;
  SS.profileDirty = nil;
  RefreshLayoutButton();
  K.Print(NAME, SS.T("Saved the layout") .. " \"" .. name .. "\".");
  SS.CloseHUDEdit();
 end);
 save:SetPoint("BOTTOMRIGHT", hud, "BOTTOMRIGHT", -12, 10);

 SS.hudRows = rows; SS.hudBoxes = {}; for _, r in pairs(rows) do table.insert(SS.hudBoxes, r.cb); end
 hud.building = false;
 SS.HUDLayout();
end
