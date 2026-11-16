-- Focused Slim Suite module; loaded in manifest order.
if ( setfenv ) then setfenv(1, SS.ENV); end
-- Let the client measure wrapped translated text; retain the established font size.
function SS.WrappedLabelHeight(label, width)
	label:SetWidth(math.max(40, width)); label:SetHeight(0);
	local height = label:GetHeight() or 0;
	if ( height <= 0 ) then
		local _, size = label:GetFont();
		height = math.ceil((label:GetStringWidth() or 0) / math.max(40, width)) * ((size or 12) + 2);
	end
	height = math.max(20, height); label:SetHeight(height); return height;
end
function SS.LayoutPage(page)
	local rows, parent = page.rows, page.parent;
	local show = {};
	for i = 1, table.getn(rows) do
		local r = rows[i];
		show[i] = not (r.up and not r.up());
	end
	local y = page.startY;
	for i = 1, table.getn(rows) do
		local r = rows[i];
		if ( r.kind == "head" ) then
			local any = false;
			for j = i + 1, table.getn(rows) do
				if ( rows[j].kind == "head" ) then break; end
				if ( show[j] ) then any = true; break; end
			end
			r.fs:ClearAllPoints(); r.fs:SetPoint("TOPLEFT", parent, "TOPLEFT", r.deathHeader and 240 or 8, y);
			if ( any ) then r.fs:Show(); y = y - 24; else r.fs:Hide(); end
		elseif ( show[i] ) then
			local rowHeight = 28;
			if ( r.kind == "button" ) then
				r.b:ClearAllPoints(); r.b:SetPoint("TOPLEFT", parent, "TOPLEFT", 26, y + 2);
				r.b:Show();
				rowHeight = 30;
			elseif r.kind=="deathmatrix" then
    r.fs:ClearAllPoints(); r.fs:SetPoint("TOPLEFT",parent,"TOPLEFT",48,y-5); r.fs:SetWidth(170); r.fs:Show();
    r.cb:ClearAllPoints(); r.cb:SetPoint("TOPLEFT",parent,"TOPLEFT",250,y); r.cb:Show(); r.cb.label:Hide();
    r.mate:ClearAllPoints(); r.mate:SetPoint("TOPLEFT",parent,"TOPLEFT",350,y); r.mate:Show(); r.mate.label:Hide();
    if r.preview then r.preview:ClearAllPoints(); r.preview:SetPoint("TOPLEFT",parent,"TOPLEFT",24,y-4); r.preview:Show(); end
   elseif ( r.kind == "choice" ) then
				r.fs:ClearAllPoints(); r.fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 30 + r.lead, y - 6);
				rowHeight = math.max(28, SS.WrappedLabelHeight(r.fs, 140 - r.lead) + 10);
				r.fs:Show(); r.b:Show();
			else
				r.cb:ClearAllPoints(); r.cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 26 + r.lead, y);
				rowHeight = math.max(28, SS.WrappedLabelHeight(r.cb.label, 350 - r.lead) + 8);
				r.cb:Show(); r.cb.label:Show();
    if r.preview then r.preview:ClearAllPoints(); r.preview:SetPoint("RIGHT",r.cb,"LEFT",-2,0); r.preview:Show(); end
			end
			y = y - rowHeight;
		else
			if ( r.kind == "button" ) then r.b:Hide();
			elseif ( r.kind == "choice" ) then r.fs:Hide(); r.b:Hide(); else r.cb:Hide(); r.cb.label:Hide(); if r.preview then r.preview:Hide(); end end
		end
	end
	parent:SetHeight(math.max(20, -y + 12));
	if ( page.after ) then page.after(y); end
	return y;
end

