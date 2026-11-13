-- Slim Suite meter: authoritative totals/checkpoints plus explicitly observed hit samples.
-- MeterQuery v1 and combat-text stream v1 from Aethus's addon_docs(2).md.
local K = AZSKIT;
local M = { view = 'damage', sort = 'amount', offset = 0, checkpoints = {}, samples = {damage={},healing={}}, listeners = {} };
SlimSuiteMeter = M;
M.fields = {};
local function Count(t) return table.getn(t or {}); end
local function Num(v) return type(v)=='number' and v or 0; end
local function Text(v) return tostring(math.floor(Num(v)+0.5)); end
local function Name(v) return string.lower(string.gsub(string.gsub(v or '', '^%[', ''), '%]$', '')); end
local function FitString(fs,text,width,minSize)
	if not fs then return;end
	text=tostring(text or '');
	if fs.fitText==text and fs.fitWidth==width and fs.fitMin==minSize then return;end   -- the same text in the same room: fitted already
	fs.fitText,fs.fitWidth,fs.fitMin=text,width,minSize;
	if not fs.baseFont then fs.baseFont,fs.baseSize,fs.baseFlags=fs:GetFont();end
	local size=fs.baseSize or 10;fs:SetWidth(math.max(1,width));fs:SetText(tostring(text or ''));
	if fs.GetStringWidth and fs.baseFont and fs.SetFont then
		fs:SetFont(fs.baseFont,size,fs.baseFlags);
		while size>(minSize or 7) and fs:GetStringWidth()>width do size=size-1;fs:SetFont(fs.baseFont,size,fs.baseFlags);end
	end
end
local function AddSample(metric, key, amount, crit, owner)
	if type(amount)~='number' or amount<0 or not key then return; end
	owner=owner or (M.context and M.context.localOwnerId);if not owner then return;end
	key=owner.."|"..key;local bucket=M.samples[metric];local s=bucket[key];
	if not s then s={count=0,crits=0,regular=0};bucket[key]=s;end
	s.count=s.count+1;s.low=s.low and math.min(s.low,amount) or amount;s.high=math.max(s.high or 0,amount);
	if crit then s.crits=s.crits+1;s.critSum=(s.critSum or 0)+amount;s.minCrit=s.minCrit and math.min(s.minCrit,amount) or amount;s.maxCrit=math.max(s.maxCrit or 0,amount);s.highCrit=math.max(s.highCrit or 0,amount);
	else s.regular=s.regular+1;s.normalSum=(s.normalSum or 0)+amount;s.minNormal=s.minNormal and math.min(s.minNormal,amount) or amount;s.highNormal=math.max(s.highNormal or 0,amount);end
end
local function Release(view)
	local id=M.checkpoints[view];
	if id and AZS_ReleaseMeterCheckpoint then SS.Safe(AZS_ReleaseMeterCheckpoint,id);end
	M.checkpoints[view]=nil;
end
-- Hit samples are kept in the saved settings for the current run, so the tooltips keep their numbers after a
-- /reload just as the game's own meter totals do. A new run (or a new counter epoch/authority) starts fresh.
local function SavedSamples(context)
	if type(SlimSuiteDB)~='table' then return nil;end
	local saved=SlimSuiteDB.meterSamples;
	if type(saved)=='table' and saved.runId==context.runId and saved.epoch==context.counterEpoch and saved.authority==context.authorityId
	and type(saved.samples)=='table' and type(saved.samples.damage)=='table' and type(saved.samples.healing)=='table' then
		return saved.samples;
	end
	return nil;
end
local function SyncContext(context)
	if not context then return;end
	if M.runId~=context.runId or M.sessionId~=context.uiSessionId or M.epoch~=context.counterEpoch or M.authority~=context.authorityId then
		for view in pairs(M.checkpoints) do Release(view);end
		M.samples=SavedSamples(context) or {damage={},healing={}};M.knownActors={};M.cursor=nil;M.dropped=0;M.owner=nil;M.offset=0;
		if type(SlimSuiteDB)=='table' then SlimSuiteDB.meterSamples={runId=context.runId,epoch=context.counterEpoch,authority=context.authorityId,samples=M.samples};end
		M.runId,M.sessionId,M.epoch,M.authority=context.runId,context.uiSessionId,context.counterEpoch,context.authorityId;
	end
	M.context=context;
end
function M.Reset()
	if M.view~='damage' and M.view~='healing' then return;end
	if not AZS_GetMeterContext or not AZS_CreateMeterCheckpoint then M.message='Reset requires the current game meter API';return;end
	local context=AZS_GetMeterContext();SyncContext(context);
	if not context then M.message='No run to reset';return;end
	if M.Drain then M.Drain();end
	local point,err=AZS_CreateMeterCheckpoint(context.runId);
	if not point then M.message=err and err.code or 'Reset unavailable';return;end
	Release(M.view);M.checkpoints[M.view]=point.checkpointId;M.samples[M.view]={};M.offset=0;M.message=nil;
