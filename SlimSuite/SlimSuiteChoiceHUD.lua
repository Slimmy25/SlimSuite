-- Temporary card-screen presentation; no saved layout or visibility settings are edited.
if ( setfenv ) then setfenv(1, SS.ENV); end
-- Deferred by owner: retain the footer implementation without changing saved preferences.
SS.CHOICE_ITEMS_DEFERRED=true;
local saved={}; local tooltipWas; local registered={}; local finishing; local itemRefresh=0;
local clockEvidence={run=nil,value=nil,stableAt=nil,phase=nil,phaseAt=nil,active=false};
function SS.ChoiceHUDActive()
 local d=SS.DB(); local now=GetTime();
 local phase=type(AZS_GetPhase)=="function" and AZS_GetPhase() or nil;
 local run=type(AZS_ZONE)=="table" and AZS_ZONE.run;
 if run~=clockEvidence.run then clockEvidence={run=run,value=nil,stableAt=nil,phase=nil,phaseAt=now,active=false}; end
 if phase~=clockEvidence.phase then clockEvidence.phase=phase; clockEvidence.phaseAt=now; end
 local value;
 if type(AZS_GetRunTime)=="function" then
  local ok,result=SS.Safe(AZS_GetRunTime);
  if ok and type(result)=="number" and result>=0 and result-result==0 then value=result; end
 end
 local moved=false;
 if value~=nil then
  moved=clockEvidence.value~=nil and math.abs(value-clockEvidence.value)>.001;
  if clockEvidence.value==nil or moved then clockEvidence.stableAt=now; end
  clockEvidence.value=value;
 end
 if d.vanillaUI or d.cardEdgeHUD==false or d.unlocked then clockEvidence.active=false; return false; end
 -- Older clients with no readable interpolated clock retain phase-only behavior.
 if value==nil then clockEvidence.active=phase=="choosing"; return clockEvidence.active; end
 if phase=="choosing" then
  -- A pause alone cannot open this overlay: both choosing and a stable clock are required.
  clockEvidence.active=now-(clockEvidence.phaseAt or now)>=.25 and now-(clockEvidence.stableAt or now)>=.25;
 elseif phase=="playing" and clockEvidence.active then
  -- Wait for the matching clock restart. A bounded grace avoids trapping the overlay
  -- if a client reports playing but never resumes publishing its clock.
  if moved or now-(clockEvidence.phaseAt or now)>=1 then clockEvidence.active=false; end
 else clockEvidence.active=false; end
 return clockEvidence.active;
end

function SS.ChoiceItemsActive() return SS.ChoiceHUDActive() and not SS.CHOICE_ITEMS_DEFERRED and not SS.DB().unlocked and not finishing; end
local function Capture(name)
 local f=getglobal(name); if ( not f or saved[name] ) then return; end
 local points={}; for i=1,f:GetNumPoints() do local a,b,c,x,y=f:GetPoint(i); table.insert(points,{a,b,c,x,y}); end
 saved[name]={points=points,w=f:GetWidth(),h=f:GetHeight(),scale=f:GetScale(),alpha=mutedBaseAlphas[f] or f:GetAlpha(),shown=f:IsShown()};
end
local function Register(name)
 local f=getglobal(name);
 if ( f and type(AZS_SetOnTopOfScreens)=="function" and registered[name]==nil ) then
  registered[name]=type(AZS_IsOnTopOfScreens)=="function" and AZS_IsOnTopOfScreens(f) or false;
  SS.Safe(AZS_SetOnTopOfScreens,f,true);
 end
end
function SS.ChoiceFooterLayout()
 -- Measured from the supplied 2560x1440 selection-screen reference. The native modal
 -- is normalized to 1280x720, with a 30-unit spell-strip icon and a 5-unit gap.
 local w,h=UIParent:GetWidth(),UIParent:GetHeight(); local scale=math.min(w/1280,h/720);
 return w/2-222.5*scale,35.5*scale,30*scale,5*scale;
