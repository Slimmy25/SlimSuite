-- Live totals and an observed pre-run baseline; gear/racial bonuses are never added twice.
local K, SU, NAME = SS.Kit, SS.SU, SS.NAME;   -- the three names every Slim Suite file uses (SlimSuiteCore.lua)
SS.STAT_FIELDS={{"hp","Maximum HP"},{"dmg","Damage multiplier"},{"cd","Cooldown multiplier"},{"crit","Critical chance"},{"cm","Critical multiplier"},{"arm","Damage reduction"},{"reg","HP per second"},{"area","Area"},{"cnt","Extra targets"},{"echo","Echo"},{"spd","Speed"},{"pick","Pickup range"},{"xp","XP bonus"},{"luck","Luck"},{"gold","Gold bonus"},{"heal","Heal per kill"},{"lch","Leech"},{"thn","Thorns"},{"liv","Lives"}};
-- What each stat means (hover text), its icon and colour. "low" marks a stat where lower is better.
SS.STAT_INFO={
	health={icon="Spell_Holy_PowerWordShield",color={0.35,1,0.4},tip="Your health now, out of your maximum. The number in brackets is the shield you carry now, which is used up before your health."},
	hp={icon="INV_Potion_51",color={0.35,1,0.4},tip="The most health you can have. Healing never takes you above it."},
	dmg={icon="Ability_Warrior_BattleShout",color={1,0.45,0.3},tip="Everything you deal is multiplied by this. 1.50 means half again as much damage as with no bonus."},
	cd={icon="Spell_Nature_TimeStop",color={0.45,0.8,1},low=true,tip="Your abilities' waits between uses are multiplied by this. Lower is better: 0.80 means they come back 20% sooner."},
	crit={icon="Ability_CriticalStrike",color={1,0.8,0.25},tip="The chance that a hit is a critical hit."},
	cm={icon="Ability_Rogue_Ambush",color={1,0.8,0.25},tip="How much harder a critical hit lands than a normal one: a hit is multiplied by this when it crits."},
	arm={icon="INV_Shield_06",color={0.75,0.75,0.85},tip="How much less damage you take from enemies' hits."},
	reg={icon="Spell_Nature_Rejuvenation",color={0.35,1,0.4},tip="Health you get back every second, all the time."},
	area={icon="Spell_Fire_SelfDestruct",color={1,0.55,0.2},tip="The size of your area spells and effects, compared with their normal size."},
	cnt={icon="Ability_UpgradeMoonGlaive",color={1,0.55,0.2},tip="How many more enemies your abilities hit or fire at, on top of their usual number."},
	echo={icon="Spell_Nature_WispSplode",color={0.75,0.55,1},tip="The chance that an ability goes off a second time by itself."},
	spd={icon="Ability_Rogue_Sprint",color={0.45,0.8,1},tip="How fast you move, compared with normal speed."},
	pick={icon="INV_Misc_Bag_08",color={0.9,0.9,0.6},tip="How far away experience wisps and gold come to you on their own."},
	xp={icon="INV_Misc_Book_11",color={0.75,0.55,1},tip="Extra experience from every wisp you pick up."},
	luck={icon="INV_Misc_Rune_06",color={0.3,1,0.6},tip="Raises your chance of rarer cards and items. The Legendary luck element shows what it means for legendaries."},
	gold={icon="INV_Misc_Coin_01",color={1,0.82,0},tip="Extra gold from every pile you pick up."},
	heal={icon="Spell_Holy_FlashHeal",color={0.35,1,0.4},tip="Health you get back each time you kill an enemy."},
	lch={icon="Spell_Shadow_LifeDrain02",color={0.8,0.3,0.4},tip="Part of the damage you deal comes back to you as health."},
	thn={icon="Spell_Nature_Thorns",color={0.6,0.85,0.3},tip="Part of the damage enemies deal you is dealt back to them."},
	liv={icon="Spell_Holy_Resurrection",color={1,0.95,0.6},tip="Extra lives: how many times you can get back up by yourself after you fall."},
	racial={icon="Spell_Holy_HolyProtection",color={0.9,0.75,0.5},tip="Your race and its racial ability, with how long it waits between uses."},
	buffs={icon="Spell_Holy_WordFortitude",color={0.6,0.85,1},tip="The buffs on you now and how long each has left."},
};
-- stats the game sends that Slim Suite has no name for yet are shown too (under the game's own short name), so a new
-- stat is never missed; gear-only parts (names starting with g) are already inside the totals and are left out
local function KnownStat(key)
	for _,field in ipairs(SS.STAT_FIELDS) do if ( field[1]==key ) then return true; end end
	return false;
end
local function Number(v)
	if ( type(v)~="number" ) then return "-"; end
	if ( v==math.floor(v) ) then return tostring(v); end
	return string.format("%.2f",v);
end
function SS.CaptureStatBaseline()
	local phase=type(AZS_GetPhase)=="function" and AZS_GetPhase() or nil;
	local key=type(AZS_ZONE)=="table" and AZS_ZONE.run;
	local stats=type(AZS_STATS)=="table" and AZS_STATS;
	local saved=SS.DB().statBaseline;
	if ( phase=="ready" and SS.statPreviousPhase~="ready" ) then SS.statReadyAt=GetTime(); SS.statBaselinePending=true; end
	local fresh=type(AZS_STATS_UPDATED)~="number" or AZS_STATS_UPDATED>=(SS.statReadyAt or 0);
	if ( phase=="ready" and fresh and stats and next(stats) and (not saved or saved.run~=key or SS.statBaselinePending) ) then
		saved={run=key,values={}};
		for _,field in ipairs(SS.STAT_FIELDS) do saved.values[field[1]]=stats[field[1]]; end
		if ( type(AZS_RUN)=="table" and type(AZS_RUN.hpm)=="number" ) then saved.values.hp=AZS_RUN.hpm; end
		SS.DB().statBaseline=saved; SS.statBaselineSession=true; SS.statBaselinePending=false;
	end
	SS.statPreviousPhase=phase;
	if ( saved and saved.run==key and (key~=nil or SS.statBaselineSession) ) then return saved.values; end
end
function SS.StatValue(key,total,baseline)
	local base=baseline and baseline[key];
	local percentages={crit=true,arm=true,echo=true,luck=true,lch=true,thn=true};
	local function Format(v) return percentages[key] and type(v)=="number" and (Number(v*100).."%") or Number(v); end
	if ( SS.DB().statDisplayMode=="split" and type(total)=="number" and type(base)=="number" ) then
		local bonus=total-base; return Format(base)..(bonus<0 and " - " or " + ")..Format(math.abs(bonus));
	end
	return Format(total);
end
-- Every stat's key in the order the player set (drag and drop in the right-click menu). Keys not saved yet keep
-- their default place, after the saved ones.
function SS.StatOrder()
	local defaults={"health"};
	for _,field in ipairs(SS.STAT_FIELDS) do table.insert(defaults,field[1]); end
	table.insert(defaults,"racial"); table.insert(defaults,"buffs");
	local saved=SS.DB().statOrder or {};
	local known,out={}, {};
	for _,key in ipairs(defaults) do known[key]=true; end
	local seen={};
	for _,key in ipairs(saved) do if known[key] and not seen[key] then table.insert(out,key); seen[key]=true; end end
	for _,key in ipairs(defaults) do if not seen[key] then table.insert(out,key); seen[key]=true; end end
	return out;
end
function SS.StatEntries()
	local baseline=SS.CaptureStatBaseline();
	local stats=type(AZS_STATS)=="table" and AZS_STATS or {};
	local run=type(AZS_RUN)=="table" and AZS_RUN or {};
	local d=SS.DB(); d.statHidden=d.statHidden or {};
	local out={};
	local function Add(key,label,value)
		if ( not d.statHidden[key] ) then
			local total=key=="hp" and (tonumber(run.hpm) or stats.hp) or stats[key];
			table.insert(out,{key=key,label=SS.T(label),value=value,total=total,base=baseline and baseline[key]});
		end
	end
	local hp=tonumber(run.hp) or (UnitHealth and UnitHealth("player"));
	local maximum=tonumber(run.hpm) or tonumber(stats.hp) or (UnitHealthMax and UnitHealthMax("player"));
	local shield=tonumber(run.sh) or (SS.AbsorbAmount and SS.AbsorbAmount("player"));
	Add("health","HP",Number(hp).." / "..Number(maximum).." ("..Number(shield)..")");
	for _,field in ipairs(SS.STAT_FIELDS) do
		local total=field[1]=="hp" and maximum or stats[field[1]];
		Add(field[1],field[2],SS.StatValue(field[1],total,baseline));
	end
	local extra={};
	for key,value in pairs(stats) do
		if ( type(key)=="string" and type(value)=="number" and not KnownStat(key) and string.sub(key,1,1)~="g" ) then table.insert(extra,key); end
	end
	table.sort(extra);
	for _,key in ipairs(extra) do Add(key,key,SS.StatValue(key,stats[key],baseline)); end
	local race=type(UnitRace)=="function" and UnitRace("player") or nil;
	local spells=type(AZS_SPELLS)=="table" and AZS_SPELLS or {};
	local racial=spells[table.getn(spells)];
	Add("racial","Racial",tostring(race or "-")..(racial and (" / "..tostring(racial.key or "-").." ("..Number(racial.cd).."s)") or ""));
	local buffs=type(AZS_BUFFS)=="table" and AZS_BUFFS or {}; local active={};
	for _,buff in ipairs(buffs) do if ( type(buff)=="table" ) then table.insert(active,tostring(buff.spell or "-").." ("..Number(buff.left).."s)"); end end
	Add("buffs","Active buffs",table.getn(active)>0 and table.concat(active,", ") or "-");
	-- the player's order; anything not in it (extra stats) stays after, in the order it was found
	local rank={}; local order=SS.StatOrder();
	for i=1,table.getn(order) do rank[order[i]]=i; end
	for i=1,table.getn(out) do out[i].seq=i; out[i].rank=rank[out[i].key] or (100+i); end
	table.sort(out,function(a,b) if a.rank~=b.rank then return a.rank<b.rank; end return a.seq<b.seq; end);
	return out;
end
function SS.StatLines()
	local lines={}; for _,entry in ipairs(SS.StatEntries()) do table.insert(lines,entry.label..": "..entry.value); end; return lines;
end
-- one list of every stat, each with its own switch (no categories)
function SS.StatSettings()
	local rows={{"Stat display",function() return SS.DB().statDisplayMode or "total"; end,function(v) SS.DB().statDisplayMode=v; SS.UpdateStats(); end,
		choice={{"Combined total","total"},{"Default + Bonus (since run start)","split"}} }};
	local labels={ health="HP", racial="Racial", buffs="Active buffs" };
	for _,field in ipairs(SS.STAT_FIELDS) do labels[field[1]]=field[2]; end
	-- one row per stat, in the player's order; each can be dragged by its grip to a new place
	local order=SS.StatOrder();
	for i=1,table.getn(order) do
		local key=order[i];
		table.insert(rows,{labels[key] or key,function() return not (SS.DB().statHidden or {})[key]; end,function(v)
			local d=SS.DB(); d.statHidden=d.statHidden or {}; d.statHidden[key]=not v; SS.MarkProfileDirty(); SS.UpdateStats();
		end, order=key});
	end
	return rows;
end

-- Drag and drop: hold the grip, move over the row you want, let go. The stat moves to that row's place.
SU.statDrag={};
function SU.StatDragTarget()
	local cursorX,cursorY=GetCursorPosition(); local scale=UIParent:GetEffectiveScale();
	cursorY=cursorY/scale;
	local hit;
	for i=1,table.getn(SU.checks or {}) do
		local row=SU.checks[i];
		if row and row.drag and row:IsShown() and row.get then
			local top,bottom=row:GetTop(),row:GetBottom();
			if top and bottom and cursorY<=top+4 and cursorY>=bottom-4 then hit=row; end
		end
	end
	return hit;
end
function SU.StartStatDrag(grip)
	SU.statDrag.row=grip.row; SU.statDrag.key=grip.key;
	grip.row:SetAlpha(.5);
	if not SU.statDragDriver then SU.statDragDriver=CreateFrame("Frame"); end
	SU.statDragDriver:SetScript("OnUpdate",function()
		local hit=SU.StatDragTarget();
		if SU.statDrag.drop and SU.statDrag.drop~=hit then SU.statDrag.drop.label:SetTextColor(1,1,1); end
		SU.statDrag.drop=hit;
		if hit and hit~=SU.statDrag.row then hit.label:SetTextColor(1,.82,.25); end
	end);
end
function SU.EndStatDrag()
	if not SU.statDrag.row then return; end
	if SU.statDragDriver then SU.statDragDriver:SetScript("OnUpdate",nil); end
	SU.statDrag.row:SetAlpha(1);
	local target=SU.statDrag.drop;
	if target and target.drag and target~=SU.statDrag.row then target.label:SetTextColor(1,1,1); end
	if target and target.drag and target.drag.key~=SU.statDrag.key then
		local order=SS.StatOrder(); local from,to;
		for i=1,table.getn(order) do
			if order[i]==SU.statDrag.key then from=i; end
			if order[i]==target.drag.key then to=i; end
		end
		if from and to then
			local key=table.remove(order,from);
			table.insert(order,to,key);
			SS.DB().statOrder=order; SS.MarkProfileDirty(); SS.UpdateStats();
		end
	end
	SU.statDrag={};
	if SU.Focus then SS.Safe(SU.Focus,"SlimSuiteStatCounterFrame"); end
end


function SS.UpdateStats()
	SS.CaptureStatBaseline();
	local frame=SU.statCounterPlaceholder;
	if ( not SS.FeatureEnabled("SlimSuiteStatCounterFrame") or SS.DB().vanillaUI ) then frame:Hide(); return; end
	frame.label:Hide(); frame.rows=frame.rows or {};
	if ( not SS.DB().sizes.SlimSuiteStatCounterFrame ) then frame:SetWidth(230); frame:SetHeight(170); end
	local w,h=frame:GetWidth(),frame:GetHeight(); local capacity=math.max(0,math.floor((h-12)/14));
	local entries=SS.StatEntries(); frame.offset=math.max(0,math.min(frame.offset or 0,table.getn(entries)-capacity));
	local lines=SS.StatLines(); local signature=table.concat(lines,"|")..w..":"..h..":"..frame.offset;
	-- a value that is flashing must be redrawn when its flash ends, so the flash state is part of the signature
	for _,row in ipairs(frame.rows) do if ( row.flashUntil and GetTime()<row.flashUntil ) then signature=signature.."!"; end end
	frame:Show(); if ( frame.statSignature==signature ) then return; end; frame.statSignature=signature;
	for i=1,math.max(capacity,table.getn(frame.rows)) do
		local row=frame.rows[i]; local entry=i<=capacity and entries[i+frame.offset];
		if ( entry ) then
			if ( not row ) then
				row=CreateFrame("Frame",nil,frame); frame.rows[i]=row; row:SetHeight(14); row:EnableMouse(true);
				row.label=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); row.value=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
				row.shade=row:CreateTexture(nil,"BACKGROUND"); row.shade:SetAllPoints(row); row.shade:SetTexture(1,1,1,1);
				row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetWidth(12); row.icon:SetHeight(12); row.icon:SetPoint("LEFT",row,"LEFT",1,0);
				row.icon:SetTexCoord(0.08,0.92,0.08,0.92);
				row.label:SetPoint("LEFT",row.icon,"RIGHT",4,0); row.value:SetPoint("RIGHT",row,"RIGHT",-2,0);
				row:SetScript("OnEnter",function()
					if ( not GameTooltip ) then return; end
					local e=this.entry or {}; local info=SS.STAT_INFO[e.key] or {};
					GameTooltip:SetOwner(this,"ANCHOR_RIGHT");
					GameTooltip:AddLine(e.label or "",1,0.82,0);
					GameTooltip:AddLine(e.value or "",1,1,1,1);
					if ( info.tip ) then GameTooltip:AddLine(SS.T(info.tip),0.85,0.85,0.85,1);
					elseif ( not KnownStat(e.key or "") and e.key~="health" ) then GameTooltip:AddLine(SS.T("A stat the game sends that Slim Suite has no description for yet."),0.85,0.85,0.85,1); end
					if ( type(e.total)=="number" and type(e.base)=="number" ) then
						local change=e.total-e.base;
						local better=(change>0)~=(info.low and true or false);
						GameTooltip:AddLine(" ");
						GameTooltip:AddDoubleLine(SS.T("At the start of the run"),SS.StatValue(e.key,e.base,nil),0.8,0.8,0.8,1,1,1);
						if ( change~=0 ) then
							GameTooltip:AddDoubleLine(SS.T("Change this run"),(change>0 and "+" or "-")..SS.StatValue(e.key,math.abs(change),nil),0.8,0.8,0.8,better and 0.3 or 1,better and 1 or 0.35,better and 0.4 or 0.3);
						end
					end
					if ( info.low ) then GameTooltip:AddLine(SS.T("Lower is better."),0.6,0.8,1); end
					GameTooltip:Show();
				end);
				row:SetScript("OnLeave",function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
			end
			row:ClearAllPoints(); row:SetPoint("TOPLEFT",frame,"TOPLEFT",6,-6-(i-1)*14); row:SetWidth(math.max(1,w-12));
			row.fullText=entry.label..": "..entry.value; row.entry=entry;
			local info=SS.STAT_INFO[entry.key] or {}; local c=info.color or {0.85,0.85,0.85};
			row.icon:SetTexture("Interface\\Icons\\"..(info.icon or "INV_Misc_QuestionMark"));
			row.shade:SetVertexColor(c[1],c[2],c[3],math.mod(i,2)==0 and 0.07 or 0.03);   -- a faint stripe in the stat's own colour
			row.label:SetTextColor(c[1],c[2],c[3]);
			-- the value flashes green when it gets better and red when worse, then settles back to white
			frame.lastValues=frame.lastValues or {};
			local before=frame.lastValues[entry.key]; local now=entry.total;
			if ( type(before)=="number" and type(now)=="number" and before~=now ) then
				row.flashUntil=GetTime()+1.2; row.flashGood=((now>before)~=(info.low and true or false));
			end
			frame.lastValues[entry.key]=now;
			row.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",10); row.value:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",10);
			row.label:SetText(entry.label); row.value:SetText(entry.value);
			if ( row.flashUntil and GetTime()<row.flashUntil ) then
				if ( row.flashGood ) then row.value:SetTextColor(0.3,1,0.4); else row.value:SetTextColor(1,0.35,0.3); end
			else row.value:SetTextColor(1,1,1); end
			SS.FitText(row.value,math.max(0,w-58),7,12,entry.value);
			SS.FitText(row.label,math.max(0,w-36-(row.value:GetStringWidth() or 0)),7,12,entry.label);
			row:Show();
		elseif ( row ) then row:Hide(); end
	end
	if ( SS.EnforceElementBounds ) then SS.EnforceElementBounds(frame); end
end
local frame=SU.statCounterPlaceholder;
frame:SetWidth(230); frame:SetHeight(170); frame:SetPoint("LEFT",UIParent,"LEFT",20,0);
frame:EnableMouseWheel(true);
frame:SetScript("OnMouseWheel",function() this.offset=math.max(0,(this.offset or 0)-(arg1 or 0)); SS.UpdateStats(); end);
SS.Every("liveStats",.25,function() SS.Safe(SS.UpdateStats); end);
