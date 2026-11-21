-- Slim Suite: HUD Edit's tools: the size menu, the grid and snapping, the drag handles and unlocking.
local K, SU, NAME = SS.Kit, SS.SU, SS.NAME;   -- the three names every Slim Suite file uses (SlimSuiteCore.lua)

-- The size & layout tools of an element's menu: width, height, scale, layout (for the elements with no layout setting
-- of their own), buff growth, padding, hide, the clock's daylight saving and Reset. Built once, set up for the element,
-- and shown as a section of the element's menu (SU.Focus) under its settings. Only the rows the element uses are
-- shown, one under the other with no gaps. Returns false when the element has no frame yet.
function SS.PrepareSizeTools(name, label)
	name = SS.Element(name);
	local f = getglobal(SS.Shown(name));

	if ( not f ) then return false; end
	if ( not SS.sizeMenu ) then
		SS.sizeMenu = CreateFrame("Frame", nil, UIParent);
		SS.sizeMenu:SetWidth(206); SS.sizeMenu:SetHeight(120);
		SS.sizeMenu:SetFrameStrata("DIALOG");
		SS.sizeMenu.rows = {};
		-- a row is the things on one line: each { thing, its corner, x, y from the row's top }
		local function Row(key, parts)
			local row = { parts = parts };
			SS.sizeMenu.rows[key] = row;
			table.insert(SS.sizeMenu.rows, row);
			return row;
		end
		local function Label()
			return SS.sizeMenu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		end
		-- the mouse wheel over a row's label or its - and + does what the buttons do
		local function WheelPair(down, up)
			local zone = CreateFrame("Frame", nil, SS.sizeMenu);
			zone:SetWidth(90); zone:SetHeight(25); zone:EnableMouseWheel(true);
			local function Wheel()
				if ( not arg1 or arg1 == 0 ) then return; end
				local action = (arg1 > 0 and up or down):GetScript("OnClick");
				if ( action ) then action(); end
			end
			zone:SetScript("OnMouseWheel", Wheel);
			down:EnableMouseWheel(true); down:SetScript("OnMouseWheel", Wheel);
			up:EnableMouseWheel(true); up:SetScript("OnMouseWheel", Wheel);
			return zone;
		end
		local function ShowSize()
			local t = SS.sizeTarget and getglobal(SS.sizeTarget);
			if ( not t ) then return; end
			SS.sizeMenuWidth:SetText(SS.T("Width") .. ": " .. math.floor((t:GetWidth() or 0) + 0.5));
			SS.sizeMenuHeight:SetText(SS.T("Height") .. ": " .. math.floor((t:GetHeight() or 0) + 0.5));
		end
		SS.sizeMenu.ShowSize = ShowSize;
		SS.sizeMenuText = SS.sizeMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		SS.sizeMenuText:SetPoint("TOPLEFT", SS.sizeMenu, "TOPLEFT", 12, -6);
		SS.sizeMenuText:SetText(SS.T("Size & layout"));
		local function ResizeBy(axis, delta)
			if ( not SS.sizeTarget ) then return; end
			local t = getglobal(SS.sizeTarget);
			if ( not t ) then return; end
			local w, h = t:GetWidth(), t:GetHeight();
			local scaleRatio = SS.RootFactor(t);
			if ( not scaleRatio or scaleRatio <= 0 ) then scaleRatio = 1; end
			if ( axis == "w" ) then
				local minWidth = SS.MinSize(SS.sizeTarget);
				w = math.max(minWidth, math.min((UIParent:GetWidth() or 1920) / scaleRatio, w + delta));
			else
				local _, minHeight = SS.MinSize(SS.sizeTarget);
				h = math.max(minHeight, math.min((UIParent:GetHeight() or 1080) / scaleRatio, h + delta));
			end
			t:SetWidth(w); t:SetHeight(h);
			if ( SS.sizeTarget == "MainMenuBar" ) then
				-- the bar is its buttons: six (seven with the racial), 2 apart (the racial 4 further)
				local vertical = SS.CurrentOrientation(SS.sizeTarget) == "vertical";
				local count = SS.DB().showRacialAbility and 7 or 6;
				local gaps = 2 * (count - 1) + (SS.DB().showRacialAbility and 4 or 0);
				local side = (axis == "w") and (vertical and w or (w - gaps) / count) or (vertical and (h - gaps) / count or h);
				local maxLong = (vertical and UIParent:GetHeight() or UIParent:GetWidth()) / scaleRatio;
				local maxShort = (vertical and UIParent:GetWidth() or UIParent:GetHeight()) / scaleRatio;
				side = math.max(12, math.min(side, (maxLong - gaps) / count, maxShort));
				w, h = vertical and side or side * count + gaps, vertical and side * count + gaps or side;
				t:SetWidth(w); t:SetHeight(h);
			end
			if ( SS.sizeTarget == "BuffFrame" ) then SS.DB().buffCustomLayout = true; end   -- the icons follow the size
			SS.DB().sizes[SS.sizeTarget] = { w = w, h = h }; SS.MarkProfileDirty();
			if ( SS.MatchBuildRowSizes ) then SS.MatchBuildRowSizes(SS.sizeTarget); end
			if ( SS.sizeTarget == "GameTooltip" ) then SS.DB().tooltipCustom = true; end
			if ( SS.sizeTarget == "BuffFrame" ) then SS.Safe(SS.ApplyBuffOrientation); end
			if ( SS.sizeTarget == "SlimSuiteClockFrame" ) then SS.ApplyClockLayout(); end
			if ( SS.Element(SS.sizeTarget) == "TargetFrame" ) then SS.Safe(SS.MirrorPlayer); end
			SS.PlaceAll();
			ShowSize();
		end
		SS.sizeMenuWidth = Label();
		local narrower = K.Button(SS.sizeMenu, "-", 30, function() ResizeBy("w", -20); end);
		local wider = K.Button(SS.sizeMenu, "+", 30, function() ResizeBy("w", 20); end);
		Row("width", { { WheelPair(narrower, wider), "TOPLEFT", 10, 0 }, { SS.sizeMenuWidth, "TOPLEFT", 12, -8 }, { narrower, "TOPRIGHT", -72, 0 }, { wider, "TOPRIGHT", -32, 0 } });
		SS.sizeMenuHeight = Label();
		local shorter = K.Button(SS.sizeMenu, "-", 30, function() ResizeBy("h", -20); end);
		local taller = K.Button(SS.sizeMenu, "+", 30, function() ResizeBy("h", 20); end);
		Row("height", { { WheelPair(shorter, taller), "TOPLEFT", 10, 0 }, { SS.sizeMenuHeight, "TOPLEFT", 12, -8 }, { shorter, "TOPRIGHT", -72, 0 }, { taller, "TOPRIGHT", -32, 0 } });
		SS.sizeMenuScale = Label();
		SS.sizeMenuScale:SetText(SS.T("Scale") .. " %:");
		SS.sizeMenuScaleInput = CreateFrame("EditBox", nil, SS.sizeMenu);
		SS.sizeMenuScaleInput:SetWidth(46); SS.sizeMenuScaleInput:SetHeight(20);
		SS.sizeMenuScaleInput:SetAutoFocus(false); SS.sizeMenuScaleInput:SetNumeric(true);
		SS.sizeMenuScaleInput:SetJustifyH("CENTER"); SS.sizeMenuScaleInput:SetMaxLetters(3);
		SS.sizeMenuScaleInput:SetFontObject(GameFontHighlightSmall);
		SS.sizeMenuScaleInput:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } });
		SS.sizeMenuScaleInput:SetBackdropColor(0.02, 0.02, 0.03, 0.95);
		SS.sizeMenuScaleInput:SetBackdropBorderColor(0.55, 0.43, 0.2, 1);
		local function SetScalePercent(percent)
			if ( not SS.sizeTarget ) then return; end
			percent = math.max(20, math.min(200, math.floor(tonumber(percent) or 100)));   -- never so small it disappears
			SS.DB().scales[SS.sizeTarget] = percent / 100; SS.MarkProfileDirty();
			if ( SS.MatchBuildRowSizes ) then SS.MatchBuildRowSizes(SS.sizeTarget); end
			if ( SS.Element(SS.sizeTarget) == "TargetFrame" ) then SS.Safe(SS.MirrorPlayer); end
			SS.PlaceAll();
			SS.sizeMenuScaleInput:SetText(tostring(percent));
		end
		local function ScaleNow() return math.floor((SS.DB().scales[SS.sizeTarget] or 1) * 100 + 0.5); end
		SS.sizeMenuScaleInput:SetScript("OnEnterPressed", function()
			this.cancelScaleEdit = true;
			SetScalePercent(this:GetText());
			this:ClearFocus();
		end);
		SS.sizeMenuScaleInput:SetScript("OnEditFocusLost", function()
			if ( this.cancelScaleEdit ) then this.cancelScaleEdit = nil; return; end
			SetScalePercent(this:GetText());
		end);
		SS.sizeMenuScaleInput:SetScript("OnEscapePressed", function()
			this.cancelScaleEdit = true;
			this:ClearFocus();
			this:SetText(tostring(ScaleNow()));
		end);
		local scaleDown = K.Button(SS.sizeMenu, "-", 30, function() SetScalePercent(ScaleNow() - 5); end);
		local scaleUp = K.Button(SS.sizeMenu, "+", 30, function() SetScalePercent(ScaleNow() + 5); end);
		Row("scale", { { WheelPair(scaleDown, scaleUp), "TOPLEFT", 10, 0 }, { SS.sizeMenuScale, "TOPLEFT", 12, -8 }, { SS.sizeMenuScaleInput, "TOPLEFT", 58, -1 },
			{ scaleDown, "TOPRIGHT", -72, 0 }, { scaleUp, "TOPRIGHT", -32, 0 } });
		-- vertical or horizontal, for the elements that have no layout setting among their own settings above
		local layout = K.Button(SS.sizeMenu, "Switch to vertical", 116, function()
			if ( not SS.sizeTarget ) then return; end
			SS.ToggleMovableOrientation(SS.Element(SS.sizeTarget));
			ShowSize();
			SS.sizeMenu.LayoutText();
		end);
		SS.sizeMenu.layoutButton = layout;
		SS.sizeMenu.LayoutText = function()
			local el = SS.Element(SS.sizeTarget);
			local orientation = el == "SlimSuiteTallyFrame" and (SS.DB().tallyVertical and "vertical" or "horizontal") or SS.CurrentOrientation(el);
			layout:SetText(SS.T(orientation == "vertical" and "Switch to horizontal" or "Switch to vertical"));
		end;
		local growth;
		growth = K.Button(SS.sizeMenu, SS.T("Grow") .. " " .. SS.T("down"), 68, function()
			if ( SS.sizeTarget ~= "BuffFrame" ) then return; end
			SS.DB().buffCustomLayout = true;
			SS.DB().buffGrowthDirection = SS.BuffGrowthDirection() == "up" and "down" or "up";
			growth:SetText(SS.T("Grow") .. " " .. SS.T(SS.BuffGrowthDirection()));
			SS.Safe(SS.ApplyBuffOrientation);
			SS.PlaceAll();
		end);
		SS.sizeMenu.growthButton = growth;
		Row("layout", { { layout, "TOPLEFT", 10, 0 }, { growth, "TOPRIGHT", -10, 0 } });
		SS.sizeMenuPadding = Label();
		local function Pad(by)
			if ( not SS.sizeTarget ) then return; end
			SS.DB().padding[SS.sizeTarget] = math.max(0, math.min(SS.FramePaddingLimit(SS.sizeTarget), SS.FramePadding(SS.sizeTarget) + by)); SS.MarkProfileDirty();
			SS.ApplyMovablePadding(SS.sizeTarget);
			SS.sizeMenuPadding:SetText(SS.T("Padding") .. ": " .. SS.FramePadding(SS.sizeTarget));
			ShowSize();
		end
		local padDown = K.Button(SS.sizeMenu, "-", 30, function() Pad(-2); end);
		local padUp = K.Button(SS.sizeMenu, "+", 30, function() Pad(2); end);
		Row("padding", { { WheelPair(padDown, padUp), "TOPLEFT", 10, 0 }, { SS.sizeMenuPadding, "TOPLEFT", 12, -8 }, { padDown, "TOPRIGHT", -72, 0 }, { padUp, "TOPRIGHT", -32, 0 } });
		-- the local clock's hour for daylight saving: automatic -> forced on (+1 hour) -> forced off -> automatic
		SS.sizeMenu.clockDst = K.Button(SS.sizeMenu, "Daylight saving: auto", 184, function()
			local dst = SS.DB().localClockDST;
			if ( dst == nil ) then SS.DB().localClockDST = 1;
			elseif ( dst == 1 ) then SS.DB().localClockDST = 0;
			else SS.DB().localClockDST = nil; end
			if ( SlimSuiteWorld and SlimSuiteWorld.UpdateLocalClock ) then SlimSuiteWorld.UpdateLocalClock(); end
			SS.sizeMenu.ClockLabels();
		end);
		SS.sizeMenu.ClockLabels = function()
			local d = SS.DB();
			-- automatic unless set by hand; the text says what the clock is doing now
			local now = SlimSuiteWorld and SlimSuiteWorld.DaylightOffset and SlimSuiteWorld.DaylightOffset() or 0;
			if ( d.localClockDST == nil ) then
				SS.sizeMenu.clockDst:SetText(SS.T("Daylight saving") .. ": " .. SS.T("auto") .. " (" .. SS.T(now > 0 and "on" or "off") .. ")");
			else
				local dst = tonumber(d.localClockDST) or 0;
				SS.sizeMenu.clockDst:SetText(SS.T("Daylight saving") .. ": " .. SS.T(dst > 0 and "+1 hour" or (dst < 0 and "-1 hour" or "off")));
			end
		end;
		Row("dst", { { SS.sizeMenu.clockDst, "TOPLEFT", 10, 0 } });
		local muteButton = K.Button(SS.sizeMenu, "Hide feature", 112, function()
			if ( SS.sizeTarget ) then SS.ToggleFeatureMute(SS.sizeTarget); end
		end);
		SS.sizeMenu.muteButton = muteButton;
		local reset = K.Button(SS.sizeMenu, "Reset", 62, function()
			if ( not SS.ResetElement(SS.sizeTarget) ) then
				K.Print(NAME, SS.T("the original size is not available yet; try again after the frame appears."));
				return;
			end
			SS.OpenSizeMenu(SS.sizeMenu.element or SS.sizeTarget, SS.sizeMenu.label);
		end);
		Row("last", { { muteButton, "TOPLEFT", 10, 0 }, { reset, "TOPRIGHT", -10, 0 } });
		local openSettings = K.Button(SS.sizeMenu, "Open in settings", 186, function()
			if ( SS.sizeMenu.element and SS.OpenElementSettings ) then SS.OpenElementSettings(SS.sizeMenu.element); end
		end);
		Row("settings", { { openSettings, "TOPLEFT", 10, 0 } });
	end
	SS.sizeTarget = SS.Shown(name);
	SS.sizeMenu.element, SS.sizeMenu.label = name, label;
	SS.sizeMenu.ShowSize();
	-- the classic player, target and party frames' and the minimap's artwork has a fixed size: width and height would
	-- only change the area you can click, so they are resized with Scale alone (the new-school cards keep all three)
	local fixedArt = SS.sizeTarget == "PlayerFrame" or SS.sizeTarget == "TargetFrame" or SS.sizeTarget == "PartyMemberFrame1"
		or SS.sizeTarget == "MinimapCluster" or SS.sizeTarget == "SlimSuiteMinimapBar";
	local rows = SS.sizeMenu.rows;
	rows.width.on, rows.height.on = not fixedArt, not fixedArt and name ~= "GameTooltip";   -- a tooltip is as tall as its text
	rows.scale.on, rows.last.on = true, true;
	rows.settings.on = SS.ELEMENTS and SS.ELEMENTS[name] and name ~= "SlimSuiteEditGrid" and true or false;
	SS.sizeMenuScaleInput:SetText(tostring(math.max(20, math.min(200, math.floor((SS.DB().scales[SS.sizeTarget] or 1) * 100 + 0.5)))));
	-- the other elements that turn have "vertical" among their settings, so it is not offered twice
	rows.layout.on = name == "SlimSuiteTallyFrame" or name == "SlimSuiteClockFrame" or name == "BuffFrame";
	if ( rows.layout.on ) then SS.sizeMenu.LayoutText(); end
	SS.sizeMenu.growthButton.wanted = name == "BuffFrame";
	if ( name == "BuffFrame" ) then SS.sizeMenu.growthButton:SetText(SS.T("Grow") .. " " .. SS.T(SS.BuffGrowthDirection())); end
	rows.padding.on = name == "SlimSuiteClockFrame" or name == "SlimSuiteBossFrames" or name == "SlimSuiteTallyFrame"
		or name == "SlimSuiteAnnouncementFrame" or name == "BuffFrame";
	if ( rows.padding.on ) then SS.sizeMenuPadding:SetText(SS.T("Padding") .. ": " .. SS.FramePadding(name)); end
	rows.dst.on = name == "SlimSuiteLocalClockFrame";
	if ( rows.dst.on ) then SS.sizeMenu.ClockLabels(); end
	SS.sizeMenu.muteButton:SetText(SS.T(SS.DB().muted[SS.sizeTarget] and "Show feature" or "Hide feature"));
	-- the rows in use, one under the other
	local y = -24;
	for i = 1, table.getn(rows) do
		local row = rows[i];
		for k = 1, table.getn(row.parts) do
			local p = row.parts[k];
			local thing = p[1];
			if ( row.on and thing.wanted ~= false ) then
				thing:ClearAllPoints();
				thing:SetPoint(p[2], SS.sizeMenu, p[2], p[3], y + p[4]);
				thing:Show();
			else
				thing:Hide();
			end
		end
		if ( row.on ) then y = y - 27; end
	end
	SS.sizeMenu:SetHeight(-y + 2);
	SS.sizeMenuName = name;
	return true;
