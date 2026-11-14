local failures = 0
local function check(label, ok)
 if not ok then failures = failures + 1; print('MISMATCH '..label) end
end
SS.SetupEnd(true)
local su, d = SS.ENV.SU, SS.DB()
for _, name in ipairs(SS.SETUP_ORDER) do check('registered setup element '..name, SS.ELEMENTS[name] and SS.ELEMENTS[name].title) end
for _, entry in ipairs(SS.MOVABLE) do check('registered movable '..entry[1], SS.ELEMENTS[entry[1]]) end
su.SetMode('SlimSuiteClockFrame','disabled','Clock')
d.enabledElements.SlimSuiteClockFrame = true; d.replaceClock = true
check('explicit disabled beats legacy flags', su.Mode('SlimSuiteClockFrame') == 'disabled')
SS.UpdateClock(); check('renderer respects explicit disabled despite stale flag', not SlimSuiteClockFrame:IsShown())
d.replaceClock = false
SS.ChangeSetting(function() return d.replaceClock end,function(v) d.replaceClock = v end,true)
check('legacy checkbox transitions authoritative mode', su.Mode('SlimSuiteClockFrame') == 'enabled')
SS.ChangeSetting(function() return d.replaceClock end,function(v) d.replaceClock = v end,false)
check('unchecking replacement restores native mode', su.Mode('SlimSuiteClockFrame') == 'default')
SS.MigrateElementModes(); check('duplicate saved enabled state cleared', next(d.enabledElements) == nil)

d.layouts['dirty test'] = {}; SS.activeCustomProfile = 'dirty test'; SS.profileDirty = nil
local original, copies = SS.LayoutSnapshot, 0
SS.LayoutSnapshot = function() copies=copies+1; return original() end
Tick(20); check('idle autosave makes no snapshots', copies == 0)
SS.FlipToggle(function() return d.tallyBackground end,function(v) d.tallyBackground=v end)
Tick(5); check('edit autosaves once', copies == 1 and d.layouts['dirty test'].tallyBackground == d.tallyBackground)
Tick(20); check('saved profile stays idle', copies == 1)
SS.LayoutSnapshot=original; SS.activeCustomProfile=nil; d.layouts['dirty test']=nil

local handler
AZS_RegisterWorldAnchorFrameHandler=function(fn) handler=fn; return true end
AZS_UnregisterWorldAnchorFrameHandler=function() handler=nil; return true end
AZS_GetWorldAnchors=function() return {entries={{anchorId=11,unitId=1,kind='boss',state='alive',name='Boss'}}} end
AZS_ProjectWorldAnchors=function() return {frameCurrent=true,entries={{anchorId=11,state='onScreen',x=400,y=300}}} end
AZS_GetDebuffs=function() return {{icon='Spell_Shadow_ShadowWordPain',remaining=4.2}} end
AZS_UNITS={{id=1,kind='boss',hp=50,hpm=100,name='Boss'}}
SS.SetNativeEnemyNameplates(true); SS.SetEnemyPlateDebuffs(true)
check('native aura attachment registers projection', handler ~= nil)
if handler then handler() end
local plate=SlimSuiteEnemyNameplate1
check('native plate retains health rendering ownership', plate and plate:IsShown() and not plate.health:IsShown() and not plate.name:IsShown() and plate.backdrop == nil)
check('native attachment shows documented DoT time', plate and plate.dots[1]:IsShown() and plate.dots[1].time:GetText()=='4.2')
NAMEPLATES_ON=nil; SS.UpdateEnemyNameplates()
check('native key binding can hide plates without being overridden',NAMEPLATES_ON==nil and handler==nil and not plate:IsShown())
NAMEPLATES_ON=1; SS.UpdateEnemyNameplates()
check('native key binding reactivates aura attachments',handler~=nil)
SS.SetModernEnemyFrames(true); if handler then handler() end
check('modern plate restores its body', plate and plate.health:IsShown() and plate.name:IsShown() and plate.backdrop)
SS.SetModernEnemyFrames(false); SS.SetEnemyPlateDebuffs(false)
check('disabled attachments unregister and hide', handler == nil and not plate:IsShown())
local bar=CreateFrame('StatusBar',nil,UIParent)
check('unknown methods are absent', bar.MadeUpUnsupportedAPI == nil and bar.HookScript == nil)
rawset(_G,'UnitGetTotalAbsorbs',nil)
check('unsupported party shields stay unknown', SS.AbsorbAmount('party1') == nil)

local selected = d.language
for _, code in ipairs({'enUS','esES','frFR','deDE','ptBR','itIT'}) do
 d.language=code; check('language selectable '..code, SS.LocaleCode()==code)
 for key in pairs(SS.LOCALE_TEXT.enUS) do check('translation key '..code..' '..key, type(SS.LOCALE_TEXT[code][key])=='string') end
end
d.language=selected
local label=UIParent:CreateFontString(nil,'OVERLAY','GameFontHighlight')
label:SetText('A deliberately long translated setting label that must fit by growing down instead of shrinking its font')
local height=SS.WrappedLabelHeight(label,100)
check('wrapped labels reserve multiple rows',height>28 and label:GetHeight()==height)
check('no runtime errors',#ERRORS==0)
for _,e in ipairs(ERRORS) do print(e) end
print('architecture problems: '..failures)
assert(failures==0,'architecture regressions')
