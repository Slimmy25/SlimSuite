-- The API exposes overlay ownership, not the renderer's individual card rectangles.
-- Dock to the viewport borders while choosing and restore exact original anchors afterwards.
if ( setfenv ) then setfenv(1, SS.ENV); end
local saved={}; local tooltipWas; local registered={};
local names={"SlimSuiteSpellRowFrame","SlimSuiteItemRowFrame","SlimSuiteStatCounterFrame"};
function SS.ChoiceHUDActive()
 return not SS.DB().vanillaUI and SS.DB().cardEdgeHUD~=false and type(AZS_GetPhase)=="function" and AZS_GetPhase()=="choosing";
end
function SS.UpdateChoiceHUD()
 local active=SS.ChoiceHUDActive() and not SS.DB().unlocked;
 for _,name in ipairs(names) do
  local f=getglobal(name);
  local element=name=="SlimSuiteItemRowFrame" and "SlimSuiteSpellRowFrame" or name;
  if ( f and active and SS.FeatureEnabled(element) and f:IsShown() ) then
   if ( not saved[name] ) then
    local points={}; for i=1,f:GetNumPoints() do local a,b,c,x,y=f:GetPoint(i); table.insert(points,{a,b,c,x,y}); end; saved[name]=points;
   end
   local factor=SS.EffectiveScale(f)/SS.EffectiveScale(UIParent);
   f:ClearAllPoints();
   if ( name=="SlimSuiteStatCounterFrame" ) then f:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-8/factor,-8/factor);
   else
    local below=getglobal("SlimSuiteItemRowFrame"); local y=name=="SlimSuiteSpellRowFrame" and below and below:IsShown() and ((below:GetHeight() or 0)*SS.EffectiveScale(below)/SS.EffectiveScale(UIParent)+20) or 8;
    f:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",8/factor,y/factor);
   end
   if ( type(AZS_SetOnTopOfScreens)=="function" and not registered[name] ) then SS.Safe(AZS_SetOnTopOfScreens,f,true); registered[name]=true; end
  elseif ( f and saved[name] ) then
   f:ClearAllPoints(); for _,p in ipairs(saved[name]) do f:SetPoint(p[1],p[2],p[3],p[4],p[5]); end
   saved[name]=nil; registered[name]=nil;
   if ( type(AZS_SetOnTopOfScreens)=="function" ) then SS.Safe(AZS_SetOnTopOfScreens,f,SS.DB().onTopOfScreens and true or false); end
  end
 end
 if ( type(AZS_SetOnTopOfScreens)=="function" and GameTooltip ) then
  if ( active or (SS.DB().onTopOfScreens and not SS.DB().vanillaUI) ) then
   if ( tooltipWas==nil ) then
    tooltipWas=type(AZS_IsOnTopOfScreens)=="function" and AZS_IsOnTopOfScreens(GameTooltip) or false;
    SS.Safe(AZS_SetOnTopOfScreens,GameTooltip,true);
   end
  elseif ( tooltipWas~=nil ) then SS.Safe(AZS_SetOnTopOfScreens,GameTooltip,tooltipWas); tooltipWas=nil; end
 end
end
SS.Every("choiceHUD",.1,function() SS.UpdateChoiceHUD(); end);
