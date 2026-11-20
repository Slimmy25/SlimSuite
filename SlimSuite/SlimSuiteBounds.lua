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
local function StateOf(f,release)
 local l,r,b,t=Rect(f);
 return { l or 0, r or 0, b or 0, t or 0, f:GetScale() or 1, release and true or false, f:IsShown() and true or false };
end
local function Same(a,b)
 for i=1,7 do if a[i]~=b[i] then return false; end end
 return true;
end
SS.Every("contentBounds",.05,function()
 local now=GetTime();
 for _,entry in ipairs(MOVABLE) do
  local name=entry[1]; local f=getglobal(name);
  if ( f and f.IsShown and f:IsShown() ) then
   local d=SS.DB(); local release=d.vanillaUI or (d.frameDefault and d.frameDefault[name]) and true or false;
   local state=StateOf(f,release);
   local old=seenState[name];
   if ( not old or not Same(old,state) or now-(lastFull[name] or 0)>=SAFETY_SECONDS ) then
    SS.EnforceElementBounds(f,release);
    seenState[name]=state; lastFull[name]=now;
   end
  else
   seenState[name]=nil;
  end
 end
end);
