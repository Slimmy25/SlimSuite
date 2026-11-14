-- A small mock of the WoW 1.12 client, enough to load Slim Suite and drive its setup in Lua 5.3.
-- Lua 5.0 compatibility
table.getn = function(t) if type(t) ~= "table" then error("bad argument #1 to 'getn' (table expected, got " .. type(t) .. ")", 2) end; if t.n then return t.n end; return #t end
table.setn = function() end
math.mod = math.fmod
math.atan2 = function(y, x) return math.atan(y, x) end
math.pow = function(a, b) return a ^ b end
unpack = table.unpack
string.gfind = string.gmatch
date = os.date
local origFormat = string.format
string.format = function(fmt, ...)
	local n = select("#", ...)
	local args = { ... }
	local ok, r = pcall(origFormat, fmt, table.unpack(args, 1, n))
	if ok then return r end
	for i = 1, n do if type(args[i]) == "number" then args[i] = math.floor(args[i]) end end
	return origFormat(fmt, table.unpack(args, 1, n))
end
getglobal = function(n) return _G[n] end
setglobal = function(n, v) _G[n] = v end

ERRORS = {}
local clock = 1000
function GetTime() return clock end
function AdvanceTime(dt) clock = clock + dt end

-- frames ---------------------------------------------------------------------------------------------------
local Frame = {}
local allFrames = {}
local function noop() end
local function Region(parent, kind)
	local r = { kind = kind, parent = parent, shown = true, alpha = 1, text = "", w = 10, h = 10 }
	return setmetatable(r, Frame.meta)
end
Frame.methods = {
	Show = function(self) self.shown = true end,
	Hide = function(self) self.shown = false end,
	IsShown = function(self) return self.shown end,
	IsVisible = function(self) local f = self while f do if not f.shown then return false end f = f.parent end return true end,
	SetAlpha = function(self, a) if type(a) ~= "number" then error("SetAlpha: number expected", 2) end self.alpha = a end,
	GetAlpha = function(self) return self.alpha end,
	SetWidth = function(self, w) self.w = w end, SetHeight = function(self, h) self.h = h end,
	GetWidth = function(self) return self.w end, GetHeight = function(self) return self.h end,
	SetSize = function(self, w, h) self.w, self.h = w, h end,
	GetLeft = function(self) return 100 end, GetRight = function(self) return 100 + self.w end,
	GetBottom = function(self) return 100 end, GetTop = function(self) return 100 + self.h end,
	GetCenter = function(self) return 100 + self.w / 2, 100 + self.h / 2 end,
	GetEffectiveScale = function(self) return 1 end, GetScale = function(self) return self.scale or 1 end,
	SetScale = function(self, s) self.scale = s end,
	-- anchors are kept (not laid out), so a scenario can check what a frame is placed against
	SetPoint = function(self, ...) self.points = self.points or {}; table.insert(self.points, { ... }) end,
	ClearAllPoints = function(self) self.points = {} end,
	SetScript = function(self, k, f) self.scripts = self.scripts or {}; self.scripts[k] = f end,
	GetScript = function(self, k) return self.scripts and self.scripts[k] end,
	HookScript = noop,
	GetParent = function(self) return self.parent end,
	SetParent = function(self, p) self.parent = p end,
	GetName = function(self) return self.name end,
	GetChildren = function(self) return table.unpack(self.children or {}) end,
	GetRegions = function(self) return table.unpack(self.regions or {}) end,
	GetNumPoints = function(self) return 1 end,
	GetPoint = function(self) return "CENTER", UIParent, "CENTER", 0, 0 end,
	CreateTexture = function(self) local t = Region(self, "Texture"); self.regions = self.regions or {}; table.insert(self.regions, t); return t end,
	CreateFontString = function(self) local t = Region(self, "FontString"); self.regions = self.regions or {}; table.insert(self.regions, t); return t end,
	SetText = function(self, t) self.text = t end, GetText = function(self) return self.text end,
	GetStringWidth = function(self) return string.len(tostring(self.text or "")) * 6 end,
	GetFont = function(self) return "Fonts\\FRIZQT__.TTF", 12, "" end,
	GetFrameLevel = function(self) return self.level or 1 end, SetFrameLevel = function(self, l) self.level = l end,
	GetFrameStrata = function(self) return self.strata or "MEDIUM" end, SetFrameStrata = function(self, s) self.strata = s end,
	SetChecked = function(self, c) self.checked = c and true or false end, GetChecked = function(self) return self.checked and 1 or nil end,
	EnableMouse = function(self, on) self.mouse = on and true or false end, IsMouseEnabled = function(self) return self.mouse end,
	Enable = function(self) self.enabled = true end, Disable = function(self) self.enabled = false end,
	IsEnabled = function(self) return self.enabled ~= false and 1 or nil end,
	GetObjectType = function(self) return self.kind or "Frame" end,
	RegisterEvent = function(self, e) self.events = self.events or {}; self.events[e] = true end,
	UnregisterEvent = function(self, e) if self.events then self.events[e] = nil end end,
	GetFontString = function(self) return self.fontString end, SetFontString = function(self, fs) self.fontString = fs end,
	GetNormalTexture = function(self) self.nt = self.nt or Region(self, "Texture"); return self.nt end,
	GetPushedTexture = function(self) self.pt = self.pt or Region(self, "Texture"); return self.pt end,
	GetHighlightTexture = function(self) self.ht = self.ht or Region(self, "Texture"); return self.ht end,
	GetCheckedTexture = function(self) self.ct = self.ct or Region(self, "Texture"); return self.ct end,
	GetDisabledCheckedTexture = function(self) self.dct = self.dct or Region(self, "Texture"); return self.dct end,
	GetMinMaxValues = function(self) return 0, 1 end, GetValue = function(self) return self.value or 0 end,
	SetValue = function(self, v) self.value = v end,
	GetZoom = function(self) return self.zoom or 0 end, SetZoom = function(self, z) self.zoom = z end, GetZoomLevels = function(self) return 6 end,
	GetID = function(self) return 1 end,
	GetNumLines = function() return 0 end,
}
local function look(t, k) local m = Frame.methods[k]; if m then return m end; if type(k) == "string" and string.match(k, "^[A-Z]") then return noop end; return nil end
Frame.meta = { __index = look }

