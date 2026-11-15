-- An optional bearing display. Positions come only from the published world data.
if ( setfenv ) then setfenv(1, SS.ENV); end
local frame=CreateFrame("Frame","SlimSuiteCompassFrame",UIParent);
frame:SetWidth(380); frame:SetHeight(88); frame:SetPoint("TOP",UIParent,"TOP",0,-65); frame:Hide();
frame:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}});
frame:SetBackdropColor(.02,.025,.035,.65); frame:SetBackdropBorderColor(.55,.47,.27,.7);
frame.arrow=frame:CreateTexture(nil,"OVERLAY"); frame.arrow:SetTexture("Interface\\Minimap\\MinimapArrow"); frame.arrow:SetWidth(14); frame.arrow:SetHeight(14); frame.arrow:SetPoint("TOP",frame,"TOP",0,-3);
frame.track=frame:CreateTexture(nil,"BACKGROUND"); frame.track:SetTexture(.65,.56,.35,.4); frame.track:SetHeight(1);
frame.track:SetPoint("TOPLEFT",frame,"TOPLEFT",16,-32); frame.track:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-16,-32);
frame.ticks={}; frame.markers={};
function SS.CompassOffset(x,y,facing,width)
 local angle=(math.atan2 or math.atan)(y,x)-(facing or 0);
 while ( angle>math.pi ) do angle=angle-2*math.pi; end
 while ( angle< -math.pi ) do angle=angle+2*math.pi; end
 if ( math.abs(angle)>math.pi/2 ) then return; end
 return -angle/(math.pi/2)*math.max(0,width/2-20);
end
function SS.UpdateCompass()
 local d=SS.DB();
 if ( (not SS.FeatureEnabled("SlimSuiteCompassFrame") and not d.unlocked) or d.vanillaUI ) then frame:Hide(); return; end
 local position=type(AZS_GetPlayerPosition)=="function" and AZS_GetPlayerPosition() or nil;
 if ( type(position)~="table" or type(position.x)~="number" or type(position.y)~="number" ) then
  if d.unlocked then frame:Show(); else frame:Hide(); end
  return;
 end
 local w,h=frame:GetWidth(),frame:GetHeight(); local rail=d.compassStyle~="free";
 frame:SetBackdropColor(.02,.025,.035,rail and .65 or 0); frame:SetBackdropBorderColor(.55,.47,.27,rail and .7 or 0);
 if ( rail ) then frame.track:Show(); else frame.track:Hide(); end
 local heading=math.mod(360-math.deg(position.facing or 0),360); local first=math.floor((heading-90)/15)*15;
 for i=1,14 do
  local text=frame.ticks[i];
  if ( not text ) then
   text=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");
   text.tick=frame:CreateTexture(nil,"OVERLAY"); text.tick:SetTexture(.8,.7,.45,.7); text.tick:SetWidth(1); text.tick:SetHeight(5);
   frame.ticks[i]=text;
  end
  local degree=first+(i-1)*15; local x=(degree-heading)/90*(w/2-20);
  if ( rail and math.abs(x)<w/2-15 ) then
   local n=math.mod(degree,360); local cardinal=({[0]="N",[90]="E",[180]="S",[270]="W"})[n];
   text:SetText(cardinal or tostring(n)); text:ClearAllPoints(); text:SetPoint("TOP",frame,"TOP",x,-19); text:Show(); text.tick:ClearAllPoints(); text.tick:SetPoint("TOP",frame,"TOP",x,-29); text.tick:Show();
  else text:Hide(); text.tick:Hide(); end
 end
 local points=SlimSuiteWorld.PointsOfInterest(position,{minimapBosses=d.compassBosses~=false,minimapLairs=d.compassLairs~=false,minimapCaches=d.compassCaches~=false});
 local used=0; local occupied={};
 for _,point in ipairs(points) do
  local x=SS.CompassOffset(point.x-position.x,point.y-position.y,position.facing,w);
  if ( x ) then
   local row;
   for candidate=1,math.max(1,math.floor((h-38)/30)) do
    local good=true; for _,prior in ipairs(occupied[candidate] or {}) do if ( math.abs(x-prior)<56 ) then good=false; end end
    if ( good ) then row=candidate; break; end
   end
   if ( row ) then
    occupied[row]=occupied[row] or {}; table.insert(occupied[row],x); used=used+1;
    local marker=frame.markers[used];
    if ( not marker ) then
     marker=CreateFrame("Frame",nil,frame); marker:SetWidth(52); marker:SetHeight(28); marker:EnableMouse(true);
     marker.icon=marker:CreateTexture(nil,"OVERLAY"); marker.icon:SetWidth(14); marker.icon:SetHeight(14); marker.icon:SetPoint("TOP",marker,"TOP",0,0);
     marker.name=marker:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); marker.name:SetPoint("TOP",marker.icon,"BOTTOM",0,-1);
     marker.pointer=marker:CreateTexture(nil,"OVERLAY"); marker.pointer:SetTexture("Interface\\Minimap\\MinimapArrow"); marker.pointer:SetWidth(8); marker.pointer:SetHeight(8); marker.pointer:SetPoint("BOTTOM",marker.icon,"TOP",0,0);
     marker:SetScript("OnEnter",function() if ( GameTooltip ) then GameTooltip:SetOwner(this,"ANCHOR_RIGHT"); GameTooltip:AddLine(this.title,1,.82,.3); GameTooltip:AddLine(this.detail,1,1,1,1); GameTooltip:Show(); end end);
     marker:SetScript("OnLeave",function() if ( GameTooltip ) then GameTooltip:Hide(); end end);
     frame.markers[used]=marker;
    end
    marker:ClearAllPoints(); marker:SetPoint("TOP",frame,"TOP",x,-(rail and 40 or 28)-(row-1)*30);
    marker.icon:SetTexture(point.texture);
    if ( point.raid ) then SlimSuiteWorld.SetRaidIcon(marker.icon,point.raid); else marker.icon:SetTexCoord(0,1,0,1); end
    marker:SetAlpha(point.alpha or 1); marker.name:SetText(point.tip or ""); SS.FitText(marker.name,52,7,12,point.tip or "");
    marker.title=point.tip or ""; local distance=math.sqrt((point.x-position.x)*(point.x-position.x)+(point.y-position.y)*(point.y-position.y));
    marker.detail=tostring(math.floor(distance+.5)).." yd"..(point.sub and ("\n"..point.sub) or "");
    if ( rail ) then marker.pointer:Hide(); else marker.pointer:Show(); end
    marker:Show();
   end
  end
 end
 for i=used+1,table.getn(frame.markers) do frame.markers[i]:Hide(); end
 frame:Show(); if ( SS.EnforceElementBounds ) then SS.EnforceElementBounds(frame); end
end
SS.Every("compass",0,function() SS.UpdateCompass(); end);
