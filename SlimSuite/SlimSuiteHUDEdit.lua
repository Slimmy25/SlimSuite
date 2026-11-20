-- HUD Edit Mode: one dark window listing every element. Each element has one tick box with three states:
-- ticked = On, empty = Off, "D" = Default (the game's own element, Original). Clicking the name opens that element's
-- panel, with Revert Changes (back to Default) and Reset To Default Position.
if ( setfenv ) then setfenv(1, SS.ENV); end

local CATEGORY_OF = {
 Frames = { PlayerFrame = true, TargetFrame = true, PartyMemberFrame1 = true, SlimSuitePartyLines = true, SlimSuitePlayerCard = true, SlimSuiteTargetCard = true },
 Combat = { MainMenuBar = true, MainMenuExpBar = true, BuffFrame = true, SlimSuiteSpellRowFrame = true, SlimSuiteItemRowFrame = true,
            SlimSuiteCombatTextFrame = true, SlimSuiteBossFrames = true, SlimSuiteReviveFrame = true, SlimSuiteStatCounterFrame = true,
            SlimSuiteMeterFrame = true },
};
local CATEGORY_ORDER = { "Frames", "Combat", "Misc" };

local hud, panel, boxes, rowsByName = nil, nil, {}, {};

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

local function Category(name)
 for _, cat in ipairs(CATEGORY_ORDER) do if ( CATEGORY_OF[cat] and CATEGORY_OF[cat][name] ) then return cat; end end
 return "Misc";
end

-- The three states: Off (empty), On (ticked), Default ("D").
local function RefreshBox(cb)
 local mode = SU.Mode(cb.elementName);
 cb:SetChecked(mode == "enabled" and 1 or nil);
 if ( mode == "default" ) then cb.defaultText:Show(); else cb.defaultText:Hide(); end
end

local function RefreshAll()
 for _, cb in ipairs(boxes) do RefreshBox(cb); end
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
 cb:SetWidth(24); cb:SetHeight(24);
 cb.elementName = name;
 cb.defaultText = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal");
 cb.defaultText:SetPoint("CENTER", cb, "CENTER", 0, 0); cb.defaultText:SetText("D"); cb.defaultText:Hide();
 cb:SetScript("OnClick", function() CycleElement(this.elementName); end);
 return cb;
end

local function ElementPanel()
 if ( panel ) then return panel; end
 panel = CreateFrame("Frame", "SlimSuiteHUDElementPanel", UIParent);
 panel:SetWidth(230); panel:SetHeight(128);
 panel:SetFrameStrata("DIALOG");
 panel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
 panel:SetBackdropColor(0.04, 0.04, 0.06, 0.95);
 panel:SetBackdropBorderColor(0.6, 0.5, 0.25, 1);
 panel:EnableMouse(true);
 panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
 panel.title:SetPoint("TOP", panel, "TOP", 0, -12); panel.title:SetTextColor(1, 0.82, 0);
 panel.revert = K.Button(panel, SS.T("Revert Changes"), 180, function()
  if ( panel.name ) then SU.SetMode(panel.name, "default", SS.ELEMENTS[panel.name] and SS.ELEMENTS[panel.name].title); RefreshAll(); end
 end);
 panel.revert:SetPoint("TOP", panel, "TOP", 0, -44);
 panel.reset = K.Button(panel, SS.T("Reset To Default Position"), 180, function()
  if ( panel.name ) then SS.ResetElement(panel.name); end
 end);
 panel.reset:SetPoint("TOP", panel, "TOP", 0, -76);
 panel:Hide();
 return panel;
end

local function OpenElementPanel(name)
 local p = ElementPanel();
 p.name = name; p.title:SetText(Label(name));
 p:ClearAllPoints(); p:SetPoint("TOPLEFT", hud, "TOPRIGHT", 8, -90);
 p:Show();
end

function SS.OpenHUDEdit()
 if ( hud ) then hud:Show(); RefreshAll(); return; end
 hud = CreateFrame("Frame", "SlimSuiteHUDEditMode", UIParent);
 hud:SetWidth(360); hud:SetHeight(520);
 hud:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
 hud:SetFrameStrata("DIALOG");
 hud:SetMovable(true); hud:RegisterForDrag("LeftButton");
 hud:SetScript("OnDragStart", function() this:StartMoving(); end);
 hud:SetScript("OnDragStop", function() this:StopMovingOrSizing(); end);
 hud:EnableMouse(true);
 hud:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } });
 hud:SetBackdropColor(0.03, 0.03, 0.05, 0.94);
 table.insert(UISpecialFrames, "SlimSuiteHUDEditMode");

 local title = hud:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
 title:SetPoint("TOP", hud, "TOP", 0, -14); title:SetText(SS.T("HUD Edit Mode"));
 local close = CreateFrame("Button", nil, hud, "UIPanelCloseButton");
 close:SetPoint("TOPRIGHT", hud, "TOPRIGHT", -4, -4);
 close:SetScript("OnClick", function() hud:Hide(); if ( panel ) then panel:Hide(); end end);

 local grid = SS.Check(hud, "Show Grid", 0, function() return SS.DB().showEditGrid; end, function(v) SU.SetGridSetting(v); end, 0);
 grid:ClearAllPoints(); grid:SetPoint("TOPLEFT", hud, "TOPLEFT", 22, -44);
 local snap = SS.Check(hud, "Snap to Elements", 0, function() return SS.DB().gridSnap; end, function(v) SS.SetSnap(v); end, 0);
 snap:ClearAllPoints(); snap:SetPoint("TOPLEFT", hud, "TOPLEFT", 22, -72);

 local scroll, child = K.Scroll("SlimSuiteHUDEditScroll", hud, 300);
 scroll:SetPoint("TOPLEFT", hud, "TOPLEFT", 20, -104);
 scroll:SetPoint("BOTTOMRIGHT", hud, "BOTTOMRIGHT", -26, 58);

 local names = ElementList();
 local y = -6;
 boxes, rowsByName = {}, {};
 for _, cat in ipairs(CATEGORY_ORDER) do
  local members = {};
  for _, name in ipairs(names) do if ( Category(name) == cat ) then table.insert(members, name); end end
  if ( table.getn(members) > 0 ) then
   local head = child:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
   head:SetPoint("TOPLEFT", child, "TOPLEFT", 4, y); head:SetTextColor(1, 0.82, 0); head:SetText(SS.T(cat));
   y = y - 26;
   for k, name in ipairs(members) do
    local col = (k - 1) - 2 * math.floor((k - 1) / 2);
    local rowY = y - math.floor((k - 1) / 2) * 28;
    local x = 4 + col * 150;
    local cb = MakeTriBox(child, name);
    cb:SetPoint("TOPLEFT", child, "TOPLEFT", x, rowY);
    table.insert(boxes, cb);
    local hit = CreateFrame("Button", nil, child);
    hit:SetPoint("TOPLEFT", cb, "TOPRIGHT", 4, -2); hit:SetWidth(118); hit:SetHeight(20);
    local fs = hit:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    fs:SetPoint("LEFT", hit, "LEFT", 0, 0); fs:SetWidth(118); fs:SetJustifyH("LEFT"); fs:SetText(Label(name));
    hit:SetScript("OnClick", function() OpenElementPanel(this.elementName); end);
    hit.elementName = name;
    rowsByName[name] = cb;
   end
   y = y - math.ceil(table.getn(members) / 2) * 28 - 10;
  end
 end
 SS.hudBoxes = boxes;
 child:SetHeight(math.max(20, -y + 10));
 child:SetWidth(300);

 local revertAll = K.Button(hud, SS.T("Revert All Changes"), 150, function()
  SU.batching = true;
  for _, name in ipairs(ElementList()) do SU.SetMode(name, "default", SS.ELEMENTS[name] and SS.ELEMENTS[name].title); end
  SU.batching = false;
  RefreshAll();
 end);
 revertAll:SetPoint("BOTTOMLEFT", hud, "BOTTOMLEFT", 22, 18);
 SS.hudRevertAll = revertAll;
 local save = K.Button(hud, SS.T("Save"), 150, function()
  if ( SS.MarkProfileDirty ) then SS.MarkProfileDirty(); end
  hud:Hide(); if ( panel ) then panel:Hide(); end
 end);
 save:SetPoint("BOTTOMRIGHT", hud, "BOTTOMRIGHT", -22, 18);

 RefreshAll();
end
