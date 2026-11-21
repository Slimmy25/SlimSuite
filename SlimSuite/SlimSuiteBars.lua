-- Slim Suite: the buff frame, the action bar and the XP bar: sample buffs, layout, empty buttons and the XP bar's look.
local K, SU, NAME = SS.Kit, SS.SU, SS.NAME;   -- the three names every Slim Suite file uses (SlimSuiteCore.lua)

-- Sample buffs and debuffs: shown on the real buff frame while it is being placed or in Demo Mode, after your own buffs
-- and laid out by the same rules (row or column, growth, padding, size and scale). In Demo Mode each comes and goes.
SS.BUFF_SAMPLES = { "Spell_Holy_WordFortitude", "Spell_Arcane_ArcaneIntellect", "Spell_Nature_RavenForm", "Ability_Warrior_BattleShout",
	"Spell_Shadow_ShadowWordPain", "Spell_Frost_FrostBolt02", "Ability_Hunter_SniperShot", "Ability_Warrior_Sunder" };
SS.demoBuffOn = {};
SS.buffSamples = {};
function SS.BuffSample(i)
	local b = SS.buffSamples[i];
	if ( b ) then return b; end
	b = CreateFrame("Frame", nil, BuffFrame);
	b:SetWidth(32); b:SetHeight(32);
	b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(b);
	b.icon:SetTexture("Interface\\Icons\\" .. SS.BUFF_SAMPLES[i]);
	if ( i > 4 ) then b.icon:SetVertexColor(1, 0.45, 0.45); end   -- the last four are debuffs
	b.time = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	b.time:SetPoint("TOP", b, "BOTTOM", 0, -1); b.time:SetText((i * 3) .. " m");
	b:Hide();
	SS.buffSamples[i] = b;
	return b;
end
function SS.BuffSamples() return SS.buffSamples; end

-- the game's buff buttons: BuffButton0 (1.12) or BuffButton1 onwards
function SS.BuffButtons()
	local list = {};
	for i = 0, (MAX_PLAYER_BUFFS or 32) do
		local button = getglobal("BuffButton" .. i);
		if ( button ) then table.insert(list, { i, button }); end
	end
	return list;
end