end

function SS.HideEditGrid()
	if ( SS.editGrid ) then SS.editGrid:Hide(); end
end

SS.ShowEditGrid = function()
	SS.HideEditGrid();
	if ( not SS.DB().showEditGrid or not SS.DB().unlocked ) then return; end
	if ( not SS.editGrid ) then
		SS.editGrid = CreateFrame("Frame", "SlimSuiteEditGrid", UIParent);
		SS.editGrid:SetFrameStrata("HIGH");
		SS.editGrid:EnableMouse(false);
		SS.editGrid:SetScript("OnSizeChanged", function()
			if ( SS.DB().showEditGrid and SS.DB().unlocked ) then SS.ShowEditGrid(); end
		end);
	end
	local left, right, bottom, top = SS.ScreenBounds();
	local width, height = right - left, top - bottom;
	SS.editGrid:ClearAllPoints();
	SS.editGrid:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom);
	SS.editGrid:SetWidth(width); SS.editGrid:SetHeight(height);
	local count, i = 1, 1;
	local function Line(x, y, w, h, color)
		local tex = SS.editGridLines[count];
		if ( not tex ) then tex = SS.editGrid:CreateTexture(nil, "OVERLAY"); SS.editGridLines[count] = tex; end
		count = count + 1;
		tex:ClearAllPoints(); tex:SetPoint("TOPLEFT", SS.editGrid, "TOPLEFT", x, -y); tex:SetWidth(w); tex:SetHeight(h);
		local c = color or { 0.95, 0.76, 0.3, 0.26 };
		tex:SetTexture(c[1], c[2], c[3], c[4]); tex:Show();
	end
	local divisions = tonumber(SS.DB().gridDivisions) or 64;
	-- The chosen count is exact on the shorter edge. The other axis gets the nearest
	-- matching count so cells stay square-like, and every edge is a full grid boundary.
	local shorter = math.min(width, height);
	local longerCount = math.max(divisions, math.floor((math.max(width, height) / shorter) * divisions + 0.5));
	local columns, rows = width <= height and divisions or longerCount, height <= width and divisions or longerCount;
	local edge = { 0.95, 0.76, 0.3, 0.34 };
	Line(0, 0, 1, height, edge); Line(math.max(0, width - 1), 0, 1, height, edge);
	Line(0, 0, width, 1, edge); Line(0, math.max(0, height - 1), width, 1, edge);
	for i = 1, columns - 1 do Line(math.floor(i * width / columns + 0.5), 0, 1, height); end
	for i = 1, rows - 1 do Line(0, math.floor(i * height / rows + 0.5), width, 1); end
	if ( SS.DB().gridCenterVertical ) then Line(math.floor(width / 2), 0, 2, height, { 1, 0.12, 0.12, 0.92 }); end
	if ( SS.DB().gridCenterHorizontal ) then Line(0, math.floor(height / 2), width, 2, { 1, 0.12, 0.12, 0.92 }); end
	for i = count, table.getn(SS.editGridLines) do SS.editGridLines[i]:Hide(); end
	SS.editGrid:Show();