end
local function Query()
	if not AZS_GetMeterContext or not AZS_GetMeterSnapshot then return nil,'Update the game for full meter details';end
	local context,err=AZS_GetMeterContext();
	if not context then return nil,err and err.code or 'Waiting for a run';end
	SyncContext(context);
	local q={apiVersion=1,runId=context.runId,metric=M.view=='healing' and 'healing' or 'damage',scope=M.view=='group' and (M.owner and 'owner' or 'party') or 'self',period=M.view=='boss' and 'encounter' or 'run',groupBy=M.view=='group' and not M.owner and 'owner' or 'source',windowSeconds=0};
	if M.view=='healing' then q.healingPerspective='performed';end
	if M.view=='group' and M.owner then q.ownerId=M.owner;end
	if M.checkpoints[M.view] then q.checkpointId=M.checkpoints[M.view];end
	local result;result,err=AZS_GetMeterSnapshot(q);
	if not result and err and (err.code=='CHECKPOINT_EXPIRED' or err.code=='CHECKPOINT_INVALIDATED' or err.code=='INVALID_CHECKPOINT') then
		Release(M.view);q.checkpointId=nil;result,err=AZS_GetMeterSnapshot(q);
	end
	if not result then return nil,err or 'Waiting for meter data';end
	M.context=result.context;
	M.absorbed=0;
	if M.view=='healing' then
		for _,credit in ipairs(result.contributions or {}) do
			if credit.creditKind=='absorb_consumed' then M.absorbed=M.absorbed+Num(credit.displayAmount);end
		end
	end
	M.knownActors=M.knownActors or {};
	for id,actor in pairs(result.actors or {}) do
		local owner=actor.kind=='hero' and id or actor.currentOwnerId;
		if owner and actor.name then
			local old=M.knownActors[actor.name];if old~=nil and old~=owner then M.knownActors[actor.name]=false;else M.knownActors[actor.name]=owner;end
		end
	end
	return result;
end
local function Samples(source,owner)
	owner=owner or (M.context and M.context.localOwnerId);if not owner then return nil;end
	if type(source)~='table' then return nil;end
	local bucket=M.samples[M.view=='healing' and 'healing' or 'damage'];
	if source.sourceKey then
		local exact=bucket[owner.."|"..source.sourceKey];if exact then return exact;end
	end
	local keys,seen={},{};
	for _,id in ipairs(source.spellIds or {}) do local key='spell:'..tostring(id);if not seen[key] then table.insert(keys,key);seen[key]=true;end end
	table.insert(keys,'name:'..Name(source.name));
	local result={count=0,crits=0,regular=0};
	for _,key in ipairs(keys) do
		local s=bucket[owner.."|"..key];if s then
			result.count=result.count+s.count;result.crits=result.crits+s.crits;result.regular=result.regular+s.regular;
			result.low=result.low and math.min(result.low,s.low) or s.low;
			if s.high then result.high=math.max(result.high or 0,s.high);end
			if s.minCrit then result.minCrit=result.minCrit and math.min(result.minCrit,s.minCrit) or s.minCrit;end
			if s.maxCrit then result.maxCrit=math.max(result.maxCrit or 0,s.maxCrit);end
			if s.highCrit then result.highCrit=math.max(result.highCrit or 0,s.highCrit);end
			if s.highNormal then result.highNormal=math.max(result.highNormal or 0,s.highNormal);end
			if s.minNormal then result.minNormal=result.minNormal and math.min(result.minNormal,s.minNormal) or s.minNormal;end
			result.normalSum=(result.normalSum or 0)+(s.normalSum or 0);result.critSum=(result.critSum or 0)+(s.critSum or 0);
		end
	end
	return result.count>0 and result or nil;
end
-- The Party tab's names are in class colour (SS.ClassColor). The actor's class comes from the meter data when it has
-- one, else from the party.
local function ClassOf(actor)
	if type(actor)~='table' then return nil;end
	local c=actor.class or actor.classToken or actor.classFile;
	if type(c)=='string' then return string.upper(c);end
	local units={'player','party1','party2','party3','party4'};
	for _,u in ipairs(units) do
		if UnitExists and UnitExists(u) and UnitName(u)==actor.name then local _,token=UnitClass(u);return token;end
	end
	return nil;