function CreateFrame(kind, name, parent, template)
	local f = setmetatable({ kind = kind, name = name, parent = parent, shown = true, alpha = 1, w = 100, h = 20 }, Frame.meta)
	if parent then parent.children = parent.children or {}; table.insert(parent.children, f) end
	if name then _G[name] = f end
	if kind == "Button" or kind == "CheckButton" then f.fontString = Region(f, "FontString") end
	table.insert(allFrames, f)
	return f
end

-- running scripts as the client does: `this`, `event`, `arg1`...
function RunScript(f, key, a1, a2, a3)
	local s = f.scripts and f.scripts[key]
	if not s then return false end
	local oldThis, oldArg1, oldArg2, oldArg3 = this, arg1, arg2, arg3
	this, arg1, arg2, arg3 = f, a1, a2, a3
	local ok, err = pcall(s)
	this, arg1, arg2, arg3 = oldThis, oldArg1, oldArg2, oldArg3
	if not ok then table.insert(ERRORS, key .. ": " .. tostring(err)) end
	return true
end
function FireEvent(e, a1, a2)
	event = e
	for _, f in ipairs(allFrames) do if f.events and f.events[e] then RunScript(f, "OnEvent", a1, a2) end end
end
function Tick(n, dt)
	for i = 1, n do
		AdvanceTime(dt or 0.1)
		for _, f in ipairs(allFrames) do if f.shown then RunScript(f, "OnUpdate", dt or 0.1) end end
	end
end
function Click(f, button)
	if f.kind == "CheckButton" then f.checked = not f.checked end
	return RunScript(f, "OnClick", button or "LeftButton")
end

-- the game's own frames and functions --------------------------------------------------------------------------
UIParent = CreateFrame("Frame", "UIParent"); UIParent.w, UIParent.h = 1024, 768
WorldFrame = CreateFrame("Frame", "WorldFrame")
for _, n in ipairs({ "PlayerFrame", "TargetFrame", "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4",
	"MinimapCluster", "BuffFrame", "MainMenuBar", "MainMenuExpBar", "ChatFrame1", "ChatFrame1Tab", "ChatFrame1EditBox",
	"GameTimeFrame", "MainMenuBarArtFrame", "UIErrorsFrame", "GameTooltip", "ScriptErrors", "DropDownList1", "ItemRefTooltip" }) do
	CreateFrame("Frame", n, UIParent)
