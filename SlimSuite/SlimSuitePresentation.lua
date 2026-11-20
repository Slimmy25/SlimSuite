-- Native combat feedback, real spell tooltips, and authoritative build cooldown labels.
if ( setfenv ) then setfenv(1, SS.ENV); end
function SS.WorldTextMode()
 local d=SS.DB(); if ( d.vanillaUI ) then return "none"; end
 if ( d.combatTextBox and (d.worldCombatMode=="iconsCrits" or d.worldCombatMode=="bosses") ) then return d.worldCombatMode; end
 return d.floatingText and "all" or "none";
end
function SS.WorldTextEnabled() return SS.WorldTextMode()~="none"; end
function SS.CombatLogVisible()
 local d=SS.DB(); local mode=SS.WorldTextMode();
 return d.combatTextBox and (mode=="none" or mode=="all" or d.keepCombatLog==true);
end
function SS.RestoreNativeDamageNumbers()
 local d=SS.DB();
 if ( d.nativeCombatDamageOriginal~=nil and type(SetCVar)=="function" ) then
  local ok=pcall(SetCVar,"CombatDamage",d.nativeCombatDamageOriginal);
  if ( ok ) then d.nativeCombatDamageOriginal=nil; end
 end
end
function SS.SyncNativeDamageNumbers()
 if ( type(GetCVar)~="function" or type(SetCVar)~="function" ) then return; end
 local d=SS.DB(); local active=not d.vanillaUI and (d.combatTextBox or SS.WorldTextEnabled());
 if ( not active ) then SS.RestoreNativeDamageNumbers(); return; end
 local ok,current=pcall(GetCVar,"CombatDamage"); if ( not ok or current==nil ) then return; end
 if ( d.nativeCombatDamageOriginal==nil ) then d.nativeCombatDamageOriginal=tostring(current); end
 local value=d.worldCombatMode=="native" and "1" or "0";
 if ( tostring(current)~=value ) then pcall(SetCVar,"CombatDamage",value); end
end
function SS.SetWorldCombatMode(value)
 local d=SS.DB(); d.worldCombatMode=value; d.floatingText=false;
 if ( value~="off" ) then SU.SetMode("SlimSuiteCombatTextFrame","enabled","Combat text"); end
 SS.SyncNativeDamageNumbers(); SS.MarkProfileDirty();
end
function SS.WorldCombatEntry()
 return {"Where the big damage numbers appear",function() return SS.DB().worldCombatMode or "off"; end,function(v) SS.SetWorldCombatMode(v); end,
 choice={{"Off: only the combat log","off"},{"Keep the game's own numbers too","native"},{"Only crits and spell hits","iconsCrits"},{"Only boss damage","bosses"}}};
end
-- A failed optional tooltip route must not add errors to the user's addon error log.
function SS.ShowBuildSpellTooltip(button)
 local tip=GameTooltip; if ( not tip or not button.spell ) then return false; end
 local id=tonumber(button.spell.spell);
 local function Try(method,...)
  if ( type(tip[method])~="function" ) then return false; end
  if ( tip.ClearLines ) then tip:ClearLines(); end
  local ok=pcall(tip[method],tip,unpack(arg));
  if ( not ok ) then return false; end
  if ( tip.NumLines and tip:NumLines()<2 ) then
   local title=getglobal("GameTooltipTextLeft1");
   if ( not button.sourceName and title and title.GetText ) then button.sourceName=title:GetText(); end
   return false;
  end
  tip:Show(); return true;
 end
 if ( id and Try("SetHyperlink","spell:"..id) ) then return true; end
 local slot=button.spellBookSlot;
 -- The 1.12 client has GetSpellName, not the newer GetSpellBookItemInfo.
 if ( not slot and button.sourceName and type(GetSpellName)=="function" ) then
  for i=1,512 do
   local name,rank=GetSpellName(i,BOOKTYPE_SPELL or "spell"); if ( not name ) then break; end
   local _,_,number=string.find(rank or "","(%d+)");
   if ( name==button.sourceName and (not button.spell.rank or tonumber(number or 1)==tonumber(button.spell.rank)) ) then slot=i; button.spellBookSlot=i; break; end
  end
 end
 if ( slot and (Try("SetSpellBookItem",slot,BOOKTYPE_SPELL or "spell") or Try("SetSpell",slot,BOOKTYPE_SPELL or "spell")) ) then return true; end
 return false;
end
function SS.UpdateBuildCooldowns()
 local ready=type(AZS_GetPhase)=="function" and AZS_GetPhase()=="ready";
 local spells=type(AZS_SPELLS)=="table" and AZS_SPELLS or {};
 local function Paint(button,spell)
  if ( not button ) then return; end
  local text=button.slimBuildCooldown;
  if ( not text ) then text=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); text:SetPoint("BOTTOM",button,"BOTTOM",0,2); button.slimBuildCooldown=text; end
  local remaining=type(spell)=="table" and tonumber(spell.cd);
  local value=type(spell)=="table" and tonumber(ready and ((remaining and remaining>0) and remaining or spell.cdmax) or spell.cd);
  if ( value and value>0 and (ready or SS.DB().cooldowns) ) then
   text:SetText(tostring(math.ceil(value))); text:SetTextColor(ready and .8 or 1,ready and .8 or 1,ready and .8 or 1); text:Show();
   SS.FitText(text,math.max(1,button:GetWidth()-4),7,math.max(1,button:GetHeight()-4),tostring(math.ceil(value)));
  else text:Hide(); end
 end
 for i=1,6 do
  local spell=i<table.getn(spells) and spells[i] or nil;
  Paint(getglobal("SlimSuiteSpellButton"..i),spell);
  Paint(getglobal("ActionButton"..i),ready and not SS.DB().vanillaUI and spell or nil);
 end
 Paint(getglobal("ActionButton12"),ready and SS.DB().showRacialAbility and spells[table.getn(spells)] or nil);
end
SS.Every("nativeDamage",.25,function() SS.SyncNativeDamageNumbers(); end);
SS.Every("buildCooldowns",.1,function() SS.UpdateBuildCooldowns(); end);
local shutdown=CreateFrame("Frame"); shutdown:RegisterEvent("PLAYER_LOGOUT"); shutdown:SetScript("OnEvent",function() SS.RestoreNativeDamageNumbers(); SS.RestoreGuardianFlag(); end);
