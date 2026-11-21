-- Slim Suite: the combat text test box and floating combat text. Split out of SlimSuiteWorld.lua, whose adapter (A) and helpers it shares.
-- Lua 5.0 / 1.12 interface: scripts read `this`, `arg1`; no # operator, no `...` in expressions; only the 1.12 API.
local W = SlimSuiteWorld;
local A, DB, Editing, Previewing = W.A, W.DB, W.Editing, W.Previewing;
local RAID_ICONS, PRE_PULL_ICON, SetRaidIcon = W.RAID_ICONS, W.PRE_PULL_ICON, W.SetRaidIcon;

-- ---------------------------------------------------------------- combat text test box
-- Normal hits form a downward log. Crits reserve successive fixed rows and fade right;
-- normal rows use the remaining space so neither stream can overlap the other.
local NORMAL_LIFE, CRIT_LIFE, FADE, MAX_LINES = 3, 6, 0.6, 14;
-- each option is on unless turned off in its setting (ctHeals, ctCrits, ctIcons, ctLong)
local function CTOn(key) return DB()[key] ~= false; end
local function CTLife(e) return (((e.featured==true) or (e.featured==nil and e.crit)) and CRIT_LIFE or NORMAL_LIFE) * (CTOn("ctLong") and 2 or 1); end
local box = CreateFrame("Frame", "SlimSuiteCombatTextFrame", UIParent);
box:SetWidth(260); box:SetHeight(220);
box:SetPoint("RIGHT", UIParent, "RIGHT", -260, 40);
box:SetFrameStrata("MEDIUM");
SS.OwnLook(box, function()
box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
box:SetBackdropColor(0.02, 0.02, 0.03, 0.55);
box:SetBackdropBorderColor(0.5, 0.4, 0.2, 0.6);
end);
box:Hide();
box.lines, box.entries = {}, {};

local function BoxLine(i)
	local l = box.lines[i];
	if ( l ) then return l; end
	l = CreateFrame("Frame", nil, box);
	l:SetWidth(240); l:SetHeight(14);
	l.icon = l:CreateTexture(nil, "ARTWORK"); l.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
	l.icon:SetPoint("LEFT", l, "LEFT", 0, 0);
	l.text = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	l.text:SetPoint("LEFT", l.icon, "RIGHT", 4, 0);
	l.text:SetJustifyH("LEFT");
	box.lines[i] = l;
	return l;
end

local function IconFor(event)
	local icon = A.Field(event, "icon", "spellIcon", "texture");
	if ( type(icon) == "table" ) then icon = icon.path; end
	if ( type(icon) ~= "string" ) then
		local meter = SlimSuiteMeter;
		local snap = meter and meter.snapshot;
		local src = snap and snap.sources and event.meterSourceKey and snap.sources[event.meterSourceKey];
		if ( src and src.icon and src.icon.status == "ready" ) then icon = src.icon.path; end
	end
	if ( type(icon) ~= "string" ) then return "Interface\\Icons\\INV_Misc_QuestionMark"; end
	if ( not string.find(icon, "\\", 1, true) ) then icon = "Interface\\Icons\\" .. icon; end
	return icon;
end

-- Per-source minute summaries learn routine damage without storing the combat log.
-- Completed minutes blend into the baseline; the current minute provides warm-up data.
local learning={sources={},minute=nil,run=nil,lastFeatured=-100,globalCount=0,globalSum=0,globalMean=nil};
function SS.ResetCombatLearning()
	learning={sources={},minute=nil,run=nil,lastFeatured=-100,globalCount=0,globalSum=0,globalMean=nil};
