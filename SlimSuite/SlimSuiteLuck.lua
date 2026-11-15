-- Optional legendary-percentage display using the supplied rarity-weight model.
if ( setfenv ) then setfenv(1, SS.ENV); end
local frame=CreateFrame("Frame","SlimSuiteLuckFrame",UIParent);
frame:SetWidth(280); frame:SetHeight(190); frame:SetPoint("CENTER",UIParent,"CENTER",250,-130);
frame:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}});
frame:SetBackdropColor(.025,.025,.04,.85); frame:SetBackdropBorderColor(.7,.55,.2,1); frame:Hide();
frame.labels={}; frame.dots={};
for i=1,7 do
 local fs=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); fs:SetJustifyH("LEFT"); fs:SetHeight(16); frame.labels[i]=fs;
end
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
 local w,h=frame:GetWidth(),frame:GetHeight();
 local origin=data.baseline and ((data.baseline.fromStart and SS.T("Started with") or SS.T("Tracking from"))..": "..string.format("%.1f%%",data.baseline.luck*100)) or SS.T("Starting luck unavailable");
 local encouragement=SS.T("Every luck gain improves these odds");
 if data.gain and data.gain>.05 then encouragement=string.format(SS.T("Luck payoff: +%.1f%% legendary odds"),data.gain);
 elseif data.gain and data.gain< -.05 then encouragement=SS.T("Luck is below your starting value"); end
 local values={SS.T("Legendary luck"),luck and (SS.T("Luck")..": "..string.format("%.1f%%",luck*100)) or SS.T("Luck unavailable"),origin,
  base and (SS.T("Spells / rings / trinkets")..": "..string.format("%.2f%%",base*100)) or "-",
  base and (SS.T("Amulets")..": "..string.format("%.2f%%",SS.LegendaryChance(luck,level,.5)*100)) or "-",
  encouragement,SS.T("Estimated chance per card")};
 for i,fs in ipairs(frame.labels) do
  fs:ClearAllPoints(); fs:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-(i<=5 and (8+(i-1)*19) or h-(i==6 and 39 or 21)));
  fs:SetWidth(w-16); fs:SetText(values[i]); SS.FitText(fs,w-16,8,16,values[i]);
  if i==1 then fs:SetTextColor(1,.8,.25); elseif i==6 and data.gain and data.gain>.05 then fs:SetTextColor(.35,1,.5); else fs:SetTextColor(.9,.9,.9); end
 end
 local plotTop,plotHeight=109,math.max(12,h-156);
 local maxLuck,graphMaximum=data.maxLuck,data.maxChance;
 for i=1,48 do
  local dot=frame.dots[i]; if not dot then dot=frame:CreateTexture(nil,"ARTWORK"); frame.dots[i]=dot; end
  local index=math.mod(i-1,24); local bonus=i>24 and .5 or 0;
  local chance=SS.LegendaryChance(index/23*maxLuck,level or 0,bonus) or 0;
  dot:SetTexture(1,bonus>0 and .45 or .8,.15,.85); dot:SetWidth(3); dot:SetHeight(3);
  dot:ClearAllPoints(); dot:SetPoint("TOPLEFT",frame,"TOPLEFT",8+index/23*(w-19),-plotTop-(1-math.min(1,chance/graphMaximum))*plotHeight); if base then dot:Show(); else dot:Hide(); end
 end
 frame:Show(); if SS.EnforceElementBounds then SS.EnforceElementBounds(frame); end
end
SS.Every("luckPanel",.25,function() SS.UpdateLuck(); end);
