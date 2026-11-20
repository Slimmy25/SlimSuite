local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SS.SetupEnd(true)
local d=SS.DB(); SS.ENV.SU.SetMode("SlimSuiteMeterFrame","enabled","Damage meter")
local context={runId="pets",uiSessionId=1,counterEpoch=1,authorityId=1,localOwnerId="H1"}
local snapshot={context=context,actors={H1={kind="hero",name="Player"},P1={kind="pet",name="Imp",summonKey="imp"},P2={kind="pet",name="Imp",summonKey="imp"}},sources={a={name="Melee"},b={name="Firebolt"}},rows={
 {ownerId="H1",actorId="P1",sourceKey="a",displayAmount=10},
 {ownerId="H1",actorId="P1",sourceKey="b",displayAmount=20},
 {ownerId="H1",actorId="P2",sourceKey="b",displayAmount=30},
 {ownerId="H1",actorId="H1",sourceKey="b",displayAmount=40},
 {ownerId="H2",actorId="P2",sourceKey="b",displayAmount=50}}}
local grouping
AZS_GetMeterContext=function() return context end
AZS_GetMeterSnapshot=function(query) grouping=query.groupBy; return snapshot end
local m=SlimSuiteMeter; m.demoSnapshot=nil; m.view="damage"; m.nextRead=0
m.Draw(true,false)
check("request actor attribution instead of source-only totals",grouping=="actor_source")
local pets,own={},nil
for _,row in ipairs(m.rows or {}) do if row.pet then pets[row.ownerId]=row else own=row end end
check("one owner combines all Imp attacks and summons",pets.H1 and pets.H1.displayAmount==60 and #pets.H1.parts==3)
check("other owners stay separate",pets.H2 and pets.H2.displayAmount==50)
check("player's matching spell stays separate",own and own.displayAmount==40 and own.actorId=="H1")
AZS_UNITS={{id=1,name="Guardian",kind="guardian",state=1,hp=100,hpm=100},{id=2,name="Guardian",kind="normal",hp=100,hpm=100},{id=3,name="Guardian",kind="elite",hp=100,hpm=100}}
local encounters=SS.EncounterList()
check("same-name ordinary and heroic elite minions do not get encounter bars",#encounters==1 and encounters[1].id==1)
local targets={{id=99,name="Guardian",kind="other"},{id=2,name="Guardian",kind="normal"},{id=1,name="Guardian",kind="guardian"}}
local cursor=0; AZS_TARGET={id=8,name="Old",kind="normal"}
UnitCanAttack=function() return AZS_TARGET.kind~="other" end
TargetNearestEnemy=function() cursor=cursor+1; AZS_TARGET=targets[math.mod(cursor-1,#targets)+1] end
local byName=0
TargetByName=function(name) byName=byName+1; AZS_TARGET={id=2,name=name,kind="normal"} end
SS.TargetEncounter(encounters[1])
for i=1,4 do FireEvent("CHAT_MSG_ADDON","AZSTGT"); Tick(1,.05) end
check("encounter clicks skip friendly and ordinary namesakes",byName==1 and SS.encounterTargetResult==true and AZS_TARGET.id==1)
AZS_TARGET={id=8,name="Old",kind="normal"}; cursor=0; local cycled=0
TargetNearestEnemy=function() cycled=cycled+1 end
TargetByName=function(name) AZS_TARGET={id=1,name=name,kind="guardian"} end
SS.TargetEncounter(encounters[1]); FireEvent("CHAT_MSG_ADDON","AZSTGT"); Tick(1,.05)
check("a unique encounter name is targeted directly, far away or not",cycled==0 and SS.encounterTargetResult==true and AZS_TARGET.id==1)
TargetNearestEnemy=function() cursor=cursor+1; AZS_TARGET=targets[math.mod(cursor-1,#targets)+1] end
AZS_TARGET={id=8,name="Old",kind="normal"}; cursor=0
TargetByName=function(name) AZS_TARGET={id=8,name=name,kind="normal"} end
ClearTarget=function() AZS_TARGET={} end
SS.TargetEncounter({id=999})
for i=1,6 do FireEvent("CHAT_MSG_ADDON","AZSTGT"); Tick(1,.05) end
check("unavailable encounter restores original target",SS.encounterTargetResult==false and AZS_TARGET.id==8)
-- A target packet can arrive several frames after the native selection call.
AZS_TARGET={id=8,name="Old",kind="normal"}; local requests=0
TargetNearestEnemy=function() requests=requests+1 end
SS.TargetEncounter({id=1})
Tick(5,.05)
check("no cycling against stale server target data",requests==1 and SS.encounterTargetResult==nil)
AZS_TARGET={id=2,name="Guardian",kind="normal"}; FireEvent("CHAT_MSG_ADDON","AZSTGT"); Tick(1,.05)
check("next candidate is requested only after acknowledgement",requests==2)
AZS_TARGET={id=1,name="Guardian",kind="guardian"}; FireEvent("CHAT_MSG_ADDON","AZSTGT")
check("delayed exact target completes successfully",SS.encounterTargetResult==true)
SS.TargetEncounter({id=999}); Tick(30,.05)
check("missing target response times out without busy cycling",requests==3 and SS.encounterTargetResult==false)
AZS_UNITS={{id=11,name="Explosive Orb",kind="elite",hp=12,hpm=50},{id=12,name="Final",kind="final",hp=200,hpm=200}}
encounters=SS.EncounterList()
check("explosive orb sorts before the final boss",#encounters==2 and encounters[1].id==11 and encounters[1].priority==0)
check("friendly named orb is not an encounter",not SS.IsExplosiveOrb({name="Explosive Orb",kind="other"}))
AZS_GetPhase=function() return "playing" end
d.bossMarks=true
AZS_GetBosses=function() return {{id=12,name="Final",final=true}} end
AZS_GetGuardians=function() return {} end
AZS_GetWorldAnchors=function() return {entries={{unitId=11,anchorId="orb",kind="elite",state="alive"},{unitId=12,anchorId="boss",kind="finalBoss",state="alive"}}} end
Tick(3,.2)
check("explosive orb reserves the highest priority Skull marker",SlimSuiteWorld.MarkFor(11)==8)
-- Ordinary orb discovery works even when the special-enemy list is empty.
AZS_UNITS={}; AZS_TARGET={kind="none"}
local live=true
AZS_GetWorldAnchors=function(query) return {entries=live and {{unitId=77,anchorId="ordinary-orb",kind="enemy",name="Explosive Orb",state="alive"}} or {}} end
Tick(2,.3)
encounters=SS.EncounterList()
check("normal orb gets a row without fabricated HP",#encounters==1 and encounters[1].id==77 and encounters[1].unknownHealth and encounters[1].hp==nil)
check("normal orb gets Skull",SlimSuiteWorld.MarkFor(77)==8)
SS.UpdateEncounterRows(encounters)
RunScript(SS.EncounterRow(1),"OnEnter")
check("unknown-health orb tooltip does not raise errors",#ERRORS==0)
AZS_TARGET={id=77,name="Explosive Orb",kind="normal",hp=17,hpm=40}
encounters=SS.EncounterList()
check("target data supplies authoritative orb health",encounters[1] and encounters[1].hp==17 and encounters[1].hpm==40 and not encounters[1].unknownHealth)
live=false; Tick(2,.3)
check("removed orb does not leave a stale row",#SS.EncounterList()==0)
print("identity problems: "..bad)
assert(bad==0 and #ERRORS==0,"identity regressions")
