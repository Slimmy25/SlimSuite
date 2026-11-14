-- Optional enemy nameplates. Native plates use the same functions/state as 1.12's nameplate key binding;
-- the modern overlay uses the game's documented world-anchor projection and AZS_UNITS data.
if ( setfenv ) then setfenv(1, SS.ENV); end

local function ReadNativeNameplates()
	return NAMEPLATES_ON and true or false;
end
local function WriteNativeNameplates(on)
	local change = HideNameplates;
	if ( on ) then change = ShowNameplates; end
	if ( type(change) ~= "function" ) then return false; end
	local ok = SS.Safe(change);
	if ( ok ) then NAMEPLATES_ON = on and 1 or nil; end
	return ok;
end
function SS.SetNativeEnemyNameplates(on)
	local d = SS.DB();
	d.enemyNameplates = on and true or false;
	if ( d.modernEnemyFrames ) then d.modernEnemyFrames = false; SS.Safe(SS.UpdateEnemyNameplates);
	else WriteNativeNameplates(on); end
end

local plates, freePlates, requests, registered, plateSerial = {}, {}, {}, false, 0;
local function NewPlate()
	local f = table.remove(freePlates);
	-- WoW frames cannot be destroyed. Reuse the entire plate, including its children.
	if ( f ) then f:Hide(); f:ClearAllPoints(); return f; end
	plateSerial = plateSerial + 1; f = CreateFrame("Frame", "SlimSuiteEnemyNameplate" .. plateSerial, WorldFrame);
	f:SetWidth(152); f:SetHeight(42); f:SetFrameStrata("HIGH");
	if ( type(AZS_SetOnTopOfScreens) == "function" ) then SS.Safe(AZS_SetOnTopOfScreens, f, SS.DB().onTopOfScreens and true or false); end
	f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } });
	f:SetBackdropColor(0.035, 0.045, 0.06, 0.88); f:SetBackdropBorderColor(0.42, 0.68, 0.95, 0.9);
	f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -4); f.name:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -4); f.name:SetJustifyH("CENTER");
	f.health = CreateFrame("StatusBar", nil, f);
	f.health:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -19); f.health:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -19); f.health:SetHeight(7);
	f.health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); f.health:SetStatusBarColor(0.82, 0.16, 0.12);
	f.health:SetMinMaxValues(0, 1); f.health:SetValue(1);
	f.health.bg = f.health:CreateTexture(nil, "BACKGROUND"); f.health.bg:SetAllPoints(f.health); f.health.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar"); f.health.bg:SetVertexColor(0.04, 0.025, 0.025, 0.9);
	f.hpText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.hpText:SetPoint("TOP", f.health, "BOTTOM", 0, 1);
	f.mark = f:CreateTexture(nil, "OVERLAY"); f.mark:SetWidth(16); f.mark:SetHeight(16); f.mark:SetPoint("BOTTOM", f.name, "TOP", 0, -1); f.mark:Hide();
	f.dots = {};
	for i = 1, 6 do
		local dot = CreateFrame("Frame", nil, f); dot:SetWidth(17); dot:SetHeight(17);
		dot.icon = dot:CreateTexture(nil, "ARTWORK"); dot.icon:SetAllPoints(dot); dot.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
		dot.time = dot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); dot.time:SetPoint("TOP", dot, "BOTTOM", 0, 1);
		f.dots[i] = dot; dot:Hide();
	end
	f:Hide();
	return f;
end

