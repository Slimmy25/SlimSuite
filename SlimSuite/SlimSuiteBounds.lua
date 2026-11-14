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
SS.Every("contentBounds",.05,function()
 for _,entry in ipairs(MOVABLE) do
  local name=entry[1]; local f=getglobal(name);
  if ( f and f.IsShown and f:IsShown() ) then
   local d=SS.DB(); local release=d.vanillaUI or (d.frameDefault and d.frameDefault[name]);
   SS.EnforceElementBounds(f,release);
  end
 end
end);
