local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SS.SetupEnd(true)
SS.ResetCombatLearning(); AZS_ZONE={run="learning"}
local featured=0
for i=1,120 do
 AdvanceTime(.5)
 if SS.LearnCombatHighlight({amount=100,crit=true,name="Repeated",sourceKey="same"}) then featured=featured+1 end
end
check("routine crits stop dominating highlights",featured<15)
AdvanceTime(1)
check("a genuinely large hit stands out after learning",SS.LearnCombatHighlight({amount=400,crit=true,sourceKey="same"}))
local routine=0
for i=1,120 do AdvanceTime(.5); if SS.LearnCombatHighlight({amount=100,crit=true,sourceKey="same"}) then routine=routine+1 end end
check("completed minutes retain the learned baseline",routine<5)
AZS_ZONE.run="new-learning"; AdvanceTime(1)
check("new runs learn their own damage profile",SS.LearnCombatHighlight({amount=100,crit=true,sourceKey="same"}))
local paths={}; PlaySoundFile=function(path) table.insert(paths,path) end
for _,key in ipairs({"bossHitmarker","bossWhip","bossGotcha","off"}) do
 SS.SetSoundSelection("boss",key); local before=#paths; SS.PlayBossKillSound()
 check("one selected boss sound: "..key,#paths==before+(key=="off" and 0 or 1))
 if key~="off" then check("selected asset plays",paths[#paths]==SS.SOUND_FILES[key]) end
end
SS.SetSoundSelection("death","legoDeath")
check("death alternatives are mutually exclusive",SS.SoundSelection("death")=="legoDeath")
SS.PlayDeathSound(); Tick(10,.1); check("LEGO selected audio",paths[#paths]==SS.SOUND_FILES.legoDeath)
SS.SetSoundSelection("death","off"); local n=#paths; SS.PlayDeathSound(); check("death Off is silent",#paths==n)
if not SS.ENV.win then SS.WinBuild() end
local counts={}; local previews=0
for _,page in ipairs(SS.pages) do for _,row in ipairs(page.rows) do
 if row.soundGroup then
  counts[row.soundGroup]=(counts[row.soundGroup] or 0)+1
  if row.soundKey~="off" and row.soundKey~="same" then
   check("compact icon beside each sound",row.preview and row.preview:GetWidth()==18)
   SS.previewUntil=0; local before=#paths; RunScript(row.preview,"OnClick"); check("speaker icon plays preview",#paths==before+1); previews=previews+1
  end
  if row.mate then RunScript(row.mate,"OnClick"); check("matrix teammate selection",SS.DeathSoundSelection("teammate")==row.soundKey) end
  RunScript(row.cb,"OnClick")
  check("sound row selects exactly its choice",SS.SoundSelection(row.soundGroup)==row.soundKey)
 end
end end
check("all sound groups include alternatives and Off",counts.boss==4 and counts.death==5 and counts.lowHealth==2 and counts.chest==2 and counts.loss==4 and counts.start==5 and counts.victory==3 and counts.teammate==nil and counts.load==nil and previews==19)
SS.previewUntil=0
local stopped={}; StopSound=function(handle) table.insert(stopped,handle) end
PlaySoundFile=function(path) return true,path end
SS.PreviewSound("matchStart"); check("preview tracks active sound",SS.PreviewActive("matchStart"))
SS.PreviewSound("cenaStart"); check("new preview stops old handle",stopped[1]==SS.SOUND_FILES.matchStart and SS.PreviewActive("cenaStart"))
SS.PreviewSound("cenaStart"); check("same preview stops instead of replaying",not SS.PreviewActive() and stopped[2]==SS.SOUND_FILES.cenaStart)
StopSound=nil; local played=0; PlaySoundFile=function() played=played+1 end
SS.PreviewSound("matchStart"); SS.PreviewSound("cenaStart"); check("legacy previews never overlap",played==1)
SS.previewUntil=0
print("adaptive/sound problems: "..bad)
assert(bad==0 and #ERRORS==0,"adaptive/sound regressions")