local function UpdatePlateData(record, unit)
	local f = record.frame or NewPlate();
	record.frame = f;
	f.name:SetText(record.name or (unit and unit.name) or "Enemy");
	if ( unit and tonumber(unit.hpm) and tonumber(unit.hpm) > 0 ) then
		local hp, max = tonumber(unit.hp) or 0, tonumber(unit.hpm);
		f.health:SetMinMaxValues(0, max); f.health:SetValue(hp); f.health:Show();
		f.hpText:SetText(tostring(math.floor(hp + 0.5)) .. " / " .. tostring(math.floor(max + 0.5))); f.hpText:Show();
	else f.health:Hide(); f.hpText:SetText(""); f.hpText:Hide(); end
	local mark = unit and SlimSuiteWorld and SlimSuiteWorld.MarkFor and SlimSuiteWorld.MarkFor(unit.id);
	if ( mark and SlimSuiteWorld.SetRaidIcon ) then SlimSuiteWorld.SetRaidIcon(f.mark, mark); else f.mark:Hide(); end
	local debuffs = {};
	if ( SS.DB().enemyPlateDebuffs and unit and (unit.kind == "boss" or unit.kind == "final" or unit.kind == "guardian") and AZS_GetDebuffs ) then
		local ok, values = SS.Safe(AZS_GetDebuffs, unit.id);
		if ( ok and type(values) == "table" ) then debuffs = values; end
	end
	for i = 1, table.getn(f.dots) do
		local dot, entry = f.dots[i], debuffs[i];
		if ( entry and entry.icon ) then
			local icon = entry.icon;
			if ( type(icon) == "string" and not string.find(icon, "\\", 1, true) ) then icon = "Interface\\Icons\\" .. icon; end
			dot.icon:SetTexture(icon);
			local left = tonumber(entry.remaining);
			if ( left and left >= 0 ) then dot.time:SetText(left >= 10 and tostring(math.floor(left + 0.5)) or string.format("%.1f", left)); else dot.time:SetText(""); end
			dot:ClearAllPoints(); dot:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 4 + ((i - 1) * 19), -1); dot:Show();
		else dot:Hide(); end
	end
end

local function ReadCatalog()
	if ( type(AZS_GetWorldAnchors) ~= "function" ) then return; end
	local d = SS.DB();
	local kinds;
	if ( d.enemyBossesOnly ) then kinds = { "boss", "finalBoss", "guardian" };
	else kinds = { "enemy", "elite", "boss", "finalBoss", "guardian" }; end
	local q = { kinds = kinds, states = { "alive" } };
	local current, cursor, pages, accepted = {}, nil, 0, 0;
	repeat
		local ok, page = SS.Safe(AZS_GetWorldAnchors, q, cursor, 256);
		if ( not ok or type(page) ~= "table" or type(page.entries) ~= "table" ) then return; end
		for i = 1, table.getn(page.entries) do
			local entry = page.entries[i];
			if ( type(entry) == "table" and entry.anchorId and entry.state == "alive" ) then
				local kind = entry.kind;
				if ( not d.enemyBossesOnly or kind == "boss" or kind == "finalBoss" or kind == "guardian" ) then
					if ( current[entry.anchorId] or accepted < 64 ) then
						-- Do not mutate live records until every requested page has arrived.
						local record = { anchorId = entry.anchorId };
						record.name, record.kind, record.unitId = entry.name, kind, entry.unitId;
						if ( not current[entry.anchorId] ) then accepted = accepted + 1; end
						current[entry.anchorId] = record;
					end
				end
			end
		end
		cursor = page.nextCursor; pages = pages + 1;
		if ( page.hasMore and (not cursor or pages >= 32) and accepted < 64 ) then return; end
	until not page.hasMore or accepted >= 64
	-- Release retired plates before allocating replacements, keeping the pool bounded at 64.
	for id, record in pairs(plates) do
		if ( current[id] ) then current[id].frame = record.frame;
		else record.frame:Hide(); table.insert(freePlates, record.frame); end
	end
	local units = {};
	if ( type(AZS_UNITS) == "table" ) then
		for i = 1, table.getn(AZS_UNITS) do
			local unit = AZS_UNITS[i];
			if ( type(unit) == "table" and unit.id ~= nil ) then units[unit.id] = unit; end
		end
	end
	requests = {};
	for id, record in pairs(current) do
		UpdatePlateData(record, units[record.unitId]);
		table.insert(requests, { anchorId = id, attachment = "overhead" });
	end
	plates = current;
end

local function ProjectPlates()
	if ( not SS.DB().modernEnemyFrames or type(AZS_ProjectWorldAnchors) ~= "function" ) then
		for _, record in pairs(plates) do if ( record.frame ) then record.frame:Hide(); end end
		return;
	end
	if ( table.getn(requests) == 0 ) then return; end
	local ok, projection = SS.Safe(AZS_ProjectWorldAnchors, requests);
	-- Missing/stale projections must not leave a nameplate floating at its last screen position.
	for _, record in pairs(plates) do record.frame:Hide(); end
	if ( not ok or type(projection) ~= "table" or projection.frameCurrent == false ) then return; end
	for i = 1, table.getn(projection.entries or {}) do
		local projected = projection.entries[i];
		local record = plates[projected.anchorId];
		if ( record and projected.state == "onScreen" and type(projected.x) == "number" and type(projected.y) == "number" ) then
			local scale = SS.EffectiveScale(record.frame);
			record.frame:ClearAllPoints(); record.frame:SetPoint("BOTTOM", WorldFrame, "BOTTOMLEFT", projected.x / scale, projected.y / scale + 10); record.frame:Show();
		end
	end
