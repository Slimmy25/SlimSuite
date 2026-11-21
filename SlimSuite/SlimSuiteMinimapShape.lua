-- Slim Suite: the minimap's look: square or round, the disabled minimap, the buttons around it and the mouse wheel.
local K, SU, NAME = SS.Kit, SS.SU, SS.NAME;   -- the three names every Slim Suite file uses (SlimSuiteCore.lua)

-- "Square minimap": the minimap's mask is swapped between the round and the square texture. Some clients
-- have no mask API at all, so this is checked and reported rather than assumed.
-- the square mask is Slim Suite's own full-size white square: the game's tiny 8x8 white texture cuts the whole map out
SlimSuiteMinimapMask = { round = "Textures\\MinimapMask", square = "Interface\\AddOns\\SlimSuite\\textures\\MinimapSquare" };
-- A disabled minimap is hidden outright: the map picture is drawn by the game itself and ignores fading, so making the
-- minimap see-through (how other elements are hidden) left the map showing. Checked every second; while the setup is
-- open it stays visible so it can be turned on again.
function SS.EnforceMinimapDisabled()
	if ( not MinimapCluster ) then return; end
	local off = SS.DB().elementModes.MinimapCluster == "disabled" and not SS.setupActive;
	if ( off ) then
		if ( MinimapCluster:IsShown() ) then MinimapCluster:Hide(); end
		SS.minimapHiddenByUs = true;
	elseif ( SS.minimapHiddenByUs ) then
		SS.minimapHiddenByUs = nil;
		MinimapCluster:Show(); if ( Minimap ) then Minimap:Show(); end
	end
end
SS.Every("minimapDisabled", 1, function() SS.Safe(SS.EnforceMinimapDisabled); SS.Safe(SS.ApplyMinimapExtras); end);

-- Optional minimap parts to hide: the day / night (sun and moon) button, the zone name with its X button, and the
-- + / - zoom buttons. They are faded out and made unclickable (not hidden, so the round / square layouts that place
-- them keep working), checked every second; turning an option off brings the part back.
SS.MINIMAP_EXTRAS = {
	minimapHideDayNight = { "GameTimeFrame" },
	minimapHideZone = { "MinimapZoneTextButton", "MinimapBorderTop", "MinimapToggleButton" },
	minimapHideZoom = { "MinimapZoomIn", "MinimapZoomOut" },
};
function SS.ApplyMinimapExtras()
	local d = SS.DB();
	for key, names in pairs(SS.MINIMAP_EXTRAS) do
		local hide = d[key] and true or false;
		for _, n in ipairs(names) do
			local f = getglobal(n);
			if ( f and f.SetAlpha ) then
				if ( hide ) then
					f:SetAlpha(0); if ( f.EnableMouse ) then f:EnableMouse(false); end
					f.slimExtraHidden = true;
				elseif ( f.slimExtraHidden ) then
					f.slimExtraHidden = nil; f:SetAlpha(1); if ( f.EnableMouse ) then f:EnableMouse(true); end
				end
			end
		end
	end
end

