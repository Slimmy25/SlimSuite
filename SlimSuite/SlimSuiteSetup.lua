-- Focused Slim Suite module; loaded in manifest order.
if ( setfenv ) then setfenv(1, SS.ENV); end
function SU.RefreshBar()
	for frame, b in pairs(SU.barButtons or {}) do
		local mode = SU.Mode(frame);
		local parentFrame, parentTitle = SS.ConnectedTo(frame);
		if ( b.nameHit ) then b.nameHit.parentTitle = parentTitle; end
		for i = 1, table.getn(b.states or {}) do
			local state = b.states[i];
			if ( state.modeValue == mode ) then state:LockHighlight(); else state:UnlockHighlight(); end
		end
		if ( parentTitle ) then
			if ( frame == "BuffFrame" ) then
				if ( b.label ) then b.label:SetText(SS.T("Buffs/Debuffs")); end
			end
		elseif ( frame == "BuffFrame" ) then
			if ( b.label ) then b.label:SetText(SS.T("Buffs/Debuffs")); end
		end
	end
end

-- the panel shows one element's own questions, placed just below that element's handle
-- the size buttons: the chosen grid size is lit
function SU.RefreshGridButtons()
	local sizes = { 16, 32, 64, 128 };
	for i = 1, 4 do
		if ( SU.sizes and SU.sizes[i] ) then
			if ( tonumber(SS.DB().gridDivisions) == sizes[i] ) then SU.sizes[i]:LockHighlight(); else SU.sizes[i]:UnlockHighlight(); end
		end
	end
end

-- The element's menu: the setup's panel for an element, the same in the setup and on a right-click while editing.
-- Its title and words, its settings, then its size & layout tools; Exit and Complete in the setup, Done otherwise.
function SS.OpenSizeMenu(name, label)
	name = SS.Element(name);
	if ( not getglobal(SS.Shown(name)) ) then return; end
	if ( not SU.panel ) then SU.Build(); end
	SU.menuLabel = label;
	SU.Focus(name);
end
function SS.MenuOpen()
	return SU.panel and SU.panel:IsShown() and SU.focus and true or false;
end
function SS.HideElementMenu()
	if ( not SU.panel ) then if ( sizeMenu ) then sizeMenu:Hide(); end return; end
	-- in the setup the panel stays: it is drawn again for its element (a Reset there leaves no empty space)
	if ( setupActive ) then
		if ( SU.panel:IsShown() and SU.focus ) then SU.Focus(SU.focus); elseif ( sizeMenu ) then sizeMenu:Hide(); end
		return;
	end
	if ( sizeMenu ) then sizeMenu:Hide(); end
	SU.panel:Hide();
	if ( SU.glow ) then SU.glow:Hide(); SU.glow.handle = nil; end
	SU.focus, SU.placedFor = nil, nil;
end

function SU.Focus(frame)
	SU.focus = frame;
	local e;
	for i = 1, table.getn(SU.elements or {}) do if ( SU.elements[i].frame == frame ) then e = SU.elements[i]; end end
	if ( not e and frame and not setupActive ) then
		local steps = SU.Steps();
		for i = 1, table.getn(steps) do if ( steps[i].frame == frame ) then e = steps[i]; end end
		e = e or { frame = frame, title = SU.menuLabel or frame, text = "" };
	end
	local checks, mode = {}, nil;
	if ( e ) then
		SU.panel.title:SetText(SS.T and SS.T(e.title) or e.title);
		mode = setupActive and frame and SU.Mode(frame) or nil;
		SU.panel.text:SetText(SS.T(e.text) .. (mode and mode ~= "enabled" and "\n" .. SS.T("Enable this element to show and move it before changing its settings.") or ""));
		-- a sub-setting shows only while the setting it depends on is on
		local all, shown = SU.ChecksFor(frame), {};
		for i = 1, table.getn(all) do if ( not all[i][4] or all[i][4]() ) then table.insert(shown, all[i]); end end
		checks = shown;
	else
		SU.panel.title:SetText(SS.T("Setup"));
		SU.panel.text:SetText(SS.T("All elements start disabled on a new install. Enable one to show and move it; Default restores the game's original element. Right-click its name for settings. Your Default profiles will appear beside this list."));
	end
	local h = 58 + (SU.panel.text:GetHeight() or 28) + 40;
	for i = 1, math.max(table.getn(checks), table.getn(SU.checks)) do
		if ( not SU.checks[i] ) then SU.checks[i] = SU.Check(SU.panel); end   -- as many rows as the element has settings
		local cb, c = SU.checks[i], checks[i];
		if ( c ) then
			cb.label:SetText(SS.T(c[1]) .. (c.warn and " |cffff9933(!)|r" or "")); cb.get, cb.set, cb.cond = c[2], c[3], c[4];
			cb.warnText = c.warn and SS.T(c.warn) or nil;
			SS.RowKind(cb, c, "right");
			cb:ClearAllPoints();
			-- a setting that only works with another one is indented under it
			local dx = (c[4] and not c.top) and 20 or 0;
			cb.indentX = dx;
			if ( i == 1 ) then cb:SetPoint("TOPLEFT", SU.panel.text, "BOTTOMLEFT", -2 + dx, -4);
			else cb:SetPoint("TOPLEFT", SU.checks[i - 1], "BOTTOMLEFT", dx - (SU.checks[i - 1].indentX or 0), -(SU.checks[i - 1].warnGap or 0)); end
			cb.warn:Hide(); cb.warnGap = 0;
			cb.Refresh(); cb:Show();
			if ( setupActive and mode ~= "enabled" ) then cb:Disable(); cb.label:SetTextColor(0.45, 0.45, 0.45);
			elseif ( c[5] and not c[5]() ) then cb:Disable(); cb.label:SetTextColor(0.45, 0.45, 0.45);
			else cb:Enable(); cb.label:SetTextColor(1, 1, 1); end
			h = h + 24 + cb.warnGap;
		else
			cb.get, cb.set, cb.cond = nil, nil, nil; cb:Hide();
		end
	end
	-- the size & layout tools, under the settings
	do
		local ok = frame and (not setupActive or SU.Mode(frame) == "enabled") and SS.PrepareSizeTools(frame, e and e.title);
		if ( ok and sizeMenu ) then
			sizeMenu:SetParent(SU.panel);
			sizeMenu:SetScale(1);
			sizeMenu:SetFrameLevel((SU.panel:GetFrameLevel() or 1) + 2);
			sizeMenu:ClearAllPoints();
			sizeMenu:SetPoint("TOPLEFT", SU.panel, "TOPLEFT", 2, -(h - 40));
			sizeMenu:Show();
			h = h + (sizeMenu:GetHeight() or 0);               -- Exit/Complete or Done stay under it
		elseif ( sizeMenu ) then
			sizeMenu:Hide();
		end
	end
	if ( SU.panel.done ) then
		SU.panel.exit:Hide(); SU.panel.complete:Hide(); SU.panel.done:Show();   -- the list's own Done ends Edit mode
	end
	SU.panel:SetHeight(h);
	if ( SU.grid ) then SU.grid.Refresh(); end
	SU.RefreshGridButtons();
	local handle = frame and handles[SS.Shown(frame)];
	-- placed when it opens for an element (it can be dragged after that and stays where it was put)
	if ( SU.placedFor ~= (frame or "") or not SU.panel:IsShown() ) then
		SU.placedFor = frame or "";
		SU.panel:ClearAllPoints();
		if ( handle and handle:IsShown() ) then SU.panel:SetPoint("TOP", handle, "BOTTOM", 0, -14);
		else SU.panel:SetPoint("TOP", UIParent, "TOP", 0, -110); end
		SS.Safe(SS.KeepMenuOnScreen);
	end
	SU.panel:Show();
	SU.glow.handle = handle;
	if ( handle ) then
		SU.glow:ClearAllPoints();
		SU.glow:SetPoint("TOPLEFT", handle, "TOPLEFT", -6, 6);
		SU.glow:SetPoint("BOTTOMRIGHT", handle, "BOTTOMRIGHT", 6, -6);
		SU.glow:Show();
	else
		SU.glow:Hide();
	end
	if ( setupActive ) then SU.RefreshBar(); end
