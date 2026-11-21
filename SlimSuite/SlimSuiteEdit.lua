-- Slim Suite: your buffs in the party, the minimap, Edit mode, the element menus and the tooltip.
local K, SU, NAME = SS.Kit, SS.SU, SS.NAME;   -- the three names every Slim Suite file uses (SlimSuiteCore.lua)

-- Buffs above the party plates (yours and your friends'): they line up with the plate's portrait and fill rows to
-- the right, each row stopping before the next party member's frame (or the plate's own right edge when the party is
-- a column). At most two rows fit between the plate and the next visible element, including duration text.
function SS.PartyBuffsActive()
	local d = SS.DB();
	return d.partyIncludesSelf and d.buffsOnPlayer and not d.buffsOnTarget and BuffFrame and true or false;
end
-- Shared bounds exclude decorative padding and never extend into a neighboring frame.
function SS.BuffRoom(plate, portrait, nextFrame)
	local box=SS.AuraFrameBounds(plate,portrait); if ( not box ) then return nil; end
	local right=box.right;
	if ( nextFrame and nextFrame:IsShown() and SS.CurrentOrientation("PartyMemberFrame1")=="horizontal" ) then
		local neighbor=SS.AuraFrameBounds(nextFrame);
		if ( neighbor and neighbor.left>box.left ) then right=math.min(right,neighbor.left-4*SS.EffectiveScale(plate)); end
	end
	return box.left,math.max(0,right-box.left),box.top;
end
function SS.LayoutBuffRows(buttons, parent, plate, portrait, nextFrame, side)
	return SS.LayoutBoundedAuras(buttons,plate,portrait,nextFrame,side);
end
function SS.LayoutPartyBuffs()
	if ( not BuffFrame ) then return; end
	local d=SS.DB();
	local side=d.buffsOnTarget and d.buffsOnTargetSide or d.buffsOnPlayerSide;
	if ( d.partyIncludesSelf and (side=="left" or side=="right") ) then side="above"; end
	local active=(d.buffsOnPlayer or d.buffsOnTarget) and (side=="above" or side=="below") and not (d.frameDefault and d.frameDefault.BuffFrame);
	if ( not active ) then
		if ( SS.partyBuffsLaid ) then
			SS.partyBuffsLaid = nil;
			for _,entry in ipairs(SS.BuffButtons()) do
				local b = entry[2];
				local o = b and b.slimPartyOrig;
				if ( b ) then SS.RestoreAuraButton(b); end
				if ( o ) then b.slimPartyOrig = nil; b:ClearAllPoints(); if ( o[2] ) then b:SetPoint(o[1], o[2], o[3], o[4], o[5]); end end
			end
		end
		SS.playerAuraBounds=nil;
		for _,sample in pairs(SS.BuffSamples()) do SS.RestoreAuraButton(sample); end
		return;
	end
	local P,T = SS.Pair();
	if ( d.buffsOnTarget ) then P=T; end
	if ( not P ) then return; end
	local shown = {};
	for _,entry in ipairs(SS.BuffButtons()) do
		local b = entry[2];
		if ( b ) then
			if ( not b.slimPartyOrig ) then local p, rel, rp, x, y = b:GetPoint(1); b.slimPartyOrig = { p, rel, rp, x or 0, y or 0 }; end
			if ( b:IsShown() ) then table.insert(shown, b); end
		end
	end
	local nextFrame = getglobal("PartyMemberFrame1");
	if ( nextFrame == P ) then nextFrame = nil; end
	for _,sample in pairs(SS.BuffSamples()) do if ( sample:IsShown() ) then table.insert(shown,sample); end end
	local layout=SS.LayoutBuffRows(shown,BuffFrame,P,SS.UnitPortrait(P),nextFrame,side);
	if ( layout ) then
		local scale=SS.EffectiveScale(BuffFrame);
		BuffFrame:SetWidth(math.max(1,(layout.right-layout.left)/scale));
		BuffFrame:SetHeight(math.max(1,(layout.top-layout.bottom)/scale));
	end
	SS.partyBuffsLaid = true;
end
SS.Every("partyBuffs", 0.25, function() if ( SS.DB().buffsOnPlayer or SS.DB().buffsOnTarget or SS.partyBuffsLaid ) then SS.Safe(SS.LayoutPartyBuffs); end end);