function SS.Check(parent, label, y, get, set, indent)
	local cb, ok = K.Templated("CheckButton", nil, parent, "UICheckButtonTemplate");
	if ( not ok or not cb.SetChecked ) then
		cb = CreateFrame("CheckButton", nil, parent);
		cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up");
		cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down");
		cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight");
		cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check");
	end
	cb:SetWidth(26);
	cb:SetHeight(26);
	cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 26 + (indent or 0), y);
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	fs:SetPoint("TOPLEFT", cb, "TOPRIGHT", 4, -4);
	fs:SetWidth(350); fs:SetHeight(28); fs:SetJustifyH("LEFT"); fs:SetText(SS.T(label));
	cb.label = fs;
	cb:SetScript("OnShow", function() this:SetChecked(get() and 1 or nil); end);
	cb.get = get;
	SS.TrackToggle(cb);
	cb:SetScript("OnClick", function()
		if this.cond and not this.cond() then return; end
  local v = not (get() and true or false);
		SS.ChangeSetting(get, set, v);
		K.Sound(v and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff");
		SS.RefreshToggles();
	end);
	return cb;
end

function SS.SoundPreviewIcon(parent,key)
 local button=CreateFrame("Button",nil,parent); button:SetWidth(18); button:SetHeight(18);
 -- Texture geometry keeps the media icons crisp without relying on font glyphs.
 local play,paused,playing={},{},{};
 local function bar(group,x,y,width,height)
  local texture=button:CreateTexture(nil,"ARTWORK"); texture:SetTexture(1,1,1,1);
  texture:SetWidth(width); texture:SetHeight(height); texture:SetPoint("CENTER",button,"CENTER",x,y);
  table.insert(group,texture);
 end
 for i=0,7 do bar(play,-3+i,0,1,12-i*1.5); end
 bar(paused,-3,0,3,12); bar(paused,3,0,3,12);
 bar(playing,-4,0,2,5); bar(playing,0,0,2,11); bar(playing,4,0,2,7);
 local hover=button:CreateTexture(nil,"BACKGROUND"); hover:SetTexture(1,1,1,.16); hover:SetAllPoints(button); hover:Hide();
 local lastState;
 local function show(group,visible)
  for _,texture in ipairs(group) do if visible then texture:Show(); else texture:Hide(); end end
 end
 local function refresh()
  local active=SS.PreviewActive(key);
  local state=active and (SS.CanStopPreview() and "pause" or "playing") or (SS.previewNext==key and "queued" or "play");
  if state==lastState then return; end
  lastState=state; button.isStop=state=="pause";
  show(play,state=="play"); show(paused,state=="pause"); show(playing,state=="playing" or state=="queued");
  for _,texture in ipairs(playing) do texture:SetAlpha(state=="queued" and .4 or 1); end
 end
 button:SetScript("OnUpdate",function() refresh(); end); refresh();
 button:SetScript("OnClick",function() SS.PreviewSound(key); refresh(); end);
 button:SetScript("OnEnter",function()
  hover:Show();
  if GameTooltip then GameTooltip:SetOwner(this,"ANCHOR_RIGHT"); GameTooltip:AddLine(SS.T(SS.previewNext==key and "Queued preview (waiting for current sound)" or SS.PreviewActive(key) and (SS.CanStopPreview() and "Stop sound" or "Playing (client cannot stop sounds)") or "Play sound")); GameTooltip:Show(); end
 end);
 button:SetScript("OnLeave",function() hover:Hide(); if GameTooltip then GameTooltip:Hide(); end end);
 return button;
end
function SS.WinBuild()
 win=K.Window("SlimSuiteFrame","Slim Suite",470,560);
 local hero=K.Hero(win,380); hero:SetWidth(430); hero:SetPoint("TOPLEFT",win,"TOPLEFT",20,-30);
 K.Icon(hero.icon,"INV_Misc_Gear_02"); hero.heading:SetText("Slim Suite"); hero.line:SetText(SS.T("Choose a module to open its settings."));
 hero.version=hero:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); hero.version:SetPoint("TOPRIGHT",hero,"TOPRIGHT",-9,-8); hero.version:SetText("v"..SS.AddonVersion());
 local hub=CreateFrame("Frame","SlimSuiteModuleHub",win); hub:SetPoint("TOPLEFT",win,"TOPLEFT",20,-110); hub:SetWidth(422); hub:SetHeight(390);
 SS.moduleHubButtons={}; local views={}; local current;
 local back=K.Button(win,"Back",75,function() SS.OpenModulePage(nil); end); back:SetPoint("TOPLEFT",win,"TOPLEFT",20,-102);
 local master=SS.Check(win,"Module enabled",-100,function() return current and SS.ModuleEnabled(current); end,function(v) if current then SS.SetModuleEnabled(current,v); end end);
 master:ClearAllPoints(); master:SetPoint("LEFT",back,"RIGHT",14,0); master.moduleControl=true; master.label:SetWidth(260); master.label:SetHeight(28);
	local function AddRows(parent, entries, startY, after, module)
		SS.pages = SS.pages or {};
		local page = { parent = parent, rows = {}, startY = startY, after = after, module=module };
		local up = nil;
		for i = 1, table.getn(entries) do
			local row = entries[i];
			if ( row.head ) then
				local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal");
				fs:SetText(SS.T(row.head)); fs:SetTextColor(1, 0.82, 0);
				table.insert(page.rows, { kind = "head", fs = fs });
				up = nil;
   elseif row.deathMatrix then
    local title=parent:CreateFontString(nil,"OVERLAY","GameFontNormal"); title:SetText(SS.T("Your Death Sound")); table.insert(page.rows,{kind="head",fs=title});
    local header=parent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); header:SetText(SS.T("Your Death").."     "..SS.T("Teammate Death"));
    header:SetPoint("TOPLEFT",parent,"TOPLEFT",242,0);
    local headerRow={kind="head",fs=header,deathHeader=true}; table.insert(page.rows,headerRow);
    for _,option in ipairs(row.deathMatrix) do
     local key=option[2]; local fs=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight"); fs:SetText(SS.T(option[1])); fs:SetHeight(24); fs:SetJustifyH("LEFT");
     local cb=SS.Check(parent,"",startY,function() return SS.SoundSelection("death")==key; end,function() SS.SetSoundSelection("death",key); end);
     cb.soundGroup="death"; cb.soundKey=key;
     local mate=SS.Check(parent,"",startY,function() return SS.DeathSoundSelection("teammate")==key; end,function() SS.SetSoundSelection("teammate",key); end); mate.soundGroup="teammate"; mate.soundKey=key; mate.cond=function() return SS.ModuleEnabled(module); end
     table.insert(page.rows,{kind="deathmatrix",fs=fs,cb=cb,mate=mate,preview=key~="off" and SS.SoundPreviewIcon(parent,key) or nil,soundGroup="death",soundKey=key});
    end
    up=nil;
   elseif row.sounds then
    local fs=parent:CreateFontString(nil,"OVERLAY","GameFontNormal"); fs:SetText(SS.T(row[1])); fs:SetTextColor(1,.82,0);
    table.insert(page.rows,{kind="head",fs=fs});
    for _,option in ipairs(row.sounds) do
     local key=option[2]; local group=row.group;
     local cb=SS.Check(parent,option[1],startY,function() return SS.SoundSelection(group)==key; end,function() SS.SetSoundSelection(group,key); end,20);
     cb.soundGroup=group; cb.soundKey=key;
     local preview=key~="off" and key~="same" and SS.SoundPreviewIcon(parent,key) or nil;
     table.insert(page.rows,{kind="check",lead=20,cb=cb,preview=preview,soundGroup=group,soundKey=key});
    end
    up=nil;
			elseif ( row.button ) then
				local b = K.Button(parent, SS.T(row.button), row.width or 150, row.onClick);
				table.insert(page.rows, { kind = "button", b = b });
				up = nil;
			else
				local label, lead = row[1], 0;
				if ( string.find(label, "^%s") ) then lead = 22; label = string.gsub(label, "^%s+", ""); end
				local r = { lead = lead, up = (lead > 0) and up or nil };
				if ( row.choice ) then
					r.kind = "choice";
					r.fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
					r.fs:SetText(SS.T(label));
					r.b = SS.ChoiceButton(parent, 200);
					r.b.entry = row; r.b:SetPoint("LEFT", r.fs, "RIGHT", 10, 0);
					r.b:SetText(SS.ChoiceText(row) .. "  v");
					r.b:SetScript("OnShow", function() if ( this.entry ) then this:SetText(SS.ChoiceText(this.entry) .. "  v"); end end);
					if ( lead == 0 ) then up = nil; end
				else
					r.kind = "check";
					r.cb = SS.Check(parent, label, startY, row[2], row[3], lead);
					up = row[2];
				end
				table.insert(page.rows, r);
			end
		end
		for _,r in ipairs(page.rows) do
   if r.cb then r.cb.cond=function() return SS.ModuleEnabled(module); end end
  end
  table.insert(SS.pages, page);
		SS.LayoutPage(page);
		return page;
	end
 local worldEntry=SS.WorldCombatEntry();
 local uiEntries={
			{head="Setup"},
			{"Toggle UI Settings (drag, resize and scale)", function() return SS.DB().unlocked; end, function(v) SS.SetUnlocked(v); end},
			{button = "Demo Mode", onClick = function() SS.ToggleDemoMode(); end},
			{button = "Profiles & import/export", onClick = function() SS.ShowLayoutWindow(); end},
			{button = "Recommended HUD preset", onClick = function() SS.ShowHUDRecommendation(); end},
			{"Keep a separate layout for each character", function() return SS.DB().layoutPerCharacter; end, function(v) SS.SetLayoutPerCharacter(v); end},
			{head="Everywhere"},
   {"Legendary luck",function() return SS.FeatureEnabled("SlimSuiteLuckFrame"); end,function(v) SU.SetMode("SlimSuiteLuckFrame",v and "enabled" or "disabled","Legendary luck"); end},
			{"Compass",function() return SS.DB().compassOn; end,function(v) SU.SetMode("SlimSuiteCompassFrame",v and "enabled" or "disabled","Compass"); end},
			{"Show green absorb amounts on player and party frames (when the client exposes them)", function() return SS.DB().showAbsorbs; end, function(v) SS.DB().showAbsorbs = v and true or false; SS.Safe(SS.UpdateAbsorbMarkers); end},
			worldEntry,
			{"Build and stats beside card choices",function() return SS.DB().cardEdgeHUD~=false; end,function(v) SS.DB().cardEdgeHUD=v; end},
			{"Show Slim Suite above the level-up and new-item cards", function() return SS.DB().onTopOfScreens; end, function(v) SS.DB().onTopOfScreens = v; if ( SlimSuiteWorld ) then SlimSuiteWorld.ApplyOnTop(); end end}
 };
 local otherEntries={
			{"Language (reload UI)", function() return SS.DB().language or "auto"; end,
			 function(v) SS.DB().language = v; end,
			 choice={{"auto","auto"},{"English","enUS"},{"Español","esES"},{"Français","frFR"},{"Deutsch","deDE"},{"Português (Brasil)","ptBR"},{"Italiano","itIT"}} },
			{button="Reload for changes", onClick=function() if ( ReloadUI ) then ReloadUI(); end end},
			{head="Chat mods"},
			{"No level-up stat bonuses in chat", function() return SS.DB().hideLevel;end,function(v) SS.DB().hideLevel=v;end},
			{"No new spell lines in chat", function() return SS.DB().hideNewSpells;end,function(v) SS.DB().hideNewSpells=v;end},
			{"Hide racial buff information in chat", function() return SS.DB().hideRacialInfo;end,function(v) SS.DB().hideRacialInfo=v;end},
			{"Hide the Oogax Q opening line (English game text only)", function() return SS.DB().hideOpeningLine;end,function(v) SS.DB().hideOpeningLine=v;end},
			{"Hide 'Who dares to enter my lair' (English game text only)", function() return SS.DB().hideLairLine;end,function(v) SS.DB().hideLairLine=v;end},
			{"Hide in-game roleplay lines from chat", function() return SS.DB().hideRP;end,function(v) SS.DB().hideRP=v;end},
			{head="Enemy frames"},
			{"Show native enemy nameplates", function() return SS.NativeEnemyNameplatesEnabled and SS.NativeEnemyNameplatesEnabled(); end, function(v) SS.SetNativeEnemyNameplates(v); end},
			{"Use modern Slim Suite enemy frames", function() return SS.DB().modernEnemyFrames; end, function(v) SS.SetModernEnemyFrames(v); end},
			{"Only show bosses and lair guardians on modern enemy frames", function() return SS.DB().enemyBossesOnly; end, function(v) SS.SetEnemyPlateBossesOnly(v); end},
			{"Show boss and lair debuffs and remaining time on enemy nameplates (native or modern)", function() return SS.DB().enemyPlateDebuffs; end, function(v) SS.SetEnemyPlateDebuffs(v); end},
			{head="Camera and marks"},
			{"Camera as far out as it goes (50)", function() return SS.DB().camera; end, function(v) SS.DB().camera = v; SS.Camera(v); end},
			{"Mark pulled bosses and Guardians (Skull, X, Circle, Star)", function() return SS.DB().bossMarks; end, function(v) SS.DB().bossMarks = v; end},
			{"   ...and Guardians and lairs before they're pulled", function() return SS.DB().prePullMarks; end, function(v) SS.DB().prePullMarks = v; end},
			{"Raid-mark row when the mouse is over a party member (in a group)", function() return SS.DB().raidRow; end, function(v) SS.DB().raidRow = v and true or false; end},
			{head="Minimap"},
			{"Show caches on the minimap", function() return SS.DB().minimapCaches; end, function(v) SS.DB().minimapCaches = v; end},
			{"Show bosses on the minimap", function() return SS.DB().minimapBosses; end, function(v) SS.DB().minimapBosses = v; end},
			{"Show lairs on the minimap, with their 3:00 refill timer", function() return SS.DB().minimapLairs; end, function(v) SS.DB().minimapLairs = v; end},
			{"Show the game's nearest Guardian lair flag on minimap", function() return SS.DB().showGuardianFlag; end, function(v) SS.DB().showGuardianFlag = v; SS.ApplyGuardianFlag(); end},
			{"Square minimap (off: round)", function() return SS.DB().minimapSquare; end, function(v) SS.SetMinimapSquare(v); end},
			{"Transparent minimap (round or square, no borders)", function() return SS.DB().minimapTransparent; end, function(v) SS.SetMinimapTransparent(v); end},
			{"Minimap button", function() local m = SS.DB().minimap; return not (m and m.hide); end, function(v) if ( SS.Mini ) then local m = SS.DB().minimap; if ( (m and m.hide and true or false) == v ) then SS.Mini.Toggle(); end end end},
			{head="Deaths and spells"},
			{"Mark where a downed friend can be revived", function() return SS.DB().deathMarks; end, function(v) SS.DB().deathMarks = v; end},
   {deathMatrix={{"Off","off"},{"Baby Crying","death"},{"LEGO die","legoDeath"},{"duck toy sound","duckDeath"},{"Roblox death sound","robloxDeath"}}},
   {"Low health sound (30% or lower)",group="lowHealth",sounds={{"Off","off"},{"Low Health Sound","lowHealth"}}},
   {"Boss / guardian / lair kill sound",group="boss",sounds={{"Off","off"},{"Hitmarker","bossHitmarker"},{"Whip Crack","bossWhip"},{"Gotcha — Dave Chappelle","bossGotcha"}}},
   {"Match loss sound",group="loss",sounds={{"Off","off"},{"The Price Is Right: losing horn","matchLoss"},{"GTA V: Wasted","matchWasted"},{'Halo "Game Over"',"haloLoss"}}},
   {"Victory sound",group="victory",sounds={{"Off","off"},{"GTA San Andreas","matchVictory"},{"To Be Continued JoJo","jojoVictory"}}},
   {"Final boss arrival soundtrack",group="finalBoss",sounds={{"Off","off"},{"Megalovania","finalMegalovania"}}},
   {button="Final boss soundtracks",onClick=function() SS.OpenFinalBossSounds(); end},
   {"Match start song",group="start",sounds={{"Off","off"},{"Kit Kit Kit","matchStart"},{"Cena","cenaStart"},{"pillar man jojo","pillarStart"},{"CSGO Okay Let’s Go","csgoStart"}}},
   {"Chest opening sound",group="chest",sounds={{"Off","off"},{"Zelda: final four notes","chestOpen"}}},
			{"Cooldown numbers on the spell squares", function() return SS.DB().cooldowns; end, function(v) SS.DB().cooldowns = v; end},
			{head="Accessibility"},
			{"High-contrast encounter bars", function() return SS.DB().accessibilityContrast; end, function(v) SS.DB().accessibilityContrast = v and true or false; SS.Safe(SS.UpdateBossFrames); end},
			{"Larger encounter names", function() return SS.DB().accessibilityLargeText; end, function(v) SS.DB().accessibilityLargeText = v and true or false; SS.Safe(SS.UpdateBossFrames); end},
			{"Reduce floating combat-text motion", function() return SS.DB().accessibilityReduceMotion; end, function(v) SS.DB().accessibilityReduceMotion = v and true or false; end},
 };
 if SS.AchievementsAvailable() then local achievements=K.Button(hub,SS.T("Side achievements"),275,function() SS.OpenAchievements(); end); achievements:SetPoint("TOPLEFT",hub,"TOPLEFT",6,-300); end;
 local entries={chat={},sounds={},ui={},gameplay={},misc={}};
 for _,row in ipairs(uiEntries) do table.insert(entries[row==worldEntry and "gameplay" or "ui"],row); end
 local category="misc";
 for _,row in ipairs(otherEntries) do
  if row.head then
   category=({["Chat mods"]="chat",["Enemy frames"]="gameplay",["Camera and marks"]="gameplay",["Minimap"]="ui",["Deaths and spells"]="sounds",["Accessibility"]="misc"})[row.head] or "misc";
  end
  local destination=category; local label=row[1];
  if label=="Mark where a downed friend can be revived" or label=="Show caches on the minimap" or label=="Show bosses on the minimap" or label=="Show lairs on the minimap, with their 3:00 refill timer" or label=="Show the game's nearest Guardian lair flag on minimap" then destination="gameplay";
  elseif label=="Minimap button" then destination="misc";
  elseif label=="Cooldown numbers on the spell squares" then destination="ui"; end
  table.insert(entries[destination],row);
 end
 if SS.AchievementsAvailable() then table.insert(entries.ui,{"Side achievements button",function() return SS.FeatureEnabled("SlimSuiteAchievementsButton"); end,function(v) SU.SetMode("SlimSuiteAchievementsButton",v and "enabled" or "disabled","Side achievements"); end});
 table.insert(entries.gameplay,{button="Side achievements",onClick=function() SS.OpenAchievements(); end}); end;
 table.insert(entries.ui,{button="Reset positions",onClick=function() SS.ResetPlaces(); end});
 table.insert(entries.ui,{button="Reset all UI",onClick=function() SS.ResetUI(); end});
 for i,id in ipairs(SS.MODULE_ORDER) do
  local module=id;
  local open=K.Button(hub,SS.T(SS.MODULE_TITLES[id]),275,function() SS.OpenModulePage(module); end);
  open:SetHeight(42); open:SetPoint("TOPLEFT",hub,"TOPLEFT",6,-(i-1)*58);
  local toggle=K.Button(hub,"",110,function() SS.SetModuleEnabled(module,not SS.ModuleEnabled(module)); end);
  toggle:SetHeight(42); toggle:SetPoint("LEFT",open,"RIGHT",8,0); SS.moduleHubButtons[id]=toggle;
  local scroll,child=K.Scroll("SlimSuiteModule_"..id,win,422);
  scroll:SetPoint("TOPLEFT",win,"TOPLEFT",20,-139); scroll:SetPoint("BOTTOMRIGHT",win,"BOTTOMRIGHT",-30,34);
  local page=AddRows(child,entries[id],-8,nil,id); views[id]={scroll=scroll,page=page};
 end
 SS.RefreshModuleHub=function()
  for id,button in pairs(SS.moduleHubButtons) do button:SetText(SS.T(SS.ModuleEnabled(id) and "On" or "Off")); end
  if current then
   for _,row in ipairs(views[current].page.rows) do
    local enabled=SS.ModuleEnabled(current);
    if row.b then if enabled then row.b:Enable(); else row.b:Disable(); end end
   end
  end
 end;
 SS.OpenModulePage=function(id)
  current=id;
  for _,view in pairs(views) do view.scroll:Hide(); end
  if id and views[id] then hub:Hide(); back:Show(); master:Show(); master.label:Show(); views[id].scroll:Show(); master.label:SetText(SS.T(SS.MODULE_TITLES[id]).." — "..SS.T("Module enabled"));
  else hub:Show(); back:Hide(); master:Hide(); master.label:Hide(); end
  SS.RefreshToggles(); SS.RefreshModuleHub();
 end;
 win:SetScript("OnShow",function() SS.OpenModulePage(nil); end);
 SS.OpenModulePage(nil);
