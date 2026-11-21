-- Category masters pause only SlimSuite features; installed addons are never changed.
local K, SU, NAME = SS.Kit, SS.SU, SS.NAME;   -- the three names every Slim Suite file uses (SlimSuiteCore.lua)
SS.MODULE_ORDER={"ui","nameplates","gameplay","chat","sounds","misc"};
SS.MODULE_TITLES={elements="Elements",ui="Interface",nameplates="Nameplates",gameplay="Gameplay",chat="Chat",sounds="Sound",misc="Accessibility",changelog="Changelog"};
local groups={
	gameplay={"camera","bossMarks","prePullMarks","deathMarks","raidRow","minimapCaches","minimapBosses","minimapLairs","showGuardianFlag","floatingText","worldCombatMode"},
	nameplates={"modernEnemyFrames","enemyBossesOnly","enemyPlateDebuffs","enemyPlateGroup","platerStyle","plateWidth","plateBarHeight","plateNameSize","plateHpText","plateBorder","plateColorEnemy","plateColorElite","plateColorBoss"},
	misc={"accessibilityContrast","accessibilityLargeText","accessibilityReduceMotion"}};
SS.MODULE_KEYS=groups;
function SS.ModuleEnabled(id)
	local d=SS.DB();
	if d.modules[id]~=nil then return d.modules[id] and true or false; end
	if id=="ui" then return not d.vanillaUI; end
	return true;
end
local function OwnedUIKeys()
	local excluded={}; for _,keys in pairs(groups) do for _,key in ipairs(keys) do excluded[key]=true; end end
	local out={vanillaUI=true};
	for _,key in ipairs(SS.LAYOUT_KEYS) do if not excluded[key] then out[key]=true; end end
	for _,key in ipairs(SS.LAYOUT_TABLES) do if key~="minimap" then out[key]=true; end end
	for _,element in pairs(SS.ELEMENTS) do if element.feature then out[element.feature]=true; end end
	return out;
end
local function Capture(keys)
	local saved={}; local d=SS.DB();
	for key in pairs(keys) do saved[key]={}; if d[key]~=nil then saved[key].value=type(d[key])=="table" and SS.CopyTable(d[key]) or d[key]; end end
	return saved;
end
local function Restore(saved)
	local d=SS.DB();
	for key,entry in pairs(saved or {}) do d[key]=type(entry.value)=="table" and SS.CopyTable(entry.value) or entry.value; end
end
local function PauseUI()
	local d=SS.DB();
			if not d.moduleSettings.ui then d.moduleSettings.ui=Capture(OwnedUIKeys()); end
			SS.StopDemoMode(); if SS.setupActive then SS.SetupEnd(true); end; SS.SetUnlocked(false,true);
			-- Default selects the native HUD. Retain all custom values in the category snapshot.
			local unrelated={}; for _,keys in pairs(groups) do for _,key in ipairs(keys) do unrelated[key]=true; end end
			local preserve=Capture(unrelated);
			SU.batching=true;
			for _,name in ipairs(SS.SETUP_ORDER) do SU.SetMode(name,"default",SS.ELEMENTS[name].title); end
			SU.batching=false;
			Restore(preserve); SS.RestoreNatives();
end
function SS.ModuleLayoutPreferences(out)
	local d=SS.DB(); local allowed={};
	for _,key in ipairs(SS.LAYOUT_KEYS) do allowed[key]=true; end
	for _,key in ipairs(SS.LAYOUT_TABLES) do allowed[key]=true; end
	for id,saved in pairs(d.moduleSettings) do
		if not SS.ModuleEnabled(id) then
			for key,entry in pairs(saved) do if allowed[key] then out[key]=type(entry.value)=="table" and SS.CopyTable(entry.value) or entry.value; end end
		end
	end
	return out;
end
function SS.EnforcePausedModules(adopt)
	local d=SS.DB();
	for id,keys in pairs(groups) do
		if not SS.ModuleEnabled(id) then
			if adopt then
				local allowed={}; for _,key in ipairs(SS.LAYOUT_KEYS) do allowed[key]=true; end
				local settings=d.moduleSettings[id] or {}; d.moduleSettings[id]=settings;
				for _,key in ipairs(keys) do if allowed[key] then settings[key]={value=d[key]}; end end
			end
			for _,key in ipairs(keys) do d[key]=key=="worldCombatMode" and "off" or false; end
		end
	end
	if not SS.ModuleEnabled("ui") then
		if adopt then d.moduleSettings.ui=Capture(OwnedUIKeys()); end
		local active=false; for _,name in ipairs(SS.SETUP_ORDER) do if d.elementModes[name]~="default" then active=true; break; end end
		if active then PauseUI(); end
	end
end
function SS.SetModuleEnabled(id,on)
	if not SS.MODULE_TITLES[id] or SS.ModuleEnabled(id)==(on and true or false) then return; end
	local d=SS.DB(); on=on and true or false;
	if id=="ui" then
		if not on then
			PauseUI();
		else
			local saved=d.moduleSettings.ui;
			if saved then Restore(saved); d.moduleSettings.ui=nil;
			else
				d.vanillaUI=false; SU.batching=true;
				for _,name in ipairs(SS.SETUP_ORDER) do SU.SetMode(name,SS.ELEMENTS[name].optional and "disabled" or "enabled",SS.ELEMENTS[name].title); end
				SU.batching=false;
			end
		end
	elseif groups[id] then
		if not on then
			local keys={}; for _,key in ipairs(groups[id]) do keys[key]=true; end
			d.moduleSettings[id]=Capture(keys);
			for key in pairs(keys) do d[key]=key=="worldCombatMode" and "off" or false; end
		else Restore(d.moduleSettings[id]); d.moduleSettings[id]=nil; end
	end
	d.modules[id]=on;
	if id=="ui" then
		local restoring=SU.restoring; SU.restoring=on;
		SS.Startup(false,false); SS.ApplyElementModes(); SS.Safe(SS.PlaceAll);
		SU.restoring=restoring;
	end
	if id=="gameplay" then SS.Camera(); SS.Safe(SS.UpdateEnemyNameplates); SS.Safe(SS.ApplyGuardianFlag); end
	if id=="misc" then SS.Safe(SS.UpdateBossFrames); end
	if SS.SyncNativeDamageNumbers then SS.SyncNativeDamageNumbers(); end
	if SS.MarkProfileDirty then SS.MarkProfileDirty(); end
	SS.RefreshToggles();
	if SS.RefreshModuleHub then SS.RefreshModuleHub(); end
end