end
local function Tooltip(button)
	if not GameTooltip or not button.entry then return;end
	local row,source=button.entry,button.source;
	GameTooltip:SetOwner(button,'ANCHOR_RIGHT');GameTooltip:AddLine(button.label or 'Ability',1,0.82,0);
	if M.view=='group' and not M.owner then GameTooltip:AddLine('Click for this player\'s abilities',1,1,1);GameTooltip:Show();return;end
	local sample=Samples(source,row.ownerId);
	local healing=M.view=='healing';local noun=healing and 'Heal' or 'Hit';
	GameTooltip:AddLine(M.view=='boss' and 'Observed hits: all targets' or healing and 'Observed combat-log samples this run' or 'Observed samples this run (kept through /reload)',0.7,0.7,0.7);
	local function Value(n) return n and Text(n) or 'Not recorded';end
	local function Avg(sum,n) return (sum and n and n>0) and Text(sum/n) or 'Not recorded';end
	GameTooltip:AddDoubleLine(noun..'s recorded',sample and tostring(sample.count) or '0',1,1,1,1,1,1);
	GameTooltip:AddDoubleLine('Normal '..string.lower(noun)..'s (min / avg / max)',sample and (Value(sample.minNormal)..' / '..Avg(sample.normalSum,sample.regular)..' / '..Value(sample.highNormal)) or 'Not recorded',1,1,1,1,1,1);
	GameTooltip:AddDoubleLine('Crits (min / avg / max)',sample and (Value(sample.minCrit)..' / '..Avg(sample.critSum,sample.crits)..' / '..Value(sample.maxCrit)) or 'Not recorded',1,1,1,1,1,1);
	if sample and sample.regular>0 and sample.crits>0 and (sample.normalSum or 0)>0 then
		GameTooltip:AddDoubleLine('Crit multiplier (avg)',string.format('x%.2f',(sample.critSum/sample.crits)/(sample.normalSum/sample.regular)),1,1,1,1,1,1);
	end
	if sample then
		GameTooltip:AddLine(string.format('Crit %%: %.1f%% (%d / %d)',sample.crits/sample.count*100,sample.crits,sample.count),1,1,1);
	else GameTooltip:AddLine('Crit %: Not recorded',1,1,1);end
	GameTooltip:AddLine(string.format('Share of total: %.1f%%',Num(row.share)*100),1,0.82,0);
	if row.displayRate and row.displayRate.status=='ready' then GameTooltip:AddLine((healing and 'HPS: ' or 'DPS: ')..Text(row.displayRate.value),1,0.82,0);end
	if (row.displayAmount or 0)>0 then GameTooltip:AddLine('Total: '..Text(row.displayAmount),1,0.82,0);end
	if (M.dropped or 0)>0 then GameTooltip:AddLine('Some damage samples were missed.',1,0.5,0);end
	GameTooltip:Show();
end
-- ---------------------------------------------------------------- the meter's look
-- Drawn like the game's own damage meter (measured from its HUD): a near-black warm panel with a thin gold-brown
-- border, a header with the view's name in gold, a small "^" button that opens the view list, the current rate
-- ("dps · now 0"), a Reset button and an "x", and a grip in the bottom-right corner to resize it.
local VIEWS = { { 'damage', 'Damage Done' }, { 'healing', 'Healing Done' }, { 'boss', 'Boss Damage' }, { 'group', 'Party DPS' } };
local GOLD, MUTED, CREAM, BORDER = { 0.97, 0.82, 0.41 }, { 0.56, 0.5, 0.38 }, { 0.85, 0.81, 0.7 }, { 0.43, 0.33, 0.145 };
local HEADER, ROW_H = 20, 16;
local FONT = STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF';
local function ViewName(view) for _, v in ipairs(VIEWS) do if v[1] == view then return v[2]; end end return 'Damage Done'; end
local function Short(v)
	v = Num(v);
	if v >= 1000000 then return string.format('%.1fm', v / 1000000); end
	if v >= 10000 then return string.format('%.1fk', v / 1000); end
	return Text(v);
end
local function Tex(parent, layer, r, g, b, a)
	local t = parent:CreateTexture(nil, layer); t:SetTexture(1, 1, 1, 1); t:SetVertexColor(r, g, b, a or 1); return t;
end
local function Label(parent, size, color, justify)
	local fs = parent:CreateFontString(nil, 'OVERLAY');
	fs:SetFont(FONT, size); fs:SetShadowColor(0, 0, 0, 1); fs:SetShadowOffset(1, -1);
	fs:SetTextColor(color[1], color[2], color[3]); fs:SetJustifyH(justify or 'LEFT');
	return fs;