end

function SS.Toggle()
	if ( not win ) then
		local ok, err = SS.Safe(SS.WinBuild);
		if ( not ok ) then K.Print(NAME, "|cffff4040the settings window could not be made:|r " .. tostring(err)); win = nil; return; end
	end
	if ( win:IsShown() ) then win:Hide(); else win:Show(); end
end

-- "/slimsuite mouse": a small label by the cursor names the frame under it (and the frame that frame belongs to), so a
-- click that does nothing can be traced to whatever is catching it. Type it again to turn the label off.
function SS.ToggleMouseProbe()
	local probe = getglobal("SlimSuiteMouseProbe");
	if ( not probe ) then
		probe = CreateFrame("Frame", "SlimSuiteMouseProbe", UIParent);
		probe:SetFrameStrata("TOOLTIP");
		probe:SetWidth(10); probe:SetHeight(10);
		probe.text = probe:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		probe.text:SetPoint("BOTTOMLEFT", probe, "TOPRIGHT", 4, 4);
		probe.text:SetJustifyH("LEFT");
		probe:Hide();
	end
	if ( probe:IsShown() ) then
		probe:Hide(); SS.Stop("mouseProbe");
		K.Print(NAME, "the frame label is off.");
		return;
	end
	probe:Show();
	SS.Every("mouseProbe", 0.1, function()
		local f = GetMouseFocus and GetMouseFocus();
		local x, y = GetCursorPosition();
		local scale = SS.EffectiveScale(UIParent);
		probe:ClearAllPoints();
		probe:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale);
		if ( not f ) then probe.text:SetText("|cffaaaaaa(the game world)|r"); return; end
		local name = (f.GetName and f:GetName()) or "(no name)";
		local parent = f.GetParent and f:GetParent();
		local pname = parent and parent.GetName and parent:GetName() or "(no name)";
		probe.text:SetText("|cffffd100" .. name .. "|r\n|cffaaaaaain " .. pname .. "|r");
	end);
	K.Print(NAME, "the frame under your cursor is named next to it. /slimsuite mouse turns it off.");
