-- Legacy WoW has no reliable clipping on every region. Overflow is never left visible.
if ( setfenv ) then setfenv(1, SS.ENV); end
local function Rect(frame)
 if ( not frame or not frame.GetLeft or not frame.GetRight or not frame.GetTop or not frame.GetBottom ) then return; end
 local l,r,b,t=frame:GetLeft(),frame:GetRight(),frame:GetBottom(),frame:GetTop();
 if ( not l or not r or not b or not t ) then return; end
 local s=SS.EffectiveScale(frame); return l*s,r*s,b*s,t*s;
end
local function Restore(region)
 if ( region.slimBoundsAlpha~=nil ) then region:SetAlpha(region.slimBoundsAlpha); region.slimBoundsAlpha=nil; end
end
function SS.EnforceElementBounds(owner,release)
 -- Native minimap chrome intentionally crosses the terrain rectangle. Its mask clips
 -- terrain/pins; generic HUD containment must not clip the moon, title or zoom controls.
 if ( owner==MinimapCluster or owner==Minimap ) then
  release=true;
  if ( Minimap and Minimap.SetClipsChildren ) then SS.Safe(Minimap.SetClipsChildren,Minimap,false); end
 end
 local l,r,b,t=Rect(owner); if ( not l ) then return; end
 local rawL,rawR,rawB,rawT=l,r,b,t;
 local left,right,bottom,top=RootBounds(owner);
 if ( left and right and bottom and top ) then
  local x1,y1,x2,y2=VisualInsets(owner); local scale=SS.EffectiveScale(UIParent);
  l,r,b,t=(left+x1+(UIParent:GetLeft() or 0))*scale,(left+x2+(UIParent:GetLeft() or 0))*scale,(bottom+y1+(UIParent:GetBottom() or 0))*scale,(bottom+y2+(UIParent:GetBottom() or 0))*scale;
 end
 if ( owner.SetClipsChildren ) then
  local same=math.abs(l-rawL)<.01 and math.abs(r-rawR)<.01 and math.abs(b-rawB)<.01 and math.abs(t-rawT)<.01;
  SS.Safe(owner.SetClipsChildren,owner,not release and same);
 end
 local seen={};
 local function Visit(frame,depth)
  if ( seen[frame] or depth>5 ) then return; end; seen[frame]=true;
  for _,region in ipairs(frame.GetRegions and {frame:GetRegions()} or {}) do
   Restore(region);
   if ( not release and region.IsShown and region:IsShown() ) then
    local x1,x2,y1,y2=Rect(region);
    if ( x1 and (x1<l-.01 or x2>r+.01 or y1<b-.01 or y2>t+.01) and region.SetAlpha ) then
     region.slimBoundsAlpha=region:GetAlpha(); region:SetAlpha(0);
    end
   end
  end
  for _,child in ipairs(frame.GetChildren and {frame:GetChildren()} or {}) do
   local name=child.GetName and child:GetName();
   -- Independently movable HUD siblings retain their own bounds, not their parent's.
   if ( not (name and SS.ELEMENTS[name]) ) then Visit(child,depth+1); end
  end
 end
 Visit(owner,0);
end
-- Checked only when a frame moves, resizes, rescales, is shown or hidden, or its release state changes. A slow
-- safety pass (SAFETY_SECONDS) still catches content that changes inside an unchanged frame.
local SAFETY_SECONDS = .5;
local seenState, lastFull = {}, {};
-- Runs 10 times a second. Each frame keeps its last state in a table that is reused, so a check that finds no change allocates nothing.
SS.Every("contentBounds",.1,function()
 local now=GetTime(); local d=SS.DB();
 for i=1,table.getn(MOVABLE) do
  local name=MOVABLE[i][1]; local f=getglobal(name);
  if ( f and f.IsShown and f:IsShown() ) then
   local release=(d.vanillaUI or (d.frameDefault and d.frameDefault[name])) and true or false;
   local l,r,b,t=Rect(f); l,r,b,t=l or 0,r or 0,b or 0,t or 0;
   local scale=f:GetScale() or 1;
   local s=seenState[name];
   if ( not s ) then s={}; seenState[name]=s; end
   local changed = s[1]~=l or s[2]~=r or s[3]~=b or s[4]~=t or s[5]~=scale or s[6]~=release or s[7]~=true;
   if ( changed or now-(lastFull[name] or 0)>=SAFETY_SECONDS ) then
    s[1],s[2],s[3],s[4],s[5],s[6],s[7]=l,r,b,t,scale,release,true;
    SS.EnforceElementBounds(f,release);
    lastFull[name]=now;
   end
  elseif ( seenState[name] ) then
   seenState[name]=nil;
  end
 end
end);