end
-- a 1-pixel border made of four textures
local function Border(f, c)
	local t = Tex(f, 'BORDER', c[1], c[2], c[3]); t:SetPoint('TOPLEFT', f, 'TOPLEFT', 0, 0); t:SetPoint('TOPRIGHT', f, 'TOPRIGHT', 0, 0); t:SetHeight(1);
	local b = Tex(f, 'BORDER', c[1], c[2], c[3]); b:SetPoint('BOTTOMLEFT', f, 'BOTTOMLEFT', 0, 0); b:SetPoint('BOTTOMRIGHT', f, 'BOTTOMRIGHT', 0, 0); b:SetHeight(1);
	local l = Tex(f, 'BORDER', c[1], c[2], c[3]); l:SetPoint('TOPLEFT', f, 'TOPLEFT', 0, 0); l:SetPoint('BOTTOMLEFT', f, 'BOTTOMLEFT', 0, 0); l:SetWidth(1);
	local r = Tex(f, 'BORDER', c[1], c[2], c[3]); r:SetPoint('TOPRIGHT', f, 'TOPRIGHT', 0, 0); r:SetPoint('BOTTOMRIGHT', f, 'BOTTOMRIGHT', 0, 0); r:SetWidth(1);
end
-- the header's small square buttons and text buttons
local function SmallButton(parent, text, width, onClick)
	local b = CreateFrame('Button', nil, parent);
	b:SetWidth(width); b:SetHeight(15);
	local fill = Tex(b, 'BACKGROUND', 0.08, 0.055, 0.027, 1); fill:SetAllPoints(b);
	Border(b, { 0.32, 0.25, 0.105 });
	b.text = Label(b, 11, { 0.59, 0.54, 0.4 }, 'CENTER'); b.text:SetPoint('CENTER', b, 'CENTER', 0, 0); b.text:SetText(text);
	local hi = Tex(b, 'HIGHLIGHT', 1, 0.85, 0.5, 0.12); hi:SetAllPoints(b);
	b:SetScript('OnClick', onClick);
	return b;
end

local function BuildViewList(frame)
	local list = CreateFrame('Frame', 'SlimSuiteMeterViewList', frame);
	list:SetFrameStrata('DIALOG');
	list:SetFrameLevel((frame:GetFrameLevel() or 1) + 20);
	list:SetWidth(112); list:SetHeight(4 + table.getn(VIEWS) * 18);
	list:EnableMouse(true);
	local bg = Tex(list, 'BACKGROUND', 0.024, 0.02, 0.05, 0.97); bg:SetAllPoints(list);
	Border(list, BORDER);
	list.items = {};
	for i = 1, table.getn(VIEWS) do
		local item = CreateFrame('Button', nil, list);
		item:SetWidth(108); item:SetHeight(18);
		item:SetPoint('TOPLEFT', list, 'TOPLEFT', 2, -2 - (i - 1) * 18);
		item:EnableMouse(true);
		if item.RegisterForClicks then item:RegisterForClicks('LeftButtonUp'); end
		item.selected = Tex(item, 'BACKGROUND', 0.12, 0.105, 0.086, 1); item.selected:SetAllPoints(item);
		item.hover = Tex(item, 'BACKGROUND', 0.16, 0.14, 0.11, 1); item.hover:SetAllPoints(item); item.hover:Hide();
		item.label = item:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall');
		item.label:SetFont(FONT, 12); item.label:SetTextColor(CREAM[1], CREAM[2], CREAM[3]);
		item.label:SetPoint('LEFT', item, 'LEFT', 6, 0); item.label:SetText(VIEWS[i][2]);
		item.view = VIEWS[i][1];
		item:SetScript('OnEnter', function() this.hover:Show(); end);
		item:SetScript('OnLeave', function() this.hover:Hide(); end);
		item:SetScript('OnClick', function()
				M.view = this.view; M.owner = nil; M.offset = 0; M.message = nil; M.nextRead = 0; M.nextNow = 0;
				this:GetParent():Hide();
			end);
		list.items[i] = item;
	end
	list:SetPoint('TOPLEFT', frame, 'TOPLEFT', 3, -(HEADER + 2));
	list:Hide();
	return list;
end

local function ToggleViewList(frame)
	if not M.viewList then
		local ok, list = SS.Safe(BuildViewList, frame);
		if not ok then
			if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cffffd100Slim Suite|r the meter\'s view list could not be made: ' .. tostring(list)); end
			return;
		end
		M.viewList = list;
	end
	local list = M.viewList;
	if list:IsShown() then list:Hide(); return; end
	for _, item in ipairs(list.items) do if item.view == M.view then item.selected:Show(); else item.selected:Hide(); end end
	list:Show();
end