function SS.ApplyBuffOrientation()
	if ( not BuffFrame or SS.buffLayoutApplying ) then return; end
	local d=SS.DB();
	local side=d.buffsOnTarget and d.buffsOnTargetSide or d.buffsOnPlayerSide;
	if ( d.partyIncludesSelf and (side=="left" or side=="right") ) then side="above"; end
	local bounded=(d.buffsOnPlayer or d.buffsOnTarget) and (side=="above" or side=="below") and not (d.frameDefault and d.frameDefault.BuffFrame);
	if ( not bounded and SS.LayoutPartyBuffs ) then SS.LayoutPartyBuffs(); end
	local orientation = SS.CurrentOrientation("BuffFrame");
	local attached;
	if ( SS.Pair and SS.DB().buffsOnTarget ) then local _, target = SS.Pair(); attached = target;
	elseif ( SS.Pair and SS.DB().buffsOnPlayer ) then local player = SS.Pair(); attached = player; end
	local buttons = SS.BuffButtons();
	local visible, real, iconW, iconH, durationW, durationH = {}, 0, nil, nil, 0, 0;
	for k = 1, table.getn(buttons) do
		local i, button = buttons[k][1], buttons[k][2];
		if ( not SS.buffButtonOriginalPoints[i] and button.GetNumPoints ) then
			local points = {};
			for p = 1, button:GetNumPoints() do
				local a, relative, relativePoint, x, y = button:GetPoint(p);
				points[p] = { a, relative, relativePoint, x, y };
			end
			SS.buffButtonOriginalPoints[i] = points;
		end
		if ( button:IsShown() ) then
			table.insert(visible, button); real = real + 1;
			iconW = iconW or button:GetWidth(); iconH = iconH or button:GetHeight();
			local duration = getglobal("BuffButton" .. i .. "Duration");
			if ( duration and duration:IsShown() ) then
				durationW = math.max(durationW, (duration.GetStringWidth and duration:GetStringWidth()) or 0);
				durationH = math.max(durationH, (duration.GetHeight and duration:GetHeight()) or 0);
			end
		end
	end
	-- the samples, after your own buffs
	local preview = SS.Previewing("BuffFrame");
	if ( not iconW ) then
		local first = buttons[1] and buttons[1][2];
		iconW, iconH = first and first:GetWidth() or 32, first and first:GetHeight() or 32;
		if ( not iconW or iconW <= 0 ) then iconW, iconH = 32, 32; end
	end
	local samples = {};
	for i = 1, table.getn(SS.BUFF_SAMPLES) do
		local on = preview and (not SS.Demoing("BuffFrame") or SS.demoBuffOn[i]);
		if ( on ) then
			local s = SS.BuffSample(i);
			s:SetWidth(iconW); s:SetHeight(iconH); s:Show();
			durationW = math.max(durationW, s.time:GetStringWidth() or 0);
			durationH = math.max(durationH, s.time:GetHeight() or 12);
			table.insert(samples, s); table.insert(visible, s);
		elseif ( SS.buffSamples[i] ) then
			SS.buffSamples[i]:Hide();
		end
	end
	local saved = SS.DB().sizes.BuffFrame;
	if ( table.getn(visible) == 0 ) then
		-- nothing to lay out; a size set by the player still applies to the frame
		if ( type(saved) == "table" and saved.w and saved.h ) then BuffFrame:SetWidth(saved.w); BuffFrame:SetHeight(saved.h); end
		return;
	end
	SS.buffLayoutApplying = true;
	if ( attached and bounded ) then
		SS.buffLayoutApplying=false; SS.LayoutPartyBuffs(); return;
	end
	if ( (SS.DB().frameDefault and SS.DB().frameDefault.BuffFrame) or (orientation == "horizontal" and not SS.DB().buffCustomLayout) ) then
		-- the game's own layout: its buttons go back where the game puts them
		local prev;
		for k = 1, table.getn(buttons) do
			local i, button = buttons[k][1], buttons[k][2];
			local points = SS.buffButtonOriginalPoints[i];
			if ( points and table.getn(points) > 0 ) then
				button:ClearAllPoints();
				for p = 1, table.getn(points) do
					local a = points[p];
					button:SetPoint(a[1], a[2], a[3], a[4], a[5]);
				end
			end
			if ( button:IsShown() ) then prev = button; end
		end
		-- the samples carry on the game's row, right to left, after your last buff
		for i = 1, table.getn(samples) do
			local s = samples[i];
			s:ClearAllPoints();
			if ( prev ) then s:SetPoint("RIGHT", prev, "LEFT", -5, 0); else s:SetPoint("TOPRIGHT", BuffFrame, "TOPRIGHT", 0, 0); end
			prev = s;
		end
		local base = SS.baseSizes.BuffFrame;
		if ( type(saved) == "table" and saved.w and saved.h ) then BuffFrame:SetWidth(saved.w); BuffFrame:SetHeight(saved.h);
		elseif ( base ) then BuffFrame:SetWidth(base.w); BuffFrame:SetHeight(base.h); end
		SS.buffLayoutApplying = false;
		return;
	end
	-- Treat each icon and its cooldown text as one cell. The text's measured size is used instead of a fixed guessed
	-- gap, so long durations never collide with the next buff.
	local gap, count = 4 + SS.FramePadding("BuffFrame"), table.getn(visible);
	local cellW = math.max(iconW, durationW) + 4;
	local cellH = iconH + durationH + 4;
	local customSize = saved;
	local columns, rows;
	if ( orientation == "vertical" ) then
		local maxRows = count;
		if ( type(customSize) == "table" and customSize.h and customSize.h > 0 ) then
			maxRows = math.max(1, math.floor((customSize.h + gap) / (cellH + gap)));
		end
		-- When attached to a unit frame, a column stays inside that frame's height; additional
		-- columns grow away from the selected edge instead of spilling over the unit frame itself.
		if ( attached and attached.GetHeight ) then
			local limit = math.max(1, math.floor((attached:GetHeight() + gap) / (cellH + gap)));
			maxRows = math.min(maxRows, limit);
		end
		rows = math.min(count, maxRows);
		columns = math.ceil(count / rows);
	else
		local base = SS.baseSizes.BuffFrame;
		local maxWidth = type(customSize) == "table" and customSize.w or (base and base.w) or (iconW * 10);
		-- Attached horizontal rows stay within the unit frame's width and wrap outward from it.
		if ( attached and attached.GetWidth ) then maxWidth = math.min(maxWidth, attached:GetWidth()); end
		columns = math.max(1, math.min(count, math.floor((maxWidth + gap) / (cellW + gap))));
		rows = math.ceil(count / columns);
	end
	local direction = SS.BuffGrowthDirection();
	if ( attached ) then
		local side = SS.DB().buffsOnTarget and SS.DB().buffsOnTargetSide or SS.DB().buffsOnPlayerSide;
		if ( side == "above" ) then direction = "up"; end
	end
	local verticalOffset = direction == "up" and 1 or -1;
	for i = 1, count do
		local column, row;
		if ( orientation == "vertical" ) then
			column = math.floor((i - 1) / rows);
			row = math.mod(i - 1, rows);
		else
			column = math.mod(i - 1, columns);
			row = math.floor((i - 1) / columns);
		end
		local button = visible[i];
		button:ClearAllPoints();
		-- Keep the first icon at the anchor. New rows/vertical icons extend in the selected direction.
		button:SetPoint("BOTTOMLEFT", BuffFrame, "BOTTOMLEFT",
			column * (cellW + gap) + (cellW - iconW) / 2,
			verticalOffset * row * (cellH + gap));
	end
	local requiredWidth = columns * (cellW + gap) - gap;
	local requiredHeight = rows * (cellH + gap) - gap;
	-- a size set by the player is the size (1.12 does not clip, so icons past its edge still draw); otherwise it fits them
	BuffFrame:SetWidth(type(customSize) == "table" and customSize.w or requiredWidth);
	BuffFrame:SetHeight(type(customSize) == "table" and customSize.h or requiredHeight);
	SS.buffLayoutApplying = false;
