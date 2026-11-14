-- Live totals and an observed pre-run baseline; gear/racial bonuses are never added twice.
if ( setfenv ) then setfenv(1, SS.ENV); end
SS.STAT_FIELDS={{"hp","Maximum HP"},{"dmg","Damage multiplier"},{"cd","Cooldown multiplier"},{"crit","Critical chance"},{"cm","Critical multiplier"},{"arm","Damage reduction"},{"reg","HP per second"},{"area","Area"},{"cnt","Extra targets"},{"echo","Echo"},{"spd","Speed"},{"pick","Pickup range"},{"xp","XP bonus"},{"luck","Luck"},{"gold","Gold bonus"},{"heal","Heal per kill"},{"lch","Leech"},{"thn","Thorns"},{"liv","Lives"}};
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
function SS.StatEntries()
 local baseline=SS.CaptureStatBaseline();
 local stats=type(AZS_STATS)=="table" and AZS_STATS or {};
 local run=type(AZS_RUN)=="table" and AZS_RUN or {};
 local d=SS.DB(); d.statHidden=d.statHidden or {};
 local out={};
 local function Add(key,label,value)
  if ( not d.statHidden[key] ) then table.insert(out,{key=key,label=SS.T(label),value=value}); end
 end
 local hp=tonumber(run.hp) or (UnitHealth and UnitHealth("player"));
 local maximum=tonumber(run.hpm) or tonumber(stats.hp) or (UnitHealthMax and UnitHealthMax("player"));
 local shield=tonumber(run.sh) or (SS.AbsorbAmount and SS.AbsorbAmount("player"));
 Add("health","HP",Number(hp).." / "..Number(maximum).." ("..Number(shield)..")");
 for _,field in ipairs(SS.STAT_FIELDS) do
  local total=field[1]=="hp" and maximum or stats[field[1]];
  Add(field[1],field[2],SS.StatValue(field[1],total,baseline));
 end
 local race=type(UnitRace)=="function" and UnitRace("player") or nil;
 local spells=type(AZS_SPELLS)=="table" and AZS_SPELLS or {};
 local racial=spells[table.getn(spells)];
 Add("racial","Racial",tostring(race or "-")..(racial and (" / "..tostring(racial.key or "-").." ("..Number(racial.cd).."s)") or ""));
 local buffs=type(AZS_BUFFS)=="table" and AZS_BUFFS or {}; local active={};
 for _,buff in ipairs(buffs) do if ( type(buff)=="table" ) then table.insert(active,tostring(buff.spell or "-").." ("..Number(buff.left).."s)"); end end
 Add("buffs","Active buffs",table.getn(active)>0 and table.concat(active,", ") or "-");
 return out;
end
function SS.StatLines()
 local lines={}; for _,entry in ipairs(SS.StatEntries()) do table.insert(lines,entry.label..": "..entry.value); end; return lines;
end
function SS.StatSettings()
 local group=SS.statSettingsGroup or "core";
 local groups={hp="core",dmg="core",cd="core",crit="core",arm="core",reg="core",cm="combat",area="combat",cnt="combat",echo="combat",lch="combat",thn="combat"};
 local rows={{"Stat display",function() return SS.DB().statDisplayMode or "total"; end,function(v) SS.DB().statDisplayMode=v; SS.UpdateStats(); end,
  choice={{"Combined total","total"},{"Default + Bonus (since run start)","split"}} },
  {"Stats category",function() return SS.statSettingsGroup or "core"; end,function(v) SS.statSettingsGroup=v; SU.Focus("SlimSuiteStatCounterFrame"); end,
  choice={{"Core stats","core"},{"Combat stats","combat"},{"Utility stats","utility"},{"Details","details"}} }};
 local function Add(key,label)
  table.insert(rows,{label,function() return not (SS.DB().statHidden or {})[key]; end,function(v)
   local d=SS.DB(); d.statHidden=d.statHidden or {}; d.statHidden[key]=not v; SS.MarkProfileDirty(); SS.UpdateStats();
  end});
 end
 if ( group=="core" ) then Add("health","HP"); end
 for _,field in ipairs(SS.STAT_FIELDS) do if ( (groups[field[1]] or "utility")==group ) then Add(field[1],field[2]); end end
 if ( group=="details" ) then Add("racial","Racial"); Add("buffs","Active buffs"); end
 return rows;
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
 frame:Show(); if ( frame.statSignature==signature ) then return; end; frame.statSignature=signature;
 for i=1,math.max(capacity,table.getn(frame.rows)) do
  local row=frame.rows[i]; local entry=i<=capacity and entries[i+frame.offset];
  if ( entry ) then
   if ( not row ) then
    row=CreateFrame("Frame",nil,frame); frame.rows[i]=row; row:SetHeight(14); row:EnableMouse(true);
    row.label=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); row.value=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
    row.label:SetPoint("LEFT",row,"LEFT",0,0); row.value:SetPoint("RIGHT",row,"RIGHT",0,0);
    row:SetScript("OnEnter",function()
     if ( GameTooltip ) then GameTooltip:SetOwner(this,"ANCHOR_RIGHT"); GameTooltip:AddLine(this.fullText,1,1,1,1); GameTooltip:Show(); end
    end);
    row:SetScript("OnLeave",function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
   end
   row:ClearAllPoints(); row:SetPoint("TOPLEFT",frame,"TOPLEFT",6,-6-(i-1)*14); row:SetWidth(math.max(1,w-12));
   row.fullText=entry.label..": "..entry.value;
   row.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",10); row.value:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",10);
   row.label:SetText(entry.label); row.value:SetText(entry.value);
   SS.FitText(row.value,math.max(0,w-58),7,12,entry.value);
   SS.FitText(row.label,math.max(0,w-20-(row.value:GetStringWidth() or 0)),7,12,entry.label);
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
