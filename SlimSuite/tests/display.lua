-- Template selection, proportional anchors and non-accumulating scale across displays.
local bad=0
local function check(label, ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
local w,h=1920,1080
SS.ScreenBounds=function() return 0,w,0,h end
local cases={ {800,600,"4:3"}, {1024,768,"4:3"}, {1280,1024,"5:4"},
 {1280,720,"16:9"}, {1366,768,"16:9"}, {1600,900,"16:9"}, {1920,1080,"16:9"},
 {2560,1440,"16:9"}, {3840,2160,"16:9"}, {7680,4320,"16:9"},
 {1280,800,"16:10"}, {1920,1200,"16:10"}, {2560,1600,"16:10"},
 {2560,1080,"21:9"}, {3440,1440,"21:9"}, {5120,2160,"21:9"},
 {3840,1080,"32:9"}, {5120,1440,"32:9"}, {1080,1920,"portrait"} }
local frame=CreateFrame("Frame",nil,UIParent)
for pass=1,3 do
 for _,case in ipairs(cases) do
  w,h=case[1],case[2]
  local context=SS.DisplayContext()
  check("profile "..w.."x"..h, context.template.id==case[3])
  for name,a in pairs(SS.DISPLAY_ANCHORS) do
   local element=SS.Element(name); SS.DB().elementModes[element]="enabled";
   SS.PlaceDisplayDefault(name,frame)
   local p=frame.points[1]
   check("horizontal anchor "..name, math.abs(p[4]/w-a[2])<.0001)
   check("vertical anchor "..name, math.abs(p[5]/h-a[3])<.0001)
  end
  SS.DB().frameDefault=SS.DB().frameDefault or {}
  SS.DB().frameDefault.SlimSuiteClockFrame=nil
  local first=SS.DisplayElementScale("SlimSuiteClockFrame",1.25)
  local second=SS.DisplayElementScale("SlimSuiteClockFrame",1.25)
  check("scale stable", first==second and first>0)
  check("player target separation", context.scale*232 < context.width*(.165-.02))
  check("user scale preserved", math.abs(first/context.scale-1.25)<.0001)
  SS.DB().frameDefault.SlimSuiteClockFrame=true
  check("Default state preserved", SS.DisplayElementScale("SlimSuiteClockFrame",1.25)==1.25)
 end
end
check("runtime errors", #ERRORS==0)
print("display template problems: "..bad)
assert(bad==0,"display template regression")
