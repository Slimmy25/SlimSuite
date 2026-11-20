-- Teammate revive sound: plays only when you helped and the fall ended by revival.
local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SS.SetupEnd(true)
local played=0; PlaySoundFile=function(path) if path==SS.SOUND_FILES.reviveSuccess then played=played+1 end; return true end
AZS_GetPhase=function() return "playing" end; AZS_ZONE={run="r1"}
local downed, revive, answers = {}, {}, {}
AZS_GetDownedPartyMembers=function() return downed end
AZS_GetRevive=function() return revive end
AZS_ProjectWorldAnchors=function(req) local out={} for _,q in ipairs(req) do if answers[q.anchorId] then table.insert(out,{anchorId=q.anchorId,state="expired",reason=answers[q.anchorId]}) end end; return {frameCurrent=true,entries=out} end
local function fall(id,name) downed={{id=id,name=name,anchorId=id,run="r1"}} end
check("default is off",SS.SoundSelection("revive")=="off")
SS.SetSoundSelection("revive","reviveSuccess"); check("selection saves",SS.SoundSelection("revive")=="reviveSuccess")
-- 1. you revive Brann and he gets up
fall(1,"Brann"); revive={reviving="Brann",rshare=0.5}; Tick(3,.1)
downed={}; revive={}; answers[1]="revived"; Tick(3,.1)
check("helped revive plays once",played==1)
Tick(3,.1); check("same fall never replays",played==1)
-- 2. someone revives a teammate you never helped
fall(2,"Rexxar"); Tick(3,.1); downed={}; answers[2]="revived"; Tick(3,.1)
check("not helping plays nothing",played==1)
-- 3. you helped but they left instead
fall(3,"Jaina"); revive={reviving="Jaina",rshare=0.8}; Tick(3,.1); downed={}; revive={}; answers[3]="left"; Tick(3,.1)
check("departure plays nothing",played==1)
-- 4. you stopped helping long before they got up
fall(4,"Thrall"); revive={reviving="Thrall",rshare=0.3}; Tick(2,.1); revive={}; Tick(50,.1); downed={}; answers[4]="revived"; Tick(3,.1)
check("stale help plays nothing",played==1)
-- 5. not-ready list is never proof
fall(5,"Anduin"); revive={reviving="Anduin",rshare=0.4}; Tick(2,.1); AZS_GetDownedPartyMembers=function() return nil end; answers[5]="revived"; Tick(3,.1)
check("not-ready list plays nothing",played==1)
AZS_GetDownedPartyMembers=function() return downed end
-- 6. Off and paused
SS.SetSoundSelection("revive","off"); fall(6,"Sylvanas"); revive={reviving="Sylvanas",rshare=0.9}; Tick(2,.1); downed={}; revive={}; answers[6]="revived"; Tick(3,.1)
check("Off plays nothing",played==1)
SS.SetSoundSelection("revive","reviveSuccess"); AZS_ZONE={run="r2"}
fall(7,"Brann"); downed[1].run="r2"; revive={reviving="Brann",rshare=0.9}; Tick(2,.1); downed={}; revive={}; answers[7]="revived"; Tick(3,.1)
check("new run plays again",played==2)
print("revive sound problems: "..bad)
assert(bad==0 and #ERRORS==0,"revive sound regressions")