function M.Attach(frame)
	M.frame = frame; frame:SetWidth(230); frame:SetHeight(170);
	frame:EnableMouse(true); frame:EnableMouseWheel(true);
	if frame.SetResizable then frame:SetResizable(true); end
	if frame.SetMinResize then frame:SetMinResize(210, 110); end   -- the same smallest size as Slim Suite's size menu
	-- panel and header
	local body = Tex(frame, 'BACKGROUND', 1, 1, 1, 1); body:SetAllPoints(frame);
	if body.SetGradient then body:SetGradient('VERTICAL', 0.039, 0.031, 0.016, 0.082, 0.063, 0.031); else body:SetVertexColor(0.063, 0.051, 0.024); end
	local head = Tex(frame, 'ARTWORK', 1, 1, 1, 1);
	head:SetPoint('TOPLEFT', frame, 'TOPLEFT', 1, -1); head:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -1, -1); head:SetHeight(HEADER);
	if head.SetGradient then head:SetGradient('VERTICAL', 0.125, 0.094, 0.043, 0.22, 0.165, 0.078); else head:SetVertexColor(0.17, 0.13, 0.06); end
	local line = Tex(frame, 'ARTWORK', 0.32, 0.25, 0.11, 1);
	line:SetPoint('TOPLEFT', head, 'BOTTOMLEFT', 0, 0); line:SetPoint('TOPRIGHT', head, 'BOTTOMRIGHT', 0, 0); line:SetHeight(1);
	Border(frame, BORDER);
	-- header contents
	frame.title = Label(frame, 13, GOLD); frame.title:SetPoint('LEFT', frame, 'TOPLEFT', 9, -(HEADER / 2 + 1));
	frame.pick = SmallButton(frame, '^', 14, function() ToggleViewList(frame); end);
	frame.pick.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3]);
	frame.pick:SetPoint('LEFT', frame.title, 'RIGHT', 6, 0);
	frame.rate = Label(frame, 11, MUTED); frame.rate:SetPoint('LEFT', frame.pick, 'RIGHT', 6, 0);
	frame.rate:SetHeight(14);   -- one line only: never wraps under itself
	frame.close = CreateFrame('Button', nil, frame);
	frame.close:SetWidth(14); frame.close:SetHeight(14); frame.close:SetPoint('RIGHT', frame, 'TOPRIGHT', -5, -(HEADER / 2 + 1));
	frame.close.text = Label(frame.close, 13, { 0.66, 0.6, 0.47 }, 'CENTER'); frame.close.text:SetPoint('CENTER', frame.close, 'CENTER', 0, 1); frame.close.text:SetText('x');
	frame.close:SetScript('OnClick', function() M.Close(); end);
	frame.close:SetScript('OnEnter', function() this.text:SetTextColor(1, 0.85, 0.5); end);
	frame.close:SetScript('OnLeave', function() this.text:SetTextColor(0.66, 0.6, 0.47); end);
	frame.reset = SmallButton(frame, 'Reset', 40, function() M.Reset(); M.nextRead = 0; end);
	frame.reset:SetPoint('RIGHT', frame.close, 'LEFT', -6, 0);
	frame.back = SmallButton(frame, 'Back', 40, function() M.owner = nil; M.offset = 0; M.nextRead = 0; end);
	frame.back:SetPoint('RIGHT', frame.close, 'LEFT', -6, 0); frame.back:Hide();
	-- the message shown when there is nothing to list
	frame.empty = Label(frame, 12, { 0.6, 0.53, 0.41 }); frame.empty:SetPoint('TOPLEFT', frame, 'TOPLEFT', 9, -(HEADER + 9));
	frame.empty:SetJustifyV('TOP');
	-- rows
	frame:SetScript('OnMouseWheel', function() M.offset = math.max(0, math.min(math.max(0, Count(M.rows) - M.visible), M.offset - (arg1 or 0) * 3)); end);
	frame.rows = {};
	for i = 1, 64 do
		local row = CreateFrame('Button', nil, frame);
		row:SetPoint('TOPLEFT', frame, 'TOPLEFT', 5, -(HEADER + 5) - (i - 1) * ROW_H); row:SetHeight(ROW_H - 1);
		row.bar = Tex(row, 'BACKGROUND', GOLD[1], GOLD[2], GOLD[3], 0.13); row.bar:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 0); row.bar:SetPoint('BOTTOMLEFT', row, 'BOTTOMLEFT', 0, 0);
		local hi = Tex(row, 'HIGHLIGHT', 1, 0.85, 0.5, 0.08); hi:SetAllPoints(row);
		row.icon = row:CreateTexture(nil, 'ARTWORK'); row.icon:SetPoint('LEFT', row, 'LEFT', 2, 0); row.icon:SetWidth(13); row.icon:SetHeight(13);
		row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
		row.name = Label(row, 11, CREAM); row.name:SetPoint('LEFT', row, 'LEFT', 20, 0);
		row.value = Label(row, 11, GOLD, 'RIGHT'); row.value:SetPoint('RIGHT', row, 'RIGHT', -3, 0);
		row:SetScript('OnEnter', function() Tooltip(this); end); row:SetScript('OnLeave', function() if GameTooltip then GameTooltip:Hide(); end end);
		row:SetScript('OnClick', function() if M.view == 'group' and not M.owner and this.entry then M.owner = this.entry.ownerId; M.offset = 0; M.nextRead = 0; if GameTooltip then GameTooltip:Hide(); end end end);
		row:EnableMouseWheel(true); row:SetScript('OnMouseWheel', frame:GetScript('OnMouseWheel')); frame.rows[i] = row;
	end
	-- the resize grip: a small gold stepped triangle in the bottom-right corner
	local grip = CreateFrame('Button', nil, frame);
	grip:SetWidth(12); grip:SetHeight(12); grip:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -2, 2);
	for i = 1, 4 do
		local step = Tex(grip, 'OVERLAY', 0.56, 0.44, 0.19, 1);
		step:SetWidth(i * 2); step:SetHeight(2); step:SetPoint('BOTTOMRIGHT', grip, 'BOTTOMRIGHT', 0, (4 - i) * 2);
	end
	grip:SetScript('OnMouseDown', function() if arg1 == 'LeftButton' and frame.StartSizing then frame:StartSizing('BOTTOMRIGHT'); end end);
	grip:SetScript('OnMouseUp', function()
			frame:StopMovingOrSizing();
			if type(SlimSuiteDB) == 'table' and type(SlimSuiteDB.sizes) == 'table' then
				SlimSuiteDB.sizes.SlimSuiteMeterFrame = { w = frame:GetWidth(), h = frame:GetHeight() };
			end
			if SS.SavePosition then SS.SavePosition('SlimSuiteMeterFrame', frame); end
		end);
	frame:SetScript('OnHide', function() if M.viewList then M.viewList:Hide(); end end);
	-- the view list is made now, with the meter, so it is ready the first time "^" is pressed
	local ok, list = SS.Safe(BuildViewList, frame);
	if ok then M.viewList = list; end
