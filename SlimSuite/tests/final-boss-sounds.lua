local bad=0
local function check(label,value) if not value then bad=bad+1; print("MISMATCH "..label) end end
SS.SetupEnd(true)
local phase="ready"; AZS_GetPhase=function() return phase end; AZS_ZONE={run="final-a"}; AZS_UNITS={}; AZS_BANNERS={}; AZS_END={}
local sounds={}; PlaySoundFile=function(path) table.insert(sounds,path); return true end
SS.UpdateFinalBossSounds(); phase="playing"; SS.SetSoundSelection("finalBoss","finalMegalovania")
SS.OnFinalBossArrival({kind="boss",name="Edwin VanCleef"}); check("ordinary enemies with matching names cannot trigger",#sounds==0)
SS.OnFinalBossArrival({kind="finalboss",name="Edwin VanCleef"}); SS.OnFinalBossArrival({kind="finalboss",name="Edwin VanCleef"});
AZS_UNITS={{kind="final",name="Edwin VanCleef",id=100}}; SS.UpdateFinalBossSounds(); check("banner and live unit share one arrival",#sounds==1 and sounds[1]==SS.SOUND_FILES.finalMegalovania)
SS.DB().finalBossSounds["Kel'Thuzad"]="off"; SS.OnFinalBossArrival({kind="finalboss",name="Kel'Thuzad"}); check("per-boss Off wins over global track",#sounds==1)
SS.SetSoundSelection("finalBoss","off"); SS.DB().finalBossSounds.Nefarian="finalMegalovania"; SS.OnFinalBossArrival({kind="finalboss",name="Nefarian"}); check("individual selection works with global Off",#sounds==2)
phase="ready"; AZS_UNITS={}; SS.UpdateFinalBossSounds(); phase="playing"; AZS_ZONE.run="final-b"; SS.OnFinalBossArrival({kind="finalboss",name="Nefarian"}); check("new run can play selected final again",#sounds==3)
SS.OpenFinalBossSounds(); check("catalog and menu cover all twelve guide finals",#SS.FINAL_BOSS_CATALOG==12 and SlimSuiteFinalBossSoundMenu:IsShown())
SS.ACHIEVEMENTS_WIP=false; SlimSuiteAchievementsDB=nil
check("observations require honest provenance",not SS.RecordSideObservation("manualReviveCredit",1,1,"confirmed","final-b"))
check("manual fallback writes explicit self-reported data",SS.RecordSideObservation("manualReviveCredit",1,1,"selfReported","final-b"))
check("duplicate and stale observations rejected",not SS.RecordSideObservation("manualReviveCredit",1,1,"selfReported","final-b") and not SS.RecordSideObservation("manualReviveCredit",2,1,"selfReported","old-run"))
local value,evidence=SS.SideObservation("manualReviveCredit"); check("observation remains labelled and isolated from achievements",value==1 and evidence=="selfReported" and not SlimSuiteAchievementsDB.unlocked)
SS.ACHIEVEMENTS_WIP=true; check("WIP prevents observations and hides their query",not SS.RecordSideObservation("manualReviveCredit",2,1,"selfReported","final-b") and SS.SideObservation("manualReviveCredit")==nil)
print("final boss/fallback problems: "..bad)
assert(bad==0 and #ERRORS==0,"final boss/fallback regressions")