end

-- the Snap switch on the edit bar: grid and nearby-frame snapping together
function SS.SetSnap(on)
	SS.DB().gridSnap = on and true or false;
	SS.SetAnchorSnap(on and true or false);
	if ( SU.snap ) then SU.snap.Refresh(); end
	SS.RefreshToggles();
end

-- the bottom-left corner rounded to the nearest grid line, using the same cell sizes the grid draws
function SS.GridRound(left, bottom)
	local W, H = UIParent:GetWidth(), UIParent:GetHeight();
	local d = tonumber(SS.DB().gridDivisions) or 64;
	local shorter = math.min(W, H);
	local longer = math.max(d, math.floor((math.max(W, H) / shorter) * d + 0.5));
	local cols = W <= H and d or longer;
	local rows = H <= W and d or longer;
	local cw, rh = W / cols, H / rows;
	return math.floor(left / cw + 0.5) * cw, math.floor(bottom / rh + 0.5) * rh;
end

-- true when following name's saved anchors leads to target (or loops back on itself): anchoring target to name then makes a loop
function SS.DependsOn(name, target)
	local seen, cur = {}, name;
	for i = 1, 40 do
		local p = SS.DB().places[cur];
		local rel = type(p) == "table" and p.relative or nil;
		if ( not rel ) then return false; end
		if ( rel == target or seen[rel] ) then return true; end
		seen[rel] = true; cur = rel;
	end
	return true;