end

-- a menu under an element near the screen's bottom would run off it: it goes above the element then, or as high as fits
function SS.KeepMenuOnScreen()
	local p = SU.panel;
	local b, t = p:GetBottom(), p:GetTop();
	if ( not b or not t ) then return; end
	if ( b >= 0 ) then return; end
	local handle = SU.glow and SU.glow.handle;
	local h = t - b;
	p:ClearAllPoints();
	if ( handle and handle:GetTop() and handle:GetTop() + 14 + h <= UIParent:GetHeight() ) then
		p:SetPoint("BOTTOM", handle, "TOP", 0, 14);
	else
		p:SetPoint("TOP", UIParent, "TOP", 0, -10);
	end
end

-- rebuilds the setup's top bar after an element was added or removed from it, keeping the open questions
function SU.Rebuild()
	if ( not setupActive ) then return; end
	local f = SU.focus;
	SS.Safe(SU.Begin);
	SU.batching, SU.restoring, SU.cascading = false, false, false;   -- never left stuck by a failure part-way
	for i = 1, table.getn(SU.elements or {}) do if ( f and SU.elements[i].frame == f ) then SS.Safe(SU.Focus, f); end end
end

-- the new-school design for the player and target frames (the same switch as the sub-option under Mirror target)
function SS.RebuildSetup()
	if ( SU.Rebuild ) then SU.Rebuild(); end
end

-- A look change is one element changing its frame: the frame now shown takes the old one's place (centred on it; the
-- party by its top-left corner) and its hidden/shown state, so nothing set before is lost.
function SS.CarryPlace(el, fromName, toName)
	local from, to = getglobal(fromName), getglobal(toName);
	if ( not from or not to ) then return; end
	local l, r, b, t = RootBounds(from);
	if ( l and r and b and t ) then
		local factor = RootFactor(to);
		local w, h = (to:GetWidth() or 0) * factor, (to:GetHeight() or 0) * factor;
		SS.UserPlace(to);
		if ( el == "PartyMemberFrame1" ) then SetRootPosition(to, l, t - h);
		else SetRootPosition(to, (l + r) / 2 - w / 2, (b + t) / 2 - h / 2); end
		SS.Safe(SS.SavePosition, toName, to);
	end
	local muted = SS.DB().muted[fromName] and true or false;
	if ( (SS.DB().muted[toName] and true or false) ~= muted ) then
		SS.DB().muted[toName] = muted;
		SS.Safe(ApplyFeatureMute, toName);
	end
end