end

-- "x": the meter stays hidden for the rest of this run and comes back with the next one. Closed before a run, it
-- comes back when that run starts.
local function CurrentRunId()
	if not AZS_GetMeterContext then return nil; end
	local ok, ctx = SS.Safe(AZS_GetMeterContext);
	if ok and type(ctx) == 'table' then return ctx.runId; end
	return nil;
end
function M.Close()
	M.closed = true;
	M.closedRun = CurrentRunId() or 'before a run';
	if M.viewList then M.viewList:Hide(); end
	if M.frame then M.frame:Hide(); end
end
function M.IsClosed()
	if not M.closed then return false; end
	local run = CurrentRunId();
	if run ~= nil and run ~= M.closedRun then M.closed, M.closedRun = nil, nil; return false; end
	return true;
end

-- the rate right now: a short recent window when the game offers one, else the whole run
local function NowRate(snapshot)
	if not (AZS_GetMeterContext and AZS_GetMeterSnapshot) or M.view == 'group' then
		return snapshot and snapshot.totals and snapshot.totals.displayRate;
	end
	local now = GetTime();
	if now >= (M.nextNow or 0) then
		M.nextNow = now + 1;
		local ctx = AZS_GetMeterContext();
		local result;
		if type(ctx) == 'table' and ctx.runId then
			local q = { apiVersion = 1, runId = ctx.runId, metric = M.view == 'healing' and 'healing' or 'damage', scope = 'self',
				period = M.view == 'boss' and 'encounter' or 'run', groupBy = 'source', windowSeconds = 5 };
			if M.view == 'healing' then q.healingPerspective = 'performed'; end
			local ok, r = SS.Safe(AZS_GetMeterSnapshot, q);
			if ok and type(r) == 'table' then result = r.totals and r.totals.displayRate; end
		end
		M.nowRate = result;
	end
	if type(M.nowRate) == 'table' and M.nowRate.status == 'ready' then return M.nowRate; end
	return snapshot and snapshot.totals and snapshot.totals.displayRate;
end

local function ByAmount(a, b)
	local av, bv = Num(a.displayAmount), Num(b.displayAmount);
	if av ~= bv then return av > bv; end
	return tostring(a.rowId) < tostring(b.rowId);