end

function SS.SnapPosition(name, f)
	local left, right, bottom, top = SS.RootBounds(f);
	if ( not left or not right or not bottom or not top ) then SS.SavePlace(name, f); return; end
	local best, bestDistance;
	local threshold = 18;
	for i = 1, table.getn(SS.MOVABLE) do
		local otherName = SS.MOVABLE[i][1];
		-- the party frames never snap onto other elements when dropped: they jumped to them by accident
		local other = (SS.DB().anchorSnap and otherName ~= name and name ~= "PartyMemberFrame1" and getglobal(otherName)) or nil;
		if ( other and SS.DependsOn(otherName, name) ) then other = nil; end   -- it already hangs off this frame: no loop
		if ( other ) then
			local ol, oright, ob, ot = SS.RootBounds(other);
			if ( ol and oright and ob and ot ) then
				local overlapX = math.min(right, oright) - math.max(left, ol);
				local overlapY = math.min(top, ot) - math.max(bottom, ob);
				local candidates = {};
				if ( overlapX > 24 ) then
					table.insert(candidates, { math.abs(top - ob), "TOPLEFT", "BOTTOMLEFT", left - ol, top - ob });
					table.insert(candidates, { math.abs(bottom - ot), "BOTTOMLEFT", "TOPLEFT", left - ol, bottom - ot });
				end
				if ( overlapY > 24 ) then
					table.insert(candidates, { math.abs(left - oright), "BOTTOMLEFT", "BOTTOMRIGHT", left - oright, bottom - ob });
					table.insert(candidates, { math.abs(right - ol), "BOTTOMRIGHT", "BOTTOMLEFT", right - ol, bottom - ob });
				end
				for j = 1, table.getn(candidates) do
					local c = candidates[j];
					if ( c[1] <= threshold and (not bestDistance or c[1] < bestDistance) ) then
						bestDistance = c[1]; best = { relative = otherName, point = c[2], relativePoint = c[3], dx = c[4], dy = c[5] };
					end
				end
			end
		end
	end
	local p = { coordinateSpace = "uiParent" };
	if ( best ) then
		for k, v in pairs(best) do p[k] = v; end
		-- logged, so a snap that moved an element by accident can be seen in /slimsuite log
		if ( SS.LogAction ) then SS.LogAction("Snapped " .. name .. " to " .. best.relative); end
	else
		p.x, p.y = left, bottom;
		if ( SS.DB().gridSnap ) then p.x, p.y = SS.GridRound(left, bottom); end
	end
	SS.DB().places[name] = p;
	SS.PlaceAll();