function SS.ApplyMinimapShape()
	if ( not Minimap ) then return false; end
	if ( SS.DB().elementModes.MinimapCluster == "enabled" ) then
		Minimap:Show();
		if ( MinimapCluster ) then
			MinimapCluster:Show();
			if ( not SS.DB().muted.MinimapCluster ) then MinimapCluster:SetAlpha(1); end
		end
	end
	-- Capture the round map's original appearance before the square/transparent options hide either border.
	SS.Safe(SS.ApplyMinimapTransparency);
	local square = SS.DB().minimapSquare and true or false;
	if ( square and not SS.squareMapPoints and Minimap:GetNumPoints()>0 ) then
		SS.squareMapPoints={};
		for i=1,Minimap:GetNumPoints() do
			local a,b,c,x,y=Minimap:GetPoint(i); SS.squareMapPoints[i]={a,b,c,x or 0,y or 0};
		end
		Minimap:ClearAllPoints();
		for _,p in ipairs(SS.squareMapPoints) do Minimap:SetPoint(p[1],p[2],p[3],p[4],p[5]-6); end
	elseif ( not square and SS.squareMapPoints ) then
		Minimap:ClearAllPoints();
		for _,p in ipairs(SS.squareMapPoints) do Minimap:SetPoint(p[1],p[2],p[3],p[4],p[5]); end
		SS.squareMapPoints=nil;
	end

	local ok = false;
	if ( Minimap.SetMaskTexture ) then
		ok = SS.Safe(Minimap.SetMaskTexture, Minimap, square and SlimSuiteMinimapMask.square or SlimSuiteMinimapMask.round);
	else
		ok = not square;                                      -- a round transparent map still works without mask support
	end
	SS.squareActive = square and ok and true or false;
	SS.Safe(SS.ArrangeEdgeButtons, square and ok);   -- the buttons follow the shape the map really has
	if ( MinimapBorder ) then if ( SS.squareActive or SS.DB().minimapTransparent ) then MinimapBorder:Hide(); else MinimapBorder:Show(); end end
	SS.Safe(SS.SquareFrame, square and ok);
	SS.Safe(SS.ApplyMinimapTransparency);
	if ( square and ok ) then SS.Safe(SS.ClockFollowsMap); end
	-- the map is only redrawn with its new shape when it changes zoom: step the zoom and back to force that
	if ( ok and Minimap.GetZoom and Minimap.SetZoom and Minimap.GetZoomLevels ) then
		local zoom, levels = Minimap:GetZoom(), Minimap:GetZoomLevels();
		local other = (zoom < levels - 1) and zoom + 1 or zoom - 1;
		if ( other >= 0 ) then SS.Safe(Minimap.SetZoom, Minimap, other); SS.Safe(Minimap.SetZoom, Minimap, zoom); end
	end
	return ok;
end

local minimapOriginalAlpha;
function SS.ApplyMinimapTransparency()
	if ( not Minimap ) then return; end
	if ( minimapOriginalAlpha == nil and Minimap.GetAlpha ) then
		local alpha = Minimap:GetAlpha(); minimapOriginalAlpha = type(alpha) == "number" and alpha > 0 and alpha or 1;
	end
	local transparent = SS.DB().minimapTransparent and true or false;
	if ( Minimap.SetAlpha ) then Minimap:SetAlpha(transparent and 0.58 or (minimapOriginalAlpha or 1)); end
	if ( MinimapBorder ) then
		if ( transparent or SS.squareActive ) then MinimapBorder:Hide();
		else MinimapBorder:Show(); end
	end
	if ( MinimapBorderTop ) then
		if ( transparent ) then MinimapBorderTop:Hide(); else MinimapBorderTop:Show(); end
	end
	if ( SS.squareTitle ) then
		SS.squareTitle:Hide(); -- retire the replacement header; both shapes use the native title
		if ( SS.squareTitle.bg ) then if ( transparent ) then SS.squareTitle.bg:Hide(); else SS.squareTitle.bg:Show(); end end
		if ( SS.squareTitle.line ) then if ( transparent ) then SS.squareTitle.line:Hide(); else SS.squareTitle.line:Show(); end end
	end
	if ( SS.squareRing ) then if ( transparent or not SS.squareActive ) then SS.squareRing:Hide(); else SS.squareRing:Show(); end end
end

