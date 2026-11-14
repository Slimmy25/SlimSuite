-- Focused Slim Suite module; loaded in manifest order.
if ( setfenv ) then setfenv(1, SS.ENV); end
function SU.Save(f)
	SU.saved = SU.saved or {};
	if ( SU.saved[f] == nil ) then SU.saved[f] = f:GetAlpha() or 1; end
end

-- hide every frame directly under UIParent except the setup's own panel, bar, glow and the handles
-- hide a frame for the setup: remembered if it was shown, so Exit or Complete can show it again
function SU.ForceHide(f)
	if ( not f or not f.SetAlpha ) then return; end
	SU.Save(f);
	SU.shownBefore = SU.shownBefore or {};
	if ( f.IsShown and f:IsShown() and SU.shownBefore[f] == nil ) then SU.shownBefore[f] = true; end
	if ( f.Hide ) then f:Hide(); end
	f:SetAlpha(0);
end

-- Slim Suite's own frames and the game's clock, which are not all children of UIParent
SU.FORCE_HIDE = { "SlimSuiteMeterFrame", "SlimSuiteTallyFrame", "SlimSuiteClockFrame", "SlimSuiteLocalClockFrame",
	"SlimSuiteBossFrames", "SlimSuiteAnnouncementFrame", "SlimSuiteReviveFrame", "SlimSuiteCombatTextFrame",
	"SlimSuiteSpellRowFrame", "SlimSuiteItemRowFrame", "SlimSuiteProcMeter", "SlimSuiteStoredLevelsButton",
	"SlimSuiteStoreLevelsToggle", "SlimSuiteWorldMarkers", "SlimSuiteFloatingText", "SlimSuiteMovePanel", "SlimSuiteStatCounterFrame", "GameTimeFrame" };

-- the chat windows, their tabs and their input boxes stay visible and usable during setup, so you can always type;
-- so do the game's error popup, menus and confirmation dialogs, and Slim Suite's own tools. Hidden, these came back
-- invisible but still catching clicks, which stopped any further changes.
SU.KEEP_VISIBLE = { ScriptErrors = true, SlimSuiteErrorFrame = true, SlimSuiteMouseProbe = true, ItemRefTooltip = true,
	UIErrorsFrame = true, SlimSuiteWarnTip = true, ChatFrameEditBox = true, ChatFrameMenuButton = true };
for i = 1, 3 do SU.KEEP_VISIBLE["DropDownList" .. i] = true; end
for i = 1, 4 do SU.KEEP_VISIBLE["StaticPopup" .. i] = true; end
for i = 1, 7 do
	SU.KEEP_VISIBLE["ChatFrame" .. i] = true; SU.KEEP_VISIBLE["ChatFrame" .. i .. "Tab"] = true; SU.KEEP_VISIBLE["ChatFrame" .. i .. "EditBox"] = true;
end

-- hide everything that is not the setup's own: the game's UI, Slim Suite's frames, the minimap and its buttons and pins
function SU.HideAll()
	local keep = { [SU.panel] = true, [SU.bar] = true, [SU.glow] = true };
	if ( SU.confirmDone ) then keep[SU.confirmDone] = true; end
	for name in pairs(SU.KEEP_VISIBLE) do local c = getglobal(name); if ( c ) then keep[c] = true; end end
	for _, h in pairs(handles) do keep[h] = true; end
	local kids = { UIParent:GetChildren() };
	for i = 1, table.getn(kids) do
		local f = kids[i];
		if ( f and not keep[f] ) then SU.ForceHide(f); end
	end
	for _, name in ipairs(SU.FORCE_HIDE) do SU.ForceHide(getglobal(name)); end
	for _, root in ipairs({ Minimap, MinimapCluster }) do
		if ( root and root.GetChildren ) then
			local mkids = { root:GetChildren() };
			for i = 1, table.getn(mkids) do SU.ForceHide(mkids[i]); end
		end
	end
	SU.ForceHide(Minimap); SU.ForceHide(MinimapCluster);
end

