-- Geometry is explicit here: the generic mock does not otherwise lay out frame anchors.
local bad=0
local function check(label,ok) if not ok then bad=bad+1; print('MISMATCH '..label) end end
local function Rect(f,l,r,b,t)
 f.GetLeft=function() return l end; f.GetRight=function() return r end
 f.GetBottom=function() return b end; f.GetTop=function() return t end
end
SS.SetupEnd(true)
Rect(UIParent,0,800,0,600)
local player=CreateFrame('Frame',nil,UIParent); Rect(player,100,300,350,400)
local party=CreateFrame('Frame',nil,UIParent); Rect(party,100,220,240,290)
local originalAnchor, originalObstacles=SS.PlayerAnchor,SS.AuraObstacles
SS.PlayerAnchor=function() return player end
local obstacles={}
SS.AuraObstacles=function() return obstacles end
local function Buttons(count)
 local list={}
 for i=1,count do
  local b=CreateFrame('Button',nil,UIParent); b:SetWidth(20); b:SetHeight(20); b:EnableMouse(true)
  b.GetEffectiveScale=function(self) return self:GetScale()*UIParent:GetEffectiveScale() end
  b.time=b:CreateFontString(nil,'OVERLAY'); b.time:SetText('8m'); b.time:SetHeight(8)
  b.time:SetPoint('TOP',b,'BOTTOM',0,-3)
  table.insert(list,b)
 end
 return list
end
local buttons=Buttons(30)
local function CheckBounds(label,layout,list)
 check(label..' max two rows',layout.rows<=2)
 for _,b in ipairs(list) do
  if b:GetAlpha()>0 then
   local p=b.points[1]; local scale=b:GetEffectiveScale()
   local x,y=p[4]*scale,p[5]*scale
   local w,h=b:GetWidth()*scale,b:GetHeight()*scale
   check(label..' icon within owner width',x>=layout.left-.001 and x+w<=layout.right+.001)
   check(label..' icon within reserved height',y>=layout.bottom-.001 and y+h<=layout.top+.001)
   check(label..' timer within reserved height',y-(b.time:GetHeight()+3)*scale>=layout.bottom-.001)
   local timerWidth=b.time:GetStringWidth()*scale
   check(label..' timer within owner width',x+w/2-timerWidth/2>=layout.left-.001 and x+w/2+timerWidth/2<=layout.right+.001)
  end
 end
end
local layout=SS.LayoutBoundedAuras(buttons,player,nil,nil,'above')
CheckBounds('player',layout,buttons)
check('player uses two rows when needed',layout.rows==2 and layout.shown>0)
check('overflow stays hidden instead of making a third row',layout.hidden>0 and layout.shown+layout.hidden==30)
local hidden
for _,b in ipairs(buttons) do if b:GetAlpha()==0 then hidden=b;check('hidden overflow cannot catch mouse input',not b:IsMouseEnabled()) end end
local firstScale=buttons[1]:GetScale()
layout=SS.LayoutBoundedAuras(buttons,player,nil,nil,'above')
check('refresh does not repeatedly shrink icons',buttons[1]:GetScale()==firstScale)
obstacles={{left=100,right=300,bottom=430,top=480}}
layout=SS.LayoutBoundedAuras(buttons,player,nil,nil,'above')
CheckBounds('crowded player',layout,buttons)
check('a frame above limits the available rows',layout.top<=428 and layout.rows<=1)
obstacles={}
local wide=CreateFrame('Frame',nil,UIParent); Rect(wide,100,700,350,400)
layout=SS.LayoutBoundedAuras(buttons,wide,nil,nil,'above')
check('overflow returns when space becomes available',hidden and hidden:GetAlpha()>0 and hidden:IsMouseEnabled())
for _,b in ipairs(buttons) do SS.RestoreAuraButton(b) end
check('native scale restored after detaching',buttons[1]:GetScale()==1)

obstacles={{left=100,right=300,bottom=280,top=320}}
layout=SS.LayoutBoundedAuras(buttons,player,nil,nil,'below')
CheckBounds('below player',layout,buttons)
check('below buffs avoid the frame underneath',layout.bottom>=322 and layout.top<=348)
obstacles={{left=100,right=180,bottom=400,top=500}}
layout=SS.LayoutBoundedAuras(buttons,player,nil,nil,'above')
for _,b in ipairs(buttons) do
 if b:GetAlpha()>0 then local p=b.points[1]; check('partial horizontal collision cannot cover another frame',p[4]*b:GetEffectiveScale()>=180) end
end
obstacles={}

-- A later party strip may never consume the player's reserved aura area.
local playerLayout=SS.LayoutBoundedAuras(Buttons(12),player,nil,nil,'above')
SS.AuraObstacles=originalObstacles
layout=SS.LayoutBoundedAuras(Buttons(16),party,nil,nil,'above')
check('party strip stops before player frame',layout.top<=348)
check('party strip stays within party width',layout.right==220)
local neighbor=CreateFrame('Frame',nil,UIParent); Rect(neighbor,500,600,350,400)
SS.AuraObstacles=function() return obstacles end
SS.DB().orientations.PartyMemberFrame1='horizontal'; obstacles={}
layout=SS.LayoutBoundedAuras(Buttons(6),player,nil,neighbor,'above')
check('distant neighbor cannot expand owner width',layout.right==300)
Rect(player,100,300,350,580)
layout=SS.LayoutBoundedAuras(Buttons(20),player,nil,nil,'above')
check('screen top also limits rows',layout.top<=600 and layout.rows==0)

-- Fractional inherited UI scales must use the same coordinate system for icons and bounds.
Rect(player,100,300,350,400)
UIParent.GetEffectiveScale=function() return .75 end
player.GetEffectiveScale=function() return 1.125 end
layout=SS.LayoutBoundedAuras(buttons,player,nil,nil,'above')
CheckBounds('scaled player',layout,buttons)
check('no unexpected runtime errors',#ERRORS==0)
SS.PlayerAnchor,SS.AuraObstacles=originalAnchor,originalObstacles
print('aura bounds problems: '..bad)
assert(bad==0,'aura layout regressions')