end
function M.Draw(active, editing)
	local f = M.frame; if not f then return; end
	local healing = M.view == 'healing';
	local unit = healing and 'hps' or 'dps';
	local width = f:GetWidth();
	f.title:SetText(ViewName(M.view));
	f.reset:Hide(); f.back:Hide();
	if M.view == 'damage' or M.view == 'healing' then f.reset:Show(); elseif M.view == 'group' and M.owner then f.back:Show(); end
	local now = GetTime();
	if now >= (M.nextRead or 0) then
		M.nextRead = now + 0.35;
		local snapshot, err = Query(); M.snapshot = snapshot; M.error = err;
		M.nextRead = now + math.max(0.35, type(err) == 'table' and Num(err.retryAfterSeconds) or 0);
	end
	if SS.demoRunning and M.demoSnapshot then M.snapshot = M.demoSnapshot; M.error = nil; end   -- Demo Mode: sample rows
	local snapshot = M.snapshot;
	-- the rows are copied and sorted once per new snapshot (it changes about three times a second), not on every redraw
	local rows = M.sortedRows;
	if not rows or M.sortedFor ~= snapshot or (SS.demoRunning and M.demoSnapshot) then
		rows = {};
		if snapshot then for _, row in ipairs(snapshot.rows or {}) do table.insert(rows, row); end end
		table.sort(rows, ByAmount);
		M.sortedRows, M.sortedFor = rows, snapshot;
	end
	local rate = NowRate(snapshot);
	local rateValue = type(rate) == 'table' and rate.status == 'ready' and Short(rate.value) or '0';
	local rateText = unit .. ' · now ' .. rateValue;
	if healing and M.absorbed and M.absorbed > 0 then rateText = rateText .. ' · absorbed ' .. Short(M.absorbed); end
	-- keep the rate between the "^" button and Reset / x
	local rightEdge = (f.reset:IsShown() or f.back:IsShown()) and 68 or 24;
	local room = math.max(16, width - 9 - (f.title:GetStringWidth() or 80) - 6 - 14 - 6 - rightEdge);
	FitString(f.rate, rateText, room, 9);
	if (f.rate:GetStringWidth() or 0) > room then FitString(f.rate, rateValue .. ' ' .. unit, room, 9); end
	M.rows = rows; M.visible = math.max(1, math.min(64, math.floor((f:GetHeight() - HEADER - 12) / ROW_H)));
	M.offset = math.max(0, math.min(M.offset, math.max(0, Count(rows) - M.visible)));
	if Count(rows) == 0 then
		local msg = M.message;
		if not active and not msg then M.error = nil; end
		if not msg and type(M.error) == 'table' then
			msg = M.error.code == 'NO_PARTY' and 'Join a party to see party DPS.' or M.error.code == 'NO_ENCOUNTER' and 'No boss fight yet.' or nil;
		elseif not msg and type(M.error) == 'string' and not editing then msg = M.error; end
		if not msg then msg = healing and 'No healing yet.' or M.view == 'boss' and 'No boss damage yet.' or M.view == 'group' and 'No party damage yet.' or 'No damage yet.'; end
		f.empty:SetWidth(math.max(40, width - 18)); f.empty:SetText(msg); f.empty:Show();
	else
		f.empty:Hide();
	end
	local top = rows[1] and Num(rows[1].displayAmount) or 0;
	for i, button in ipairs(f.rows) do
		local row = i <= M.visible and rows[M.offset + i] or nil;
		if row then
			local source = snapshot.sources and snapshot.sources[row.sourceKey]; local actor = snapshot.actors and snapshot.actors[row.ownerId];
			button.entry = row; button.source = source; button.label = source and source.name or actor and actor.name or 'Unknown source';
			local rowWidth = math.max(20, width - 10); button:SetWidth(rowWidth);
			local share = top > 0 and Num(row.displayAmount) / top or 0;
			button.bar:SetWidth(math.max(1, rowWidth * math.max(0, math.min(1, share))));
			local r = row.displayRate and row.displayRate.status == 'ready' and Short(row.displayRate.value) or nil;
			local value = Short(row.displayAmount) .. (r and ('  (' .. r .. ')') or '');
			local valueWidth = math.max(60, math.floor(rowWidth * 0.45));
			FitString(button.value, value, valueWidth, 8);
			FitString(button.name, button.label, math.max(24, rowWidth - 20 - valueWidth - 4), 8);
			local color = M.view == 'group' and not M.owner and SS.ClassColor and SS.ClassColor(ClassOf(actor));   -- Slim Suite's one class colour table
			if color then button.name:SetTextColor(color[1], color[2], color[3]);
			else button.name:SetTextColor(CREAM[1], CREAM[2], CREAM[3]); end
			if source and source.icon and source.icon.status == 'ready' then button.icon:SetTexture(source.icon.path); button.icon:Show(); button.name:SetPoint('LEFT', button, 'LEFT', 18, 0);
			else button.icon:Hide(); button.name:SetPoint('LEFT', button, 'LEFT', 4, 0); end
			button:Show();
		else button.entry = nil; button:Hide(); end
	end
end

-- The stream belongs to this addon alone; polling never consumes another addon's events.
local stream=CreateFrame('Frame');
function M.Drain()
	if not AZS_GetCombatTextEvents or not AZS_GetMeterContext then return;end
	local context=AZS_GetMeterContext();if not context then return;end;SyncContext(context);
	for read=1,16 do
		local batch,err=AZS_GetCombatTextEvents(M.cursor,256);
		if not batch then if err and err.code=='STREAM_CHANGED' then M.cursor=nil;end;return;end
		M.cursor=batch.cursor;M.dropped=(M.dropped or 0)+Num(batch.droppedCount);
		for _,event in ipairs(batch.events or {}) do
			for _,fn in ipairs(M.listeners) do SS.Safe(fn,event);end
			if event.kind=='damage' then AddSample('damage',event.meterSourceKey or (event.spellId and ('spell:'..tostring(event.spellId)) or ('name:'..Name(event.abilityName or event.damageType))),event.amount,event.critical==true);end
		end
		if not batch.hasMore then break;end
	end