-- turn an element on or off: its frame (and the frames that move with it) and its handle
SU.FEATURES = {
	SlimSuiteStatCounterFrame = function(v)
		if ( v and setupActive ) then SU.statCounterPlaceholder:Show(); else SU.statCounterPlaceholder:Hide(); end
	end,
	SlimSuiteStoredLevelsButton = function(v) SS.DB().moveLevelButton = v; SS.UpdateLevelButton(); end,
	SlimSuiteSpellRowFrame = function(v) SS.DB().replaceBuildRows = v; SS.ApplyBuildRowReplacement(); end,
	SlimSuiteClockFrame = function(v) SS.DB().replaceClock = v; SS.UpdateClock(); end,
	SlimSuiteBossFrames = function(v) SS.DB().replaceEncounters = v; SS.UpdateBossFrames(); end,
	SlimSuiteTallyFrame = function(v) SS.DB().replaceTally = v; SS.UpdateTally(); end,
	SlimSuiteAnnouncementFrame = function(v) SS.DB().replaceBanners = v; SS.UpdateAnnouncementFrame(); end,
	SlimSuiteReviveFrame = function(v) SS.DB().replaceRevive = v; end,
	SlimSuiteCombatTextFrame = function(v) SS.DB().combatTextBox = v; end,
	SlimSuiteLocalClockFrame = function(v)
		if ( v ) then SS.DB().replaceLocalClock = true;
		else SS.DB().replaceLocalClock = false; SS.DB().clockDetached = false; end
		SS.Safe(SlimSuiteWorld.UpdateLocalClock);
	end,
	SlimSuiteMinimapBar = function(v) SS.SetMinimapBar(v, true); end,
};

-- A setup element's Default state means the original Blizzard/Aethus element is active and Slim Suite's
-- replacement is inactive. These calls intentionally set game HUD visibility to shown, even if the player
-- previously hid that part in Interface settings: choosing Default explicitly asks for the game's design.
SU.NATIVE_PARTS = SS.NATIVE_PARTS;
function SU.RestoreNative(frame)
	local d = SS.DB();
	local part = SU.NATIVE_PARTS[frame];
	if ( part ) then
		SS.Safe(SS.HideNative, part, false);
		local key = SS.NATIVE_KEYS and SS.NATIVE_KEYS[part];
		if ( key ) then d[key] = nil; end
		if ( type(AZS_SetHudShown) == "function" ) then SS.Safe(AZS_SetHudShown, part, true); end
	end
	if ( frame == "PlayerFrame" ) then
		d.playerLook = "classic";
		if ( SS.DB().partyIncludesSelf ) then SS.SetPartySelf(false); end
		if ( SS.DB().mirrorTarget ) then SS.SetMirrorTarget(false); end
	elseif ( frame == "TargetFrame" ) then
		d.targetLook = "classic"; d.hideTarget = false;
		SS.Safe(SS.TargetFrameHidden, false);
	elseif ( frame == "PartyMemberFrame1" ) then d.partyLook = "classic";
	elseif ( frame == "BuffFrame" ) then
		d.buffsOnPlayer, d.buffsOnTarget, d.buffCustomLayout = false, false, false;
		d.buffGrowthDirection = "down";
		d.sizes.BuffFrame, d.orientations.BuffFrame, d.padding.BuffFrame = nil, nil, nil;
		SS.Safe(SS.ApplyBuffOrientation);
	elseif ( frame == "MinimapCluster" ) then
		d.minimapSquare, d.minimapTransparent, d.minimapBar, d.gatherButtons = false, false, false, false;
		SS.Safe(SS.SetMinimapBar, false, true); SS.Safe(SS.LayoutGather); SS.Safe(SS.LayoutMinimapBar);
	elseif ( frame == "MainMenuBar" ) then
		d.plainBar = false; SS.Safe(SS.PlainBar, false); SS.Safe(SS.RestoreNativeActionBarLayout);
	end
	if ( frame == "SlimSuiteStatCounterFrame" ) then return; end
	if ( frame == "TargetFrame" or frame == "PlayerFrame" or frame == "PartyMemberFrame1" ) then SS.Safe(SS.ApplyNewFrames); end
	if ( frame == "MinimapCluster" ) then SS.Safe(SS.ApplyMinimapShape); end