-- runs a change that can swap the frame showing the player, the target or the party, and brings everything along
function SS.ChangeLooks(change)
	local els = { "PlayerFrame", "TargetFrame", "PartyMemberFrame1" };
	local before = {};
	for i = 1, 3 do before[els[i]] = SS.Shown(els[i]); end
	change();
	for i = 1, 3 do
		local el = els[i];
		local old, new = before[el], SS.Shown(el);
		if ( old ~= new ) then
			SS.Safe(SS.CarryPlace, el, old, new);
			if ( setupActive and SU.on and SU.on[el] ) then
				local of = getglobal(old);
				if ( of ) then SU.Save(of); of:SetAlpha(0); end
				if ( handles[old] ) then handles[old]:Hide(); end
			end
		end
	end
	SS.Safe(SS.ApplyNewFrames);
	SS.Safe(SS.UpdatePartyLines);
	SS.Safe(SS.LayoutPartySelf, true);
	if ( setupActive and SU.on ) then
		for i = 1, 3 do if ( SU.on[els[i]] ) then SU.SetOn(els[i], true, SU.titles and SU.titles[els[i]]); end end
	end
	if ( SS.DB().mirrorTarget ) then SS.Safe(SS.MirrorTarget); end
	if ( SS.DB().unlocked ) then SS.Safe(SS.SetUnlocked, true, true); end
	SS.Safe(PlaceAll);
	if ( setupActive and SU.focus ) then SU.Focus(SU.focus); end
end

-- a frame's own look: the player ("classic" or "new"), the target ("classic" or "new"), the party ("classic" or "thin")
function SS.SetLook(el, look)
	SS.ChangeLooks(function()
		if ( el == "PlayerFrame" ) then SS.DB().playerLook = look == "new" and "new" or "classic";
		elseif ( el == "TargetFrame" ) then SS.DB().targetLook = look == "new" and "new" or "classic";
		elseif ( el == "PartyMemberFrame1" ) then SS.DB().partyLook = look == "thin" and "thin" or "classic"; end
	end);
	if ( el == "PartyMemberFrame1" ) then SS.Safe(ApplyMovableOrientation, "PartyMemberFrame1"); SU.UpdateDemo(); end
end

-- Where the party sits: anywhere ("free"), or held just under or above the player frame. Holding it there takes you
-- out of the party frames (the newest choice wins).
function SS.PartyPosition()
	local d = SS.DB();
	if ( not d.partyLocked ) then return "free"; end
	return d.partyLockAbove and "above" or "below";
end
function SS.SetPartyPosition(v)
	local d = SS.DB();
	if ( v ~= "free" and d.partyIncludesSelf ) then SS.SetPartySelf(false); end
	d.partyLocked = v ~= "free";
	d.partyLockAbove = v == "above";
	if ( d.partyLocked ) then SS.MakeMovable("PartyMemberFrame1", "they sit by the player frame"); end
	SS.Safe(PlaceAll);
	SU.UpdateDemo();
end

-- Settings that cannot both be on: the one chosen last wins and the other is turned off (it can be turned back on).
--   "self"    you join the party frames: your own player frame goes off, since your card is in the party now. The
--             target frame stays on its own: Mirror Target, which needs the player frame, goes off.
--   "mirror", "combine", "player" (the player frame turned on from its button): you leave the party frames and your
--             player frame comes back; mirroring also brings back a hidden target frame
function SS.ClaimTarget(by)
	local d = SS.DB();
	if ( by == "self" ) then
		if ( d.partyLocked ) then d.partyLocked = false; SS.Notice("The party frames are free again: you are in them now."); end
		if ( d.mirrorTarget ) then SS.SetMirrorTarget(false); SS.Notice("Mirror Target turned off: the target frame stands on its own now."); end
		-- The player is represented inside the party block now; do not let the next setup
		-- rebuild reactivate the standalone player frame from an earlier Mirror Target choice.
		if ( d.elementModes ) then d.elementModes.PlayerFrame = "default"; end
		if ( d.enabledElements ) then d.enabledElements.PlayerFrame = nil; end
		if ( SU.on ) then SU.on.PlayerFrame = nil; end
		if ( handles.PlayerFrame ) then handles.PlayerFrame:Hide(); end
		SS.Notice("The player frame turned off: you are in the party frames now.");
		SS.Safe(SS.PlayerFrameHidden, true);
		return;
	end
	if ( d.partyIncludesSelf ) then
		d.partyIncludesSelf = false;
		SS.Notice("Add yourself to party turned off: the player frame is back.");
		SS.Safe(SS.PlayerFrameHidden, false);
		SS.Safe(ApplyMovableOrientation, "PartyMemberFrame1");
	end
	if ( by == "mirror" and d.hideTarget ) then d.hideTarget = false; SS.Safe(SS.TargetFrameHidden, false); end
end

-- your own player frame (classic or new-school) is hidden while you are in the party frames
function SS.PlayerFrameHidden(on)
	if ( PlayerFrame ) then
		if ( not SS.playerShow ) then SS.playerShow = PlayerFrame.Show; end
		if ( on ) then
			PlayerFrame.Show = function() end;
			PlayerFrame:Hide();
		else
			PlayerFrame.Show = SS.playerShow;
			PlayerFrame:Show();
		end
	end
	local card = getglobal("SlimSuitePlayerCard");
	if ( card ) then SS.Safe(SS.RefreshCard, card); end
end

-- You in the party frames: your own card joins the end of the party column or row and takes your player frame's
-- place, so the player frame is turned off. Unticked, the player frame comes back.
function SS.SetPartySelf(on)
	local was = SS.DB().partyIncludesSelf and true or false;
	SS.ChangeLooks(function()
		SS.DB().partyIncludesSelf = on and true or false;
		if ( on ) then SS.ClaimTarget("self");
		elseif ( was ) then
			SS.Safe(SS.PlayerFrameHidden, false);
			SS.Notice("The player frame is back: you left the party frames.");
			-- in the setup the player frame's element comes back on with it
			if ( setupActive and SU.on and not SU.on.PlayerFrame ) then SU.SetMode("PlayerFrame", "enabled", SU.titles and SU.titles.PlayerFrame or "Unit frame"); end
		end
	end);
	-- Choosing to join the party frames also turns that frame on in the UI setup; otherwise the option
	-- would hide the player plate without giving the user a party-frame handle to place.
	if ( on and setupActive and SU.on and not SU.on.PartyMemberFrame1 ) then
		SU.SetMode("PartyMemberFrame1", "enabled", SU.titles and SU.titles.PartyMemberFrame1 or "Party frames");
	end
	SS.Safe(ApplyMovableOrientation, "PartyMemberFrame1");
	SU.Rebuild();
	SU.UpdateDemo();