-- The square map's gold ring: a gold band like the round map's border, with a dark line on each side of it. The zone's
-- name sits on a small plate centred on its top edge, as the round map's name sits on its top.
function SS.SquareFrame(on)
	if ( not Minimap ) then return; end
	local ring = SS.squareRing;
	if ( on and not ring ) then
		ring = CreateFrame("Frame", "SlimSuiteSquareRing", Minimap);
		ring:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 2);
		ring:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -5, 5); ring:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 5, -5);
		local function Band(inset, width, r, g, b)
			local t = {};
			for i = 1, 4 do t[i] = ring:CreateTexture(nil, "OVERLAY"); t[i]:SetTexture(r, g, b, 1); end
			t[1]:SetPoint("TOPLEFT", ring, "TOPLEFT", inset, -inset); t[1]:SetPoint("TOPRIGHT", ring, "TOPRIGHT", -inset, -inset); t[1]:SetHeight(width);
			t[2]:SetPoint("BOTTOMLEFT", ring, "BOTTOMLEFT", inset, inset); t[2]:SetPoint("BOTTOMRIGHT", ring, "BOTTOMRIGHT", -inset, inset); t[2]:SetHeight(width);
			t[3]:SetPoint("TOPLEFT", ring, "TOPLEFT", inset, -inset); t[3]:SetPoint("BOTTOMLEFT", ring, "BOTTOMLEFT", inset, inset); t[3]:SetWidth(width);
			t[4]:SetPoint("TOPRIGHT", ring, "TOPRIGHT", -inset, -inset); t[4]:SetPoint("BOTTOMRIGHT", ring, "BOTTOMRIGHT", -inset, inset); t[4]:SetWidth(width);
		end
		-- the colours of the round map's own ring (measured from it): a dark rim, the worn gold, its lighter middle,
		-- a darker bronze inside it and a dark inner edge
		Band(0, 1, 0.12, 0.08, 0.02);
		Band(1, 3, 0.65, 0.51, 0.20);
		Band(2, 1, 0.73, 0.58, 0.24);
		Band(4, 1, 0.40, 0.34, 0.18);
		Band(5, 1, 0.12, 0.09, 0.03);
		-- the ring is part of the square map, not a setting of its own: it can only show while the map is square
		ring:SetScript("OnShow", function() if ( not SS.squareActive ) then this:Hide(); end end);
		SS.squareRing = ring;
	end
	if ( ring ) then if ( on and not SS.DB().minimapTransparent ) then ring:Show(); else ring:Hide(); end end
	-- Preserve the game's exact subzone name, native typeface, title plate and close button.
	if ( SS.squareTitle ) then SS.squareTitle:Hide(); end
	local zone = MinimapZoneTextButton;
	if ( zone and zone.slimSquareOrig ) then
		local o = zone.slimSquareOrig; zone.slimSquareOrig = nil;
		zone:ClearAllPoints(); if ( o[2] ) then zone:SetPoint(o[1], o[2], o[3], o[4], o[5]); end
		if ( zone.slimSquareStrata ) then zone:SetFrameStrata(zone.slimSquareStrata); end
		if ( zone.slimSquareLevel ) then zone:SetFrameLevel(zone.slimSquareLevel); end
		zone.slimSquareWasShown, zone.slimSquareStrata, zone.slimSquareLevel, zone.slimSquareAlpha = nil, nil, nil, nil;
	end
	if ( zone ) then zone:SetAlpha(1); zone:Show(); end
end

-- Restore native chrome after a legacy containment pass suppressed a texture or its
-- parent was clipped. Keep the ring below the native controls rather than moving them.
function SS.RestoreMinimapChrome()
	if ( not Minimap or not MinimapCluster ) then return; end
	if ( SS.DB().elementModes.MinimapCluster~="enabled" ) then return; end
	if ( MinimapCluster.SetClipsChildren ) then MinimapCluster:SetClipsChildren(false); end
	if ( Minimap.SetClipsChildren ) then Minimap:SetClipsChildren(false); end
	if ( SS.EnforceElementBounds ) then SS.EnforceElementBounds(MinimapCluster,true); end
	local level=(Minimap:GetFrameLevel() or 1)+10;
	for _,name in ipairs({"MinimapZoomIn","MinimapZoomOut","MinimapToggleButton","MiniMapWorldMapButton","GameTimeFrame"}) do
		local control=getglobal(name);
		if ( control ) then
			if ( SS.EnforceElementBounds ) then SS.EnforceElementBounds(control,true); end
			control:SetAlpha(1);
			if ( control.SetFrameLevel ) then control:SetFrameLevel(math.max(control:GetFrameLevel() or 1,level)); end
			if ( control.Show ) then control:Show(); end
		end
	end
end