end
function SS.LearnCombatHighlight(e)
	if e.heal then return false; end
	local now=GetTime(); local run=type(AZS_ZONE)=="table" and AZS_ZONE.run;
	if run~=learning.run then SS.ResetCombatLearning(); learning.run=run; end
	local minute=math.floor(now/60);
	if learning.minute~=minute then
		if learning.globalCount>0 then
			local mean=learning.globalSum/learning.globalCount;
			learning.globalMean=learning.globalMean and learning.globalMean*.4+mean*.6 or mean;
		end
		learning.globalCount=0; learning.globalSum=0;
		for key,source in pairs(learning.sources) do
			local current=source.current;
			if current and current.count>0 then
				local mean=current.sum/current.count; local square=current.square/current.count; local crit=current.crits/current.count;
				local old=source.baseline; local weight=old and .6 or 1;
				source.baseline={mean=old and old.mean*(1-weight)+mean*weight or mean,
					square=old and old.square*(1-weight)+square*weight or square,
					crit=old and old.crit*(1-weight)+crit*weight or crit,count=math.min(10000,(old and old.count or 0)+current.count)};
			end
			source.current={count=0,sum=0,square=0,crits=0};
			if now-source.seen>180 then learning.sources[key]=nil; end
		end
		learning.minute=minute;
	end
	local key=tostring(e.sourceKey or e.name or "other"); local source=learning.sources[key];
	if not source then
		local count,oldest,oldTime=0,nil,now;
		for id,s in pairs(learning.sources) do count=count+1; if s.seen<=oldTime then oldest=id; oldTime=s.seen; end end
		if count>=64 and oldest then learning.sources[oldest]=nil; end
		source={seen=now,lastFeatured=-100,current={count=0,sum=0,square=0,crits=0}}; learning.sources[key]=source;
	end
	source.seen=now;
	local c=source.current; local baseline=source.baseline;
	if not baseline and c.count>0 then baseline={mean=c.sum/c.count,square=c.square/c.count,crit=c.crits/c.count,count=c.count}; end
	local count=baseline and baseline.count or 0; local mean=baseline and baseline.mean or e.amount;
	local deviation=baseline and math.sqrt(math.max(0,baseline.square-mean*mean)) or 0;
	local critRate=baseline and baseline.crit or 0;
	local exceptional=count>=8 and e.amount>=mean+math.max(deviation*2,mean*.75);
	local globalMean=learning.globalMean or (learning.globalCount>=12 and learning.globalSum/learning.globalCount) or nil;
	local weakForPlayer=globalMean and e.amount<globalMean*.6;
	local strongForSource=count<12 or e.amount>=mean+math.max(deviation,mean*.2);
	local uncommonCrit=e.crit and strongForSource and (count<12 or critRate<.15 or e.amount>=mean+math.max(deviation*1.8,mean*.25));
	local frequency=c.count/math.max(1,now-minute*60);
	local cooldown=math.min(3.5,.8+frequency*.08);
	local feature=not weakForPlayer and (exceptional or uncommonCrit) and now-source.lastFeatured>=cooldown and now-learning.lastFeatured>=.15;
	learning.globalCount=learning.globalCount+1; learning.globalSum=learning.globalSum+e.amount;
	c.count=c.count+1; c.sum=c.sum+e.amount; c.square=c.square+e.amount*e.amount;
	if e.crit then c.crits=c.crits+1; end
	if feature then source.lastFeatured=now; learning.lastFeatured=now; end
	return feature and true or false;
end
local function Featured(e)
	if e.featured~=nil then return e.featured; end
	return e.crit and true or false; -- legacy/manual previews
end
-- WoW 1.12 does not clip children: fit the actual glyphs before showing a line.
function SS.FitCombatText(text,value,width)
	value=string.gsub(tostring(value or ""),"[\r\n\t]"," "); width=math.floor(math.max(0,width));
	local font,size,flags=text:GetFont(); local style=tostring(font)..tostring(size)..tostring(flags);
	if text.slimCombatValue==value and text.slimCombatWidth==width and text.slimCombatStyle==style then return; end
	text.slimCombatValue,text.slimCombatWidth,text.slimCombatStyle=value,width,style;
	text:SetText(value);
	if (text:GetStringWidth() or 0)<=width then return; end
	-- Search character boundaries rather than removing and measuring every byte each frame.
	local cuts={0};
	for i=2,string.len(value) do local byte=string.byte(value,i); if byte<128 or byte>=192 then table.insert(cuts,i-1); end end
	table.insert(cuts,string.len(value));
	local low,high,best=1,table.getn(cuts),0;
	while low<=high do
		local middle=math.floor((low+high)/2); text:SetText(string.sub(value,1,cuts[middle]));
		if (text:GetStringWidth() or 0)<=width then best=cuts[middle]; low=middle+1; else high=middle-1; end
	end
	text:SetText(string.sub(value,1,best));