end
Minimap = CreateFrame("Frame", "Minimap", MinimapCluster)
-- the XP bar and its four border pieces, as the game makes them: 256x10 each along the bar's lower edge
MainMenuExpBar.w, MainMenuExpBar.h = 1024, 13
for i = 0, 3 do
	local t = MainMenuExpBar:CreateTexture()
	t.w, t.h = 256, 10
	t.GetTexCoord = function() return 0, 0.79, 0, 0.83, 1, 0.79, 1, 0.83 end
	t.GetPoint = function() return "BOTTOM", MainMenuExpBar, "BOTTOM", -384 + 256 * i, -3 end
	t.GetTexture = function() return "Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf" end
	_G["MainMenuXPBarTexture" .. i] = t
end
for i = 1, 12 do CreateFrame("CheckButton", "ActionButton" .. i, MainMenuBar) end
for i = 1, 4 do
	CreateFrame("Frame", "PartyMemberFrame" .. i .. "Portrait", _G["PartyMemberFrame" .. i])
end
DEFAULT_CHAT_FRAME = ChatFrame1
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
MAX_PLAYER_BUFFS = 16
NUM_CHAT_WINDOWS = 7
-- raid marks by unit, and the game's usual tooltip corner
MOCK_MARKS = {}
function GetRaidTargetIndex(u) return MOCK_MARKS[u] end
function GameTooltip_SetDefaultAnchor(t, p) t:SetOwner(p, "ANCHOR_NONE"); t:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -13, 70) end
MOCK_TARGET = false                                    -- a scenario sets this to have something targeted
function UnitExists(u) return u == "player" or (u == "target" and MOCK_TARGET) end
-- as in 1.12: the target frame's update works on `this` and fails when `this` is any other frame
function TargetFrame_Update()
	if this ~= TargetFrame then error("Interface\\FrameXML\\UnitFrame.lua:25: attempt to index field `name' (a nil value)") end
	if UnitExists("target") then this:Show() else this:Hide() end
end
function UnitName(u) if u == "player" then return "Slim" end end
function UnitClass(u) if u == "player" then return "Warrior", "WARRIOR" end end
function UnitHealth() return 100 end
function UnitHealthMax() return 100 end
function UnitMana() return 50 end
function UnitManaMax() return 100 end
function UnitPowerType() return 1 end
function UnitLevel() return 10 end
function UnitIsPlayer(u) return u == "player" end
function UnitIsDeadOrGhost() return false end
function UnitDebuff() return nil end
function UnitBuff() return nil end
function GetCursorPosition() return 500, 400 end
function IsShiftKeyDown() return nil end
function IsMouseButtonDown() return nil end
local cvars = {}
function GetCVar(name) return cvars[name] or "0" end
function SetCVar(name, value) cvars[name] = tostring(value) end
function GetMouseFocus() return nil end
function HasAction() return true end
function PlaySoundFile() end
function PlaySound() end
function GetZoneText() return "Elwynn Forest" end
function GetRealZoneText() return "Elwynn Forest" end
function GetNumPartyMembers() return 0 end
function GetPlayerMapPosition() return 0, 0 end
function ToggleDropDownMenu() end
function UIDropDownMenu_Initialize() end
function UIDropDownMenu_AddButton() end
function CloseDropDownMenus() end
function SetPortraitTexture() end
function message(m) table.insert(ERRORS, "popup: " .. tostring(m)) end
_ERRORMESSAGE = function(m) table.insert(ERRORS, "error: " .. tostring(m)) end
SlashCmdList = {}

-- anything else the addon touches that is not modelled: a harmless object that is both a frame and a function
local Any = {}
Any.meta = { __call = function() return nil end, __index = look }
local missing = {}
setmetatable(_G, { __index = function(t, k)
	if type(k) ~= "string" then return nil end
	if string.match(k, "^AZS_") or string.match(k, "^SlimSuite") or k == "SS" or k == "SU" or k == "AZSKIT" then return nil end
	if string.match(k, "^[A-Z]") then
		missing[k] = true
		local a = setmetatable({ name = k, shown = false, alpha = 1, w = 10, h = 10 }, Any.meta)
		rawset(t, k, a)
		return a
	end
	return nil
end })
function MissingGlobals() local l = {} for k in pairs(missing) do table.insert(l, k) end table.sort(l) return l end
