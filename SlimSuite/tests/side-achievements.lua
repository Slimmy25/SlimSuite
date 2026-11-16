local bad=0
local function check(label,value) if not value then bad=bad+1; print("MISMATCH "..label) end end
SS.SetupEnd(true); SlimSuiteAchievementsDB=nil
check("WIP is disabled and hidden",not SS.AchievementsAvailable() and table.getn(SS.SideAchievementRows())==0)
SS.UpdateSideAchievements(); FireEvent("PLAYER_DEAD"); SS.RefreshAchievementStats(); SS.OpenAchievements(); SS.UpdateAchievementButton()
check("WIP performs no tracking or menu creation",SlimSuiteAchievementsDB==nil and not SlimSuiteAchievementsWindow and not SlimSuiteAchievementsButton:IsShown())
check("WIP observation writes are blocked",not SS.RecordSideObservation("manualReviveCredit",1,1,"selfReported","test"))
SS.ACHIEVEMENTS_WIP=false
local phase="ready"; AZS_GetPhase=function() return phase end
AZS_ZONE={run="side-one",heroic=1}; AZS_RUN={kills=0,bk=0,gk=0,ck=0,ge=0,dealt=0}; AZS_BANNERS={}; AZS_END={}
SS.UpdateSideAchievements(); phase="playing"; AZS_RUN.kills=10000; AZS_RUN.bk=25; AZS_RUN.gk=50; AZS_RUN.ck=100; AZS_RUN.ge=10000; AZS_RUN.dealt=1000000; SS.UpdateSideAchievements()
local d=SlimSuiteAchievementsDB
check("verified counters award native goals",d.unlocked.kills10000 and d.unlocked.bosses25 and d.unlocked.guardians50 and d.unlocked.caches100 and d.unlocked.gold10000 and d.unlocked.runDamage1m)
SS.UpdateSideAchievements(); check("same cumulative sample is not counted twice",d.totals.kills==10000)
AZS_RUN.kills=9999; SS.UpdateSideAchievements(); AZS_RUN.kills=10001; SS.UpdateSideAchievements(); check("counter corrections never inflate totals",d.totals.kills==10001)
FireEvent("PLAYER_DEAD"); FireEvent("PLAYER_DEAD"); check("one death event per life",d.totals.deaths==1)
FireEvent("PLAYER_ALIVE"); FireEvent("PLAYER_DEAD"); check("a later life can count again",d.totals.deaths==2)
phase="victory"; AZS_END={result="victory"}; SS.UpdateSideAchievements(); SS.UpdateSideAchievements(); check("confirmed victory only counted once",d.totals.wins==1 and d.totals.heroicWins==1)
phase="ready"; AZS_ZONE.run="side-two"; AZS_RUN.kills=0; AZS_END={}; SS.UpdateSideAchievements(); phase="playing"; AZS_RUN.kills=3; SS.UpdateSideAchievements(); check("next run starts independent delta ledger",d.totals.kills==10004)
local native=table.getn(SS.SideAchievementRows()); AzerothStats={LatestRetainedRunId=function() return "retained" end,ExportRetainedRunV1=function() return {schemaVersion="1.0.0",run={status="ended",partial=false},metrics={damage={availability="available",value=1000000},healing={availability="available",value=10000},peakDps={availability="unavailable",value=99999}}} end}; IsAddOnLoaded=function(name) return name=="AzerothStats" end
SS.RefreshAchievementStats(); check("Stats goals appear only with supported addon",table.getn(SS.SideAchievementRows())==native+3 and d.unlocked.statsHealing and d.unlocked.statsDamage and not d.unlocked.statsDps)
check("missing revive credit never earns objective",not d.unlocked.helpingHand)
AzerothStats=nil; check("Stats achievements stay hidden when addon is absent",table.getn(SS.SideAchievementRows())==native)
SS.OpenAchievements(); check("achievement menu opens",SlimSuiteAchievementsWindow:IsShown())
SS.StartSetup(true); SS.RefreshEditHandles(); SS.UpdateAchievementButton(); check("WIP build never registered achievement mover",not SS.ENV.handles.SlimSuiteAchievementsButton)
SS.SetupEnd(true); SS.SetModuleEnabled("gameplay",false); SS.UpdateSideAchievements(); AZS_RUN.kills=100; SS.SetModuleEnabled("gameplay",true); SS.UpdateSideAchievements();
check("paused tracking does not backfill unseen kills",d.totals.kills==10004)
SS.ACHIEVEMENTS_WIP=true
local kills=d.totals.kills; AZS_RUN.kills=99999; SS.UpdateSideAchievements(); FireEvent("PLAYER_DEAD"); SS.UpdateAchievementButton(); check("reapplied WIP gate preserves existing history without tracking",d.totals.kills==kills and not SlimSuiteAchievementsButton:IsShown())
print("side achievement problems: "..bad)
assert(bad==0 and #ERRORS==0,"side achievement regressions")