end

local function CombatRows()
	return math.max(1,math.min(MAX_LINES,math.floor(((box:GetHeight() or 220)-12)/28)));
end
local function LayoutCombatEntries(now)
	local rows=CombatRows();
	-- Preserve normal-log capacity even during a burst of qualifying critical hits.
	local maxHighlights=math.max(0,rows-math.max(1,math.ceil(rows*.35)));
	if maxHighlights==0 then for _,entry in ipairs(box.entries) do entry.featured=false; entry.emphasized=nil; end end
	local highlights=0;
	for _,entry in ipairs(box.entries) do if Featured(entry) then highlights=highlights+1; end end
	for i=table.getn(box.entries),1,-1 do
		if highlights>maxHighlights and Featured(box.entries[i]) then table.remove(box.entries,i); highlights=highlights-1; end
	end
	for i=table.getn(box.entries),1,-1 do
		local e=box.entries[i];
		if now-e.born>CTLife(e) or (e.tier and e.tier>=rows) then table.remove(box.entries,i); end
	end
	-- Existing rows keep their assigned position; expiration never repacks the survivors.

end
local function AddEntry(e)
	if e.featured==nil then
		e.featured=e.demo and e.crit and true or (not e.demo and SS.LearnCombatHighlight(e) or false);
	end
	e.emphasized=CTOn("ctPop") and e.featured or nil;
	-- One forward-only cursor serves both streams and survives empty/hidden periods.
	local rows=CombatRows();
	box.nextCombatTier=math.mod(box.nextCombatTier or 0,rows);
	e.tier=box.nextCombatTier; box.nextCombatTier=math.mod(box.nextCombatTier+1,rows);
	for i=table.getn(box.entries),1,-1 do
		if box.entries[i].tier==e.tier then table.remove(box.entries,i); end
	end
	table.insert(box.entries,1,e);
	LayoutCombatEntries(GetTime());
end

local function OnCombatEvent(event)
	if ( not DB().combatTextBox or type(event) ~= "table" or type(event.amount) ~= "number" ) then return; end
	local kind = event.kind;
	if ( kind ~= "damage" and kind ~= "heal" and kind ~= "healing" ) then return; end
	if ( kind ~= "damage" and not CTOn("ctHeals") ) then return; end
	local name = event.meterSource or event.abilityName or event.spell or event.damageType or "";
	AddEntry({ born = GetTime(), crit = event.critical == true and CTOn("ctCrits"), heal = kind ~= "damage",
		amount = math.floor(event.amount + 0.5), sourceKey=event.meterSourceKey or event.spellId or name, name = tostring(name), icon = CTOn("ctIcons") and IconFor(event) or nil });
end
if ( SlimSuiteMeter and SlimSuiteMeter.listeners ) then table.insert(SlimSuiteMeter.listeners, OnCombatEvent); end
-- Demo Mode: a sample hit or heal goes into the real box (its own options still apply to what is drawn)
function SlimSuiteWorld.DemoHit(amount, name, icon, crit, heal)
	AddEntry({ born = GetTime(), demo=true, crit = crit and CTOn("ctCrits"), heal = heal and true or false,
		amount = amount, name = name, icon = CTOn("ctIcons") and icon or nil });
end

