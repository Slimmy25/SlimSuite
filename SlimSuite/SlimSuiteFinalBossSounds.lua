-- Guide catalog: Zones & Bosses, last scheduled boss in each of the twelve zones.
if ( setfenv ) then setfenv(1, SS.ENV); end
SS.FINAL_BOSS_CATALOG={
 {"Elwynn Forest","Edwin VanCleef"},{"Duskwood","Morbent Fel"},
 {"Warsong Gulch","Lord Kazzak"},{"Un'Goro Crater","King Mosh"},
 {"Arathi Basin","Lord Aliden Perenolde"},{"Feralas","King Gordok"},
 {"Gurubashi Arena","Hakkar the Soulflayer"},{"Scarlet Monastery","High Inquisitor Whitemane"},
 {"Alterac Valley","Azuregos"},{"Blackrock Mountain","Nefarian"},
 {"Gates of Ahn'Qiraj","C'Thun"},{"Naxxramas","Kel'Thuzad"},
};
function SS.FinalBossTrack(name)
 local d=SS.DB(); local selected=type(d.finalBossSounds)=="table" and d.finalBossSounds[name];
 if selected=="off" then return "off"; end
 if selected=="finalMegalovania" then return selected; end
 return SS.SoundSelection("finalBoss");
end
local phase,seeded; local seenBanners={};
local function state()
 local d=SS.DB(); local run=type(AZS_ZONE)=="table" and AZS_ZONE.run;
 if not d.finalBossAudioState or d.finalBossAudioState.run~=run then d.finalBossAudioState={run=run,played={}}; end
 return d.finalBossAudioState;
end
function SS.OnFinalBossArrival(banner)
 if type(banner)~="table" or banner.kind~="finalboss" or type(banner.name)~="string" or banner.name=="" then return; end
 local current=type(AZS_GetPhase)=="function" and AZS_GetPhase();
 if current~="playing" and current~="choosing" and current~="paused" then return; end
 local s=state(); if s.played[banner.name] then return; end
 s.played[banner.name]=true;
 local selected=SS.FinalBossTrack(banner.name); if selected~="off" then SS.PlayAddonSound(selected); end
end
function SS.UpdateFinalBossSounds()
 local current=type(AZS_GetPhase)=="function" and AZS_GetPhase();
 if current=="ready" and phase~="ready" then SS.DB().finalBossAudioState=nil; end
 phase=current;
 local s=state();
 -- On reload, seed existing enemies/banners without replaying their arrival music.
 for _,b in ipairs(type(AZS_BANNERS)=="table" and AZS_BANNERS or {}) do
  if b.id and not seenBanners[b.id] then
   if seeded then SS.OnFinalBossArrival(b); end
   seenBanners[b.id]=true;
  end
 end
 for _,unit in ipairs(type(AZS_UNITS)=="table" and AZS_UNITS or {}) do
  if unit.kind=="final" and type(unit.name)=="string" then
   if seeded then SS.OnFinalBossArrival({kind="finalboss",name=unit.name}); else s.played[unit.name]=true; end
  end
 end
 seeded=true;
 -- Banner ring is bounded; retain only its current IDs.
 local active={}; for _,b in ipairs(type(AZS_BANNERS)=="table" and AZS_BANNERS or {}) do if b.id then active[b.id]=true; end end; seenBanners=active;
end
local events=CreateFrame("Frame"); events:RegisterEvent("CHAT_MSG_ADDON");
events:SetScript("OnEvent",function()
 if arg1~="AZSBANNER" or type(arg2)~="string" then return; end
 local _,_,id,name=string.find(arg2,"^id=(%d+);kind=finalboss;boss=%d;name=([^;]*);text=.*$");
 if id then SS.OnFinalBossArrival({id=tonumber(id),kind="finalboss",name=name}); end
end);
local menu;
function SS.OpenFinalBossSounds()
 if not menu then
  menu=K.Window("SlimSuiteFinalBossSoundMenu",SS.T("Final boss soundtracks"),470,500);
  local scroll,child=K.Scroll("SlimSuiteFinalBossSoundScroll",menu,420); scroll:SetPoint("TOPLEFT",menu,"TOPLEFT",20,-42); scroll:SetPoint("BOTTOMRIGHT",menu,"BOTTOMRIGHT",-28,30);
  for i,entry in ipairs(SS.FINAL_BOSS_CATALOG) do
   local name=entry[2]; local label=child:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); label:SetPoint("TOPLEFT",child,"TOPLEFT",4,-(i-1)*67); label:SetWidth(400); label:SetHeight(30); label:SetJustifyH("LEFT"); label:SetText(SS.T(entry[1]).." — "..name);
   local choice=K.Button(child,"",270,function() end); choice:SetPoint("TOPLEFT",child,"TOPLEFT",28,-(i-1)*67-31);
   local function refresh()
    local value=SS.DB().finalBossSounds[name]; choice:SetText(SS.T(value=="off" and "Off" or (value=="finalMegalovania" and "Megalovania" or "Use global soundtrack")));
   end
   choice:SetScript("OnShow",refresh); choice:SetScript("OnClick",function()
    local d=SS.DB(); local value=d.finalBossSounds[name]; d.finalBossSounds[name]=value==nil and "finalMegalovania" or (value=="finalMegalovania" and "off" or nil); refresh();
   end); refresh();
   local preview=SS.SoundPreviewIcon(child,"finalMegalovania"); preview:SetPoint("TOPLEFT",child,"TOPLEFT",4,-(i-1)*67-33);
  end
  child:SetHeight(table.getn(SS.FINAL_BOSS_CATALOG)*67+12);
 end
 menu:Show();
end
SS.Every("finalBossSounds",.1,function() SS.UpdateFinalBossSounds(); end);