end

function SU.ApplyOn(frame, on, title)
	-- the newest choice wins: a target frame turned on or off by its own button takes precedence over the party/combine settings
	if ( frame == "PlayerFrame" and on and not SU.restoring and SS.DB().partyIncludesSelf ) then SS.Safe(SS.ClaimTarget, "player"); end
	if ( frame == "TargetFrame" and not on and SS.DB().combineTarget and not SU.restoring and not SU.cascading and not SU.defaulting ) then
		SS.Notice("Mirror Target turned off: the target frame is off.");
		SS.Safe(SS.SetMirrorTarget, false); SS.Safe(SS.RebuildSetup);
	end
	-- the damage meter element is the same switch as "Replace Default Damage Meter with Movable Version?"
	if ( frame == "SlimSuiteMeterFrame" and not SU.restoring ) then SS.DB().moveMeter = on and true or false; end
	-- the same goes for every replacement: its element in the list is its on/off switch
	local feature = SU.FEATURES[frame];
	if ( feature and not SU.restoring ) then SS.Safe(feature, on and true or false); end
	local nativePart = SU.NATIVE_PARTS[frame];
	if ( nativePart ) then SS.Safe(SS.HideNative, nativePart, on or SS.DB().elementModes[frame] == "disabled"); end
	-- the target frame element is the same switch as "Hide the target frame": off here is off in the game too
	if ( frame == "TargetFrame" and not SU.restoring and not SU.defaulting and (SS.DB().hideTarget and true or false) == (on and true or false) ) then
		SS.DB().hideTarget = not on;
		SS.Safe(SS.TargetFrameHidden, not on);
		SS.Safe(SS.ApplyNewFrames);
	end
	SU.on = SU.on or {};
	SU.on[frame] = on and true or nil;
	if ( frame == "PlayerFrame" and SS.DB().combineTarget and getglobal("TargetFrame") ) then
		SU.cascading = true;
		SS.Safe(SU.SetOn, "TargetFrame", on, SU.titles and SU.titles.TargetFrame or "Target frame");
		SU.cascading = false;
	end
	local names = { frame };
	local companions = SU.CompanionsOf(frame);
	for i = 1, table.getn(companions) do table.insert(names, companions[i]); end
	if ( frame == "TargetFrame" and SS.DB().buffsOnTarget ) then table.insert(names, "BuffFrame"); end
	if ( frame == "PlayerFrame" and SS.DB().buffsOnPlayer ) then table.insert(names, "BuffFrame"); end
	if ( frame == "SlimSuiteMinimapBar" ) then
		for i = 1, table.getn(SlimSuiteMinimapBarList) do
			local n = SlimSuiteMinimapBarList[i].GetName and SlimSuiteMinimapBarList[i]:GetName();
			if ( n ) then table.insert(names, n); end
		end
	end
	if ( frame == "MinimapCluster" ) then
		table.insert(names, "Minimap");
		if ( GameTimeFrame and not GameTimeFrame.slimBarOrig ) then table.insert(names, "GameTimeFrame"); end   -- unless the moon is in the row
		-- the game's own minimap parts (its round border, zoom buttons, zone text), so the chosen shape can be seen;
		-- other addons' minimap buttons stay hidden
		for _, root in ipairs({ Minimap, MinimapCluster }) do
			if ( root and root.GetChildren ) then
				local kids = { root:GetChildren() };
				for i = 1, table.getn(kids) do
					local n = kids[i] and kids[i].GetName and kids[i]:GetName();
					if ( n and n ~= "Minimap" and not kids[i].slimBarOrig and (string.find(n, "^Minimap") or string.find(n, "^MiniMap")) ) then table.insert(names, n); end
				end
			end
		end
		-- the local clock hangs under the minimap unless it has been detached (then it is its own element)
		if ( SS.DB().replaceLocalClock and not SS.DB().clockDetached ) then table.insert(names, "SlimSuiteLocalClockFrame"); end
	end
	for i = 1, table.getn(names) do
		if ( names[i] == "PlayerFrame" or names[i] == "TargetFrame" or names[i] == "PartyMemberFrame1" ) then names[i] = SS.Shown(names[i]); end
	end
	for _, fname in ipairs(names) do
		local f = getglobal(fname);
		if ( f and f.SetAlpha ) then
			SU.Save(f);
			if ( on ) then
				if ( SU.shownBefore and SU.shownBefore[f] and f.Show ) then f:Show(); end
				if ( (fname == "SlimSuitePlayerCard" or fname == "SlimSuiteTargetCard" or fname == "SlimSuiteMinimapBar") and f.Show ) then f:Show(); end
				-- an element turned on is shown, even if it was invisible when the setup opened (e.g. the classic frames
				-- sat at alpha 0 under the new-school cards); a hidden feature is faded out again by its own setting
				local a = SU.saved[f];
				if ( type(a) ~= "number" or a <= 0 ) then a = 1; end
				f:SetAlpha(a);
				if ( fname == "TargetFrame" and not SS.DB().hideTarget and f.Show ) then f:Show(); end
				local p = f:GetParent();                     -- a hidden parent would hide the element too
				while ( p and p ~= UIParent and p.SetAlpha ) do SU.Save(p); p:SetAlpha(SU.saved[p]); p = p:GetParent(); end
			elseif ( not SU.defaulting and frame ~= "ChatFrame1" and not SU.KEEP_VISIBLE[fname] ) then
				f:SetAlpha(0);
			end
		end
	end
	-- Turning the target frame off ends the combined mirror; reopening setup only restores what is shown.
	if ( frame == "TargetFrame" and not on and SS.DB().mirrorTarget and not SU.restoring and not SU.defaulting ) then
		SS.SetMirrorTarget(false); SS.Notice("Mirror Target turned off: the target frame is off.");
	end
	local hname = SS.Shown(frame);
	if ( hname ~= frame and handles[frame] ) then handles[frame]:Hide(); end    -- the hidden frame's handle never shows
	if ( on and not handles[hname] and title ) then SS.Safe(SS.Handle, hname, title); end
	if ( handles[hname] ) then if ( on and SS.HandleAllowed(hname) ) then handles[hname]:Show(); else handles[hname]:Hide(); end end
	if ( frame == "MinimapCluster" and on ) then SS.Safe(SS.ApplyMinimapShape); end   -- round border or square edge
	if ( frame == "ChatFrame1" and on ) then SS.Safe(SS.PrepareChatWindow); end
	if ( frame == "PlayerFrame" or frame == "TargetFrame" ) then
		SS.Safe(SS.RefreshCard, getglobal(frame == "PlayerFrame" and "SlimSuitePlayerCard" or "SlimSuiteTargetCard"));
	end
	if ( not SU.batching ) then
		SU.RefreshBar(); SU.UpdateDemo();
		if ( frame == "PlayerFrame" and SU.focus == "TargetFrame" ) then SU.Focus("TargetFrame"); end
	end