local function DrawBox()
	local d = DB();
	local editing = Editing("SlimSuiteCombatTextFrame");
	local demo = SS.Demoing("SlimSuiteCombatTextFrame");   -- Demo Mode samples only this enabled element
	local now = GetTime();
	LayoutCombatEntries(now);
	if ( (not d.combatTextBox or (SS.CombatLogVisible and not SS.CombatLogVisible())) and not editing and not demo ) then box:Hide(); return; end
	local list = box.entries;
	-- nothing to show (no hits yet): the box stays out of the way unless it is being placed
	if ( table.getn(list) == 0 and not editing and not demo ) then box:Hide(); return; end
	box:Show();
	if ( editing and table.getn(list) == 0 ) then
		list = { { born = now, crit = true, amount = 1234, name = "Crit example", icon = "Interface\\Icons\\Spell_Fire_Fireball02" },
			{ born = now, amount = 512, name = "Hit example", icon = "Interface\\Icons\\Spell_Frost_FrostBolt02" } };
	end

	local y, n = -6, 0;
	local bottom = -(box:GetHeight() or 220) + 6;
	for i = 1, table.getn(list) do
		local e = list[i];
		local important=Featured(e);
		local h = important and 24 or 15;
		y=-6-(e.tier or (i-1))*28;
		local life=CTLife(e); local progress=math.max(0,math.min(1,(now-e.born)/life));
		local x=8+((not Featured(e) or d.accessibilityReduceMotion) and 0 or progress*math.max(0,(box:GetWidth() or 260)-46));
		local lineWidth=(box:GetWidth() or 260)-x-6;
		if ( lineWidth<20 ) then break; end
		if ( n >= MAX_LINES or y - h < bottom ) then break; end
		n = n + 1;
		local l = BoxLine(n);
		local life = CTLife(e);
		local age = now - e.born;
		local alpha = Featured(e) and (1-progress) or 1;
		if ( not Featured(e) and age > life - FADE ) then alpha = math.max(0, (life - age) / FADE); end
		l:ClearAllPoints();
		l:SetPoint("TOPLEFT", box, "TOPLEFT", x, y);
		l:SetWidth(lineWidth); l:SetHeight(h);
		l.icon:SetWidth(e.icon and (h - 2) or 0); l.icon:SetHeight(h - 2); l.icon:SetTexture(e.icon or nil);
		l.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",important and (e.crit and 15 or 12) or 10,e.crit and "THICKOUTLINE" or "OUTLINE");
		l.text:SetHeight(h-4);
		SS.FitCombatText(l.text,(important and e.crit and (e.amount .. "!") or tostring(e.amount)) .. "  " .. e.name,math.max(0,l:GetWidth()-(e.icon and h+4 or 6)));
		if ( e.heal ) then l.text:SetTextColor(0.3, 1, 0.4);
		elseif ( important ) then l.text:SetTextColor(1, 0.85, 0.2);
		else l.text:SetTextColor(1, 1, 1); end
		l:SetAlpha(alpha);
		l:Show();
		y = y - h - 1;
	end
	for i = n + 1, table.getn(box.lines) do box.lines[i]:Hide(); end
	if ( SS.EnforceElementBounds ) then SS.EnforceElementBounds(box); end
end


-- ---------------------------------------------------------------- floating combat text (0.138)
-- Each of your hits floats up from the enemy it struck, stays over the spot where an enemy fell, and hides when that
-- spot leaves your view. Text is sized by distance. Crits are bigger, pop, and stay twice as long. Positions are
-- worked out in AZS_RegisterCombatTextFrameHandler (after the camera moves each frame) so numbers never trail behind.
-- Each event carries its anchor as event.anchorId; AZS_ProjectCombatTextAnchors(list) answers like
-- AZS_ProjectWorldAnchors (x, y, onScreen, distance), matched back by anchor id (or by order if it gives none).
local FLOAT_LIFE, FLOAT_CRIT_LIFE, FLOAT_RISE = 1.1, 2.2, 46;
local floatLayer = CreateFrame("Frame", "SlimSuiteFloatingText", UIParent);
floatLayer:SetAllPoints(UIParent);
floatLayer:SetFrameStrata("LOW");
floatLayer:EnableMouse(false);
local floats, floatPool = {}, {};

