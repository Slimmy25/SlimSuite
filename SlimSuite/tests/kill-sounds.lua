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
check("polling fallback plays only one legacy selection",count(hit)==2 and count(whip)==1)
SS.ENV.bannerHandler({id=104,kind="boss"}); SS.ENV.bannerHandler({id=105,kind="finalboss"})
check("spawn notifications never count as kills",count(hit)==2 and count(whip)==1)
AZS_GetPhase=function() return "playing" end
AZS_GetMeterContext=function() return {runId="sound-test"} end
AZS_UNITS={{id=1,kind="boss",name="Not dead",hp=2,hpm=100}}; Tick(3,.1)
AZS_UNITS={}; Tick(3,.1)
check("low-health disappearance is not a confirmed kill sound",count(hit)==2 and count(whip)==1)
SS.ENV.bannerHandler({id=106,kind="bossdown"})
check("death after an empty enemy list still plays",count(hit)==3 and count(whip)==1)
d.bossHitmarkerSound=false; d.bossWhipSound=false
SS.ENV.bannerHandler({id=107,kind="guardian"})
check("Off remains silent",count(hit)==3 and count(whip)==1)
-- No banner delivery: a confirmed dead guardian anchor must still play.
d.bossHitmarkerSound=true; d.bossWhipSound=true
local corpses={}
AZS_GetWorldAnchors=function(query) return {entries=query.states and query.states[1]=="dead" and corpses or {}} end
AZS_ZONE={run="fallback"}; AZS_RUN={bk=0,gk=0}; Tick(4,.1)
corpses={{anchorId="guardian-death",kind="guardian",state="dead",name="Lair guardian"}}
Tick(4,.1)
check("dead guardian anchor works without banner delivery",count(hit)==4 and count(whip)==1)
AZS_RUN.gk=1; Tick(3,.1)
check("counter confirmation does not repeat anchor audio",count(hit)==4 and count(whip)==1)
FireEvent("CHAT_MSG_ADDON","AZSBANNER","id=108;kind=guardian;boss=0;name=Lair guardian;text=Slain")
check("raw wire callback does not repeat the confirmed kill",count(hit)==4 and count(whip)==1)
Tick(40,.1)
AZS_RUN.bk=1; Tick(3,.1)
check("authoritative boss count works without banners or corpse anchors",count(hit)==5 and count(whip)==1)
FireEvent("CHAT_MSG_ADDON","AZSBANNER","id=109;kind=bossdown;boss=1;name=Boss;text=Slain")
check("boss counter and notification match one kill",count(hit)==5 and count(whip)==1)
Tick(40,.1)
FireEvent("CHAT_MSG_ADDON","AZSBANNER","id=110;kind=guardian;boss=0;name=Twin;text=Slain")
FireEvent("CHAT_MSG_ADDON","AZSBANNER","id=111;kind=guardian;boss=0;name=Twin;text=Slain")
corpses={{anchorId="twin1",kind="guardian",state="dead",name="Twin"},{anchorId="twin2",kind="guardian",state="dead",name="Twin"}}
Tick(4,.1)
check("two same-name guardians each play once across both sources",count(hit)==7 and count(whip)==1)
print("kill sound problems: "..bad)
assert(bad==0 and #ERRORS==0,"kill sound regressions")