end
function SS.HideChoiceSpellRow()
 if ( not SS.ChoiceItemsActive() ) then return; end
 Capture("SlimSuiteSpellRowFrame");
 local f=getglobal("SlimSuiteSpellRowFrame"); if ( f ) then f:Hide(); end -- native footer already supplies the spells
end
function SS.LayoutChoiceItems()
 if ( not SS.ChoiceItemsActive() ) then return; end
 local f=getglobal("SlimSuiteItemRowFrame"); if ( not f ) then return; end
 Capture("SlimSuiteItemRowFrame");
 local x,y,icon,gap=SS.ChoiceFooterLayout();
 f:SetScale(1); f:SetWidth(5*icon+4*gap); f:SetHeight(icon);
 f:ClearAllPoints(); f:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x,y);
 for i,button in ipairs(itemRowButtons or {}) do
  button:ClearAllPoints(); button:SetPoint("TOPLEFT",f,"TOPLEFT",(i-1)*(icon+gap),0);
  button:SetWidth(icon); button:SetHeight(icon);
 end
 ApplyFeatureMute("SlimSuiteItemRowFrame");
 f:SetAlpha(1); f:Show(); Register("SlimSuiteItemRowFrame");
end
local function Restore()
 if ( not next(saved) ) then return; end
 finishing=true;
 for name,old in pairs(saved) do
  local f=getglobal(name);
  if ( f ) then
   f:ClearAllPoints(); for _,point in ipairs(old.points) do f:SetPoint(point[1],point[2],point[3],point[4],point[5]); end
   f:SetScale(old.scale); f:SetWidth(old.w); f:SetHeight(old.h); f:SetAlpha(old.alpha);
   if ( old.shown ) then f:Show(); else f:Hide(); end
   ApplyFeatureMute(name);
   if ( registered[name]~=nil and type(AZS_SetOnTopOfScreens)=="function" ) then SS.Safe(AZS_SetOnTopOfScreens,f,registered[name] or SS.DB().onTopOfScreens and true or false); end
  end
 end
 saved={}; registered={};
 SS.Place("SlimSuiteSpellRowFrame"); SS.Place("SlimSuiteItemRowFrame");
 SS.RefreshSpellRow(); SS.RefreshItemRow(); SS.ApplyBuildRowReplacement();
 ApplyFeatureMute("SlimSuiteSpellRowFrame"); ApplyFeatureMute("SlimSuiteItemRowFrame");
 finishing=nil;
end
function SS.UpdateChoiceHUD()
 local active=SS.ChoiceHUDActive() and not SS.DB().unlocked and not finishing;
 if ( active ) then
  if not SS.CHOICE_ITEMS_DEFERRED then
  -- Always provide the player's actual items on this page, even if that row is hidden in the normal HUD.
  SS.HideChoiceSpellRow();
  if ( GetTime()>=itemRefresh ) then itemRefresh=GetTime()+.1; SS.RefreshItemRow(); end
  SS.LayoutChoiceItems();
  end
  local f=getglobal("SlimSuiteStatCounterFrame");
  if ( f and SS.FeatureEnabled("SlimSuiteStatCounterFrame") and f:IsShown() ) then
   Capture("SlimSuiteStatCounterFrame");
   local factor=SS.EffectiveScale(f)/SS.EffectiveScale(UIParent);
   f:ClearAllPoints(); f:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-8/factor,-8/factor); Register("SlimSuiteStatCounterFrame");
  end
 else Restore(); end
 if ( type(AZS_SetOnTopOfScreens)=="function" and GameTooltip ) then
  if ( active or (SS.DB().onTopOfScreens and not SS.DB().vanillaUI) ) then
   if ( tooltipWas==nil ) then tooltipWas=type(AZS_IsOnTopOfScreens)=="function" and AZS_IsOnTopOfScreens(GameTooltip) or false; SS.Safe(AZS_SetOnTopOfScreens,GameTooltip,true); end
  elseif ( tooltipWas~=nil ) then SS.Safe(AZS_SetOnTopOfScreens,GameTooltip,tooltipWas); tooltipWas=nil; end
 end
end
SS.Every("choiceHUD",0,function() SS.UpdateChoiceHUD(); end);
