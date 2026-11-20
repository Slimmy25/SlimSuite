-- Optional legendary-percentage display using the supplied rarity-weight model.
if ( setfenv ) then setfenv(1, SS.ENV); end
local frame=CreateFrame("Frame","SlimSuiteLuckFrame",UIParent);
frame:SetWidth(300); frame:SetHeight(212); frame:SetPoint("CENTER",UIParent,"CENTER",250,-130);
-- a flat, dark card with a thin gold edge
frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",tile=true,tileSize=8,edgeSize=1,insets={left=1,right=1,top=1,bottom=1}});
frame:Hide();
local function Line(size,x,y,align)
 local fs=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); fs:SetJustifyH(align or "LEFT");
 fs:SetPoint(align=="RIGHT" and "TOPRIGHT" or "TOPLEFT",frame,align=="RIGHT" and "TOPRIGHT" or "TOPLEFT",x,y);
 if size then SS.SetGameDefaultFont(fs,size); end
 return fs;
end
frame.title=Line(10,10,-8); frame.title:SetTextColor(1,.8,.25);
frame.luckTag=Line(nil,-10,-8,"RIGHT");
frame.big=Line(20,10,-24); frame.big:SetTextColor(1,.9,.45);
frame.bigTag=Line(nil,10,-50); frame.bigTag:SetTextColor(.65,.65,.65);
frame.gain=Line(nil,-10,-30,"RIGHT");
frame.barBack=frame:CreateTexture(nil,"BACKGROUND"); frame.barBack:SetTexture(1,1,1,.08);
frame.barBack:SetPoint("TOPLEFT",frame,"TOPLEFT",10,-70); frame.barBack:SetWidth(280); frame.barBack:SetHeight(6);
frame.barFill=frame:CreateTexture(nil,"ARTWORK"); frame.barFill:SetTexture(1,.8,.25,.9);
frame.barFill:SetPoint("TOPLEFT",frame,"TOPLEFT",10,-70); frame.barFill:SetWidth(1); frame.barFill:SetHeight(6);
frame.dots={};
frame.marker=frame:CreateTexture(nil,"OVERLAY"); frame.marker:SetTexture(1,1,1,1); frame.marker:SetWidth(7); frame.marker:SetHeight(7); frame.marker:Hide();
frame.miles={};
for i=1,4 do frame.miles[i]=Line(nil,10+(i-1)*72,-172); end
frame.note=Line(nil,10,-190); frame.note:SetWidth(280);
frame.origin=Line(nil,10,-204); frame.origin:SetTextColor(.5,.5,.5);
function SS.RestyleLuck() frame.panelStyle=nil; SS.ApplyPanelStyle(frame); end
function SS.LegendaryChance(luck,level,bonus)
 if type(luck)~="number" or type(level)~="number" or level<0 then return; end
 local k=math.max(0,1+luck+math.min(.30,level*.01)+(bonus or 0));
 if k>1 then return 1/(60/(k*k*k*k)+25/(k*k*k)+10/(k*k)+4/k+1); end
 local square=k*k; return square*square/(60+25*k+10*square+4*square*k+square*square);
end
local progress={run=nil,session=false,phase=nil,maxLuck=2,maxChance=.4};
function SS.LuckProgress()
 local run=type(AZS_ZONE)=="table" and AZS_ZONE.run;
 if run~=progress.run then progress={run=run,session=false,phase=nil,maxLuck=2,maxChance=.4}; end
 local phase=type(AZS_GetPhase)=="function" and AZS_GetPhase();
 local luck=type(AZS_STATS)=="table" and tonumber(AZS_STATS.luck);
 local level=UnitLevel and UnitLevel("player");
 if type(level)~="number" or level<1 then level=nil; end
 local saved=SS.DB().luckBaseline;
 local valid=type(saved)=="table" and saved.run==run and (run~=nil or progress.session);
 if phase=="ready" and progress.phase~="ready" then valid=false; saved=nil; end
 if luck and level and (phase=="ready" or not valid) then
  saved={run=run,luck=luck,level=level,fromStart=phase=="ready"}; SS.DB().luckBaseline=saved; progress.session=true;
 elseif not valid then saved=nil; end
 progress.phase=phase;
 -- Ranges grow only after values exceed the scale; they never contract as buffs expire.
 if luck and luck>progress.maxLuck then progress.maxLuck=math.ceil(luck); end
 if level then
  local edge=SS.LegendaryChance(progress.maxLuck,level,.5);
  if edge>progress.maxChance then progress.maxChance=math.min(1,math.ceil(edge*5)/5); end
 end
 local gain;
 if saved and luck and level then
  local before=SS.LegendaryChance(saved.luck,level); local current=SS.LegendaryChance(luck,level);
  if before>0 then gain=(current/before-1)*100; end
 end
 return {luck=luck,level=level,baseline=saved,gain=gain,maxLuck=progress.maxLuck,maxChance=progress.maxChance};
