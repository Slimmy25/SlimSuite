-- Unofficial local side objectives. Never writes the game's achievement state.
if ( setfenv ) then setfenv(1, SS.ENV); end
local bannerSeen={};
for _,b in ipairs(type(AZS_BANNERS)=="table" and AZS_BANNERS or {}) do if b.id then bannerSeen[b.id]=true; end end
local definitions={}; SS.SIDE_ACHIEVEMENTS=definitions;
function SS.RegisterSideAchievement(id,title,text,metric,goal,source)
 table.insert(definitions,{id=id,title=title,text=text,metric=metric,goal=goal,source=source or "native"});
end
local function add(id,title,text,metric,goal,source) SS.RegisterSideAchievement(id,title,text,metric,goal,source); end
add("kills1000","Getting warmed up","Defeat 1,000 enemies across observed runs.","kills",1000);
add("kills10000","Five-digit problem","Defeat 10,000 enemies across observed runs.","kills",10000);
add("kills100000","Occupational hazard","Defeat 100,000 enemies across observed runs.","kills",100000);
add("deaths25","Frequent floor inspector","Die or get downed 25 times while tracking.","deaths",25);
add("bosses25","Management problems","Defeat 25 bosses across observed runs.","bosses",25);
add("guardians50","Lair clearance","Defeat 50 guardians across observed runs.","guardians",50);
add("caches100","Just one more chest","Open 100 caches across observed runs.","caches",100);
add("gold10000","Pocket change","Earn 10,000 gold across observed runs.","gold",10000);
add("wins10","Victory lap club","Win 10 observed runs.","wins",10);
add("runKills1000","Crowd control","Defeat 1,000 enemies in one observed run.","runKills",1000);
add("runDamage1m","A million little problems","Deal 1,000,000 damage in one observed run.","runDamage",1000000);
add("heroicWin","Taking the scenic route","Win an observed Heroic run.","heroicWins",1);
add("helpingHand","Return the favor","Revive more teammates in one run than you are revived. Pending a confirmed revive-credit API.","reviveBalance",1,"pending");
add("statsHealing","According to the records","Retain a completed run with 10,000 effective healing in Azeroth Stats.","healing",10000,"stats");
add("statsDamage","Paper trail","Retain a completed run with 1,000,000 damage in Azeroth Stats.","damage",1000000,"stats");
add("statsDps","Peak performance","Retain a completed run with 1,000 peak DPS in Azeroth Stats.","peakDps",1000,"stats");
local function number(v) if type(v)=="number" and v>=0 and v-v==0 then return v; end end
local function db()
 if type(SlimSuiteAchievementsDB)~="table" then SlimSuiteAchievementsDB={}; end
 local d=SlimSuiteAchievementsDB;
 d.totals=d.totals or {}; d.best=d.best or {}; d.unlocked=d.unlocked or {}; return d;
end
function SS.AchievementStatsAvailable()
 if not SS.AchievementsAvailable() then return false; end
 return type(AzerothStats)=="table" and type(AzerothStats.LatestRetainedRunId)=="function" and type(AzerothStats.ExportRetainedRunV1)=="function" and (not IsAddOnLoaded or IsAddOnLoaded("AzerothStats"));
end
local function unlock(d)
 for _,a in ipairs(definitions) do
  local value=(a.source=="stats" and d.best["stats_"..a.metric]) or d.totals[a.metric] or d.best[a.metric] or 0;
  if a.source~="pending" and (a.source~="stats" or SS.AchievementStatsAvailable()) and value>=a.goal and not d.unlocked[a.id] then d.unlocked[a.id]=date and date("%Y-%m-%d %H:%M") or "Earned"; end
 end