end

-- combined, the player and target are one element in the setup, and the player frame takes the target's look
function SS.SetCombineTarget(on)
	-- Kept as an internal compatibility entry point; the UI now has one combined Mirror Target switch.
	SS.SetMirrorTarget(on);
end

function SS.SetLocalClockOn(on)
	local wanted = on and "enabled" or "default";
	if ( setupActive and SU.Mode and SU.SetMode and SU.Mode("SlimSuiteLocalClockFrame") ~= wanted ) then
		SU.SetMode("SlimSuiteLocalClockFrame", wanted, SU.titles and SU.titles.SlimSuiteLocalClockFrame or "Local clock");
	end
	SS.DB().replaceLocalClock = on and true or false;
	SS.Safe(SlimSuiteWorld.UpdateLocalClock);
	SU.Rebuild();
end

function SS.SetClockDetached(on)
	SS.DB().clockDetached = on and true or false;
	if ( SlimSuiteWorld and SlimSuiteWorld.SetClockDetached ) then SS.Safe(SlimSuiteWorld.SetClockDetached, SS.DB().clockDetached); end
	SU.Rebuild();
end

-- a bar button: first click turns the element on and opens its questions; clicking the open one turns it off
function SU.Click(frame)
	if ( frame == "SlimSuiteEditGrid" ) then SU.SetGridSetting(not (SU.on and SU.on[frame])); return; end
	if ( SU.focus == frame ) then SU.Focus(nil); else SU.Focus(frame); end
	SS.RefreshToggles();
end

-- the setup leaves Blizzard's interface visible until an element is explicitly enabled or disabled
function SU.PlaceProfiles()
	local panel = SU.bar and SU.bar.profilePanel;
	if ( not panel ) then return; end
	local left = SU.bar:GetLeft() or 0;
	local width = SU.bar:GetWidth() or 0;
	local profileWidth = panel:GetWidth() or 0;
	panel:ClearAllPoints();
	if ( left + width + profileWidth <= (UIParent:GetWidth() or 0) ) then
		panel:SetPoint("TOPLEFT", SU.bar, "TOPRIGHT", -2, 0);
	elseif ( left >= profileWidth ) then
		panel:SetPoint("TOPRIGHT", SU.bar, "TOPLEFT", 2, 0);
	else
		panel:SetPoint("TOPLEFT", SU.bar, "BOTTOMLEFT", 0, 2);
	end
end