end

function SS.FinishHandleMove(h, name)
	h:SetScript("OnUpdate", nil);   -- the drag step only runs while a drag is in progress
	name = h.mover or name;
	local t = getglobal(name);
	SS.dragActive = nil;
	if ( not t or not h.dragging ) then return; end
	h.dragging = nil;
	if ( SS.DB().anchorSnap or SS.DB().gridSnap ) then SS.SnapPosition(name, t);
	else SS.SavePlace(name, t); SS.DB().places[name].relative = nil; SS.Place(name); end
	SS.KeepSizeAfterMove(name, t, h.keepSize);
	-- and again a moment later, in case something resizes it after the drop
	local keep, at = h.keepSize, GetTime() + 0.6;
	SS.Every("keepSize" .. name, 0.2, function()
		if ( GetTime() < at ) then return; end
		SS.Stop("keepSize" .. name); SS.KeepSizeAfterMove(name, t, keep);
	end);
	h.keepSize = nil;
end
-- While editing, every scale change of an element is written to the action log with the code that made it, so a
-- frame that shrinks on its own can be traced.
SS.Every("watchScales", 1, function()
	for i = 1, table.getn(SS.MOVABLE) do
		local name = SS.MOVABLE[i][1];
		local list = { name };
		if ( name == "PartyMemberFrame1" ) then list = { "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4" }; end
		for _, listed in ipairs(list) do
			local n = listed;
			local f = getglobal(n);
			if ( f and f.SetScale and not f.slimScaleWatched ) then
				f.slimScaleWatched = true;
				local original = f.SetScale;
				f.SetScale = function(self, s)
					local before = self.GetScale and self:GetScale() or 1;
					original(self, s);
					if ( SS.DB().unlocked and type(s) == "number" and math.abs(s - before) > 0.001 and SS.LogAction ) then
						local from = type(debugstack) == "function" and string.gsub(debugstack(2, 2, 0) or "", "\n", " | ") or "";
						SS.LogAction(string.format("[scale] %s %.2f -> %.2f  %s", n, before, s, from));
					end
				end;
			end
		end
	end
end);
function SS.KeepSizeAfterMove(name, t, keep)
	if ( not keep or not t ) then return; end
	local d = SS.DB();
	local now = d.sizes[name];
	local changed = d.scales[name] ~= keep.scale
		or (keep.size and (not now or now.w ~= keep.size.w or now.h ~= keep.size.h)) or (not keep.size and now ~= nil)
		or math.abs((t:GetWidth() or 0) - (keep.w or 0)) > 0.5 or math.abs((t:GetHeight() or 0) - (keep.h or 0)) > 0.5
		or math.abs((t:GetScale() or 1) - (keep.s or 1)) > 0.001;
	if ( not changed ) then return; end
	if ( SS.LogAction ) then
		SS.LogAction(string.format("[move] %s changed size while moving (%.0fx%.0f scale %.2f -> %.0fx%.0f scale %.2f); put back",
			name, keep.w or 0, keep.h or 0, keep.s or 1, t:GetWidth() or 0, t:GetHeight() or 0, t:GetScale() or 1));
	end
	d.scales[name] = keep.scale;
	d.sizes[name] = keep.size and { w = keep.size.w, h = keep.size.h } or nil;
	SS.Safe(SS.ApplySize, name, t);
	if ( not keep.size and keep.w and keep.h ) then t:SetWidth(keep.w); t:SetHeight(keep.h); end
	if ( t.SetScale and keep.s and not keep.scale ) then t:SetScale(keep.s); end
