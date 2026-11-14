-- Dock updates can reposition inactive tabs after Slim Suite moves the main chat window.
local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("  MISMATCH " .. label) end end
local d = SS.DB()
d.frameDefault = d.frameDefault or {}
d.elementModes.ChatFrame1 = "enabled"; d.frameDefault.ChatFrame1 = nil
d.chatOffsets.ChatFrame1Tab = { x = 8, y = 20 } -- a stale offset from the broken layout
local background = CreateFrame("Frame", "ChatFrame1Background", ChatFrame1)
local combat = CreateFrame("Frame", "ChatFrame2", UIParent)
local combatTab = CreateFrame("Frame", "ChatFrame2Tab", UIParent)
local detached = CreateFrame("Frame", "ChatFrame3", UIParent)
local detachedTab = CreateFrame("Frame", "ChatFrame3Tab", UIParent)
local extra = CreateFrame("Frame", "ChatFrame4", UIParent)
local extraTab = CreateFrame("Frame", "ChatFrame4Tab", UIParent)
ChatFrame1.isDocked, combat.isDocked, extra.isDocked = true, true, true
detached.isDocked = false
ChatFrame1Tab:SetHeight(24); combatTab:SetHeight(32)
detachedTab:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 500, 400)
extraTab:Hide()
DOCKED_CHAT_FRAMES = { ChatFrame1, combat, extra }
local updates = 0
SELECTED_DOCK_FRAME = ChatFrame1
local originalWidth, originalHeight, originalScale = ChatFrame1:GetWidth(), ChatFrame1:GetHeight(), ChatFrame1:GetScale()
ChatFrame1.SetUserPlaced = function(self, on) self.userPlaced = on and true or false end
ChatFrame1.IsUserPlaced = function(self) return self.userPlaced end
ChatFrame1.GetEffectiveScale = function(self) return self:GetScale() * UIParent:GetEffectiveScale() end
ChatFrameEditBox:SetText("unsent message")
FCF_DockUpdate = function()
    updates = updates + 1
    combatTab:ClearAllPoints(); combatTab:SetPoint("BOTTOMLEFT", combat, "TOPLEFT", 90, 30)
    for _, f in ipairs(DOCKED_CHAT_FRAMES) do if f == SELECTED_DOCK_FRAME then f:Show() else f:Hide() end end