end

-- Show empty buttons: the game keeps a per-button grid count that its own drag events raise and lower, so a grid
-- shown once can be undone by the game. This is checked every quarter second (from the tally ticker): with the
-- setting on, any button whose count has dropped to 0 is given the grid again; with it off, only the grid Slim Suite
-- added is taken back.
SS.ApplyActionSlotGrid = function()
	local on = SS.DB().showEmptyActionSlots and true or false;
	if ( type(ActionButton_ShowGrid) ~= "function" or type(ActionButton_HideGrid) ~= "function" ) then return; end
	for i = 1, 7 do
		local button = getglobal("ActionButton" .. i);
		if ( button ) then
			-- the game's grid functions work on `this` (the button), so run them as the button, with it passed too
			if ( on and (tonumber(button.showgrid) or 0) < 1 ) then
				SS.RunAs(button, ActionButton_ShowGrid, button); button.slimGrid = true;
			elseif ( on and button.slimGrid and button.Show and button.IsShown and not button:IsShown() ) then
				button:Show();
			elseif ( not on and button.slimGrid ) then
				button.slimGrid = nil; SS.RunAs(button, ActionButton_HideGrid, button);
			end
		end
	end
	SS.actionSlotsGridApplied = on;
end

SS.CaptureActionBarLayout = function()
	if ( SS.actionBarOriginal or not MainMenuBar ) then return; end
	local saved = SS.DB().actionBarHorizontalSize;
	local w, h = MainMenuBar:GetWidth(), MainMenuBar:GetHeight();
	if ( type(saved) == "table" and saved.w and saved.h ) then w, h = saved.w, saved.h;
	else SS.DB().actionBarHorizontalSize = { w = w, h = h }; end
	SS.actionBarOriginal = { w = w, h = h, buttonSize = nil, buttons = {}, racial = nil, arrows = {} };
	for i = 1, 6 do
		local button = getglobal("ActionButton" .. i);
		if ( button and button.GetNumPoints ) then
			SS.actionBarOriginal.buttonSize = SS.actionBarOriginal.buttonSize or button:GetWidth();
			local points = {};
			for p = 1, button:GetNumPoints() do
				local point, relative, relativePoint, x, y = button:GetPoint(p);
				points[p] = { point, relative, relativePoint, x, y };
			end
			SS.actionBarOriginal.buttons[i] = points;
		end
	end
	if ( ActionButton12 and ActionButton12.GetNumPoints ) then
		local points = {};
		for p = 1, ActionButton12:GetNumPoints() do
			local point, relative, relativePoint, x, y = ActionButton12:GetPoint(p);
			points[p] = { point, relative, relativePoint, x, y };
		end
		SS.actionBarOriginal.racial = { w = ActionButton12:GetWidth(), h = ActionButton12:GetHeight(), points = points,
			shown = ActionButton12.IsShown and ActionButton12:IsShown() or false };
	end
	for _, name in ipairs({ "ActionBarUpButton", "ActionBarDownButton" }) do
		local arrow = getglobal(name);
		if ( arrow and arrow.GetNumPoints ) then
			local points = {};
			for p = 1, arrow:GetNumPoints() do
				local point, relative, relativePoint, x, y = arrow:GetPoint(p);
				points[p] = { point, relative, relativePoint, x, y };
			end
			SS.actionBarOriginal.arrows[name] = { w = arrow:GetWidth(), h = arrow:GetHeight(), points = points };
		end
	end
	if ( AZS_RacialRim and AZS_RacialRim.GetNumPoints ) then
		local points = {};
		for p = 1, AZS_RacialRim:GetNumPoints() do
			local point, relative, relativePoint, x, y = AZS_RacialRim:GetPoint(p);
			points[p] = { point, relative, relativePoint, x, y };
		end
		SS.actionBarOriginal.rim = points;
	end