end
-- Delta high-water marks survive reload. Never add cumulative counters a second time.
function SS.UpdateSideAchievements()
 if not SS.AchievementsAvailable() then return; end
 local d=db();
 if SS.ModuleEnabled and not SS.ModuleEnabled("gameplay") then d.trackingPaused=true; return; end
 if d.trackingPaused then d.run=nil; d.trackingPaused=nil; end
 local phase=type(AZS_GetPhase)=="function" and AZS_GetPhase() or (type(AZS_RUN)=="table" and AZS_RUN.ph);
 local id=type(AZS_ZONE)=="table" and AZS_ZONE.run;
 if phase=="ready" then
  if d.lastPhase~="ready" or not d.run or d.run.id~=id then d.run={id=id,counts={},ready=true}; end
  d.fallen=false;
 end
 if phase=="playing" or phase=="choosing" or phase=="paused" then
  if not d.run or d.run.id~=id then d.run={id=id,counts={}}; end
  local raw=type(AZS_RUN)=="table" and AZS_RUN or {};
  for field,metric in pairs({kills="kills",bk="bosses",gk="guardians",ck="caches",ge="gold"}) do
   local v=number(raw[field]); local previous=d.run.counts[metric];
   if v then
    -- Without an observed start, begin at the first sample rather than claiming unseen history.
    if previous==nil then previous=d.run.ready and 0 or v; end
    if v>=previous then d.totals[metric]=(d.totals[metric] or 0)+(v-previous); d.run.counts[metric]=v; end
   end
  end
  for field,metric in pairs({kills="runKills",dealt="runDamage"}) do local v=number(raw[field]); if v then d.best[metric]=math.max(d.best[metric] or 0,v); end end
 end
 local ending=type(AZS_END)=="table" and AZS_END;
 if d.run and not d.run.ended and ending and ending.result=="victory" and phase=="victory" then
  d.run.ended=true; d.totals.wins=(d.totals.wins or 0)+1;
  if type(AZS_ZONE)=="table" and number(AZS_ZONE.heroic) and AZS_ZONE.heroic>0 then d.totals.heroicWins=(d.totals.heroicWins or 0)+1; end
 end
 local nextSeen={};
 for _,b in ipairs(type(AZS_BANNERS)=="table" and AZS_BANNERS or {}) do
  if b.id then
   nextSeen[b.id]=true;
   if not bannerSeen[b.id] then
    if b.kind=="downed" and not d.fallen then d.totals.deaths=(d.totals.deaths or 0)+1; d.fallen=true;
    elseif b.kind=="revived" then d.fallen=false; end
   end
  end
 end
 bannerSeen=nextSeen;
 d.lastPhase=phase; unlock(d);
end
local events=CreateFrame("Frame"); events:RegisterEvent("PLAYER_DEAD"); events:RegisterEvent("PLAYER_ALIVE"); events:RegisterEvent("PLAYER_UNGHOST");
events:SetScript("OnEvent",function()
 if not SS.AchievementsAvailable() then return; end
 if SS.ModuleEnabled and not SS.ModuleEnabled("gameplay") then return; end
 local d=db();
 if event=="PLAYER_DEAD" then
  if not d.fallen then d.totals.deaths=(d.totals.deaths or 0)+1; d.fallen=true; unlock(d); end
 else d.fallen=false; end
end);
-- Optional read-only projection. No direct writes or private database access.
function SS.RefreshAchievementStats()
 if not SS.AchievementStatsAvailable() then return; end
 local ok,id=SS.Safe(AzerothStats.LatestRetainedRunId); if not ok or not id then return; end
 local valid,p=SS.Safe(AzerothStats.ExportRetainedRunV1,id);
 if not valid or type(p)~="table" or p.schemaVersion~="1.0.0" or type(p.run)~="table" or p.run.status~="ended" or p.run.partial~=false or type(p.metrics)~="table" then return; end
 local d=db();
 for _,key in ipairs({"damage","healing","peakDps"}) do
  local m=p.metrics[key]; local v=type(m)=="table" and m.availability=="available" and number(m.value);
  if v then d.best["stats_"..key]=math.max(d.best["stats_"..key] or 0,v); end
 end
 unlock(d);