end
SS.Every('meterStream',0.1,function() M.Drain(); end, stream);
-- Match only localized heal formats the client actually supplies. Do not parse player chat.
local healPatterns;
local function BuildHealPatterns()
	local formats={
		{'HEALEDCRITSELFSELF',1,2,true,'healing'},{'HEALEDCRITSELFOTHER',1,3,true,'healing'},
		{'HEALEDCRITOTHERSELF',2,3,true,'healing',1},{'HEALEDCRITOTHEROTHER',2,4,true,'healing',1},
		{'HEALEDSELFSELF',1,2,false,'healing'},{'HEALEDSELFOTHER',1,3,false,'healing'},
		{'HEALEDOTHERSELF',2,3,false,'healing',1},{'HEALEDOTHEROTHER',2,4,false,'healing',1},
		{'SPELLLOGCRITSELFOTHER',1,3,true,'damage'},{'SPELLLOGCRITOTHEROTHER',2,4,true,'damage',1},
		{'SPELLLOGSELFOTHER',1,3,false,'damage'},{'SPELLLOGOTHEROTHER',2,4,false,'damage',1}
	};
	healPatterns={};
	for _,format in ipairs(formats) do
		local text=getglobal(format[1]);if type(text)=='string' then
			local pattern='';local i=1;local captures={};local nextField=0;
			while i<=string.len(text) do
				local tail=string.sub(text,i);
				local a,b,pos,typ=string.find(tail,'^%%(%d+)%$([sd])');
				if not a then a,b,typ=string.find(tail,'^%%([sd])');pos=nil;end
				if a then nextField=nextField+1;table.insert(captures,tonumber(pos) or nextField);pattern=pattern..(typ=='d' and '(%d+)' or '(.-)');i=i+b;
				else local ch=string.sub(text,i,i);pattern=pattern..string.gsub(ch,'([%^%$%(%)%%%.%[%]%*%+%-%?])','%%%1');i=i+1;end
			end
			table.insert(healPatterns,{pattern='^'..pattern..'$',fields=captures,spell=format[2],amount=format[3],crit=format[4],metric=format[5],actor=format[6]});
		end
	end
end
local log=CreateFrame('Frame');
for _,name in ipairs({'CHAT_MSG_SPELL_SELF_BUFF','CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS','CHAT_MSG_SPELL_PARTY_BUFF','CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF','CHAT_MSG_SPELL_PET_BUFF','CHAT_MSG_SPELL_SELF_DAMAGE','CHAT_MSG_SPELL_PARTY_DAMAGE','CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE','CHAT_MSG_SPELL_PET_DAMAGE','VARIABLES_LOADED'}) do SS.Safe(log.RegisterEvent,log,name);end
log:SetScript('OnEvent',function()
		if event=='VARIABLES_LOADED' then BuildHealPatterns();return;end
		if type(arg1)~='string' then return;end
		-- our own spells' and pets' damage comes from the game's hit stream when it has one: its log lines are not read at all
		if AZS_GetCombatTextEvents and (event=='CHAT_MSG_SPELL_SELF_DAMAGE' or event=='CHAT_MSG_SPELL_PET_DAMAGE') then return;end
		if AZS_GetMeterContext then local context=AZS_GetMeterContext();if not context then return;end;SyncContext(context);end
		if not healPatterns then BuildHealPatterns();end
		for _,format in ipairs(healPatterns) do
			local found,_,m1,m2,m3,m4=string.find(arg1,format.pattern);   -- a line has at most four parts
			if found then
				local fields=M.fields;fields[1],fields[2],fields[3],fields[4]=nil,nil,nil,nil;
				local order=format.fields;
				if order[1] then fields[order[1]]=m1;end;if order[2] then fields[order[2]]=m2;end
				if order[3] then fields[order[3]]=m3;end;if order[4] then fields[order[4]]=m4;end
				local owner=format.actor and M.knownActors and M.knownActors[fields[format.actor]] or (not format.actor and M.context and M.context.localOwnerId);
				local isLocal=owner and M.context and owner==M.context.localOwnerId;
				-- The native outgoing stream already covers our own pets and spells. Never count its
				-- matching damage log a second time. Other owners require a known, unambiguous actor.
				if owner and fields[format.spell] and not (format.metric=='damage' and isLocal and AZS_GetCombatTextEvents) then AddSample(format.metric,'name:'..Name(fields[format.spell]),tonumber(fields[format.amount]),format.crit,owner);end
				return;
			end
		end
	end);