end

function SS.RestoreRacialActionButtonLayout()
	local original = SS.actionBarOriginal;
	if ( not original or not original.racial or not ActionButton12 ) then return; end
	ActionButton12:SetWidth(original.racial.w); ActionButton12:SetHeight(original.racial.h);
	ActionButton12:ClearAllPoints();
	for p = 1, table.getn(original.racial.points) do
		local a = original.racial.points[p]; ActionButton12:SetPoint(a[1], a[2], a[3], a[4], a[5]);
	end
	local id = (ActionButton_GetPagedID and ActionButton_GetPagedID(ActionButton12)) or 12;
	local ok, has = SS.Safe(HasAction, id);
	if ( original.racial.shown or (ok and has) ) then ActionButton12:Show();
	elseif ( ActionButton12.slimShownByUs ) then ActionButton12:Hide(); end
	ActionButton12.slimShownByUs = nil;
	if ( ActionButton12.slimRacialBorder ) then ActionButton12.slimRacialBorder:Hide(); end
	if ( AZS_RacialRim and original.rim ) then
		AZS_RacialRim:ClearAllPoints();
		for p = 1, table.getn(original.rim) do local a = original.rim[p]; AZS_RacialRim:SetPoint(a[1], a[2], a[3], a[4], a[5]); end
	end
end

-- The XP bar keeps the game's own border in every layout. The game draws that border as four art pieces at a fixed
-- size along the bar where it first sits, so once Slim Suite moves, resizes or turns the bar it draws copies of the
-- same pieces (the same picture, read from the game's own) that follow the bar's size and turn with it when it stands
-- upright; the game's pieces step aside. The pieces are read once at load, while the bar is still the game's own. A
-- client that can't read or turn them keeps the older upright look (a thin gold border) there.
SS.XP_POINT = { CENTER = { 0, 0 }, TOP = { 0, 0.5 }, BOTTOM = { 0, -0.5 }, LEFT = { -0.5, 0 }, RIGHT = { 0.5, 0 },
	TOPLEFT = { -0.5, 0.5 }, TOPRIGHT = { 0.5, 0.5 }, BOTTOMLEFT = { -0.5, -0.5 }, BOTTOMRIGHT = { 0.5, -0.5 } };
SS.xpArt = {};
function SS.CaptureXpArt()
	local xp = MainMenuExpBar;
	if ( SS.xpArt.pieces or SS.xpArt.tried or not xp ) then return; end
	SS.xpArt.tried = true;
	local W, H = xp:GetWidth(), xp:GetHeight();
	if ( not W or not H or W <= 0 or H <= 0 ) then return; end
	local pieces = {};
	for i = 0, 3 do
		local t = getglobal("MainMenuXPBarTexture" .. i);
		if ( not t or type(t.GetTexCoord) ~= "function" or type(t.GetPoint) ~= "function" or type(t.GetTexture) ~= "function" ) then return; end
		if ( t.GetNumPoints and t:GetNumPoints() ~= 1 ) then return; end
		local ok, c1, c2, c3, c4, c5, c6, c7, c8 = pcall(t.GetTexCoord, t);
		if ( not ok or type(c8) ~= "number" ) then return; end
		local okPoint, p, rel, rp, x, y = pcall(t.GetPoint, t, 1);
		local w, h, file = t:GetWidth(), t:GetHeight(), t:GetTexture();
		if ( not okPoint or rel ~= xp or not file or not w or not h or w <= 0 or h <= 0 ) then return; end
		local a, b = SS.XP_POINT[p or ""], SS.XP_POINT[rp or p or ""];
		if ( not a or not b ) then return; end
		-- the piece's centre from the bar's centre, in parts of the bar's length (u) and thickness (v)
		local cx = b[1] * W + (x or 0) - a[1] * w;
		local cy = b[2] * H + (y or 0) - a[2] * h;
		pieces[i + 1] = { file = file, c = { c1, c2, c3, c4, c5, c6, c7, c8 }, u = cx / W, v = cy / H, w = w / W, h = h / H };
	end
	SS.xpArt.pieces = pieces;
end
SS.Safe(SS.CaptureXpArt);

-- true while Slim Suite's copies draw the border (the bar is Slim Suite's to move); upright needs the copies turned
function SS.XpArtShown()
	local xp, pieces = MainMenuExpBar, SS.xpArt.pieces;
	if ( SS.DB().xpHideBorder or not xp or not pieces or not SS.xpBarDetached ) then return false; end
	if ( SS.DB().orientations.MainMenuExpBar == "vertical" and SS.xpArt.noTurn ) then return false; end
	return true;
