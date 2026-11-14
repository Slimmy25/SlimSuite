-- Shared resizing: drag the lower-right grip; drag the body to move the element.
if ( setfenv ) then setfenv(1, SS.ENV); end
function SS.MatchBuildRowSizes(name)
 local d=SS.DB();
 if ( not d.matchBuildSizes or (name~="SlimSuiteSpellRowFrame" and name~="SlimSuiteItemRowFrame") ) then return; end
 local other=name=="SlimSuiteSpellRowFrame" and "SlimSuiteItemRowFrame" or "SlimSuiteSpellRowFrame";
 local source=getglobal(name); if ( not source ) then return; end
 local count=name=="SlimSuiteSpellRowFrame" and 6 or 5;
 local vertical=SS.CurrentOrientation(name)=="vertical";
 local size=d.sizes[name]; local w=size and size.w or source:GetWidth(); local h=size and size.h or source:GetHeight();
 local icon=math.max(12,math.min(vertical and w or h,((vertical and h or w)-(count-1)*BUILD.GAP)/count));
 local n=other=="SlimSuiteSpellRowFrame" and 6 or 5;
 local upright=SS.CurrentOrientation(other)=="vertical";
 d.sizes[other]={w=upright and icon or n*icon+(n-1)*BUILD.GAP,h=upright and n*icon+(n-1)*BUILD.GAP or icon};
 d.scales[other]=d.scales[name] or 1;
end
function SS.AddResizeGrip(handle,name)
 if ( handle.resizeGrip ) then return; end
 local grip=CreateFrame("Frame",nil,handle); handle.resizeGrip=grip;
 grip:SetWidth(14); grip:SetHeight(14); grip:SetPoint("BOTTOMRIGHT",handle,"BOTTOMRIGHT",0,0); grip:EnableMouse(true);
 grip.mark=grip:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); grip.mark:SetPoint("CENTER",grip,"CENTER"); grip.mark:SetText("+");
 local function Finish()
  if ( not grip.resizing ) then return; end
  grip.resizing=nil; grip:SetScript("OnUpdate",nil);
  SS.SavePlace(grip.target,getglobal(grip.target)); SS.MarkProfileDirty();
 end
 grip:SetScript("OnMouseDown",function()
  if ( arg1~="LeftButton" ) then return; end
  grip.target=SS.BuildRowsJoined(name) and "SlimSuiteSpellRowFrame" or name;
  local f=getglobal(grip.target); if ( not f ) then return; end
  local l,r,b,t=RootBounds(f); if ( not l or not r or not b or not t ) then return; end
  local x,y=GetCursorPosition(); local ui=SS.EffectiveScale(UIParent);
  grip.x,grip.y=x/ui,y/ui; grip.w,grip.h=math.max(1,r-l),math.max(1,t-b);
  grip.left,grip.top=l,t; grip.scale=SS.DB().scales[grip.target] or 1; grip.resizing=true;
  SS.MarkProfileDirty();
  grip:SetScript("OnUpdate",function()
   local x,y=GetCursorPosition(); local factor=SS.EffectiveScale(UIParent);
   local ratio=math.max((grip.w+x/factor-grip.x)/grip.w,(grip.h+grip.y-y/factor)/grip.h);
   SS.DB().scales[grip.target]=math.max(.2,math.min(2,grip.scale*ratio));
   SS.MatchBuildRowSizes(grip.target); PlaceAll();
   local f=getglobal(grip.target); local l,r,b,t=RootBounds(f);
   if ( l and r and b and t ) then SetRootPosition(f,grip.left,grip.top-(t-b)); SS.SavePlace(grip.target,f); end
   if ( SS.Element(grip.target)=="PlayerFrame" ) then SS.Safe(SS.MirrorTarget); end
   if ( SS.Element(grip.target)=="TargetFrame" ) then SS.Safe(SS.MirrorPlayer); end
  end);
 end);
 grip:SetScript("OnMouseUp",function() if ( arg1=="LeftButton" ) then Finish(); end end);
 grip:SetScript("OnHide",Finish);
end