end

-- the grid: the setting, the bar button and the panel's tick box all agree
function SU.SetGridSetting(on)
	SS.DB().showEditGrid = on and true or false;
	SS.Safe(ShowEditGrid);                                 -- shows it while editing, or takes it away
	if ( setupActive ) then SU.SetOn("SlimSuiteEditGrid", on and true or false); end
	if ( SU.grid ) then SU.grid.Refresh(); end
end

-- Explicit elementModes are authoritative. These fallbacks only read unmigrated saves.
function SU.Mode(frame)
 local d = SS.DB(); local mode = d.elementModes[frame];
 if ( mode == "enabled" or mode == "disabled" or mode == "default" ) then return mode; end
 if ( d.enabledElements and d.enabledElements[frame] ) then return "enabled"; end
 local element = SS.ELEMENTS[frame];
 if ( element and element.feature and d[element.feature] ) then return "enabled"; end
 if ( (frame == "PlayerFrame" or frame == "TargetFrame") and SS.UsesCard(frame) ) then return "enabled"; end
 if ( frame == "PartyMemberFrame1" and SS.Look(frame) == "thin" ) then return "enabled"; end
 if ( frame == "TargetFrame" and d.hideTarget ) then return "disabled"; end
 return "default";
end

function SS.MigrateElementModes()
 local d = SS.DB();
 for i = 1, table.getn(SS.SETUP_ORDER) do
  local name = SS.SETUP_ORDER[i]; d.elementModes[name] = SU.Mode(name);
 end
 d.enabledElements = {}; -- legacy import input only; no second saved source of enabled state