end

function SS.LayoutXpArt()
	local xp, pieces = MainMenuExpBar, SS.xpArt.pieces;
	if ( not xp or not pieces ) then return; end
	local f = SS.xpArt.frame;
	if ( not SS.XpArtShown() ) then
		if ( f ) then f:Hide(); end
		return;
	end
	if ( not f ) then
		f = CreateFrame("Frame", "SlimSuiteXpArt", xp);
		f:SetAllPoints(xp);
		f:EnableMouse(false);
		f.tex = {};
		for k = 1, table.getn(pieces) do f.tex[k] = f:CreateTexture(nil, "OVERLAY"); end
		SS.xpArt.frame = f;
	end
	f:SetFrameLevel((xp:GetFrameLevel() or 1) + 2);         -- over the fill, under the 20-segment dividers
	for i = 0, 3 do                                        -- the game's own pieces step aside for the copies
		local g = getglobal("MainMenuXPBarTexture" .. i);
		if ( g and g.SetAlpha ) then g:SetAlpha(0); end
	end
	local vertical = SS.DB().orientations.MainMenuExpBar == "vertical";
	local len, thick = xp:GetWidth() or 0, xp:GetHeight() or 0;
	if ( vertical ) then len, thick = xp:GetHeight() or 0, xp:GetWidth() or 0; end
	for k = 1, table.getn(pieces) do
		local p, t = pieces[k], f.tex[k];
		local c = p.c;
		t:SetTexture(p.file);
		t:ClearAllPoints();
		if ( vertical ) then
			-- a quarter turn to the left: the bar's start (its left end) at the bottom, as the upright bar fills
			t:SetWidth(math.max(1, p.h * thick)); t:SetHeight(math.max(1, p.w * len));
			t:SetPoint("CENTER", xp, "CENTER", -p.v * thick, p.u * len);
			if ( not pcall(t.SetTexCoord, t, c[5], c[6], c[1], c[2], c[7], c[8], c[3], c[4]) ) then
				SS.xpArt.noTurn = true;                        -- this client can't turn art: the older upright look
				f:Hide();
				SS.Safe(SS.StyleExpBar, true);
				return;
			end
		else
			t:SetWidth(math.max(1, p.w * len)); t:SetHeight(math.max(1, p.h * thick));
			t:SetPoint("CENTER", xp, "CENTER", p.u * len, p.v * thick);
			t:SetTexCoord(c[1], c[5], c[2], c[4]);             -- left, right, top, bottom
		end
		t:Show();
	end
	f:Show();
end

-- "Split into 20 segments": 19 thin dividers over the XP bar, each 5% of a level apart. They sit on the bar, follow its
-- size, and lie across it when the bar stands upright. On unless turned off.
function SS.LayoutXpSegments()
	local xp = MainMenuExpBar;
	if ( not xp ) then return; end
	local seg = getglobal("SlimSuiteXpSegments");
	if ( SS.DB().frameDefault and SS.DB().frameDefault.MainMenuExpBar ) then
		if ( seg ) then seg:Hide(); end
		return;
	end
	if ( not seg ) then
		seg = CreateFrame("Frame", "SlimSuiteXpSegments", xp);
		seg:SetAllPoints(xp);
		seg:SetFrameStrata("HIGH");
		seg:EnableMouse(false);
		seg.ticks = {};
		for i = 1, 19 do
			local t = seg:CreateTexture(nil, "OVERLAY");
			t:SetTexture(0, 0, 0, 0.65);
			seg.ticks[i] = t;
		end
		seg:SetScript("OnSizeChanged", function() SS.Safe(SS.LayoutXpSegments); end);
	end
	SS.Safe(SS.LayoutXpArt);                               -- the game's border follows the bar's size and turn
	seg:SetAllPoints(xp);
	seg:SetFrameLevel((xp:GetFrameLevel() or 1) + 3);      -- over the fill and the upright bar's border
	if ( SS.DB().xpSegments == false ) then seg:Hide(); return; end
	seg:Show();
	local vertical = SS.DB().orientations.MainMenuExpBar == "vertical";
	local w, h = xp:GetWidth() or 0, xp:GetHeight() or 0;
	for i = 1, 19 do
		local t = seg.ticks[i];
		t:ClearAllPoints();
		if ( vertical ) then
			local y = h * i / 20;
			t:SetPoint("BOTTOMLEFT", seg, "BOTTOMLEFT", 0, y); t:SetPoint("BOTTOMRIGHT", seg, "BOTTOMRIGHT", 0, y);
			t:SetHeight(1);
		else
			local x = w * i / 20;
			t:SetPoint("TOPLEFT", seg, "TOPLEFT", x, 0); t:SetPoint("BOTTOMLEFT", seg, "BOTTOMLEFT", x, 0);
			t:SetWidth(1);
		end
	end
