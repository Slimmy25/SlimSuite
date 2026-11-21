-- Party member status on the party frames: grey when down or dead, a revive bar while you bring them back,
-- how far away they are (top-left of their face) and slightly dimmed when out of your range.
-- What the game tells us (docs/api-capabilities.md):
--   * a downed teammate's world position comes from AZS_GetDownedPartyMembers(), so their distance is exact;
--   * a standing teammate's position is not exposed, so their distance is the client's range check, shown as a band;
--   * revive progress is only known for the teammate *you* are reviving (AZS_GetRevive().reviving / rshare).
if ( setfenv ) then setfenv(1, SS.ENV); end

local OUT_OF_RANGE_ALPHA = 0.6;
local GREY = { 0.45, 0.45, 0.45 };

local function API() return SlimSuiteWorld and SlimSuiteWorld.API; end

-- the extras one party frame carries: distance text, revive bar
local function Extras(i)
	local f = getglobal("PartyMemberFrame" .. i);
	if ( not f ) then return nil; end
	if ( f.slimStatus ) then return f, f.slimStatus; end
	local s = {};
	local face = getglobal("PartyMemberFrame" .. i .. "Portrait");
	s.range = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	SS.SetGameDefaultFont(s.range, 8);
	s.range:SetPoint("TOPLEFT", face or f, "TOPLEFT", face and -2 or 2, face and 4 or -2);
	s.range:SetJustifyH("LEFT");
	s.revive = CreateFrame("StatusBar", nil, f);
	s.revive:SetWidth(70); s.revive:SetHeight(6);
	s.revive:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 46, 6);
	s.revive:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
	s.revive:SetStatusBarColor(0.35, 0.9, 1);
	s.revive:SetMinMaxValues(0, 1);
	s.revive.bg = s.revive:CreateTexture(nil, "BACKGROUND");
	s.revive.bg:SetAllPoints(s.revive); s.revive.bg:SetTexture(0, 0, 0, 0.7);
	s.revive.text = s.revive:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	SS.SetGameDefaultFont(s.revive.text, 7);
	s.revive.text:SetPoint("CENTER", s.revive, "CENTER", 0, 0);
	s.revive:Hide();
	f.slimStatus = s;
	return f, s;
end

local function SetGrey(i, on)
	local f, s = Extras(i);
	if ( not f or s.grey == on ) then return; end
	s.grey = on;
	local face = getglobal("PartyMemberFrame" .. i .. "Portrait");
	if ( face ) then
		local ok = face.SetDesaturated and face:SetDesaturated(on and 1 or nil);
		if ( not ok ) then if ( on ) then face:SetVertexColor(0.5, 0.5, 0.5); else face:SetVertexColor(1, 1, 1); end end
	end
	local name = getglobal("PartyMemberFrame" .. i .. "Name");
	if ( name ) then
		if ( on ) then name:SetTextColor(GREY[1], GREY[2], GREY[3]);
		elseif ( NORMAL_FONT_COLOR ) then name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b); end
	end
	if ( not on ) then
		-- the bars take their own colours back
		local hp = getglobal("PartyMemberFrame" .. i .. "HealthBar");
		if ( hp ) then hp:SetStatusBarColor(0, 1, 0); end
		local mana = getglobal("PartyMemberFrame" .. i .. "ManaBar");
		local unit = "party" .. i;
		if ( mana and UnitPowerType and ManaBarColor and UnitExists(unit) ) then
			local c = ManaBarColor[UnitPowerType(unit)];
			if ( c ) then mana:SetStatusBarColor(c.r, c.g, c.b); end
		end
	end
end
local function KeepGrey(i)
	for _, part in ipairs({ "HealthBar", "ManaBar" }) do
		local bar = getglobal("PartyMemberFrame" .. i .. part);
		if ( bar ) then bar:SetStatusBarColor(GREY[1], GREY[2], GREY[3]); end
	end
end