end

SS.HELP = {
	"/slim: the settings window.  /slim edit: move and size the UI (/slim lock when done).  /slim setup: the guided setup.",
	"/slim demo: Demo Mode on or off.  /slim levelup: Slim Suite's Level Up button or the game's own.",
	"/slim layout: manage named profiles and import/export layouts.  /slim layout save <name>, load <name>, delete <name>, list.",
	"/slim hud: recommended positions for this display.",
	"/slim reset places, /slim reset all: back to where everything started.",
	"/slim hide <words>, /slim unhide <words>, /slim hide: chat lines with those words.",
	"/slim minimap: the gear button.  /slim errors: the error log.  /slim mouse: names the frame under the cursor.",
};
SLASH_SLIMSUITE1 = "/slimsuite";
SLASH_SLIMSUITE2 = "/slim";
SlashCmdList["SLIMSUITE"] = function(msg)
	msg = msg or "";
	local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.-)$");
	cmd = string.lower(cmd or "");
	rest = string.lower(rest or "");
	local d = SS.DB();
	if ( cmd == "help" or cmd == "?" ) then
		for _, line in ipairs(SS.HELP) do K.Print(NAME, line); end
	elseif ( cmd == "hide" and rest == "" ) then
		if ( table.getn(d.words) == 0 ) then K.Print(NAME, "no words are hidden. /slim hide <words> hides chat lines with them.");
		else K.Print(NAME, "hidden in chat: \"" .. table.concat(d.words, "\", \"") .. "\". /slim unhide <words> shows them again."); end
	elseif ( cmd == "hide" ) then
		for i = 1, table.getn(d.words) do
			if ( d.words[i] == rest ) then K.Print(NAME, "\"" .. rest .. "\" is hidden already."); return; end
		end
		table.insert(d.words, rest);
		K.Print(NAME, "chat lines with \"" .. rest .. "\" are hidden now.");
	elseif ( cmd == "unhide" and rest ~= "" ) then
		for i = table.getn(d.words), 1, -1 do if ( d.words[i] == rest ) then table.remove(d.words, i); end end
		K.Print(NAME, "chat lines with \"" .. rest .. "\" are shown again.");
	elseif ( cmd == "errors" ) then
		SS.ShowErrors();
	elseif ( cmd == "hud" or cmd == "recommend" ) then
		SS.ShowHUDRecommendation();
	elseif ( cmd == "mouse" ) then
		SS.ToggleMouseProbe();
	elseif ( cmd == "minimap" ) then
		local shown = SS.Mini and SS.Mini.Toggle();
		K.Print(NAME, shown and "the minimap button is back." or "the minimap button is hidden. /slimsuite minimap brings it back.");
	elseif ( cmd == "unlock" or cmd == "move" or cmd == "edit" ) then
		SS.SetUnlocked(true);
	elseif ( cmd == "lock" ) then
		SS.SetUnlocked(false);
	elseif ( cmd == "setup" ) then
		SS.StartSetup(true);
	elseif ( cmd == "demo" ) then
		SS.ToggleDemoMode();
		K.Print(NAME, SS.demoRunning and "Demo Mode is on. /slim demo turns it off." or "Demo Mode is off.");
	elseif ( cmd == "levelup" ) then
		d.moveLevelButton = not d.moveLevelButton;
		SS.Safe(SS.UpdateLevelButton); SS.RefreshToggles();
		K.Print(NAME, d.moveLevelButton and "Slim Suite's movable Level Up button is on." or "the game's own Level Up button is back.");
	elseif ( cmd == "reset" ) then
		if ( rest == "all" ) then SS.ResetUI(); elseif ( rest == "places" ) then SS.ResetPlaces();
		else K.Print(NAME, "/slim reset places puts every element back where it started; /slim reset all also resets sizes, scales and layouts."); end
	elseif ( cmd == "layout" or cmd == "layouts" ) then
		local _, _, action, name = string.find(rest, "^(%S*)%s*(.-)$");
		if ( action == "save" and name ~= "" ) then
			d.layouts[name] = SS.LayoutSnapshot();
			K.Print(NAME, "layout \"" .. name .. "\" saved.");
		elseif ( action == "load" and name ~= "" ) then
			if ( type(d.layouts[name]) == "table" and string.sub(name, 1, 5) ~= "char:" ) then SS.LayoutApply(d.layouts[name]); K.Print(NAME, "layout \"" .. name .. "\" is in use.");
			else K.Print(NAME, "there is no layout called \"" .. name .. "\". /slim layout list shows them."); end
		elseif ( action == "delete" and name ~= "" ) then
			if ( d.layouts[name] and string.sub(name, 1, 5) ~= "char:" ) then d.layouts[name] = nil; K.Print(NAME, "layout \"" .. name .. "\" deleted.");
			else K.Print(NAME, "there is no layout called \"" .. name .. "\"."); end
		elseif ( action == "list" ) then
			local names = SS.LayoutNames();
			K.Print(NAME, table.getn(names) > 0 and ("saved layouts: " .. table.concat(names, ", ")) or "no layouts saved yet. /slim layout save <name> saves this one.");
		else
			SS.ShowLayoutWindow();
			K.Print(NAME, "/slim layout save <name>, load <name>, delete <name>, list. The window shares a layout as text.");
		end
	else
		SS.Toggle();
	end
end