-- The game's own clock is made for the round map in its first place. Once the map is square or has been moved,
-- Slim Suite's clock takes over (it hangs under the map wherever the map goes) so the two never clash.
function SS.ClockFollowsMap()
	local d = SS.DB();
	if ( d.replaceLocalClock ) then return; end
	-- A square or moved map must respect the clock's explicit Default/Disabled choice.
	local mode = d.elementModes and d.elementModes.SlimSuiteLocalClockFrame;
	if ( mode == "default" or mode == "disabled" ) then return; end
	SS.SetLocalClockOn(true);
	if ( SS.Notice ) then SS.Notice("Slim Suite's clock now replaces the game's, so it stays with the map."); end
end

-- With the square minimap, the buttons around it follow the square: the zoom buttons stand one above the other at
-- its right edge, and every other minimap button (the game's own, the day/night moon, other addons' and Slim Suite's
-- gear) lines up in a column down its left edge. Switching back to round puts each one back where it was.
-- Gathered buttons and the buttons in their own row are left to those layouts; the map's pins are never touched (they
-- have no name), and neither is the minimap's close button.
SS.SQUARE_KNOWN = { MinimapZoomIn = true, MinimapZoomOut = true, MinimapToggleButton = true, MiniMapWorldMapButton = true,
	WorldMapFrameMinimizeButton = true, GameTimeFrame = true, MiniMapTrackingFrame = true,
	MiniMapMailFrame = true, MiniMapBattlefieldFrame = true, MiniMapMeetingStoneFrame = true };