end

-- Detect an existing HUD setup so onboarding never resets a returning player's saved layout.
function SS.HasPriorUISetup(d)
	d = d or SS.DB();
	if ( d.setupDone or d.unlocked ) then return true; end
	if ( next(d.elementModes or {}) or next(d.enabledElements or {}) ) then return true; end
	if ( next(d.frameDefault or {}) or next(d.layouts or {}) or d.layoutPerCharacter ) then return true; end
	if ( next(d.sizes or {}) or next(d.scales or {}) or next(d.orientations or {}) ) then return true; end
	for frame in pairs(d.places or {}) do if ( frame ~= "SlimSuiteItemRowFrame" ) then return true; end end
	for _, key in ipairs({ "moveLevelButton", "moveMeter", "replaceBuildRows", "replaceClock", "replaceEncounters", "replaceTally", "replaceBanners", "replaceRevive", "replaceLocalClock", "minimapBar", "combatTextBox", "hideTarget", "partyIncludesSelf", "mirrorTarget", "combineTarget", "buffsOnPlayer", "minimapSquare", "minimapTransparent" }) do
		if ( d[key] ) then return true; end
	end
	return false;
end

-- Reapply explicit element choices after the game restores its native frames during login or setup exit.
function SS.ApplyElementModes()
	if ( setupActive ) then return; end
	local modes, steps, seen = SS.DB().elementModes or {}, SU.Steps(), {};
	for i = 1, table.getn(steps) do
		local frame = steps[i].frame;
		if ( frame and (modes[frame] == "enabled" or modes[frame] == "disabled") ) then
			seen[frame] = true;
			SS.Safe(SU.SetOn, frame, modes[frame] == "enabled", steps[i].title);
		end
	end
	if ( modes.SlimSuiteMeterFrame and not seen.SlimSuiteMeterFrame and (modes.SlimSuiteMeterFrame == "enabled" or modes.SlimSuiteMeterFrame == "disabled") ) then
		SS.Safe(SU.SetOn, "SlimSuiteMeterFrame", modes.SlimSuiteMeterFrame == "enabled", "Damage meter");
	end
	if ( not SS.DB().unlocked ) then SS.Safe(SS.SetUnlocked, false, true); end
end