-- an event's anchor: a handle the game says is ready, else none (never a place the game does not know)
local function FloatAnchor(event)
	if ( event.anchorStatus ~= nil and event.anchorStatus ~= "ready" ) then return nil; end
	return event.anchorId;
end

local function OnFloatEvent(event)
	if ( not (SS.WorldTextEnabled and SS.WorldTextEnabled() or DB().floatingText) or type(event) ~= "table" or event.kind ~= "damage" or type(event.amount) ~= "number" ) then return; end
	local mode=SS.WorldTextMode and SS.WorldTextMode() or "all";
	local kind=event.targetUnitId~=nil and SS.UnitKind(event.targetUnitId) or nil;
	if ( mode=="bosses" and kind~="boss" and kind~="final" ) then return; end
	local anchor = FloatAnchor(event);
	if ( not anchor ) then return; end
	local now = GetTime();
	local born = tonumber(event.presentedAt) or now;
	if ( now - born > FLOAT_LIFE ) then return; end      -- a delayed batch's old hit: not shown
	if ( table.getn(floats) >= 60 ) then table.remove(floats, 1); end
	table.insert(floats, { anchor = anchor, born = born, crit = event.critical == true,
		text = tostring(math.floor(event.amount + 0.5)), icon = IconFor(event),
		drift = math.mod(table.getn(floats), 5) * 9 - 18,
		kind = event.targetUnitId ~= nil and SS.UnitKind(event.targetUnitId) or nil });
end
if ( SlimSuiteMeter and SlimSuiteMeter.listeners ) then table.insert(SlimSuiteMeter.listeners, OnFloatEvent); end

local function FloatText(i)
	local f = floatPool[i];
	if ( f ) then return f; end
	f = CreateFrame("Frame", nil, floatLayer);
	f:SetWidth(120); f:SetHeight(24);
	f.text = f:CreateFontString(nil, "OVERLAY");
	f.text:SetPoint("CENTER", f, "CENTER", 8, 0);
	f.iconBack = f:CreateTexture(nil, "BACKGROUND"); f.iconBack:SetTexture(0, 0, 0, 0.7);
	f.icon = f:CreateTexture(nil, "ARTWORK"); f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
	f.icon:SetPoint("RIGHT", f.text, "LEFT", -3, 0);
	f.iconBack:SetPoint("CENTER", f.icon, "CENTER", 0, 0);
	floatPool[i] = f;
	return f;
end