end

-- Upright, the rested-XP marker (ExhaustionTick, the diamond "end point") is drawn for a flat bar and looks broken,
-- so it is hidden; the bar gets a dark background and a smooth fill. Laid flat again, all of that comes back.
SS.xpStyle = { shows = {} };
function SS.StyleExpBar(on)
	local xp = MainMenuExpBar;
	if ( not xp ) then return; end
	SS.Safe(SS.LayoutXpArt);
	local copies = SS.XpArtShown();
	for i = 0, 3 do
		local t = getglobal("MainMenuXPBarTexture" .. i);
		if ( t and t.SetAlpha ) then t:SetAlpha((on or copies or SS.DB().xpHideBorder) and 0 or 1); end
	end
	for _, n in ipairs({ "ExhaustionTick", "ExhaustionLevelFillBar" }) do
		local f = getglobal(n);
		if ( f and f.Hide ) then
			if ( not SS.xpStyle.shows[n] ) then SS.xpStyle.shows[n] = f.Show; end
			if ( on ) then f.Show = function() end; f:Hide();
			elseif ( f.Show ~= SS.xpStyle.shows[n] ) then f.Show = SS.xpStyle.shows[n]; f:Show(); end
		end
	end
	local fill = xp.GetStatusBarTexture and xp:GetStatusBarTexture();
	if ( fill and SS.xpStyle.texture == nil and fill.GetTexture ) then SS.xpStyle.texture = fill:GetTexture() or false; end
	if ( on ) then
		if ( not SS.xpStyle.bg ) then
			SS.xpStyle.bg = xp:CreateTexture(nil, "BACKGROUND");
			SS.xpStyle.bg:SetAllPoints(xp);
			SS.xpStyle.bg:SetTexture(0.04, 0.035, 0.05, 0.85);
			SS.xpStyle.border = CreateFrame("Frame", nil, xp);
			SS.xpStyle.border:SetPoint("TOPLEFT", xp, "TOPLEFT", -3, 3);
			SS.xpStyle.border:SetPoint("BOTTOMRIGHT", xp, "BOTTOMRIGHT", 3, -3);
			SS.xpStyle.border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 });
			SS.xpStyle.border:SetBackdropBorderColor(0.75, 0.58, 0.25, 0.9);
			SS.xpStyle.border:EnableMouse(false);
		end
		SS.xpStyle.bg:Show();
		if ( copies or SS.DB().xpHideBorder ) then SS.xpStyle.border:Hide(); else SS.xpStyle.border:Show(); end   -- the game's border when it can turn
		SS.xpStyle.border:SetFrameLevel((xp:GetFrameLevel() or 1) + 2);
		if ( xp.SetStatusBarTexture ) then xp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); end
		-- keep the game's own XP text readable on the narrow bar
		for _, n in ipairs({ "MainMenuBarExpText", "MainMenuExpBarText" }) do
			local t = getglobal(n);
			if ( t and t.SetFont ) then
				local font, _, flags = t:GetFont();
				if ( font ) then t:SetFont(font, 10, "OUTLINE"); end
			end
		end
	elseif ( SS.xpStyle.bg ) then
		SS.xpStyle.bg:Hide(); SS.xpStyle.border:Hide();
		if ( SS.xpStyle.texture and xp.SetStatusBarTexture ) then xp:SetStatusBarTexture(SS.xpStyle.texture); end
	end
	SS.xpStyle.on = on;
end