SS.SQUARE_SKIP = { MinimapPing = true, MinimapToggleButton = true, MinimapZoneTextButton = true };
-- true while the square layout places the buttons (the minimap buttons' "Around the minimap" choice)
function SS.SquareColumn()
	return SS.squareActive and SS.MinimapButtonPlace() == "ring";
end
function SS.ArrangeEdgeButtons(square)
	if ( not Minimap or not Minimap.GetCenter ) then return; end
	local mx, my = Minimap:GetCenter();
	if ( not mx ) then return; end
	local ms = SS.EffectiveScale(Minimap);
	local half = (Minimap:GetWidth() or 140) / 2;
	local halfH = (Minimap:GetHeight() or 140) / 2;
	local column = square and SS.MinimapButtonPlace() == "ring";
	local left, zoomIn, zoomOut = {}, nil, nil;
	for _, root in ipairs({ Minimap, MinimapCluster }) do
		local kids = { root:GetChildren() };
		for i = 1, table.getn(kids) do
			local f = kids[i];
			local name = f and f.GetName and f:GetName();
			if ( name and f ~= SS.Mini and f ~= Minimap and not f.slimOrig and not f.slimBarOrig and not SS.SQUARE_SKIP[name]
				and string.sub(name, 1, 9) ~= "SlimSuite" ) then
				local w, h = f:GetWidth() or 0, f:GetHeight() or 0;
				if ( w > 0 and w <= 40 and h > 0 and h <= 40 ) then
					if ( column ) then
						-- a button joins the layout once: the game's own by name, another addon's if it sits around the edge
						local member = f.slimSquareOrig ~= nil or SS.SQUARE_KNOWN[name];
						if ( not member ) then
							local fx, fy = f:GetCenter();
							if ( fx ) then
								local fs = SS.EffectiveScale(f);
								local dx, dy = fx * fs / ms - mx, fy * fs / ms - my;
								member = math.sqrt(dx * dx + dy * dy) >= half * 0.75;
							end
						end
						if ( member ) then
							if ( not f.slimSquareOrig ) then
								local p, rel, rp, x, y = f:GetPoint(1);
								f.slimSquareOrig = { p, rel, rp, x or 0, y or 0 };
								-- its place around the round ring, kept as an angle: on the square it sits on the ring at that angle
								local fx, fy = f:GetCenter();
								if ( fx ) then
									local fs = SS.EffectiveScale(f);
									f.slimSquareAngle = (math.atan2 or math.atan)(fy * fs / ms - my, fx * fs / ms - mx);
								end
							end
							if ( name == "MinimapZoomIn" ) then zoomIn = f;
							elseif ( name == "MinimapZoomOut" ) then zoomOut = f;
							else table.insert(left, f); end
						end
					elseif ( f.slimSquareOrig ) then
						local o = f.slimSquareOrig;
						f.slimSquareOrig = nil;
						f:ClearAllPoints();
						if ( o[2] ) then f:SetPoint(o[1], o[2], o[3], o[4], o[5]); end
					end
				end
			end
		end
	end
	if ( column ) then
		-- a button's offsets are in its own scale; sizes and places here are in the minimap's
		local function Put(f, x, y)
			local k = ms / (SS.EffectiveScale(f));
			f:ClearAllPoints();
			f:SetPoint("CENTER", Minimap, "CENTER", x * k, y * k);
		end
		local function Size(f)
			local k = ms / (SS.EffectiveScale(f));
			return (f:GetWidth() or 32) / k, (f:GetHeight() or 32) / k;
		end
		-- every button sits centred on the gold ring at the angle it had around the round map, as the round map does
		local function OnRing(f, angle)
			local x, y = math.cos(angle), math.sin(angle);
			local most = math.max(math.abs(x), math.abs(y));
			if ( most > 0 ) then x, y = x / most, y / most; end
			Put(f, x * (half + 3), y * (halfH + 3));
		end
		if ( zoomIn ) then table.insert(left, zoomIn); end
		if ( zoomOut ) then table.insert(left, zoomOut); end
		for i = 1, table.getn(left) do
			local f = left[i];
			local angle = f.slimSquareAngle;
			if ( not angle ) then angle = math.rad(150 + i * 20); end
			OnRing(f, angle);
		end
	end
	if ( SS.Mini and SS.Mini.Place ) then SS.Safe(SS.Mini.Place); end
end

-- buttons that appear later (new mail, a queue, another addon's button) join the square's column
SS.Every("squareEdge", 1, function()
	SS.RestoreMinimapChrome();
	if ( SS.SquareColumn() ) then SS.ArrangeEdgeButtons(true); end

	-- the ring and the round border always match the map's real shape, whatever else showed or hid them
	local ring = SS.squareRing;
	if ( ring and ring:IsShown() and not SS.squareActive ) then ring:Hide(); end
	if ( ring and not ring:IsShown() and SS.squareActive and not SS.DB().minimapTransparent ) then ring:Show(); end
	if ( MinimapBorder and SS.squareActive and MinimapBorder:IsShown() ) then MinimapBorder:Hide(); end
end);

-- The mouse wheel over the minimap zooms it, as the + and - buttons do.
function SS.MinimapWheel(delta)
	if ( not Minimap or not Minimap.GetZoom or not Minimap.SetZoom ) then return; end
	local zoom = Minimap:GetZoom() or 0;
	local levels = Minimap.GetZoomLevels and Minimap:GetZoomLevels() or 6;
	if ( delta > 0 and zoom < levels - 1 ) then
		if ( type(Minimap_ZoomInClick) == "function" ) then Minimap_ZoomInClick(); else Minimap:SetZoom(zoom + 1); end
	elseif ( delta < 0 and zoom > 0 ) then
		if ( type(Minimap_ZoomOutClick) == "function" ) then Minimap_ZoomOutClick(); else Minimap:SetZoom(zoom - 1); end
	end
end
if ( Minimap and Minimap.EnableMouseWheel and not Minimap:GetScript("OnMouseWheel") ) then
	Minimap:EnableMouseWheel(true);
	Minimap:SetScript("OnMouseWheel", function() SS.Safe(SS.MinimapWheel, arg1 or 0); end);
end

function SS.SetMinimapSquare(on)
	SS.DB().minimapSquare = on and true or false;
	if ( not SS.ApplyMinimapShape() ) then
		K.Print(NAME, "this client cannot change the minimap's shape.");
	end
end

function SS.SetMinimapTransparent(on)
	SS.DB().minimapTransparent = on and true or false;
	SS.Safe(SS.ApplyMinimapShape);
	SS.Safe(SS.ApplyMinimapTransparency);
end

function SS.ApplyTallyLayout(resetSize)
	if ( not SS.tallyFrame ) then return; end
	if ( resetSize ) then SS.DB().sizes.SlimSuiteTallyFrame = nil; end
	SS.PlaceAll();
	SS.UpdateTally();
end