end

-- the frame a handle sits on: its outline follows the frame (the tooltip handle also keeps itself on top)
function SS.FollowHandle(h, name)
	local t = getglobal(name);
	if ( not t ) then return; end
	if ( name == "GameTooltip" and t:IsShown() ) then
		h:SetFrameStrata("TOOLTIP");
		if ( h:GetFrameLevel() <= t:GetFrameLevel() ) then h:SetFrameLevel(t:GetFrameLevel() + 1); end
	end
	local l, r, b, top = SS.RootBounds(t);
	if ( l and b ) then
		-- measuring what a frame shows looks at all its parts: done when the frame moves or changes size, and otherwise
		-- twice a second (its parts can change on their own)
		local now = GetTime and GetTime() or 0;
		if ( h.followL == l and h.followR == r and h.followB == b and h.followT == top and now - (h.followAt or 0) < 0.5 and now >= (h.followAt or 0) ) then return; end
		h.followL, h.followR, h.followB, h.followT, h.followAt = l, r, b, top, now;
		local x1, y1, x2, y2 = SS.VisualInsets(t);
		h:ClearAllPoints();
		h:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l + x1, b + y1);
		h:SetWidth(math.max(1, x2 - x1)); h:SetHeight(math.max(1, y2 - y1));
	end
end

-- one step of a drag: runs each frame only while the handle is being dragged
function SS.DragStep(h, name)
	local t = getglobal(name);
	if ( not t ) then return; end
	if ( IsMouseButtonDown and not IsMouseButtonDown("LeftButton") ) then
		SS.FinishHandleMove(h, name);
		return;
	end
	local scale = SS.EffectiveScale(UIParent);
	local x, y = GetCursorPosition(); x, y = x / scale, y / scale;
	local deltaX, deltaY = x - h.dragStartX, y - h.dragStartY;
	local nextX, nextY = h.frameStartX + deltaX, h.frameStartY + deltaY;
	local moved = getglobal(h.mover or name) or t;
	nextX, nextY = SS.ClampPosition(moved, nextX, nextY);
	SS.SetRootPosition(moved, nextX, nextY);
	SS.SavePlace(h.mover or name, moved);          -- keep the newest location even if /reload happens mid-session
	-- mirrored frames move together: drag either one and the other moves the opposite way
	if ( SS.DB().mirrorTarget ) then
		local element = SS.Element(h.mover or name);
		if ( element == "PlayerFrame" ) then SS.MirrorTarget();
		elseif ( element == "TargetFrame" ) then SS.MirrorPlayer(); end
	end
	SS.FollowHandle(h, name);
end

function SS.Handle(name, label)
	local f = getglobal(name);
	if ( not f ) then return nil; end
	local h = SS.handles[name];
	if ( not h ) then
		h = CreateFrame("Frame", nil, UIParent);
		h:SetFrameStrata("DIALOG");
		h:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
		if ( name == "GameTooltip" ) then
			h:SetBackdropColor(0, 0, 0, 0); -- keep tooltip text readable while its drag outline is active
			h:SetFrameStrata("TOOLTIP");
			if ( not SS.RootBounds(f) ) then
				local size = SS.DB().sizes.GameTooltip;
				if ( type(size) ~= "table" ) then size = { w = 260, h = 140 }; end
				f:SetWidth(size.w); f:SetHeight(size.h); f:ClearAllPoints();
				f:SetPoint("CENTER", UIParent, "CENTER", 0, 0); f:Hide();
			end
		else
			h:SetBackdropColor(0.1, 0.6, 0.1, 0.45);
		end
		h:SetBackdropBorderColor(0.3, 1, 0.3, 0.9);
		h:EnableMouse(true);
		h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal");
		h.text:SetPoint("CENTER", h, "CENTER", 0, 0);
		if ( name == "GameTooltip" ) then h.text:Hide(); else h.text:SetText(label); end
		if ( SS.QUIET_HANDLES[name] ) then
			-- the player and target frames are previewed as they really look: no green box over them, just a faint
			-- outline and the name while the mouse is over the frame (it still drags and right-clicks as before)
			h.quiet = true;
			h:SetBackdropColor(0, 0, 0, 0); h:SetBackdropBorderColor(0.3, 1, 0.3, 0); h.text:Hide();
			h:SetScript("OnEnter", function() this:SetBackdropBorderColor(0.3, 1, 0.3, 0.7); this.text:Show(); end);
			h:SetScript("OnLeave", function() this:SetBackdropBorderColor(0.3, 1, 0.3, 0); this.text:Hide(); end);
		end
		local dragStep = function() SS.DragStep(this, name); end;
		h:SetScript("OnMouseDown", function()
			if ( arg1 == "RightButton" ) then
				SS.OpenSizeMenu(name, label);
				return;
			end
			if ( arg1 ~= "LeftButton" ) then return; end
			if ( IsShiftKeyDown and IsShiftKeyDown() ) then
				SS.ToggleFeatureMute(name);
				return;
			end
			-- The joined jewelry row moves with the spell row: dragging either handle moves the pair.
			this.mover = (name == "SlimSuiteItemRowFrame" and SS.DB().buildRowsAttached) and "SlimSuiteSpellRowFrame" or name;
			local t = getglobal(this.mover);
			if ( not t ) then return; end
			t:SetMovable(true);
			-- We clamp the visible child bounds ourselves below; native clamping would keep the
			-- parent inside the screen and leave a gap when its buttons extend beyond its edges.
			if ( t.SetClampedToScreen ) then t:SetClampedToScreen(false); end
			if ( (name == "BuffFrame" or name == "MainMenuBar" or name == "MinimapCluster" or name == "PartyMemberFrame1") and t.SetUserPlaced ) then SS.UserPlace(t); end
			local scale = SS.EffectiveScale(UIParent);
			local x, y = GetCursorPosition(); x, y = x / scale, y / scale;
			this.dragStartX, this.dragStartY = x, y;
			local left, right, bottom = SS.RootBounds(t);
			this.frameStartX, this.frameStartY = left or x, bottom or y;
			-- moving never changes size: remember it, and put it back if anything changed it by the drop
			local dd = SS.DB();
			this.keepSize = { scale = dd.scales[this.mover], size = dd.sizes[this.mover] and { w = dd.sizes[this.mover].w, h = dd.sizes[this.mover].h },
				w = t:GetWidth(), h = t:GetHeight(), s = t:GetScale() };
			local saved = SS.DB().places[this.mover];
			if ( type(saved) == "table" ) then saved.relative, saved.point, saved.relativePoint, saved.dx, saved.dy = nil, nil, nil, nil, nil; end
			this.dragging = true; SS.dragActive = true;
			this:SetScript("OnUpdate", dragStep);
		end);
		h:SetScript("OnMouseUp", function()
			if ( arg1 ~= "LeftButton" ) then return; end
			SS.FinishHandleMove(this, name);
		end);
		h.handleName = name;
		table.insert(SS.handleList, h);   -- the shared follower below keeps every shown handle on its frame
		SS.handles[name] = h;
	end
	if ( SS.AddResizeGrip ) then SS.AddResizeGrip(h,name); end
 	return h;
