-- Temporary card-screen presentation; no saved layout or visibility settings are edited.
if ( setfenv ) then setfenv(1, SS.ENV); end
local saved={}; local tooltipWas; local registered={}; local finishing; local itemRefresh=0;
function SS.ChoiceHUDActive()
 return not SS.DB().vanillaUI and SS.DB().cardEdgeHUD~=false and type(AZS_GetPhase)=="function" and AZS_GetPhase()=="choosing";
end
function SS.ChoiceItemsActive() return SS.ChoiceHUDActive() and not SS.DB().unlocked and not finishing; end
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
 local active=SS.ChoiceItemsActive();
 if ( active ) then
  -- Always provide the player's actual items on this page, even if that row is hidden in the normal HUD.
  SS.HideChoiceSpellRow();
  if ( GetTime()>=itemRefresh ) then itemRefresh=GetTime()+.1; SS.RefreshItemRow(); end
  SS.LayoutChoiceItems();
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