SS.ApplyMovableOrientation = function(name)
	if ( SS.DB().frameDefault and SS.DB().frameDefault[name] and name ~= "BuffFrame" ) then return; end
	local orientation = SS.CurrentOrientation(name);
	if ( name == "MainMenuBar" ) then
		local d = SS.DB();
		if ( not d.unlocked and not d.showRacialAbility and not d.plainBar and orientation ~= "vertical" and type(d.sizes.MainMenuBar) ~= "table" ) then return; end
			local first = getglobal("ActionButton1");
			if ( not first ) then return; end
			local vertical = orientation == "vertical";
			local saved = SS.DB().sizes.MainMenuBar;
			local showRacial = d.showRacialAbility and true or false;
			local buttonCount = showRacial and 7 or 6;
			local gap, racialGap = 2, showRacial and 4 or 0;
			local side = first:GetWidth() or 36;
			if ( type(saved) == "table" ) then
			side = math.max(12, math.min(vertical and saved.w or saved.h,
			((vertical and saved.h or saved.w) - gap * (buttonCount - 1) - racialGap) / buttonCount));
			end
			for i = 1, buttonCount do
			local button = getglobal("ActionButton" .. (i == 7 and 12 or i));
			if ( button ) then
			button:SetWidth(side); button:SetHeight(side); button:ClearAllPoints();
			local offset = (i - 1) * (side + gap) + (showRacial and i == 7 and racialGap or 0);
			button:SetPoint("TOPLEFT", MainMenuBar, "TOPLEFT", vertical and 0 or offset, vertical and -offset or 0);
			if ( showRacial and i == 7 and AZS_RacialRim and AZS_RacialRim.SetAllPoints ) then AZS_RacialRim:ClearAllPoints(); AZS_RacialRim:SetAllPoints(button); end
			if ( showRacial and i == 7 and not button.slimRacialBorder ) then
			local rim = CreateFrame("Frame", nil, button);
			rim:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2);
			rim:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2);
			rim:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=8});
			rim:SetBackdropBorderColor(1, 0.78, 0.18, 1); rim:EnableMouse(false);
			button.slimRacialBorder = rim;
			end
			if ( showRacial and i == 7 ) then
			if ( not button:IsShown() ) then button.slimShownByUs = true; end   -- so it can be hidden again later
			button:Show();
			end
			end
			end
		if ( not showRacial ) then SS.RestoreRacialActionButtonLayout(); end
			MainMenuBar:SetWidth(vertical and side or side * buttonCount + gap * (buttonCount - 1) + racialGap);
			MainMenuBar:SetHeight(vertical and side * buttonCount + gap * (buttonCount - 1) + racialGap or side);
			if ( ActionBarUpButton ) then
			ActionBarUpButton:ClearAllPoints(); ActionBarUpButton:SetWidth(12); ActionBarUpButton:SetHeight(12);
			ActionBarUpButton:SetPoint("TOPRIGHT", first, "TOPLEFT", -2, 0);
			end
			if ( ActionBarDownButton ) then
			ActionBarDownButton:ClearAllPoints(); ActionBarDownButton:SetWidth(12); ActionBarDownButton:SetHeight(12);
			ActionBarDownButton:SetPoint("TOPRIGHT", first, "TOPLEFT", -2, -14);
			end
	elseif ( name == "MainMenuExpBar" ) then
		local d = SS.DB();
		if ( not d.unlocked and type(d.places.MainMenuExpBar) ~= "table" and type(d.sizes.MainMenuExpBar) ~= "table"
			and type(d.scales.MainMenuExpBar) ~= "number" and d.orientations.MainMenuExpBar == nil ) then return; end
		local xp = MainMenuExpBar;
		-- Some client builds keep rested-XP child textures anchored to the original horizontal
		-- extent after rotating the status bar. Clip children to the bar when this Frame API exists,
		-- so the movable handle and the rendered XP indicator share the same visible bounds.
		if ( xp and xp.SetClipsChildren ) then SS.Safe(xp.SetClipsChildren, xp, true); end
		if ( xp and xp.SetOrientation ) then SS.Safe(xp.SetOrientation, xp, string.upper(orientation)); end
		SS.Safe(SS.StyleExpBar, orientation == "vertical");
		SS.Safe(SS.LayoutXpSegments);                         -- the dividers turn with the bar
		local base = SS.baseSizes.MainMenuExpBar;
		local saved = SS.DB().sizes.MainMenuExpBar;
		if ( xp and base and type(saved) ~= "table" ) then
			if ( orientation == "vertical" ) then xp:SetWidth(base.h); xp:SetHeight(base.w);
			else xp:SetWidth(base.w); xp:SetHeight(base.h); end
			SS.DB().sizes.MainMenuExpBar = { w = xp:GetWidth(), h = xp:GetHeight() };
		end
	elseif ( name == "BuffFrame" ) then
		SS.ApplyBuffOrientation();
	elseif ( name == "SlimSuiteBossFrames" ) then
		SS.UpdateBossFrames();
	elseif ( name == "PartyMemberFrame1" ) then
		local d = SS.DB();
		-- with yourself in the party the layout always runs, so your card joins the four members
		if ( not d.unlocked and not d.partyIncludesSelf and d.orientations.PartyMemberFrame1 == nil and not SS.demoRunning
			and type(d.places.PartyMemberFrame1) ~= "table" and type(d.sizes.PartyMemberFrame1) ~= "table"
			and type(d.scales.PartyMemberFrame1) ~= "number" ) then
			-- nothing to lay out: frames 2-4 go back to the game's own anchors (after Demo Mode or editing showed a row)
			for i = 2, 4 do
				local frame, points = getglobal("PartyMemberFrame" .. i), SS.partyNativePoints[i];
				if ( frame and points ) then
					frame:ClearAllPoints();
					for p = 1, table.getn(points) do local a = points[p]; frame:SetPoint(a[1], a[2], a[3], a[4], a[5]); end
				end
			end
			return;
		end
		local root = PartyMemberFrame1;
		if ( not root ) then return; end
		for i = 2, 4 do
			local frame = getglobal("PartyMemberFrame" .. i);
			if ( frame and not SS.partyNativePoints[i] and frame.GetNumPoints ) then
				local points = {};
				for p = 1, frame:GetNumPoints() do local a, r, rp, x, y = frame:GetPoint(p); points[p] = { a, r, rp, x, y }; end
				SS.partyNativePoints[i] = points;
			end
			if ( frame ) then
				if ( frame.SetUserPlaced ) then SS.UserPlace(frame); end
				frame:ClearAllPoints();
				local gap = SS.PartyGap();
				if ( orientation == "horizontal" ) then
					frame:SetPoint("LEFT", getglobal("PartyMemberFrame" .. (i - 1)), "RIGHT", gap, 0);
				else
					frame:SetPoint("TOP", getglobal("PartyMemberFrame" .. (i - 1)), "BOTTOM", 0, -gap);
				end
				if ( frame.SetUserPlaced ) then SS.UserPlace(frame); end
			end
		end
		-- yourself, before the first member (in the party's own look), and the thin lines
		if ( SS.LayoutPartySelf ) then SS.Safe(SS.LayoutPartySelf, true); SS.Safe(SS.UpdatePartyLines); end
	end
end

function SS.RestoreNativeActionBarLayout()
	local original = SS.actionBarOriginal;
	if ( not original or not MainMenuBar ) then return; end
	MainMenuBar:SetWidth(original.w); MainMenuBar:SetHeight(original.h);
	for i = 1, 6 do
		local button = getglobal("ActionButton" .. i);
		local points = original.buttons[i];
		if ( button ) then
			if ( original.buttonSize ) then button:SetWidth(original.buttonSize); button:SetHeight(original.buttonSize); end
			if ( points and table.getn(points) > 0 ) then
				button:ClearAllPoints();
				for p = 1, table.getn(points) do local a = points[p]; button:SetPoint(a[1], a[2], a[3], a[4], a[5]); end
			end
		end
	end
	SS.RestoreRacialActionButtonLayout();
	for name, layout in pairs(original.arrows or {}) do
		local arrow = getglobal(name);
		if ( arrow ) then
			arrow:SetWidth(layout.w); arrow:SetHeight(layout.h); arrow:ClearAllPoints();
			for p = 1, table.getn(layout.points) do local a = layout.points[p]; arrow:SetPoint(a[1], a[2], a[3], a[4], a[5]); end
		end
	end
end

function SS.SetRacialAbility(on)
	local d = SS.DB();
	d.showRacialAbility = on and true or false;
	if ( on and SS.CaptureActionBarLayout ) then SS.Safe(SS.CaptureActionBarLayout); end
	if ( not d.showRacialAbility and not d.unlocked and not d.plainBar and d.orientations.MainMenuBar ~= "vertical"
		and type(d.sizes.MainMenuBar) ~= "table" ) then
		SS.Safe(SS.RestoreNativeActionBarLayout);
	else
		SS.Safe(SS.ApplyMovableOrientation, "MainMenuBar");
	end
	SS.PlaceAll();
end