-- downed teammates by name: { x, y, space }
local function Downed()
	local A = API(); local out = {};
	if ( not A ) then return out; end
	local list = A.Call("AZS_GetDownedPartyMembers");
	if ( type(list) ~= "table" ) then return out; end
	for i = 1, table.getn(list) do
		local e = list[i];
		local name = A.Field(e, "name", "playerName", "hero");
		if ( name ) then
			local x, y = A.Pos(e);
			out[name] = { x = x, y = y, space = A.Field(e, "spaceId", "space") };
		end
	end
	return out;
end

local function RangeText(unit, down)
	local A = API();
	if ( down and down.x and A and A.PlayerPos ) then
		local px, py, space = A.PlayerPos();
		if ( px and (down.space == nil or space == nil or down.space == space) ) then
			local dx, dy = down.x - px, down.y - py;
			return math.floor(math.sqrt(dx * dx + dy * dy) + 0.5) .. " yd", true;
		end
	end
	if ( not CheckInteractDistance ) then return "", true; end
	if ( UnitIsVisible and not UnitIsVisible(unit) ) then return "100+ yd", false; end
	if ( CheckInteractDistance(unit, 3) ) then return "<10 yd", true; end
	if ( CheckInteractDistance(unit, 4) ) then return "<28 yd", true; end
	return "28+ yd", false;
end

-- the sample party in setup and Demo Mode: one member down with a revive under way, one out of range
local SAMPLE = { { range = "<10 yd" }, { range = "17 yd", grey = true, revive = 0.4 }, { range = "28+ yd", far = true }, { range = "<28 yd" } };

function SS.UpdatePartyStatus()
	local d = SS.DB();
	local classic = SS.Look("PartyMemberFrame1") ~= "thin";
	-- a hidden party (Hide feature, or the element set to Disabled) is left alone: its fade must not be undone here
	local mode = d.elementModes and d.elementModes.PartyMemberFrame1;
	if ( (d.muted and d.muted.PartyMemberFrame1) or mode == "disabled" ) then classic = false; end
	local downed, revive;
	local A = API();
	for i = 1, 4 do
		local f = getglobal("PartyMemberFrame" .. i);
		local unit = "party" .. i;
		if ( f and classic and f:IsShown() and (UnitExists(unit) or f.slimPreview) ) then
			local _, s = Extras(i);
			local grey, far, text, progress = false, false, "", nil;
			if ( f.slimPreview and not UnitExists(unit) ) then
				local sample = SAMPLE[i];
				grey, far, text, progress = sample.grey and true or false, sample.far and true or false, sample.range, sample.revive;
			else
				if ( not downed ) then downed = Downed(); end
				local name = UnitName(unit);
				local down = name and downed[name];
				grey = (down or (UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit))) and true or false;
				local inRange;
				text, inRange = RangeText(unit, down);
				far = not inRange;
				if ( revive == nil ) then revive = A and A.Call("AZS_GetRevive") or false; end
				if ( type(revive) == "table" and revive.reviving and name and revive.reviving == name ) then progress = tonumber(revive.rshare); end
			end
			grey = grey and d.partyGreyDead ~= false;
			SetGrey(i, grey);
			if ( grey ) then KeepGrey(i); end
			f.slimDimmed = (far and d.partyDimFar ~= false and not grey) and true or nil;
			f:SetAlpha((f.slimDimmed and OUT_OF_RANGE_ALPHA or 1) * (SS.ElementOpacity and SS.ElementOpacity("PartyMemberFrame1") or 100) / 100);
			if ( d.partyDistance ~= false and text ~= "" ) then s.range:SetText(text); s.range:Show(); else s.range:Hide(); end
			if ( progress and progress > 0 ) then
				progress = math.max(0, math.min(1, progress));
				s.revive:SetValue(progress); s.revive.text:SetText(math.floor(progress * 100) .. "%"); s.revive:Show();
			else s.revive:Hide(); end
		elseif ( f and f.slimStatus ) then
			SetGrey(i, false);
			if ( classic ) then f:SetAlpha(1); end
			f.slimStatus.range:Hide(); f.slimStatus.revive:Hide();
		end
	end
end

SS.Every("partyStatus", 0.2, function() SS.Safe(SS.UpdatePartyStatus); end);