-- Your friends' buffs, above each friend's plate in the same way (classic plates only; "Party members' buffs" in the
-- party's menu). The icons are Slim Suite's own, read from UnitBuff; hover one for its name.
SS.FRIEND_BUFFS = 16;
function SS.FriendBuffsOn()
	local d = SS.DB();
	return d.partyMemberBuffs ~= false and SS.Look("PartyMemberFrame1") ~= "thin";
end
function SS.UpdateFriendBuffs()
	SS.LayoutPartyBuffs();
	local on = SS.FriendBuffsOn();
	local size = SS.PartyBuffsActive() and BuffFrame and (getglobal("BuffButton0") or getglobal("BuffButton1")) or nil;
	local icon = 16;
	if ( size and size.GetHeight ) then icon = math.max(10, math.min(22, (size:GetHeight() or 30) * (BuffFrame:GetScale() or 1))); end
	SS.friendBuffs = SS.friendBuffs or {};
	for i = 1, 4 do
		local f = getglobal("PartyMemberFrame" .. i);
		local unit = "party" .. i;
		local set = SS.friendBuffs[i];
		if ( not set and f ) then
			set = {};
			for j = 1, SS.FRIEND_BUFFS do
				local b = CreateFrame("Button", nil, UIParent);
				b:SetFrameStrata("MEDIUM");
				b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints(b);
				b.unit, b.index = unit, j;
				b:SetScript("OnEnter", function()
					if ( GameTooltip and GameTooltip.SetUnitBuff ) then GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT"); GameTooltip:SetUnitBuff(this.unit, this.index); end
				end);
				b:SetScript("OnLeave", function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
				b:Hide();
				set[j] = b;
			end
			SS.friendBuffs[i] = set;
		end
		if ( set ) then
			local shown = {};
			local exists = on and f and f:IsShown() and UnitExists and UnitExists(unit);
			for j = 1, SS.FRIEND_BUFFS do
				local b = set[j];
				SS.RestoreAuraButton(b);
				local tex = exists and UnitBuff and UnitBuff(unit, j);
				if ( tex ) then
					b.tex:SetTexture(tex); b:SetWidth(icon); b:SetHeight(icon); b:SetScale(SS.EffectiveScale(f) / SS.EffectiveScale(UIParent));
					b:Show(); table.insert(shown, b);
				else b:Hide(); end
			end
			if ( table.getn(shown) > 0 ) then
				SS.LayoutBuffRows(shown, shown[1], f, getglobal("PartyMemberFrame" .. i .. "Portrait"), getglobal("PartyMemberFrame" .. (i + 1)));
			end
		end
	end
end
SS.Every("friendBuffs", 0.5, function() SS.Safe(SS.UpdateFriendBuffs); end);

-- Every tick box that shows a setting, wherever it is: the setup, the right-click menu, the settings window, the move
-- panel. A click always flips the setting itself (not whatever the box happened to show), and afterwards every visible
-- box reads its setting again. One setting can be shown in two places, and turning one setting on can turn another off
-- (the newest choice wins); a box left showing the old value only set the value it already had when clicked, which
-- looked like the box did nothing.
SS.toggleBoxes = {};
function SS.TrackToggle(cb)
	table.insert(SS.toggleBoxes, cb);
	return cb;
end
function SS.FlipToggle(get, set)
	if ( SS.MarkProfileDirty ) then SS.MarkProfileDirty(); end
	if ( type(get) ~= "function" or type(set) ~= "function" ) then return; end
	SS.ChangeSetting(get, set, not (get() and true or false));
end
-- which rows of a page are shown right now, as a string; the page is only laid out again when this changes
function SS.PageSignature(page)
	local parts = {};
	for i = 1, table.getn(page.rows) do
		local r = page.rows[i];
		parts[i] = (not (r.up and not r.up())) and "1" or "0";
	end
	return table.concat(parts);
end

function SS.RefreshToggles()
	for i = 1, table.getn(SS.toggleBoxes) do
		local cb = SS.toggleBoxes[i];
		if ( cb.get and cb:IsVisible() ) then
			local ok, v = pcall(cb.get);
			if ( ok ) then cb:SetChecked(v and 1 or nil); end
			if ( cb.cond ) then
				local okc, c = pcall(cb.cond);
				if ( okc and not c ) then cb:Disable(); if ( cb.label ) then cb.label:SetTextColor(0.45, 0.45, 0.45); end
				else cb:Enable(); if ( cb.label ) then cb.label:SetTextColor(1, 1, 1); end end
			end
		end
	end
	if ( SS.RefreshChoices ) then SS.RefreshChoices(); end
	for i = 1, table.getn(SS.pages or {}) do
		local page = SS.pages[i];
		local sig = SS.PageSignature(page);
		if ( page.sig ~= sig ) then page.sig = sig; SS.LayoutPage(page); end
	end
end
-- the boxes are read again twice a second as well, for settings changed by a slash command or by the game
-- (only while one of those windows is open)
SS.Every("toggleRefresh", 0.5, function()
	local panel = getglobal("SlimSuiteSetupPanel");
	if ( (SS.win and SS.win:IsShown()) or (panel and panel:IsShown()) ) then SS.RefreshToggles(); end
end);


function SS.SetMirrorTarget(on)
	-- Mirroring is a combined custom layout. In the setup list, selecting it opts both unit
	-- frames into Slim Suite so a later Default-state pass cannot immediately undo it.
	if ( on and SS.setupActive and SU and SU.SetMode ) then
		SU.SetMode("PlayerFrame", "enabled", SU.titles and SU.titles.PlayerFrame or "Unit frame");
		SU.SetMode("TargetFrame", "enabled", SU.titles and SU.titles.TargetFrame or "Target frame");
	end
	if ( on ) then SS.Safe(SS.ClaimTarget, "mirror"); end   -- the newest choice wins: mirroring takes the target's place
	if ( on ) then SS.MakeMovable("PlayerFrame", "Mirror target moves it"); SS.MakeMovable("TargetFrame", "Mirror target moves it"); end
	-- Mirroring and combining are one user-facing behavior: the target follows the player across the screen,
	-- and the pair uses the same frame appearance and size.
	SS.DB().mirrorTarget, SS.DB().combineTarget = on and true or false, on and true or false;
	if ( on ) then SS.Safe(SS.MirrorTarget); SS.Safe(SS.OfferMirrorBuffs); end
	SS.Safe(SS.ApplyNewFrames);
	if ( SU and SU.Rebuild ) then SS.Safe(SU.Rebuild); end
end
