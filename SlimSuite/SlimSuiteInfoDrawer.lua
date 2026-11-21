-- Info drawer: a read-only panel of run numbers (your damage per second, legendary luck and a few stats).
-- Nothing in it can be clicked; it only tells you things. It reuses the luck model and the stats list.
if ( setfenv ) then setfenv(1, SS.ENV); end

local frame = CreateFrame("Frame", "SlimSuiteInfoDrawer", UIParent);
frame:SetWidth(220); frame:SetHeight(150); frame:SetPoint("RIGHT", UIParent, "RIGHT", -12, 0); frame:Hide();
frame:EnableMouse(false);
SS.OwnLook(frame, function()
	frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 10, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	frame:SetBackdropColor(0.02, 0.025, 0.035, 0.75); frame:SetBackdropBorderColor(0.55, 0.47, 0.27, 0.8);
end);
frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8);
frame.title:SetText(SS.T and SS.T("Run info") or "Run info");
frame.lines = {};
local MAX_LINES = 7;
for i = 1, MAX_LINES do
	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	label:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10 - i * 16); label:SetJustifyH("LEFT");
	local value = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	value:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10 - i * 16); value:SetJustifyH("RIGHT");
	value:SetTextColor(1, 0.82, 0);
	frame.lines[i] = { label = label, value = value };
end

local function Short(n)
	n = tonumber(n) or 0;
	if ( n >= 1000000 ) then return string.format("%.1fm", n / 1000000); end
	if ( n >= 1000 ) then return string.format("%.1fk", n / 1000); end
	return tostring(math.floor(n + 0.5));
end

-- your damage per second over the last five seconds, from the game's meter (asked at most once a second)
local dps = { at = 0 };
function SS.CurrentDPS()
	local now = GetTime();
	if ( now < dps.at ) then return dps.value; end
	dps.at = now + 1;
	dps.value = nil;
	if ( type(AZS_GetMeterContext) ~= "function" or type(AZS_GetMeterSnapshot) ~= "function" ) then return nil; end
	local okC, ctx = SS.Safe(AZS_GetMeterContext);
	if ( not okC or type(ctx) ~= "table" or not ctx.runId ) then return nil; end
	local ok, r = SS.Safe(AZS_GetMeterSnapshot, { apiVersion = 1, runId = ctx.runId, metric = "damage", scope = "self",
		period = "run", groupBy = "actor_source", windowSeconds = 5 });
	local rate = ok and type(r) == "table" and r.totals and r.totals.displayRate;
	if ( type(rate) == "table" and rate.status == "ready" ) then dps.value = tonumber(rate.value); end
	return dps.value;
end

-- what the drawer says: { label, value } pairs
function SS.InfoDrawerLines()
	local out = {};
	local rate = SS.CurrentDPS and SS.CurrentDPS();
	table.insert(out, { "DPS", rate and Short(rate) or "-" });
	local luck = SS.LuckProgress and SS.LuckProgress();
	if ( luck and luck.luck and luck.level and SS.LegendaryChance ) then
		local chance = SS.LegendaryChance(luck.luck, luck.level);
		table.insert(out, { "Legendary chance", chance and (string.format("%.1f", chance * 100) .. "%") or "-" });
		table.insert(out, { "Luck", tostring(luck.luck) });
	else
		table.insert(out, { "Legendary chance", "-" });
	end
	if ( SS.StatEntries ) then
		local ok, entries = SS.Safe(SS.StatEntries);
		if ( ok and type(entries) == "table" ) then
			for _, e in ipairs(entries) do
				if ( table.getn(out) >= MAX_LINES ) then break; end
				if ( e.key ~= "health" and e.key ~= "buffs" and e.key ~= "racial" and e.key ~= "luck" ) then
					table.insert(out, { e.label, tostring(e.value) });
				end
			end
		end
	end
	return out;
end

local SAMPLE = { { "DPS", "1.2k" }, { "Legendary chance", "3.4%" }, { "Luck", "1.5" }, { "Crit", "24%" },
	{ "Haste", "12%" }, { "Pickup range", "+30%" }, { "Armor", "310" } };

function SS.UpdateInfoDrawer()
	if ( not SS.FeatureEnabled or not SS.FeatureEnabled("SlimSuiteInfoDrawer") ) then frame:Hide(); return; end
	local phase = type(AZS_GetPhase) == "function" and AZS_GetPhase() or nil;
	local live = phase == "playing" or phase == "choosing" or phase == "paused";
	local lines;
	if ( live ) then lines = SS.InfoDrawerLines();
	elseif ( SS.Previewing and SS.Previewing("SlimSuiteInfoDrawer") ) then lines = SAMPLE;
	else frame:Hide(); return; end
	for i = 1, MAX_LINES do
		local row, entry = frame.lines[i], lines[i];
		if ( entry ) then row.label:SetText(entry[1]); row.value:SetText(entry[2]); row.label:Show(); row.value:Show();
		else row.label:Hide(); row.value:Hide(); end
	end
	frame:SetHeight(math.max(60, 28 + math.min(MAX_LINES, table.getn(lines)) * 16));
	frame:Show();
end

SS.Every("infoDrawer", 0.5, function() SS.Safe(SS.UpdateInfoDrawer); end);