end

-- one shared follower keeps every shown handle on its frame, 20 times a second (the one being dragged follows every
-- frame, from its own drag step)
SS.Every("handleFollow", 0.05, function()
	for i = 1, table.getn(SS.handleList) do
		local h = SS.handleList[i];
		if ( h:IsShown() ) then SS.FollowHandle(h, h.handleName); end
	end
end);

-- unlocked: the handles show (the frames are shown too, so even an empty party frame can be placed)
-- Which movable frames are switched off right now (false): a feature turned off, or the design not in use (the
-- classic player/target frames while the new-school cards are on, and the other way round). Anything not listed is on.
function SS.AvailableElements()
	local d = SS.DB();
	local off = {
		SlimSuiteStoredLevelsButton = d.moveLevelButton, SlimSuiteSpellRowFrame = d.replaceBuildRows and not d.hideBuildSpells, SlimSuiteItemRowFrame = d.replaceBuildRows and not d.hideBuildItems,
		SlimSuiteMeterFrame = d.moveMeter, SlimSuiteClockFrame = d.replaceClock, SlimSuiteBossFrames = d.replaceEncounters,
		SlimSuiteTallyFrame = d.replaceTally, SlimSuiteAnnouncementFrame = d.replaceBanners, SlimSuiteReviveFrame = d.replaceRevive,
		SlimSuiteLocalClockFrame = d.replaceLocalClock and d.clockDetached, SlimSuiteCombatTextFrame = d.combatTextBox and true or false, SlimSuiteMinimapBar = d.minimapBar and true or false,
		TargetFrame = not d.hideTarget and not SS.UsesCard("TargetFrame"), PlayerFrame = not SS.UsesCard("PlayerFrame") and not d.partyIncludesSelf,
		SlimSuitePlayerCard = SS.UsesCard("PlayerFrame"), SlimSuiteTargetCard = SS.UsesCard("TargetFrame") and not d.hideTarget,
		PartyMemberFrame1 = SS.Look("PartyMemberFrame1") ~= "thin", SlimSuitePartyLines = SS.Look("PartyMemberFrame1") == "thin",
	};
	local out = {};
	for name, isOn in pairs(off) do out[name] = isOn and true or false; end
	return out;
end

-- whether a frame may have a handle now: not left to the game's own layout, its design in use, not joined to a unit frame
function SS.RefreshEditHandles()
	local available=SS.AvailableElements();
	for _,entry in ipairs(SS.MOVABLE) do
		local name=entry[1]; local wanted=SS.DB().unlocked and not SS.HiddenInSetup(name) and
			((SS.setupActive and SS.SetupShows(name)) or (not SS.setupActive and (not SS.editOnly or SS.editOnly==name)));
		if wanted and SS.HandleAllowed(name,available) then
			local h=SS.Handle(name,entry[2]); if h then h:Show(); end
		elseif SS.handles[name] then SS.handles[name]:Hide(); end
	end
end

function SS.HandleAllowed(name, available)
	local d = SS.DB();
	if SS.demoRunning then return false; end
	if ( d.frameDefault and d.frameDefault[name] ) then return false; end
	if ( (available or SS.AvailableElements())[name] == false ) then return false; end
	if ( name == "BuffFrame" and (d.buffsOnTarget or d.buffsOnPlayer) ) then return false; end
	return true;
end