end
function SS.SideAchievementRows()
 if not SS.AchievementsAvailable() then return {}; end
 local d=db(); local out={};
 for _,a in ipairs(definitions) do
  if a.source~="stats" or SS.AchievementStatsAvailable() then
   local value=(a.source=="stats" and d.best["stats_"..a.metric]) or d.totals[a.metric] or d.best[a.metric] or 0;
   table.insert(out,{definition=a,value=value,earned=d.unlocked[a.id]});
  end
 end
 return out;
end
local window,content,labels;
function SS.OpenAchievements()
 if not SS.AchievementsAvailable() then return; end
 SS.UpdateSideAchievements(); SS.RefreshAchievementStats();
 if not window then
  window=K.Window("SlimSuiteAchievementsWindow",SS.T("Side achievements"),480,500);
  local scroll; scroll,content=K.Scroll("SlimSuiteSideAchievementsScroll",window,430);
  scroll:SetPoint("TOPLEFT",window,"TOPLEFT",20,-42); scroll:SetPoint("BOTTOMRIGHT",window,"BOTTOMRIGHT",-28,30); labels={};
  local intro=window:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); intro:SetPoint("TOPLEFT",window,"TOPLEFT",22,-28); intro:SetWidth(425); intro:SetText(SS.T("Unofficial side objectives — no gameplay rewards."));
 end
 local y=0;
 for i,row in ipairs(SS.SideAchievementRows()) do
  local fs=labels[i]; if not fs then fs=content:CreateFontString(nil,"OVERLAY","GameFontHighlight"); labels[i]=fs; end
  fs:ClearAllPoints(); fs:SetPoint("TOPLEFT",content,"TOPLEFT",4,-y); fs:SetWidth(408); fs:SetJustifyH("LEFT");
  local a=row.definition; local status=a.source=="pending" and SS.T("Awaiting API support") or (row.earned and (SS.T("Earned")..": "..row.earned) or string.format("%.0f / %.0f",math.min(row.value,a.goal),a.goal));
  fs:SetText(SS.T(a.title).." — "..status.."\n"..SS.T(a.text)); fs:SetTextColor(row.earned and .4 or 1,row.earned and 1 or .85,.4);
  local h=SS.WrappedLabelHeight(fs,408)+12; fs:SetHeight(h); y=y+h+10; fs:Show();
 end
 local n=table.getn(SS.SideAchievementRows()); for i=n+1,table.getn(labels) do labels[i]:Hide(); end
 content:SetHeight(math.max(100,y)); window:Show();
end
local button=CreateFrame("Button","SlimSuiteAchievementsButton",UIParent); button:SetWidth(150); button:SetHeight(30); button:SetPoint("TOPLEFT",UIParent,"TOPLEFT",24,-250);
SS.OwnLook(button, function()
button:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12}); button:SetBackdropColor(.04,.04,.08,.9);
end);
local label=button:CreateFontString(nil,"OVERLAY","GameFontNormal"); label:SetPoint("CENTER",button,"CENTER",0,0); label:SetText(SS.T("Side achievements"));
button:SetScript("OnClick",function() SS.OpenAchievements(); end); button:Hide();
function SS.UpdateAchievementButton()
 if not SS.AchievementsAvailable() then button:Hide(); return; end
 if (SS.FeatureEnabled("SlimSuiteAchievementsButton") or SS.IsEditing("SlimSuiteAchievementsButton")) and not SS.DB().vanillaUI then
  label:SetWidth(math.max(20,button:GetWidth()-12)); SS.FitText(label,button:GetWidth()-12,8,14,SS.T("Side achievements")); button:Show();
 else button:Hide(); end
end
SS.Every("sideAchievements",1,function() SS.UpdateSideAchievements(); SS.UpdateAchievementButton(); end);