function SU.Begin()
	if ( not SU.panel ) then SU.Build(); end
	SU.Unreveal();
	for name in pairs(SU.KEEP_VISIBLE) do                        -- undo an earlier sweep of these, if any
		local c = getglobal(name);
		if ( c and c.SetAlpha and c.GetAlpha and c:GetAlpha() == 0 ) then c:SetAlpha(1); end
	end
	editOnly = "SlimSuiteSetupNothing";                  -- no handles until an element is turned on
	SU.on = {};
	SS.SetUnlocked(true, true);
	SU.elements = {};
	local steps = SU.Steps();
	for i = 1, table.getn(steps) do if ( steps[i].frame and steps[i].frame ~= "SlimSuiteEditGrid" ) then table.insert(SU.elements, steps[i]); end end
	local hasMeter = false;
	for i = 1, table.getn(SU.elements) do if ( SU.elements[i].frame == "SlimSuiteMeterFrame" ) then hasMeter = true; end end
	if ( not hasMeter ) then table.insert(SU.elements, { frame = "SlimSuiteMeterFrame", title = "Damage meter", text = "The damage meter. Its corner grip resizes it any time." }); end
	SU.titles = {};
	for i = 1, table.getn(SU.elements) do SU.titles[SU.elements[i].frame] = SU.elements[i].title; end
	local modes = SS.DB().elementModes or {};
	SS.DB().elementModes = modes;
	local saved = SS.DB().enabledElements or {};
	local d = SS.DB();
	local initializeDisabled = (tonumber(d.firstSetupDefaultsVersion) or 0) < 1 and not d.setupDone and (SS.firstRunSetupPending or not SS.HasPriorUISetup(d));
	-- Rebuilding the editor restores visibility; only an explicit Default click resets settings.
	SU.restoring = not initializeDisabled;
	SU.batching = true;      -- one bar and demo refresh at the end, not one per element
	SS.Safe(SU.SetGridSetting, SS.DB().showEditGrid and true or false);
	-- A clean profile starts with every element, including Blizzard's native version, explicitly Disabled.
	-- Profiles that already chose modes keep those choices and their existing migration data.
	for i = 1, table.getn(SU.elements) do
		local f = SU.elements[i].frame;
		if ( initializeDisabled ) then modes[f] = "disabled"; end
		local mode = SU.Mode(f);
		if ( modes[f] == nil and saved[f] ) then modes[f] = "enabled"; mode = "enabled"; end
		if ( f == "SlimSuiteMeterFrame" and SS.DB().moveMeter ) then mode = modes[f] or "enabled"; end
		if ( f == "PlayerFrame" and SS.DB().partyIncludesSelf ) then mode = modes[f] or "default"; end
		if ( f == "TargetFrame" and SS.DB().hideTarget ) then mode = modes[f] or "disabled"; end
		if ( mode == "enabled" or mode == "disabled" ) then SS.Safe(SU.SetMode, f, mode, SU.titles[f]);
		else SS.Safe(SU.SetMode, f, "default", SU.titles[f]); end
	end
	SU.restoring = false;
	if ( initializeDisabled ) then d.firstSetupDefaultsVersion = 1; end
	SU.batching = false;
	-- the bar: one button per element
	SU.barButtons = SU.barButtons or {};
	-- a vertical list from the top left corner: one element per line, a new column when the screen runs out of height
	local wanted, col, idx, maxIdx = {}, 0, 0, 0;
	local maxH = (UIParent:GetHeight() or 768) - 80;
	local COLUMN, LINE, TOP, BOTTOM = 310, 19, 26, 27;   -- three explicit states beside a plain name; actions stay on the bottom edge
	maxH = maxH - TOP - BOTTOM;
	for i = 1, table.getn(SU.elements) do
		local e = SU.elements[i];
		local name = e.frame;
		wanted[name] = true;
		local b = SU.barButtons[name];
		if ( not b ) then
			b = CreateFrame("Frame", nil, SU.bar);
			SU.barButtons[name] = b;
			b:SetWidth(COLUMN); b:SetHeight(LINE);
			b.nameHit = CreateFrame("Frame", nil, b); b.nameHit:SetWidth(102); b.nameHit:SetHeight(17); b.nameHit:SetPoint("LEFT", b, "LEFT", 0, 0); b.nameHit:EnableMouse(true);
			b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
			b.label:SetPoint("LEFT", b, "LEFT", 0, 0); b.label:SetWidth(102); b.label:SetJustifyH("LEFT");
			b.nameHit:SetScript("OnMouseUp", function()
				if ( arg1 ~= "RightButton" ) then return; end
				if ( setupActive ) then SU.Focus(this.ownerFrame); else SS.OpenSizeMenu(this.ownerFrame, this.elementTitle); end
			end);
			b.nameHit:SetScript("OnEnter", function()
				if ( not GameTooltip ) then return; end
				GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
				GameTooltip:AddLine(this.elementTitle or "", 1, 0.82, 0.2);
				GameTooltip:AddLine(SS.T("Right-click the name to open its settings."), 0.8, 0.8, 0.8, 1);
				if ( this.parentTitle ) then GameTooltip:AddLine("Connected to: " .. this.parentTitle, 0.7, 0.85, 1); end
				GameTooltip:Show();
			end);
			b.nameHit:SetScript("OnLeave", function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
			b.states = {};
			b.stateLabels = { "Enabled", "Disabled", "Default" };
			local stateModes = { "enabled", "disabled", "default" };
			for j = 1, 3 do
				local value, label = stateModes[j], b.stateLabels[j];
				local state = K.Button(b, SS.T(label), 64, function()
					SU.SetMode(this.ownerFrame, this.modeValue, SU.titles and SU.titles[this.ownerFrame]);
				end);
				state:SetHeight(17); state.ownerFrame = name; state.modeValue = value;
				state:SetPoint("LEFT", b, "LEFT", 105 + ((j - 1) * 67), 0);
				state:SetScript("OnEnter", function()
					if ( not GameTooltip ) then return; end
					GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
					if ( this.modeValue == "default" ) then GameTooltip:AddLine(SS.T("Restore Blizzard / Aethus default. Hide Slim Suite's replacement and turn the game's element on."), 1, 0.82, 0.2);
					elseif ( this.modeValue == "enabled" ) then GameTooltip:AddLine(SS.T("Show and move Slim Suite's replacement."), 0.4, 1, 0.4);
					else GameTooltip:AddLine(SS.T("Hide both the game element and Slim Suite's replacement."), 1, 0.45, 0.35); end
					GameTooltip:Show();
				end);
				state:SetScript("OnLeave", function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
				b.states[j] = state;
			end
		end
		b.nameHit.ownerFrame = name; b.nameHit.elementTitle = e.title; b.label:SetText(SS.T(e.title));
		for j = 1, table.getn(b.states) do b.states[j].ownerFrame = name; b.states[j]:SetText(SS.T(b.stateLabels[j])); end
		-- two columns, half the elements in each (a third column only if the screen is too short for two)
		local perCol = math.ceil(table.getn(SU.elements) / 2);
		if ( idx > 0 and (idx >= perCol or 6 + (idx + 1) * LINE > maxH) ) then col = col + 1; idx = 0; end
		b:ClearAllPoints(); b:SetPoint("TOPLEFT", SU.bar, "TOPLEFT", 6 + col * COLUMN, -6 - TOP - idx * LINE); b:Show();
		for j = 1, table.getn(b.states) do b.states[j]:Show(); end
		if ( idx > maxIdx ) then maxIdx = idx; end
		idx = idx + 1;
	end
	for name, b in pairs(SU.barButtons) do if ( not wanted[name] ) then b:Hide(); for j = 1, table.getn(b.states or {}) do b.states[j]:Hide(); end end end
	SU.bar:SetWidth(6 + (col + 1) * COLUMN);
	SU.bar:SetHeight((maxIdx + 1) * LINE + 12 + TOP + BOTTOM);
	SU.PlaceProfiles();
	if ( SU.bar.resetAll ) then
		SU.bar.resetAll:ClearAllPoints(); SU.bar.resetAll:SetPoint("BOTTOMRIGHT", SU.bar, "BOTTOMRIGHT", -104, 7);
		SU.bar.done:ClearAllPoints(); SU.bar.done:SetPoint("BOTTOMRIGHT", SU.bar, "BOTTOMRIGHT", -8, 7);
	end
	SU.bar:Show();
	SU.Focus(nil);
	SU.RefreshBar();
	SU.UpdateDemo();
	SU.RefreshDemoButtons();
end

function SU.RefreshDemoButtons()
	if ( not SU.bar or not SU.bar.demoOn ) then return; end
	local count = 0;
	for i = 1, table.getn(SU.elements or {}) do
		local frame = SU.elements[i].frame;
		if ( SU.Mode(frame) == "enabled" ) then
			count = count + 1;
		end
	end
	if ( SS.demoRunning and SS.demoElements ) then
		local stillEnabled = 0;
		for frame in pairs(SS.demoElements) do
			if ( SU.Mode(frame) ~= "enabled" ) then SS.demoElements[frame] = nil; else stillEnabled = stillEnabled + 1; end
		end
		if ( stillEnabled == 0 ) then SS.StopDemoMode(); return; end
	end
	if ( SU.bar.demoLabel ) then SU.bar.demoLabel:SetText(SS.T("Demo")); end
	if ( count == 0 and not SS.demoRunning ) then SU.bar.demoOn:Disable(); else SU.bar.demoOn:Enable(); end
	if ( SS.demoRunning ) then SU.bar.demoOn:LockHighlight(); SU.bar.demoOff:UnlockHighlight();
	else SU.bar.demoOff:LockHighlight(); SU.bar.demoOn:UnlockHighlight(); end
	local box = getglobal("SlimSuiteDemoBox");
	if ( box and box.on ) then if ( count == 0 ) then box.on:Disable(); else box.on:Enable(); end end
end
function SU.Build()
	SU.panel = CreateFrame("Frame", "SlimSuiteSetupPanel", UIParent);
	SU.panel:SetWidth(420); SU.panel:SetHeight(150);
	SU.panel:SetFrameStrata("DIALOG");
	SU.panel:SetMovable(true); SU.panel:EnableMouse(true);
	if ( SU.panel.SetClampedToScreen ) then SU.panel:SetClampedToScreen(true); end
	SU.panel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	SU.panel:SetBackdropColor(0.04, 0.035, 0.07, 0.97);
	SU.panel:SetBackdropBorderColor(0.85, 0.65, 0.2, 1);
	SU.panel:RegisterForDrag("LeftButton");
	SU.panel:SetScript("OnDragStart", function() this:StartMoving(); end);
	SU.panel:SetScript("OnDragStop", function() this:StopMovingOrSizing(); end);
	SU.panel.title = SU.panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	SU.panel.title:SetPoint("TOPLEFT", SU.panel, "TOPLEFT", 12, -10);
	SU.panel.text = SU.panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	SU.panel.text:SetPoint("TOPLEFT", SU.panel, "TOPLEFT", 12, -58);
	SU.panel.text:SetWidth(396); SU.panel.text:SetJustifyH("LEFT"); SU.panel.text:SetJustifyV("TOP");
	-- the grid settings, top right: grid on/off and its size; the red centre lines; frames snapping together
	local function Tick(x, y, label, get, set)
		local cb = CreateFrame("CheckButton", nil, SU.bar, "UICheckButtonTemplate");
		cb:SetWidth(20); cb:SetHeight(20); cb:SetPoint("TOPLEFT", SU.bar, "TOPLEFT", x, y);
		cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		cb.label:SetPoint("LEFT", cb, "RIGHT", 0, 1); cb.label:SetText(SS.T(label));
		cb.Refresh = function() cb:SetChecked(get() and 1 or nil); end;
		cb.get = get;
		SS.TrackToggle(cb);
		cb:SetScript("OnClick", function() SS.FlipToggle(get, set); SS.RefreshToggles(); end);
		return cb;
	end
	-- the grid, top right of every setup panel: on or off, and its size
	-- the bar down the left of the screen: the grid on top, one toggle per element, Done at the bottom
	SU.bar = CreateFrame("Frame", "SlimSuiteSetupBar", UIParent);
	SU.grid = Tick(8, -8, "Grid", function() return SS.DB().showEditGrid; end, function(v) SU.SetGridSetting(v); end);
	SU.sizes = {};
	local sizes = { 16, 32, 64, 128 };
	for i = 1, 4 do
		local pixels = sizes[i];
		local b = K.Button(SU.bar, tostring(pixels), 34, function()
			SS.DB().gridDivisions = pixels; SU.SetGridSetting(SS.DB().showEditGrid and true or false); SU.RefreshGridButtons();
		end);
		b:SetHeight(18); b:SetPoint("TOPLEFT", SU.bar, "TOPLEFT", 64 + (i - 1) * 36, -9);
		SU.sizes[i] = b;
	end
	-- the element's own settings (more rows are made when an element needs them)
	SU.checks = {};
	for i = 1, 12 do SU.checks[i] = SU.Check(SU.panel); end
	SU.panel.exit = K.Button(SU.panel, "Exit", 90, function() SS.SetupEnd(false); end);
	SU.panel.exit:SetPoint("BOTTOMLEFT", SU.panel, "BOTTOMLEFT", 10, 8); SU.panel.exit:Hide();
	SU.panel.complete = K.Button(SU.panel, "Complete", 100, function() SS.SetupEnd(true); end);
	SU.panel.complete:SetPoint("BOTTOMRIGHT", SU.panel, "BOTTOMRIGHT", -10, 8);
	-- the same panel is every element's right-click menu outside the setup: Done closes it
	SU.panel.done = K.Button(SU.panel, "Done", 90, function()
		if ( setupActive ) then
			SU.panel:Hide(); if ( SU.glow ) then SU.glow:Hide(); SU.glow.handle = nil; end
			SU.focus, SU.placedFor = nil, nil;
		else SS.HideElementMenu(); end
	end);
	SU.panel.done:SetPoint("BOTTOMRIGHT", SU.panel, "BOTTOMRIGHT", -10, 8);
	SU.panel.done:Hide();
	SU.panel:Hide();
	-- Demo Mode beside the grid: On and Off, the one that is in effect lit
	SU.bar.demoLabel = SU.bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	SU.bar.demoLabel:SetPoint("TOPLEFT", SU.bar, "TOPLEFT", 218, -12); SU.bar.demoLabel:SetText(SS.T("Demo"));
	SU.bar.demoOn = K.Button(SU.bar, "On", 36, function() SS.StartDemoMode(); SU.RefreshDemoButtons(); end);
	SU.bar.demoOn:SetHeight(18); SU.bar.demoOn:SetPoint("TOPLEFT", SU.bar, "TOPLEFT", 255, -9);
	SU.bar.demoOff = K.Button(SU.bar, "Off", 36, function() SS.StopDemoMode(); SU.RefreshDemoButtons(); end);
	SU.bar.demoOff:SetHeight(18); SU.bar.demoOff:SetPoint("TOPLEFT", SU.bar, "TOPLEFT", 296, -9);
	SU.bar.demoHint = SU.bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	SU.bar.demoHint:SetPoint("LEFT", SU.bar.demoOff, "RIGHT", 7, 0); SU.bar.demoHint:SetWidth(280); SU.bar.demoHint:SetHeight(24);
	SU.bar.demoHint:SetJustifyH("LEFT"); SU.bar.demoHint:SetText(SS.T("(Right click element to change settings)"));
	SU.bar.done = K.Button(SU.bar, "Done", 90, function() SS.ConfirmSetupDone(); end);
	SU.bar.done:SetPoint("BOTTOMRIGHT", SU.bar, "BOTTOMRIGHT", -8, 7);
	SU.bar.resetAll = K.Button(SU.bar, "Reset All", 90, function() SS.ResetUI(); end);
	SU.bar.resetAll:SetPoint("RIGHT", SU.bar.done, "LEFT", -6, 0);
	SU.bar:SetFrameStrata("DIALOG");
	SU.bar:SetHeight(52);
	SU.bar:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	SU.bar:SetBackdropColor(0.04, 0.035, 0.07, 0.97);
	SU.bar:SetBackdropBorderColor(0.85, 0.65, 0.2, 1);
	-- A compact sidecar for the starter profiles the author will supply later. It moves with the setup list.
	SU.bar.profilePanel = CreateFrame("Frame", "SlimSuiteDefaultProfiles", SU.bar);
	SU.bar.profilePanel:SetWidth(184); SU.bar.profilePanel:SetHeight(136);
	SU.bar.profilePanel:SetFrameStrata("DIALOG");
	SU.bar.profilePanel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	SU.bar.profilePanel:SetBackdropColor(0.04, 0.035, 0.07, 0.97);
	SU.bar.profilePanel:SetBackdropBorderColor(0.85, 0.65, 0.2, 1);
	SU.bar.profilePanel.title = SU.bar.profilePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	SU.bar.profilePanel.title:SetPoint("TOPLEFT", SU.bar.profilePanel, "TOPLEFT", 10, -10);
	SU.bar.profilePanel.title:SetText(SS.T("Default profiles"));
	SU.bar.profilePanel.note = SU.bar.profilePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	SU.bar.profilePanel.note:SetPoint("TOPLEFT", SU.bar.profilePanel, "TOPLEFT", 10, -34);
	SU.bar.profilePanel.note:SetWidth(160); SU.bar.profilePanel.note:SetJustifyH("LEFT"); SU.bar.profilePanel.note:SetText(SS.T("Read-only presets. Applying one creates your own editable copy."));
	SU.bar.profilePanel.buttons = {};
	SU.bar.profilePanel.Refresh = function()
		local names = {};
		for name, layout in pairs(SS.DEFAULT_PROFILES or {}) do if ( type(name) == "string" and type(layout) == "table" ) then table.insert(names, name); end end
		table.sort(names);
		for i = 1, math.max(table.getn(names), table.getn(SU.bar.profilePanel.buttons)) do
			local button = SU.bar.profilePanel.buttons[i];
			if ( not button and names[i] and K and K.Button ) then
				button = K.Button(SU.bar.profilePanel, names[i], 164, function() SS.ApplyDefaultProfile(this.profileName); end);
				SU.bar.profilePanel.buttons[i] = button;
			end
			if ( button ) then
				if ( names[i] ) then button.profileName = names[i]; button:SetText(names[i]); button:ClearAllPoints(); button:SetPoint("TOPLEFT", SU.bar.profilePanel, "TOPLEFT", 10, -58 - ((i - 1) * 22)); button:Show();
				else button:Hide(); end
			end
		end
		if ( table.getn(names) == 0 ) then
			SU.bar.profilePanel.note:SetText(SS.T("Your read-only presets will appear here. Applying one creates your editable copy."));
		else SU.bar.profilePanel.note:SetText(SS.T("Applying a read-only preset creates your editable copy.")); end
	end;
	SU.bar.profilePanel.Refresh();
	SU.bar.profilePanel:SetPoint("TOPLEFT", SU.bar, "TOPRIGHT", -2, 0);
	-- the list can be dragged by its background; it stays where it was put
	SU.bar:SetMovable(true); SU.bar:EnableMouse(true); SU.bar:RegisterForDrag("LeftButton");
	if ( SU.bar.SetClampedToScreen ) then SU.bar:SetClampedToScreen(true); end
	SU.bar:SetScript("OnDragStart", function() this:StartMoving(); end);
	SU.bar:SetScript("OnDragStop", function()
		this:StopMovingOrSizing();
		local l, t = this:GetLeft(), this:GetTop();
		if ( l and t ) then SS.DB().elementListPlace = { x = l, y = t - UIParent:GetHeight() }; end
		SU.PlaceProfiles();
	end);
	local saved = SS.DB().elementListPlace;
	if ( type(saved) == "table" and saved.x and saved.y ) then SU.bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", saved.x, saved.y);
	else SU.bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 6, -6); end
	SU.bar:Hide();
	-- the gold outline around the element being set up
	SU.glow = CreateFrame("Frame", "SlimSuiteSetupGlow", UIParent);
	SU.glow:SetFrameStrata("DIALOG");
	SU.glow:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 });
	SU.glow:SetBackdropBorderColor(1, 0.82, 0.2, 1);
	SU.glow:EnableMouse(false);
	SS.Every("glow", 0, function()
		local h = SU.glow.handle;
		if ( not h or not h:IsShown() ) then SU.glow:SetAlpha(0); return; end
		SU.glow:SetAlpha(0.45 + 0.55 * math.abs(math.sin(GetTime() * 3)));
	end, SU.glow);
	SU.glow:Hide();