function SS.SetUnlocked(on, quiet)
	-- The first time the mover is opened, the setup walks through the UI one element at a time instead.
	-- After that it opens Edit mode (every handle, and the move panel with "Run setup again").
	-- Edit mode is the element list: every element, Enabled or Disabled, the grid on top and Done at the bottom.
	if ( on and not quiet and not SS.setupActive and SS.StartSetup ) then
		SS.StartSetup();
		return;
	end
	if ( not on ) then
		if ( SS.setupActive and SS.SetupHide ) then SS.SetupHide(); end   -- its step is kept for next time
		SS.editOnly = nil;
	end
	SS.DB().unlocked = on and true or false;
	if ( on and GameTooltip ) then
		local size = SS.DB().sizes.GameTooltip;
		if ( type(size) ~= "table" ) then size = { w = 260, h = 140 }; end
		GameTooltip:SetWidth(size.w); GameTooltip:SetHeight(size.h);
		if ( not SS.RootBounds(GameTooltip) ) then
			GameTooltip:ClearAllPoints(); GameTooltip:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
		end
		local saved = SS.DB().places.GameTooltip;
		if ( type(saved) == "table" and saved.x and saved.y ) then SS.SetRootPosition(GameTooltip, saved.x, saved.y); end
		GameTooltip:Hide();
	end
	if ( on ) then
		SS.Safe(SS.PrepareChatWindow);
		-- Reparent the stock XP bar only after the player explicitly opens the mover.
		SS.Safe(SS.DetachExperienceBar);
		SS.Safe(SS.PlaceAll);
	end
	if ( not on ) then SS.HideElementMenu(); end
	if ( not on ) then SS.Safe(SS.EndPreviewsIfDone); end   -- the sample party and target go when nothing previews them
	if ( on ) then
		-- Leave the settings/menu window before presenting the in-world mover and its Done control.
		if ( SS.win ) then SS.win:Hide(); end
	end
	if ( on ) then SS.ShowEditGrid(); else SS.HideEditGrid(); end
	local available = SS.AvailableElements();
	for i = 1, table.getn(SS.MOVABLE) do
		local name = SS.MOVABLE[i][1];
		-- in the setup the elements turned on there have handles; otherwise every element (or the one chosen)
		local wanted = not SS.HiddenInSetup(name) and ((SS.setupActive and SS.SetupShows and SS.SetupShows(name)) or (not SS.setupActive and (not SS.editOnly or SS.editOnly == name)));
		if ( on and wanted and SS.HandleAllowed(name, available) ) then
			local ok, h = SS.Safe(SS.Handle, name, SS.MOVABLE[i][2]);
			if ( ok and h ) then h:Show(); end
		elseif ( SS.handles[name] ) then
			SS.handles[name]:Hide();
		end
		if ( SS.DB().muted[name] ) then SS.Safe(SS.ApplyFeatureMute, name); end
	end
	SS.Safe(SS.UpdateLevelButton);
	SS.Safe(SS.UpdateMeter);
	-- while unlocked the action bar uses the movable layout; locked again with no custom layout, the game's own returns
	if ( not on ) then
		local d = SS.DB();
		if ( not d.showRacialAbility and not d.plainBar and d.orientations.MainMenuBar ~= "vertical" and type(d.sizes.MainMenuBar) ~= "table" ) then
			SS.Safe(SS.RestoreNativeActionBarLayout);
		end
	end
	if ( not quiet ) then K.Print(NAME, on and "drag a handle to move it; right-click for its settings, size and layout. Shift-left-click hides/shows a feature. Use Lock UI when done." or "the UI is locked."); end
end

SS.tooltipOwnerOriginal = nil;
SS.tooltipShowOriginal = nil;
function SS.HookTooltipOwner()
	if ( not GameTooltip or SS.tooltipOwnerOriginal or not GameTooltip.SetOwner ) then return; end
	SS.tooltipOwnerOriginal = GameTooltip.SetOwner;
	GameTooltip.SetOwner = function(self, owner, anchor, x, y)
		SS.tooltipOwnerOriginal(self, owner, anchor, x, y);
		self.slimSample = nil;                                -- a real tooltip replaces the sample
		if ( self.SetClampedToScreen ) then self:SetClampedToScreen(true); end
		-- Leave every tooltip at the game's own size until the player resizes it or moves it.
		if ( not SS.DB().tooltipCustom and not SS.DB().unlocked ) then return; end
		-- the chosen width; the height is whatever the text needs (a one-line tooltip stays one line tall)
		local size = SS.DB().sizes.GameTooltip;
		if ( type(size) ~= "table" ) then size = { w = 260, h = 140 }; end
		self:SetWidth(size.w);
		local p = SS.DB().places.GameTooltip;
		if ( SS.DB().unlocked and type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" ) then
			SS.SetRootPosition(self, p.x, p.y);
		end
	end;
	-- the tooltips the game puts in its usual corner (units in the world, unit frames, most of the HUD) go where the
	-- player moved the tooltip, in a run as well as while editing; tooltips pinned to a button stay by their button
	if ( type(GameTooltip_SetDefaultAnchor) == "function" and not SS.tooltipDefaultOriginal ) then
		SS.tooltipDefaultOriginal = GameTooltip_SetDefaultAnchor;
		GameTooltip_SetDefaultAnchor = function(tooltip, parent)
			SS.tooltipDefaultOriginal(tooltip, parent);
			if ( tooltip == GameTooltip ) then SS.Safe(SS.PlaceTooltip, tooltip); end
		end;
	end
	if ( GameTooltip.Show and not SS.tooltipShowOriginal ) then
		SS.tooltipShowOriginal = GameTooltip.Show;
		GameTooltip.Show = function(self)
			local size = (SS.DB().tooltipCustom or SS.DB().unlocked) and SS.DB().sizes.GameTooltip or nil;
			-- Set wrapping width before the game lays out its rows. Applying it only after Show
			-- leaves the old row heights in place and lets long text paint outside the tooltip.
			if ( type(size) == "table" and size.w ) then self:SetWidth(size.w); end
			SS.tooltipShowOriginal(self);
		end;
	end
end