end
SS.PrepareChatWindow()
local first, second = ChatFrame1Tab.points[1], combatTab.points[1]
check("General sits above the chat background instead of at its old saved offset", first[2] == background and first[3] == "TOPLEFT" and first[5] == 0)
check("tabs share bottom baseline despite different heights", second[1] == "BOTTOMLEFT" and second[2] == ChatFrame1Tab and second[3] == "BOTTOMRIGHT" and second[5] == 0)
check("the native dock stays attached", ChatFrame1.isDocked and combat.isDocked)
check("undocked tabs keep their own anchors", detachedTab.points[1][2] == UIParent and detachedTab.points[1][4] == 500)
local before = updates
FCF_DockUpdate()
check("native dock refresh still runs and alignment follows it", updates == before + 1 and combatTab.points[1][2] == ChatFrame1Tab and combatTab.points[1][5] == 0)
extraTab:Show(); DOCKED_CHAT_FRAMES = { ChatFrame1, extra, combat }
FCF_DockUpdate()
check("native tab order is retained", extraTab.points[1][2] == ChatFrame1Tab and combatTab.points[1][2] == extraTab)
SELECTED_DOCK_FRAME = combat; FCF_DockUpdate()
check("selecting Combat Log does not also show General", combat:IsShown() and not ChatFrame1:IsShown())
d.sizes.ChatFrame1 = { w = 420, h = 180 }; d.scales.ChatFrame1 = 1.4
SS.ApplySize("ChatFrame1", ChatFrame1)
local scale = ChatFrame1:GetEffectiveScale() / UIParent:GetEffectiveScale()
check("tabs and docked messages share the chat scale", combat:GetScale() == scale and combatTab:GetScale() == scale and ChatFrame1Tab:GetScale() == scale)
check("real shared input box follows both chat edges", #ChatFrameEditBox.points == 2 and ChatFrameEditBox.points[1][2] == ChatFrame1 and ChatFrameEditBox.points[2][3] == "BOTTOMRIGHT")
check("input and chat menu scale with chat", ChatFrameEditBox:GetScale() == scale and ChatFrameMenuButton:GetScale() == scale)
check("custom placement is protected from native repositioning", ChatFrame1:IsUserPlaced())
SS.SavePosition("ChatFrame1", ChatFrame1)
local savedX, savedY = d.places.ChatFrame1.x, d.places.ChatFrame1.y
SS.Place("ChatFrame1"); SS.PrepareChatWindow(); SS.PrepareChatWindow()
check("reapplying saved layout does not rewrite its position or detach input width", d.places.ChatFrame1.x == savedX and d.places.ChatFrame1.y == savedY and #ChatFrameEditBox.points == 2)
local exported = SS.LayoutText(SS.LayoutSnapshot())
SS.LayoutApply(SS.LayoutFromText(exported))
check("profile export/import preserves chat layout and selection", math.abs(d.places.ChatFrame1.x - savedX) < 0.006 and math.abs(d.places.ChatFrame1.y - savedY) < 0.006 and SELECTED_DOCK_FRAME == combat and not ChatFrame1:IsShown())
SS.Startup(true, true)
check("startup reapplication retains scaled dock and input anchors", combat:GetScale() == ChatFrame1:GetEffectiveScale() / UIParent:GetEffectiveScale() and #ChatFrameEditBox.points == 2 and combat:IsShown() and not ChatFrame1:IsShown())
SS.StartSetup(true); Tick(2); SS.SetupEnd(true); Tick(2)
check("setup exit retains the selected docked tab", SELECTED_DOCK_FRAME == combat and combat:IsShown() and not ChatFrame1:IsShown())
SS.ENV.SU.SetMode("ChatFrame1", "default", "Chat")
check("Default restores native dimensions and scale", ChatFrame1:GetWidth() == originalWidth and ChatFrame1:GetHeight() == originalHeight and ChatFrame1:GetScale() == originalScale)
check("Default restores shared input anchors", #ChatFrameEditBox.points == 2 and ChatFrameEditBox.points[1][4] == -5 and ChatFrameEditBox.points[2][4] == 5)
check("Default clears custom sizing and releases native placement", not d.sizes.ChatFrame1 and not d.scales.ChatFrame1 and not ChatFrame1:IsUserPlaced())
FCF_DockUpdate()
check("Default leaves native dock positioning in control", combatTab.points[1][2] == combat and combatTab.points[1][5] == 30)
SS.PrepareChatWindow()
check("opening an unrelated mover does not rewrite Default chat input", ChatFrameEditBox.points[1][4] == -5 and #ChatFrameEditBox.points == 2)
SS.ENV.SU.SetMode("ChatFrame1", "enabled", "Chat")
check("chat can be enabled and moved again after Default", SS.ChatIsCustom() and combatTab.points[1][2] == extraTab)
SS.ENV.SU.SetMode("ChatFrame1", "disabled", "Chat"); FCF_DockUpdate()
check("Disabled hides the selected messages and every docked tab", combat:GetAlpha() == 0 and combatTab:GetAlpha() == 0 and ChatFrame1Tab:GetAlpha() == 0 and ChatFrameEditBox:GetAlpha() == 0)
check("Disabled leaves separately undocked windows alone", detachedTab:GetAlpha() ~= 0)
SS.ENV.SU.SetMode("ChatFrame1", "enabled", "Chat")
check("enabling restores the docked chat controls", combat:GetAlpha() > 0 and ChatFrameEditBox:GetAlpha() > 0)
SS.ToggleFeatureMute("ChatFrame1"); FCF_DockUpdate()
check("feature mute hides Combat Log as part of the group", combat:GetAlpha() == 0 and combatTab:GetAlpha() == 0)
SS.ToggleFeatureMute("ChatFrame1")
check("unmute restores chat controls", combat:GetAlpha() > 0 and ChatFrameEditBox:GetAlpha() > 0)
local defaultProfile = SS.LayoutSnapshot()
defaultProfile.elementModes.ChatFrame1 = "default"
SS.LayoutApply(defaultProfile)
check("applying a Default profile restores native scale and releases placement", ChatFrame1:GetScale() == originalScale and not ChatFrame1:IsUserPlaced() and combatTab.points[1][2] == combat)
check("layout and setup transitions preserve unsent input", ChatFrameEditBox:GetText() == "unsent message")
print("chat problems: " .. bad)
print("errors: " .. #ERRORS); for _, e in ipairs(ERRORS) do print("  " .. e) end