end

-- The setup hides the whole UI while it runs. If anything in it fails, the UI is brought back at once and the setup
-- closes, so a failure can never leave the screen empty until a /reload (the error is still logged and said in chat).
function SS.SetupRescue(err)
	SS.Report(err);
	pcall(SU.Unreveal);
	pcall(SS.SetupHide);
	setupActive = false;
	editOnly = nil;
	pcall(SS.SetUnlocked, false, true);
	pcall(PlaceAll);
	K.Print(NAME, "the setup hit a problem and closed; your UI is back as it was. /slim errors shows what happened.");
end
function SS.StartSetup(fromStart)
	setupActive = true;
	local ok, err = pcall(SU.Begin);
	if ( not ok ) then SS.SetupRescue(err); end
end

-- what each element brings along: the frames that move with it
SU.COMPANIONS = SS.ELEMENT_COMPANIONS;

-- an element turned on in the setup, or a frame that comes with one (the jewelry row with the build spells)
function SS.SetupShows(name)
	if ( not setupActive or not SU.on or not name ) then return false; end
	if ( SU.on[name] or SU.on[SS.Element(name)] ) then return true; end
	for parent in pairs(SU.on) do
		local list = SU.CompanionsOf(parent);
		for i = 1, table.getn(list) do if ( list[i] == name ) then return true; end end
	end
	return false;