end

function SS.UpdateEnemyNameplates()
	local d = SS.DB();
	local supported = type(AZS_GetWorldAnchors) == "function" and type(AZS_ProjectWorldAnchors) == "function" and type(AZS_RegisterWorldAnchorFrameHandler) == "function";
	if ( d.modernEnemyFrames and supported ) then
		if ( d.enemyNameplatesOriginal == nil ) then
			d.enemyNameplatesOriginal = ReadNativeNameplates() and "1" or "0";
		end
		if ( ReadNativeNameplates() ) then WriteNativeNameplates(false); end
		if ( not registered and type(AZS_RegisterWorldAnchorFrameHandler) == "function" ) then
			local ok, result = SS.Safe(AZS_RegisterWorldAnchorFrameHandler, ProjectPlates);
			registered = ok and result == true;
		end
		SS.Safe(ReadCatalog);
	else
		if ( d.enemyNameplatesOriginal ~= nil ) then
			local restore = d.enemyNameplates ~= nil and (d.enemyNameplates and "1" or "0") or tostring(d.enemyNameplatesOriginal);
			local wanted = SS.HudShown(restore);
			if ( ReadNativeNameplates() == wanted or WriteNativeNameplates(wanted) ) then d.enemyNameplatesOriginal = nil; end
		elseif ( d.enemyNameplates ~= nil and ReadNativeNameplates() ~= (d.enemyNameplates and true or false) ) then WriteNativeNameplates(d.enemyNameplates); end
		if ( registered and type(AZS_UnregisterWorldAnchorFrameHandler) == "function" ) then
			SS.Safe(AZS_UnregisterWorldAnchorFrameHandler, ProjectPlates); registered = false;
		end
		for _, record in pairs(plates) do if ( record.frame ) then record.frame:Hide(); end end
	end
	if ( SlimSuiteWorld and SlimSuiteWorld.ApplyOnTop ) then SS.Safe(SlimSuiteWorld.ApplyOnTop); end
end

local update = CreateFrame("Frame");
update:RegisterEvent("PLAYER_ENTERING_WORLD"); update:RegisterEvent("PLAYER_LOGOUT"); update:RegisterEvent("CHAT_MSG_ADDON");
update:SetScript("OnEvent", function()
	if ( event == "PLAYER_LOGOUT" ) then
		local d = SS.DB();
		if ( d.modernEnemyFrames and d.enemyNameplatesOriginal ~= nil ) then
			local value = d.enemyNameplates ~= nil and (d.enemyNameplates and "1" or "0") or tostring(d.enemyNameplatesOriginal);
			WriteNativeNameplates(SS.HudShown(value));
		end
		return;
	end
	if ( event == "CHAT_MSG_ADDON" and arg1 ~= "AZSUNITS" and arg1 ~= "AZSDEBUFFS" ) then return; end
	if ( SS.DB().modernEnemyFrames ) then SS.Safe(SS.UpdateEnemyNameplates); end
end);
SS.Every("enemyNameplates", 0.5, function() if ( SS.DB().modernEnemyFrames ) then SS.Safe(SS.UpdateEnemyNameplates); end end);

function SS.SetModernEnemyFrames(on)
	local d = SS.DB();
	d.modernEnemyFrames = on and true or false;
	SS.Safe(SS.UpdateEnemyNameplates);
end
function SS.SetEnemyPlateBossesOnly(on)
	local d = SS.DB();
	d.enemyBossesOnly = on and true or false;
	if ( on ) then d.modernEnemyFrames = true; end
	SS.Safe(SS.UpdateEnemyNameplates);
end
function SS.SetEnemyPlateDebuffs(on)
	SS.DB().enemyPlateDebuffs = on and true or false;
	SS.Safe(SS.UpdateEnemyNameplates);
end
function SS.NativeEnemyNameplatesEnabled() return ReadNativeNameplates(); end