function SU.SetMode(frame, mode, title)
	if ( mode ~= "enabled" and mode ~= "disabled" and mode ~= "default" ) then mode = "default"; end
	local d = SS.DB();
	d.elementModes = d.elementModes or {};
	if ( d.elementModes[frame] ~= mode and SS.MarkProfileDirty ) then SS.MarkProfileDirty(); end
	d.elementModes[frame] = mode;
	if ( mode == "enabled" ) then
		SU.defaulting = false;
		if ( d.frameDefault ) then d.frameDefault[frame] = nil; end
		if ( not SU.restoring ) then d.muted[frame] = nil; d.muted[SS.Shown(frame)] = nil; end
		SU.ApplyOn(frame, true, title);
	elseif ( mode == "disabled" ) then
		SU.defaulting = false;
		SU.ApplyOn(frame, false, title);
	else
		-- Restore the game's native element without treating Default as an instruction to hide it.
		SU.defaulting = true;
		SU.ApplyOn(frame, false, title);
		SU.defaulting = false;
		if ( not SU.restoring ) then SS.Safe(SU.RestoreNative, frame); end
		if ( SU.NATIVE[frame] ) then SS.Safe(SU.SetMovable, frame, false); end
		if ( not SU.restoring ) then
			if ( frame == "TargetFrame" ) then
				d.hideTarget = false;
				if ( SS.UsesCard("TargetFrame") ) then SS.Safe(SS.SetLook, "TargetFrame", "classic"); end
				SS.Safe(SS.TargetFrameHidden, false); SS.Safe(SS.ApplyNewFrames);
			elseif ( frame == "PlayerFrame" and SS.UsesCard("PlayerFrame") ) then
				SS.Safe(SS.SetLook, "PlayerFrame", "classic");
			elseif ( frame == "PartyMemberFrame1" and SS.Look("PartyMemberFrame1") == "thin" ) then
				SS.Safe(SS.SetLook, "PartyMemberFrame1", "classic");
			elseif ( frame == "MinimapCluster" ) then
				d.minimapSquare, d.minimapTransparent = false, false;
			end
		end
		local names = { frame };
		local companions = SU.CompanionsOf(frame);
		for i = 1, table.getn(companions) do table.insert(names, companions[i]); end
		for i = 1, table.getn(names) do
			local name = names[i];
			if ( name == "PlayerFrame" or name == "TargetFrame" or name == "PartyMemberFrame1" ) then name = SS.Shown(name); end
			local f = type(name) == "table" and name or getglobal(name);
			if ( f and f.SetAlpha and not SU.FEATURES[frame] ) then
				f:SetAlpha(1);
				if ( f.Show and frame ~= "GameTooltip" ) then f:Show(); end
			end
		end
		if ( frame == "MinimapCluster" ) then SS.Safe(SS.ApplyMinimapShape); end
		if ( frame == "SlimSuiteMeterFrame" ) then SS.Safe(SS.HideNative, "meter", false); end
	end
	if ( not SU.batching ) then SU.RefreshBar(); SU.UpdateDemo(); SU.RefreshDemoButtons(); end
	-- Selecting Enabled in setup immediately selects that element and exposes its green move handle.
	if ( not SU.batching and setupActive and mode == "enabled" ) then SU.Focus(frame); end
	if ( frame == "ChatFrame1" ) then SS.Safe(SS.RefreshChatDock); end
	if ( not SU.batching ) then SS.RefreshToggles(); end
end

function SU.SetOn(frame, on, title)
 if ( not SS.ELEMENTS[frame] ) then return SU.ApplyOn(frame, on, title); end
 return SU.SetMode(frame, on and "enabled" or "disabled", title);
end

function SU.CycleMode(frame)
	local nextMode = { default = "enabled", enabled = "disabled", disabled = "default" };
	SU.SetMode(frame, nextMode[SU.Mode(frame)] or "default", SU.titles and SU.titles[frame]);
	if ( SU.Mode(frame) == "enabled" ) then SU.Focus(frame); elseif ( SU.focus == frame ) then SU.Focus(nil); end
end

function SS.Demoing(name)
	if ( not SS.demoRunning or not SS.demoElements ) then return false; end
	local element = SS.Element and SS.Element(name) or name;
	local selected = SS.demoElements[name] or SS.demoElements[element];
	-- The spell and worn-jewelry rows are one default build element and preview together.
	if ( name == "SlimSuiteItemRowFrame" or name == "SlimSuiteSpellRowFrame" ) then
		selected = SS.demoElements.SlimSuiteSpellRowFrame;
	end
	if ( not selected ) then return false; end
	return not SU or not SU.Mode or SU.Mode(element) == "enabled";
end

-- the action bar: vertical or horizontal, kept until changed
function SU.SetVertical(name, on)
	SS.DB().orientations[name] = on and "vertical" or "horizontal";
	SS.Safe(ApplyMovableOrientation, name);
	SS.Safe(PlaceAll);
	SU.UpdateDemo();
	if ( SU.checks ) then for i = 1, table.getn(SU.checks) do SU.checks[i].Refresh(); end end
end

-- How far the party block reaches down from the first party frame's top, in UIParent units: all four party frames,
-- shown or not (a hidden frame keeps its place), and the setup's sample cards while they are on screen.