end

-- the frames that come with an element in the setup (the party's depend on its look)
function SU.CompanionsOf(frame)
	if ( frame == "ChatFrame1" and SS.ChatCompanions ) then return SS.ChatCompanions(); end
	if ( frame == "PartyMemberFrame1" ) then
		if ( SS.Look("PartyMemberFrame1") == "thin" ) then return {}; end   -- the thin lines are one frame, you included
		return { "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4", "SlimSuitePartySelfFrame" };
	end
	return SU.COMPANIONS[frame] or {};
end

-- restore every frame's alpha as it was before the setup
function SU.Unreveal()
	-- the minimap is faded while the setup runs; a faded value saved by mistake must never be put back
	if ( SU.saved ) then
		for _, m in ipairs({ Minimap, MinimapCluster }) do
			if ( m and SU.saved[m] ~= nil and (type(SU.saved[m]) ~= "number" or SU.saved[m] <= 0) ) then SU.saved[m] = 1; end
		end
	end
	for f, a in pairs(SU.saved or {}) do if ( f and f.SetAlpha ) then f:SetAlpha(a); end end
	for f in pairs(SU.shownBefore or {}) do if ( f and f.Show ) then f:Show(); end end
	SU.saved = nil; SU.shownBefore = nil;
	SS.Safe(SS.ApplyNewFrames);
end

function SS.SetupHide()
	setupActive = false;
	SU.on = {};                                            -- nothing is "on in the setup" outside it
	SU.Unreveal();
	SS.Safe(SS.ApplyElementModes);
	if ( SU.panel ) then SU.panel:Hide(); end
	if ( SU.bar ) then SU.bar:Hide(); end
	SS.Safe(SS.EndPreviewsIfDone);
	SS.Safe(SS.RefreshChatDock);
	SS.Safe(SS.HideNative, "meter", false);
	if ( SS.DB().moveMeter ) then SS.Safe(SS.HideNative, "meter", true); end
	if ( SU.glow ) then SU.glow:Hide(); SU.glow.handle = nil; end
end

-- Exit: the UI stays unlocked for moving. Complete: the UI is locked.
function SS.ConfirmSetupDone()
	if ( not SU.confirmDone ) then
		local f = K.Window("SlimSuiteSetupConfirmation", "Finish setup", 380, 150);
		SU.confirmDone = f;
		f:SetFrameStrata("FULLSCREEN_DIALOG");
		local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
		text:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -38); text:SetWidth(340); text:SetHeight(60);
		text:SetText(SS.T("Have you added everything you want? To add more use /slim setup"));
		local confirm = K.Button(f, "Confirm", 110, function() f:Hide(); SS.SetupEnd(true); end);
		f.confirm = confirm;
		confirm:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 14);
		local back = K.Button(f, "Back", 110, function() f:Hide(); end);
		f.back = back;
		back:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 14);
	end
	SU.confirmDone:Show();
	SU.confirmDone:SetAlpha(1);
end

function SS.SetupEnd(finished)
	if ( SU.confirmDone ) then SU.confirmDone:Hide(); end
	SS.DB().setupDone = true;
	local ok, err = pcall(SS.SetupHide);
	if ( not ok ) then SS.SetupRescue(err); return; end
	editOnly = nil;
	SS.SetUnlocked(false, true);   -- Done (or Exit) leaves Edit mode
end

-- ---------------------------------------------------------------- the settings window

-- Places a settings page's visible rows top to bottom. A sub-setting whose setting is off, and a heading with nothing
-- under it, take no room. Runs again after every change, so sub-settings appear and disappear as they are turned on.
