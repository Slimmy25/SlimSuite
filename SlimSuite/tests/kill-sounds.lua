local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SS.SetupEnd(true)
local d=SS.DB(); local played={}
PlaySoundFile=function(path) played[path]=(played[path] or 0)+1 end -- legacy client returns no handle
local hit,whip=SS.SOUND_FILES.bossHitmarker,SS.SOUND_FILES.bossWhip
local function count(path) return played[path] or 0 end
AZS_BANNERS={{id=100,kind="bossdown"}}; Tick(2,.1)
check("historical banners are not replayed on login",count(hit)==0 and count(whip)==0)
d.bossHitmarkerSound=true; d.bossWhipSound=false; d.replaceBanners=false
SS.ENV.bannerHandler({id=101,kind="bossdown",name="Boss"})
check("hitmarker plays without visible announcements",count(hit)==1 and count(whip)==0)
AZS_BANNERS={{id=101,kind="bossdown"}}; Tick(3,.1)
check("callback and polling do not play twice",count(hit)==1)
d.bossHitmarkerSound=false; d.bossWhipSound=true
SS.ENV.bannerHandler({id=102,kind="guardian",name="Lair owner"})
check("whip plays for guardian or lair owner death",count(whip)==1 and count(hit)==1)
SS.ENV.bannerHandler({id=102,kind="guardian"})
check("duplicate death notice is ignored",count(whip)==1)
d.bossHitmarkerSound=true
AZS_BANNERS={{id=103,kind="bossdown"}}; Tick(3,.1)
check("polling fallback plays both selected sounds",count(hit)==2 and count(whip)==2)
SS.ENV.bannerHandler({id=104,kind="boss"}); SS.ENV.bannerHandler({id=105,kind="finalboss"})
check("spawn notifications never count as kills",count(hit)==2 and count(whip)==2)
AZS_GetPhase=function() return "playing" end
AZS_GetMeterContext=function() return {runId="sound-test"} end
AZS_UNITS={{id=1,kind="boss",name="Not dead",hp=2,hpm=100}}; Tick(3,.1)
AZS_UNITS={}; Tick(3,.1)
check("low-health disappearance is not a confirmed kill sound",count(hit)==2 and count(whip)==2)
SS.ENV.bannerHandler({id=106,kind="bossdown"})
check("death after an empty enemy list still plays",count(hit)==3 and count(whip)==3)
d.bossHitmarkerSound=false; d.bossWhipSound=false
SS.ENV.bannerHandler({id=107,kind="guardian"})
check("both options disabled remain silent",count(hit)==3 and count(whip)==3)
print("kill sound problems: "..bad)
assert(bad==0 and #ERRORS==0,"kill sound regressions")