end
function SS.UpdateLuck()
 local data=SS.LuckProgress();
 if (not SS.FeatureEnabled("SlimSuiteLuckFrame") and not SS.IsEditing("SlimSuiteLuckFrame")) or SS.DB().vanillaUI then frame:Hide(); return; end
 if SS.IsEditing("SlimSuiteLuckFrame") then frame:SetAlpha(1); else ApplyFeatureMute("SlimSuiteLuckFrame"); end
 local luck,level=data.luck,data.level; local base=SS.LegendaryChance(luck,level);
 local w=frame:GetWidth();
 frame.title:SetText(SS.T("Legendary luck"));
 frame.luckTag:SetText(luck and (SS.T("Luck")..": "..string.format("%.0f%%",luck*100)) or SS.T("Luck unavailable"));
 frame.big:SetText(base and string.format("%.2f%%",base*100) or "-");
 frame.bigTag:SetText(SS.T("chance per card, right now"));
 -- the benefit of stacking: what the next 10% of luck adds at this level
 local nextChance=base and SS.LegendaryChance(luck+.10,level);
 if nextChance then
  frame.gain:SetText(string.format(SS.T("+10%% luck = +%.2f pts"),(nextChance-base)*100)); frame.gain:SetTextColor(.35,1,.5);
 else frame.gain:SetText(""); end
 -- the bar: how close the current chance is to the top of the graph
 local fill=base and math.max(1,math.min(1,base/data.maxChance)*(w-20)) or 1;
 frame.barBack:SetWidth(w-20); frame.barFill:SetWidth(fill);
 frame.note:SetWidth(w-20);
 -- the curve: gold for your own legendary chance, orange for amulets
 local plotTop,plotHeight=-116,52;
 for i=1,48 do
  local dot=frame.dots[i]; if not dot then dot=frame:CreateTexture(nil,"ARTWORK"); frame.dots[i]=dot; end
  local index=math.mod(i-1,24); local bonus=i>24 and .5 or 0;
  local chance=SS.LegendaryChance(index/23*data.maxLuck,level or 0,bonus) or 0;
  dot:SetTexture(1,bonus>0 and .5 or .85,bonus>0 and .15 or .25,bonus>0 and .6 or .9); dot:SetWidth(3); dot:SetHeight(3);
  dot:ClearAllPoints(); dot:SetPoint("TOPLEFT",frame,"TOPLEFT",10+index/23*(w-20),plotTop-(1-math.min(1,chance/data.maxChance))*plotHeight);
  if base then dot:Show(); else dot:Hide(); end
 end
 -- your place on the curve
 if luck and base then
  frame.marker:ClearAllPoints();
  frame.marker:SetPoint("CENTER",frame,"TOPLEFT",10+math.min(1,luck/data.maxLuck)*(w-20),plotTop-(1-math.min(1,base/data.maxChance))*plotHeight);
  frame.marker:Show();
 else frame.marker:Hide(); end
 -- milestones: the chance at 50, 100, 150 and 200% luck, lit once you reach them
 local milestones={.5,1,1.5,2};
 for i,m in ipairs(milestones) do
  local fs=frame.miles[i];
  local v=level and SS.LegendaryChance(m,level);
  fs:SetText(string.format("%d%%  %s",m*100,v and string.format("%.1f%%",v*100) or "-"));
  if luck and luck>=m then fs:SetTextColor(1,.8,.25); else fs:SetTextColor(.5,.5,.5); end
 end
 local origin=data.baseline and ((data.baseline.fromStart and SS.T("Started with") or SS.T("Tracking from"))..": "..string.format("%.1f%%",data.baseline.luck*100)) or SS.T("Starting luck unavailable");
 local note=SS.T("Every luck gain improves these odds");
 if data.gain and data.gain>.05 then note=string.format(SS.T("Luck payoff so far: +%.1f%% legendary odds"),data.gain);
 elseif data.gain and data.gain< -.05 then note=SS.T("Luck is below your starting value"); end
 frame.note:SetText(note); frame.origin:SetText(origin);
 SS.ApplyPanelStyle(frame);
 frame:Show(); if SS.EnforceElementBounds then SS.EnforceElementBounds(frame); end
end
SS.Every("luckPanel",.25,function() SS.UpdateLuck(); end);
