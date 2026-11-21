-- Future fallback metrics. Observations never pretend to be authoritative counters.
local K, SU, NAME = SS.Kit, SS.SU, SS.NAME;   -- the three names every Slim Suite file uses (SlimSuiteCore.lua)
SS.SIDE_OBSERVATION_METRICS={
	reviveAssistAttempt={description="Reached 90% of a teammate revive; not proof of completion",confidence="observed"},
	manualReviveCredit={description="Player-reported completed revive",confidence="selfReported"},
	manualRevivesReceived={description="Player-reported revives received",confidence="selfReported"},
};
function SS.RecordSideObservation(metric,sequence,amount,confidence,runId)
	if not SS.AchievementsAvailable() then return false,"wip"; end
	local definition=SS.SIDE_OBSERVATION_METRICS[metric];
	if not definition or confidence~=definition.confidence then return false,"unsupported evidence"; end
	if type(sequence)~="number" or sequence<1 or sequence~=math.floor(sequence) or sequence-sequence~=0 then return false,"invalid sequence"; end
	if type(amount)~="number" or amount<0 or amount>1000000 or amount-amount~=0 then return false,"invalid amount"; end
	if (type(runId)~="string" and type(runId)~="number") or string.len(tostring(runId))>80 then return false,"missing run"; end
	if SS.ModuleEnabled and not SS.ModuleEnabled("gameplay") then return false,"paused"; end
	if type(AZS_ZONE)~="table" or AZS_ZONE.run~=runId then return false,"stale run"; end
	SlimSuiteAchievementsDB=SlimSuiteAchievementsDB or {}; local d=SlimSuiteAchievementsDB;
	if not d.observations or d.observations.run~=runId then d.observations={run=runId,metrics={}}; end
	local prior=d.observations.metrics[metric];
	if prior and sequence<=prior.sequence then return false,"duplicate or out of order"; end
	d.observations.metrics[metric]={sequence=sequence,value=(prior and prior.value or 0)+amount,confidence=confidence};
	return true;
end
function SS.SideObservation(metric)
	if not SS.AchievementsAvailable() then return; end
	local d=SlimSuiteAchievementsDB; local o=type(d)=="table" and d.observations;
	if o and type(AZS_ZONE)=="table" and o.run==AZS_ZONE.run then
		local m=o.metrics[metric]; if m then return m.value,m.confidence; end
	end
end
-- A near-complete bar supports an assist-attempt observation only. Disappearance
-- cannot establish who completed the revive, or whether it was interrupted.
SS.Every("sideObservationSampler",.2,function()
	if not SS.AchievementsAvailable() or (SS.ModuleEnabled and not SS.ModuleEnabled("gameplay")) or type(AZS_GetRevive)~="function" then return; end
	local ok,r=SS.Safe(AZS_GetRevive); if not ok or type(r)~="table" then return; end
	local target=type(r.reviving)=="string" and string.sub(r.reviving,1,80); local share=tonumber(r.rshare);
	if not target or target=="" or not share or share<.9 then
		if type(SlimSuiteAchievementsDB)=="table" then SlimSuiteAchievementsDB.reviveAttemptTarget=nil; end
		return;
	end
	local d=SlimSuiteAchievementsDB or {}; if d.reviveAttemptTarget==target then return; end
	local o=d.observations; local m=o and o.metrics and o.metrics.reviveAssistAttempt;
	local sequence=(m and m.sequence or 0)+1;
	local recorded=SS.RecordSideObservation("reviveAssistAttempt",sequence,1,"observed",type(AZS_ZONE)=="table" and AZS_ZONE.run);
	if recorded then SlimSuiteAchievementsDB.reviveAttemptTarget=target; end
end);