local floatIds, floatById, NONE = {}, {}, {};
local function DrawFloats()
	if ( (SS.WorldTextEnabled and SS.WorldTextEnabled() or DB().floatingText) and SlimSuiteMeter and SlimSuiteMeter.Drain ) then SS.Safe(SlimSuiteMeter.Drain); end
	local now = GetTime();
	local mode=SS.WorldTextMode and SS.WorldTextMode() or "all";
	for i = table.getn(floats), 1, -1 do
		local e = floats[i];
		if ( now - e.born > (e.crit and FLOAT_CRIT_LIFE or FLOAT_LIFE) or (mode=="bosses" and e.kind~="boss" and e.kind~="final") ) then table.remove(floats, i); end
	end
	local n = table.getn(floats);
	if ( n == 0 or not (SS.WorldTextEnabled and SS.WorldTextEnabled() or DB().floatingText) ) then
		for i = 1, table.getn(floatPool) do floatPool[i]:Hide(); end
		return;
	end
	-- AZS_ProjectCombatTextAnchors(ids, "follow"): over the living enemy, then where it fell
	-- the lists below are kept and refilled each frame, not made new
	local ids = floatIds;
	for i = 1, n do ids[i] = floats[i].anchor; end
	for i = table.getn(ids), n + 1, -1 do table.remove(ids, i); end
	local result = A.Call("AZS_ProjectCombatTextAnchors", ids, "follow");
	local entries = type(result) == "table" and type(result.entries) == "table" and result.entries or NONE;
	-- each reply is matched to its hit by the anchor id it carries; a reply without ids is taken in the order asked
	local byId;
	for id in pairs(floatById) do floatById[id] = nil; end
	for i = 1, table.getn(entries) do
		local id = type(entries[i]) == "table" and entries[i].anchorId;
		if ( id ~= nil ) then byId = floatById; byId[id] = entries[i]; end
	end
	local scale = SS.EffectiveScale(UIParent);
	local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF";
	local shown = 0;
	for i = 1, n do
		local e = floats[i];
		local p;
		if ( byId ) then p = byId[e.anchor]; else p = entries[i]; end
		local x, y = p and p.x, p and p.y;
		if ( p and p.state == "onScreen" and type(x) == "number" and type(y) == "number" ) then
			shown = shown + 1;
			local f = FloatText(shown);
			local life = e.crit and FLOAT_CRIT_LIFE or FLOAT_LIFE;
			local t = (now - e.born) / life;
			local dist = tonumber(p.playerDistance);
			local near = dist and math.max(0.6, math.min(1.25, 1.35 - dist / 90)) or 1;
			local reduceMotion = DB().accessibilityReduceMotion and true or false;
			local pop = (not reduceMotion and e.crit and t < 0.12) and (1.5 - t * 4) or 1;
			local size = math.floor((e.crit and 20 or 11) * near * pop + 0.5);
			size = math.max(8, size);
			local flags = e.crit and "THICKOUTLINE" or "OUTLINE";
			if ( f.fontSize ~= size or f.flags ~= flags ) then f.fontSize = size; f.flags = flags; f.text:SetFont(font, size, flags); end
			f.text:SetText(SS.WorldTextMode and SS.WorldTextMode()=="iconsCrits" and not e.crit and "" or (e.crit and (e.text .. "!") or e.text));
			if ( e.crit ) then f.text:SetTextColor(1, 0.9, 0.3); f.iconBack:SetTexture(1, 0.82, 0.15, 0.9);
			else f.iconBack:SetTexture(0, 0, 0, 0.7); end
			if ( e.crit ) then
			elseif ( e.kind == "boss" or e.kind == "final" ) then f.text:SetTextColor(1, 0.6, 0.3);
			else f.text:SetTextColor(1, 1, 1); end
			local iconSize = e.crit and size + 4 or size;
			f.icon:SetWidth(iconSize); f.icon:SetHeight(iconSize); f.icon:SetTexture(e.icon);
			f.iconBack:SetWidth(iconSize + 2); f.iconBack:SetHeight(iconSize + 2);
			f:ClearAllPoints();
			f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale + (reduceMotion and 0 or e.drift), y / scale + 20 + (reduceMotion and 0 or t * FLOAT_RISE * near));
			f:SetAlpha(t > 0.7 and math.max(0, (1 - t) / 0.3) or 1);
			f:Show();
		end
	end
	for i = shown + 1, table.getn(floatPool) do floatPool[i]:Hide(); end
end

if ( not (A.Has("AZS_RegisterCombatTextFrameHandler") and SS.Safe(AZS_RegisterCombatTextFrameHandler, function() SS.Safe(DrawFloats); end)) ) then
	SS.Every("floats", 0, function() SS.Safe(DrawFloats); end, floatLayer);
end


-- Animates while combat text is on screen; when it is empty and hidden, it is checked 4 times a second instead of every frame.
local boxLastRun = 0;
SS.Every("box", 0, function()
	if ( box.entries and table.getn(box.entries) == 0 and not box:IsShown() ) then
		local now = GetTime();
		if ( now - boxLastRun < 0.25 ) then return; end
		boxLastRun = now;
	end
	SS.Safe(DrawBox);
end);
