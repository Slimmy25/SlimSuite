-- Focused Slim Suite module; loaded in manifest order.
local K, SU, NAME = SS.Kit, SS.SU, SS.NAME;   -- the three names every Slim Suite file uses (SlimSuiteCore.lua)
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
-- an element's section can be opened only while the element is On (no element: always)
function SS.FoldCanOpen(r)
	if ( not r or not r.element ) then return true; end
	return SU.Mode(r.element) == "enabled";
end

function SS.LayoutPage(page)
	local rows, parent = page.rows, page.parent;
	local show = {};
	-- while searching, every element section with a match opens by itself (only for as long as the search lasts)
	local q = SS.searchText and SS.searchText ~= "";
	local hit = {};
	if ( q ) then
		for i = 1, table.getn(rows) do
			local r = rows[i];
			if ( r.kind == "fold" and SS.RowMatches(r) ) then hit[r] = "title";
			elseif ( r.fold and not hit[r.fold] and not (r.up and not r.up()) and SS.RowMatches(r) ) then hit[r.fold] = true; end
		end
	end
	page.matchCount = 0;
	for i = 1, table.getn(rows) do
		local r = rows[i];
		show[i] = not (r.up and not r.up()) and SS.RowMatches(r);
		if ( r.fold ) then
			if ( q ) then show[i] = SS.FoldCanOpen(r.fold) and not (r.up and not r.up()) and (show[i] or hit[r.fold] == "title");
			elseif ( not (SS.openFolds and SS.openFolds[r.fold.title] and SS.FoldCanOpen(r.fold)) ) then show[i] = false; end
		end
		if ( r.kind == "fold" ) then show[i] = (not q) or (hit[r] and true or false); r.searchOpen = q and hit[r] and true; end
		if ( r.kind == "fold" and r.when and not r.when() ) then show[i] = false; end
		if ( r.fold and r.fold.when and not r.fold.when() ) then show[i] = false; end
		if ( r.group and not q and SS.closedGroups and SS.closedGroups[r.group.count] ) then show[i] = false; end
		if ( show[i] and r.kind ~= "head" ) then page.matchCount = page.matchCount + 1; end
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
			if ( r.count and SS.SectionCount ) then r.fs:SetText(r.label .. "  |cffbbbbbb" .. SS.SectionCount(r.count) .. " " .. SS.T("on") .. "|r"); end
			if ( r.groupButtons ) then
				-- a group of elements: + / - to open or close it, and On / Off / Default / Reset for all of them at once
				any = any or not q or false;
				local closed = SS.closedGroups and SS.closedGroups[r.count];
				if ( any ) then
					r.sign:SetText(closed and not q and "+" or "-");
					r.sign:ClearAllPoints(); r.sign:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y - 1); r.sign:Show();
					r.fs:ClearAllPoints(); r.fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, y - 3); r.fs:Show();
					r.click:ClearAllPoints(); r.click:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, y + 2); r.click:Show();
					for j, gb in ipairs(r.groupButtons) do
						gb:ClearAllPoints(); gb:SetPoint("TOPLEFT", parent, "TOPLEFT", 238 + (j - 1) * 58, y + 2); gb:Show();
					end
					y = y - 28;
				else
					r.sign:Hide(); r.fs:Hide(); r.click:Hide(); for _, gb in ipairs(r.groupButtons) do gb:Hide(); end
				end
			else
				r.fs:ClearAllPoints(); r.fs:SetPoint("TOPLEFT", parent, "TOPLEFT", r.deathHeader and 240 or 8, y);
				if ( any ) then r.fs:Show(); y = y - 24; else r.fs:Hide(); end
			end
		elseif ( show[i] ) then
			local rowHeight = 28;
			if ( r.kind == "button" ) then
				r.b:ClearAllPoints(); r.b:SetPoint("TOPLEFT", parent, "TOPLEFT", 26, y + 2);
				r.b:Show();
				rowHeight = 30;
			elseif ( r.kind == "fold" ) then
				local can = SS.FoldCanOpen(r);
				local open = can and ((SS.openFolds and SS.openFolds[r.title]) or r.searchOpen);
				r.y = y;
				-- the + / - sits outside the button, to the left of the name
				r.b:SetText(r.title);
				r.sign:SetText(can and (open and "-" or "+") or "");
				r.sign:ClearAllPoints(); r.sign:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y - 1); r.sign:Show();
				r.b:ClearAllPoints(); r.b:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, y + 2); r.b:Show();
				local current = r.element and SU.Mode(r.element);
				for j, mb in ipairs(r.modes or {}) do
					mb:ClearAllPoints(); mb:SetPoint("TOPLEFT", parent, "TOPLEFT", 238 + (j - 1) * 58, y + 2); mb:Show();
					if ( mb.mode and mb.mode == current ) then mb:LockHighlight(); else mb:UnlockHighlight(); end
				end
				rowHeight = 26;
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
			if ( r.kind == "button" or r.kind == "fold" ) then r.b:Hide(); if ( r.kind == "fold" ) then r.searchOpen = nil; end if ( r.sign ) then r.sign:Hide(); end for _, mb in ipairs(r.modes or {}) do mb:Hide(); end
			elseif ( r.kind == "choice" ) then r.fs:Hide(); r.b:Hide(); else r.cb:Hide(); r.cb.label:Hide(); if r.preview then r.preview:Hide(); end end
		end
	end
	parent:SetHeight(math.max(20, -y + 12));
	if ( page.after ) then page.after(y); end
	return y;
end

-- Short explanations shown when a setting is hovered, keyed by the setting's label.
SS.TIPS = {
	["Panel style (Slim Suite panels)"] = "Original keeps each element as it was. RPG and New School restyle Slim Suite's panels. Each element can override this from its right-click menu.",
	["Window text size"] = "Makes the Slim Suite windows and the setup panel bigger or smaller. Game text is not changed.",
	["Critical hits are bigger and stay longer"] = "Critical hit numbers are drawn larger and stay on screen for longer than normal hits.",
	["Also write the numbers in the combat log"] = "Adds each combat number to the game's combat log as well as the floating text.",
};
-- Keeps the text size of the Slim Suite windows in step with the chosen size.
function SS.SetTextScale(v)
	SS.DB().uiTextScale = v or 1;
	local frame = getglobal("SlimSuiteFrame"); if ( frame and frame.SetScale ) then frame:SetScale(SS.DB().uiTextScale); end
	if ( SU.panel and SU.panel.SetScale ) then SU.panel:SetScale(SS.DB().uiTextScale); end
end
-- A settings row is hidden while the search box does not match its label. Headings stay if a row under them shows.
SS.searchText = "";
function SS.RowMatches(r)
	local q = SS.searchText;
	if ( not q or q == "" or r.kind == "head" ) then return true; end
	local t = r.full or r.title or "";
	-- an element's section also answers to its other names (encounter finds the Encounter bars, ...)
	if ( r.element ) then t = t .. " " .. SS.ElementWords(r.element); end
	if ( r.full == nil and r.title == nil ) then
		if ( r.cb and r.cb.label and r.cb.label.GetText ) then t = r.cb.label:GetText() or "";
		elseif ( r.fs and r.fs.GetText ) then t = r.fs:GetText() or ""; end
	end
	t = string.lower(t);
	if ( string.find(t, q, 1, true) ) then return true; end
	-- buzz words: a word opens its whole family (hide finds hidden, remove and off, size finds scale and width, ...)
	if ( string.len(q) >= 3 ) then
		for _, family in ipairs(SS.SEARCH_WORDS) do
			local hit = false;
			for _, word in ipairs(family) do if ( string.find(word, q, 1, true) == 1 ) then hit = true; break; end end
			if ( hit ) then for _, word in ipairs(family) do if ( string.find(t, word, 1, true) ) then return true; end end end
		end
	end
	return false;
end
-- every name an element goes by: its label, title, frame name and the everyday words players use for it
SS.ELEMENT_WORDS = {
	PlayerFrame = "player me my frame unit frame portrait health", TargetFrame = "target enemy unit frame",
	PartyMemberFrame1 = "party group team friends", SlimSuitePartyLines = "party group lines",
	MinimapCluster = "minimap map", BuffFrame = "buffs debuffs auras", MainMenuBar = "action bar abilities buttons",
	MainMenuExpBar = "xp experience bar level", ChatFrame1 = "chat", SlimSuiteMeterFrame = "damage meter dps",
	SlimSuiteClockFrame = "run clock timer next boss", SlimSuiteBossFrames = "encounter boss bars bosses guardians",
	SlimSuiteAnnouncementFrame = "announcements banners events", SlimSuiteStoredLevelsButton = "level up stored levels",
	SlimSuiteReviveFrame = "revive bar", SlimSuiteLocalClockFrame = "local clock time",
	SlimSuiteSpellRowFrame = "build spells spell row", SlimSuiteItemRowFrame = "rings trinkets jewelry items",
	SlimSuiteTallyFrame = "kills gold cache tally", GameTooltip = "tooltip", SlimSuiteCombatTextFrame = "combat text numbers",
	SlimSuitePlayerCard = "player new style card", SlimSuiteTargetCard = "target new style card",
	SlimSuiteStatCounterFrame = "stats", SlimSuiteCompassFrame = "compass", SlimSuiteLuckFrame = "legendary luck",
	SlimSuiteAchievementsButton = "side achievements", CharacterFrame = "character", TalentFrame = "talents",
};
function SS.ElementWords(name)
	local e = SS.ELEMENTS and SS.ELEMENTS[name] or {};
	return string.lower(table.concat({ e.label or "", e.title or "", name or "", SS.ELEMENT_WORDS[name] or "" }, " "));
end
SS.SEARCH_WORDS = {
	{ "hide", "hidden", "remove", "off", "disable" }, { "opacity", "transparent", "see-through", "fade" },
	{ "move", "position", "place", "join", "anchor" }, { "size", "bigger", "smaller", "scale", "width", "height" },
	{ "clock", "time", "timer" }, { "boss", "guardian", "lair" }, { "sound", "audio", "music", "preview" },
	{ "party", "group", "team", "raid" }, { "map", "minimap", "compass" }, { "cards", "level-up", "new-item" },
	{ "buff", "aura", "debuff" }, { "enemy", "nameplate", "plate", "monster" },
};
function SS.RelayoutAllPages()
	if ( not SS.pages ) then return; end
	for i = 1, table.getn(SS.pages) do SS.LayoutPage(SS.pages[i]); end
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
	-- hovering a setting explains it, when a description is written in SS.TIPS
	local tip = SS.TIPS and SS.TIPS[label];
	cb:SetScript("OnEnter", function() if ( tip ) then SS.ShowWarnTip(this, SS.T(tip)); end end);
	cb:SetScript("OnLeave", function() SS.HideWarnTip(); end);
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
	SS.win=K.Window("SlimSuiteFrame","Slim Suite",720,560);
	local search=CreateFrame("EditBox","SlimSuiteSettingsSearch",SS.win,"InputBoxTemplate");
	search:SetWidth(150); search:SetHeight(20); search:SetPoint("TOPRIGHT",SS.win,"TOPRIGHT",-22,-30);
	search:SetAutoFocus(false); search:SetMaxLetters(40);
	search:SetScript("OnTextChanged",function()
		SS.searchText=string.lower(this:GetText() or ""); SS.RelayoutAllPages();
		-- nothing here matches: go to the first page that has something
		local views=SS.settingsViews; local cur=views and SS.currentModule and views[SS.currentModule];
		if SS.searchText~="" and cur and (cur.page.matchCount or 0)==0 then
			for _,id in ipairs(SS.MODULE_ORDER) do if views[id] and (views[id].page.matchCount or 0)>0 then SS.OpenModulePage(id); break; end end
		end
	end);
	SS.AddTip(search,"Search: type a word (hide, clock, boss, size, party...) and every setting about it opens.");
	search:SetScript("OnEscapePressed",function() this:SetText(""); this:ClearFocus(); end);
	-- the search box says what it is; the version sits quietly in the bottom bar
	local searchLabel=SS.win:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); searchLabel:SetPoint("RIGHT",search,"LEFT",-8,0); searchLabel:SetText(SS.T("Search"));
	local version=SS.win:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); version:SetPoint("BOTTOM",SS.win,"BOTTOM",60,18); version:SetText("v"..SS.AddonVersion());
	local hub=CreateFrame("Frame","SlimSuiteModuleHub",SS.win); hub:SetPoint("TOPLEFT",SS.win,"TOPLEFT",14,-34); hub:SetWidth(182); hub:SetHeight(470);
	-- the one primary category: every subcategory below is a part of Slim Suite
	-- (no band: the window's own title already says Slim Suite)
	local title=SS.win:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("TOPLEFT",SS.win,"TOPLEFT",214,-34); title:SetTextColor(1,1,1);
	local rule=SS.win:CreateTexture(nil,"ARTWORK"); rule:SetTexture("Interface\\Buttons\\WHITE8X8"); rule:SetVertexColor(0.5,0.5,0.55,0.8); rule:SetPoint("TOPLEFT",SS.win,"TOPLEFT",214,-58); rule:SetWidth(470); rule:SetHeight(1);
	local closeButton=K.Button(SS.win,"Close",90,function() SS.win:Hide(); end); closeButton:SetPoint("BOTTOMRIGHT",SS.win,"BOTTOMRIGHT",-22,12);
	-- Defaults resets the category on the page; Reset ALL asks first, then wipes the whole addon
	local defaultsButton=K.Button(SS.win,"Defaults",100,function() if SS.currentModule and SS.currentModule~="changelog" then SS.ResetCategory(SS.currentModule); end end); defaultsButton:SetPoint("BOTTOMLEFT",SS.win,"BOTTOMLEFT",22,12);
	local resetAllButton=K.Button(SS.win,"Reset ALL",110,function() SS.ConfirmResetAll(); end); resetAllButton:SetPoint("LEFT",defaultsButton,"RIGHT",8,0); SS.settingsTitle=title;
	SS.moduleHubButtons={}; local views={}; local current; SS.settingsViews=views;
	local undo=K.Button(SS.win,"Undo",70,function() SS.Undo(); end); undo:SetPoint("LEFT",resetAllButton,"RIGHT",16,0);
	local redo=K.Button(SS.win,"Redo",70,function() SS.Redo(); end); redo:SetPoint("LEFT",undo,"RIGHT",6,0);
	SS.undoButton, SS.redoButton = undo, redo;
	SS.AddTip(undo,function() local c=SS.history[SS.historyPos]; return c and (SS.T("Undo")..": "..c.what) or SS.T("Nothing to undo"); end);
	SS.AddTip(redo,function() local c=SS.history[SS.historyPos+1]; return c and (SS.T("Redo")..": "..c.what) or SS.T("Nothing to redo"); end);
	SS.RefreshHistoryButtons();
	local back=K.Button(SS.win,"Back",75,function() SS.OpenModulePage(nil); end); back:SetPoint("TOPLEFT",SS.win,"TOPLEFT",20,-102); back:Hide();
	local master=SS.Check(SS.win,"Module enabled",-100,function() return current and SS.ModuleEnabled(current); end,function(v) if current then SS.SetModuleEnabled(current,v); end end);
	master:ClearAllPoints(); master:SetPoint("TOPLEFT",SS.win,"TOPLEFT",214,-62); master.moduleControl=true; master.label:SetWidth(330); master.label:SetHeight(28);
	local function AddRows(parent, entries, startY, after, module)
		SS.pages = SS.pages or {};
		local page = { parent = parent, rows = {}, startY = startY, after = after, module=module };
		local up = nil;
		local fold = nil;   -- the open/close section the next rows belong to
		local group = nil;  -- the element group (Aethus creations, ...) the next rows belong to
		for i = 1, table.getn(entries) do
			local row = entries[i];
			local before = table.getn(page.rows);
			if ( row.fold ) then
				-- an element's section: its name as a button that opens and closes the settings under it
				local r = { kind = "fold", title = SS.T(row.fold), element = row.element, when = row.when };
				r.sign = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
				r.b = K.Button(parent, "", 204, function()
					if ( not SS.FoldCanOpen(r) ) then return; end
					SS.openFolds = SS.openFolds or {};
					SS.openFolds[r.title] = not SS.openFolds[r.title];
					SS.LayoutPage(page);
				end);
				r.b:SetHeight(22);
				if ( r.b.GetFontString and r.b:GetFontString() ) then r.b:GetFontString():SetJustifyH("LEFT"); end
				-- On, Off and Default for the element itself; its settings open only while it is On
				r.modes = {};
				if ( row.element ) then
					local name, label = row.element, r.title;
					for j, m in ipairs({ { "On", "enabled" }, { "Off", "disabled" }, { "Default", "default" } }) do
						local mode = m[2];
						local mb = K.Button(parent, SS.T(m[1]), 56, function()
							local before = SU.Mode(name);
							SU.SetMode(row.element, mode, SS.ELEMENTS[row.element] and SS.ELEMENTS[row.element].title);
							if ( before ~= mode ) then
								SS.RecordChange(label .. " > On/Off/Default", before, mode, function(v)
									SU.SetMode(name, v, SS.ELEMENTS[name] and SS.ELEMENTS[name].title);
								end);
							end
							-- On does not open the section by itself; Off and Default close it
							if ( mode ~= "enabled" and SS.openFolds ) then SS.openFolds[r.title] = nil; end
							SS.LayoutPage(page);
						end);
						mb:SetHeight(22); mb.mode = mode;
						SS.AddTip(mb, SS.MODE_TIPS[mode](label));
						r.modes[j] = mb;
					end
					local rb = K.Button(parent, SS.T("Reset"), 56, function() SS.ResetElementAll(name, label); SS.LayoutPage(page); end);
					rb:SetHeight(22);
					SS.AddTip(rb, SS.MODE_TIPS.reset(label));
					r.modes[4] = rb;
				end
				table.insert(page.rows, r);
				fold = r; up = nil;
			elseif ( row.head ) then
				fold = nil;
				local fs = parent:CreateFontString(nil, "OVERLAY", row.members and "GameFontNormal" or "GameFontNormalLarge");
				fs:SetText(SS.T(row.head)); fs:SetTextColor(1, 1, 1);
				local r = { kind = "head", fs = fs, label = SS.T(row.head), count = row.count };
				group = nil;
				if ( row.members ) then
					-- one of the element groups: click its name to open or close it; its buttons change every element in it
					group = r;
					local key, label, members = row.count, SS.T(row.head), row.members;
					r.sign = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
					r.click = CreateFrame("Button", nil, parent); r.click:SetWidth(228); r.click:SetHeight(22);
					r.click:SetScript("OnClick", function()
						SS.closedGroups = SS.closedGroups or {};
						SS.closedGroups[key] = not SS.closedGroups[key] or nil;
						SS.LayoutPage(page);
					end);
					SS.AddTip(r.click, function() return string.format(SS.T("Click to open or close %s."), label); end);
					r.groupButtons = {};
					for j, m in ipairs({ { "On", "enabled" }, { "Off", "disabled" }, { "Default", "default" }, { "Reset", "reset" } }) do
						local mode = m[2];
						local gb = K.Button(parent, SS.T(m[1]), 56, function() SS.SetGroupMode(members, mode, label); SS.LayoutPage(page); end);
						gb:SetHeight(22);
						SS.AddTip(gb, function() return string.format(SS.T(SS.GROUP_TIP_TEXT[mode]), label); end);
						r.groupButtons[j] = gb;
					end
				end
				table.insert(page.rows, r);
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
				-- a short label in the list; the full sentence is in the hover text and still found by the search
				local full = label;
				label = row.short or SS.SHORT_LABELS[full] or full;
				-- every change is kept for Undo / Redo and written to the action log
				local get, set = row[2], row[3];
				local what = (fold and fold.title and (fold.title .. " > ") or "") .. label;
				local copy = {}; for k, v in pairs(row) do copy[k] = v; end
				copy[3] = function(v)
					local ok, b = SS.Safe(get); set(v); local ok2, a = SS.Safe(get);
					if ( ok and ok2 and b ~= a and (a or b) ) then SS.RecordChange(what, b, a, set); end
				end;
				row = copy;
				local r = { lead = lead, up = (lead > 0) and up or nil, full = SS.T(full) .. " " .. label };
				if ( row.choice ) then
					r.kind = "choice";
					r.fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
					r.fs:SetText(SS.T(label)); r.fs:SetTextColor(1, 0.82, 0);
					r.b = SS.ChoiceButton(parent, 200);
					r.b.entry = row; r.b:SetPoint("LEFT", r.fs, "RIGHT", 10, 0);
					r.b:SetText(SS.ChoiceText(row));
					r.b:SetScript("OnShow", function() if ( this.entry ) then this:SetText(SS.ChoiceText(this.entry)); end end);
					if ( label ~= full ) then SS.AddTip(r.b, SS.T(full)); end
					if ( lead == 0 ) then up = nil; end
				else
					r.kind = "check";
					r.cb = SS.Check(parent, label, startY, row[2], row[3], lead);
					if ( label ~= full ) then SS.AddTip(r.cb, SS.T(full)); end
					if ( r.cb.label ) then r.cb.label:SetTextColor(1, 0.82, 0); end
					up = row[2];
				end
				if ( row.when ) then r.up = row.when; end
				table.insert(page.rows, r);
			end
			if ( fold and not row.fold ) then
				for j = before + 1, table.getn(page.rows) do page.rows[j].fold = fold; end
			end
			if ( group and not row.head ) then
				for j = before + 1, table.getn(page.rows) do page.rows[j].group = group; end
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
	-- every element's right-click settings, each under its own name that opens and closes
	local function ElementSections()
		local out={};
		-- the setup's order first, then any element it does not list (in the order elements can be moved)
		local order,seen={}, {};
		for _,name in ipairs(SS.SETUP_ORDER or {}) do if not seen[name] then seen[name]=true; table.insert(order,name); end end
		for _,m in ipairs(SS.MOVABLE or {}) do if SS.ELEMENTS[m[1]] and not seen[m[1]] then seen[m[1]]=true; table.insert(order,m[1]); end end
		for name in pairs(SS.ELEMENTS) do if not seen[name] then seen[name]=true; table.insert(order,name); end end
		-- grouped: Aethus creations, my creations, then the default WoW / Blizzard ones (anything unlisted last)
		local groupOf={};
		for _,sec in ipairs(SS.ELEMENT_SECTIONS or {}) do for _,n in ipairs(sec.names or {}) do groupOf[n]=sec.key; end end
		local GROUPS={{"aethus","Aethus creations"},{"custom","My creations"},{"original","Default WoW / Blizzard ideas"},{"other","Other"}};
		local grouped={};
		for _,g in ipairs(GROUPS) do
			local names={};
			for _,name in ipairs(order) do if (groupOf[name] or "other")==g[1] and name~="SlimSuiteEditGrid" and not (SS.STYLE_ONLY and SS.STYLE_ONLY[name]) then table.insert(names,name); end end
			if table.getn(names)>0 then table.insert(grouped,{head=g[2],count=g[1],members=names}); for _,n in ipairs(names) do table.insert(grouped,n); end end
		end
		for _,name in ipairs(grouped) do
			if type(name)=="table" then table.insert(out,name); end
			local element=type(name)=="string" and SS.ELEMENTS[name];
			local ok,checks=SS.Safe(SU.ChecksFor,name);
			if element and name~="SlimSuiteEditGrid" then
				if not ok or type(checks)~="table" then checks={}; end
				table.insert(out,{fold=element.label or element.title or name,element=name,when=SS.ElementListed and SS.ListedCheck(name) or nil});
				for _,e in ipairs(checks) do
					if type(e)=="table" and type(e[1])=="string" and e[2] and e[3] then
						table.insert(out,{e[1],e[2],e[3],choice=e.choice,short=e.short,when=type(e[4])=="function" and e[4] or nil});
					end
				end
			end
		end
		return out;
	end
	local uiEntries={
			{head="Setup"},
			{"HUD Edit Mode (move, resize and turn elements on or off)", function() return SS.DB().unlocked; end, function(v) SS.SetUnlocked(v, true); if ( v ) then SS.OpenHUDEdit(); else SS.CloseHUDEdit(); end end},
			{button = "Demo Mode", onClick = function() SS.ToggleDemoMode(); end},
			{elementSections = true},
			-- settings that join one element into another: turning one on makes an element leave its own place
			{head="Optional combined that hide elements"},
			{"Join the party yourself: your player frame leaves and you become the first party member", function() return SS.DB().partyIncludesSelf; end, function(v) SS.SetPartySelf(v); end},
			{"Mirror Target: the target frame joins your player frame as one mirrored pair", function() return SS.DB().mirrorTarget and SS.DB().combineTarget; end, function(v) SS.SetMirrorTarget(v); end},
			{"Party frames join the player frame (and move with it)", function() return SS.PartyPosition(); end, function(v) SS.SetPartyPosition(v); end,
			 choice={{"No (anywhere)","free"},{"Under the player frame","below"},{"Above the player frame","above"}}},
			{"Buffs leave their own place and join the player frame", function() return SS.BuffsPlace(); end, function(v) SS.SetBuffsPlace(v); end, choice=SS.BUFF_PLACES},
			{"Worn rings / trinkets row joins the build spell row", function() return SS.DB().buildRowsAttached; end, function(v) if ( (v and true or false) ~= (SS.DB().buildRowsAttached and true or false) ) then SS.ToggleBuildRowsAttached(); end end},
			{"Local clock stays inside the minimap (off: its own movable clock)", function() return not SS.DB().clockDetached; end, function(v) SS.SetClockDetached(not v); end, when=function() return SS.DB().replaceLocalClock; end},
			{button = "Profiles & import/export", onClick = function() SS.ShowLayoutWindow(); end},
			{"Keep a separate layout for each character", function() return SS.DB().layoutPerCharacter; end, function(v) SS.SetLayoutPerCharacter(v); end},
			{head="Everywhere"},
			{"Run clock in the compass (run time, next boss, zone)", function() return SS.DB().compassRunClock; end, function(v) SS.DB().compassRunClock = v and true or false; SS.Safe(SS.UpdateCompass); end},
			{"Show green absorb amounts on player and party frames (when the client exposes them)", function() return SS.DB().showAbsorbs; end, function(v) SS.DB().showAbsorbs = v and true or false; SS.Safe(SS.UpdateAbsorbMarkers); end},
			worldEntry,
			{"Build and stats beside card choices",function() return SS.DB().cardEdgeHUD~=false; end,function(v) SS.DB().cardEdgeHUD=v; end},
			{"Show every element above the level-up and new-item cards (each element can still be set on its own)", function() return SS.DB().onTopOfScreens; end, function(v) SS.DB().onTopOfScreens = v; SS.DB().onTop = {}; if ( SlimSuiteWorld ) then SlimSuiteWorld.ApplyOnTop(); end end}
	};
	local otherEntries={
			{"Language (reload UI)", function() return SS.DB().language or "auto"; end,
			 function(v) SS.DB().language = v; end,
			 choice={{"auto","auto"},{"English","enUS"},{"Español","esES"},{"Français","frFR"},{"Deutsch","deDE"},{"Português (Brasil)","ptBR"},{"Italiano","itIT"}} },
			{button="Reload for changes", onClick=function() if ( ReloadUI ) then ReloadUI(); end end},
			{"Panel style (Slim Suite panels)", function() return SS.PanelStyleKey(); end, function(v) SS.SetPanelStyle(v); end,
			 choice={{"Original","original"},{"RPG","meter"},{"New School","tooltip"}}},
			{"Window text size", function() return SS.DB().uiTextScale or 1; end, function(v) SS.SetTextScale(v); end,
			 choice={{"Normal",1},{"Large",1.25},{"Larger",1.5}}},
			{head="Chat mods"},
			{"No level-up stat bonuses in chat", function() return SS.DB().hideLevel;end,function(v) SS.DB().hideLevel=v;end},
			{"No new spell lines in chat", function() return SS.DB().hideNewSpells;end,function(v) SS.DB().hideNewSpells=v;end},
			{"Hide racial buff information in chat", function() return SS.DB().hideRacialInfo;end,function(v) SS.DB().hideRacialInfo=v;end},
			{"Hide the Oogax Q opening line (English game text only)", function() return SS.DB().hideOpeningLine;end,function(v) SS.DB().hideOpeningLine=v;end},
			{"Hide 'Who dares to enter my lair' (English game text only)", function() return SS.DB().hideLairLine;end,function(v) SS.DB().hideLairLine=v;end},
			{"Hide in-game roleplay lines from chat", function() return SS.DB().hideRP;end,function(v) SS.DB().hideRP=v;end},
			{"Hide addon text (Azeroth Stats loaded line)", function() return SS.DB().hideAddonText;end,function(v) SS.DB().hideAddonText=v;end},
			{"Hide location lines ('enters ... Move to begin')", function() return SS.DB().hideLocation;end,function(v) SS.DB().hideLocation=v;end},
			{"Hide difficulty lines (Heroic, Normal)", function() return SS.DB().hideDifficulty;end,function(v) SS.DB().hideDifficulty=v;end},
			{"Hide talent experience lines", function() return SS.DB().hideTalentXP;end,function(v) SS.DB().hideTalentXP=v;end},
			{head="Enemy frames"},
			{"Show native enemy nameplates", function() return SS.NativeEnemyNameplatesEnabled and SS.NativeEnemyNameplatesEnabled(); end, function(v) SS.SetNativeEnemyNameplates(v); end},
			{"Use modern Slim Suite enemy frames", function() return SS.DB().modernEnemyFrames; end, function(v) SS.SetModernEnemyFrames(v); end},
			{"Only show bosses and lair guardians on modern enemy frames", function() return SS.DB().enemyBossesOnly; end, function(v) SS.SetEnemyPlateBossesOnly(v); end},
			{"Group identical monsters into one plate (e.g. Spider x34)", function() return SS.DB().enemyPlateGroup ~= false; end, function(v) SS.DB().enemyPlateGroup = v and true or false; SS.Safe(SS.UpdateEnemyNameplates); end},
			{"Show boss and lair debuffs and remaining time on enemy nameplates (native or modern)", function() return SS.DB().enemyPlateDebuffs; end, function(v) SS.SetEnemyPlateDebuffs(v); end},
			{"Slim nameplates: slim health bar with the name above", function() return SS.DB().platerStyle ~= false; end, function(v) SS.DB().platerStyle = v and true or false; SS.Safe(SS.UpdateEnemyNameplates); end},
			{"Health text under the bar", function() return SS.DB().plateHpText ~= false; end, function(v) SS.DB().plateHpText = v and true or false; SS.Safe(SS.UpdateEnemyNameplates); end},
			{"Black border around the bar", function() return SS.DB().plateBorder ~= false; end, function(v) SS.DB().plateBorder = v and true or false; SS.Safe(SS.UpdateEnemyNameplates); end},
			{"Plate width", function() return SS.DB().plateWidth or 110; end, function(v) SS.DB().plateWidth = v; SS.Safe(SS.UpdateEnemyNameplates); end,
			 choice={{"Narrow",90},{"Normal",110},{"Wide",140}}},
			{"Bar height", function() return SS.DB().plateBarHeight or 7; end, function(v) SS.DB().plateBarHeight = v; SS.Safe(SS.UpdateEnemyNameplates); end,
			 choice={{"Thin",5},{"Normal",7},{"Thick",10}}},
			{"Name size", function() return SS.DB().plateNameSize or "normal"; end, function(v) SS.DB().plateNameSize = v; SS.Safe(SS.UpdateEnemyNameplates); end,
			 choice={{"Small","small"},{"Normal","normal"},{"Large","large"}}},
			{"Normal enemy colour", function() return SS.DB().plateColorEnemy or "Red"; end, function(v) SS.DB().plateColorEnemy = v; SS.Safe(SS.UpdateEnemyNameplates); end,
			 choice={{"Red","Red"},{"Gold","Gold"},{"Purple","Purple"},{"Green","Green"},{"Blue","Blue"},{"White","White"}}},
			{"Elite colour", function() return SS.DB().plateColorElite or "Gold"; end, function(v) SS.DB().plateColorElite = v; SS.Safe(SS.UpdateEnemyNameplates); end,
			 choice={{"Red","Red"},{"Gold","Gold"},{"Purple","Purple"},{"Green","Green"},{"Blue","Blue"},{"White","White"}}},
			{"Boss colour", function() return SS.DB().plateColorBoss or "Purple"; end, function(v) SS.DB().plateColorBoss = v; SS.Safe(SS.UpdateEnemyNameplates); end,
			 choice={{"Red","Red"},{"Gold","Gold"},{"Purple","Purple"},{"Green","Green"},{"Blue","Blue"},{"White","White"}}},
			{head="Camera and marks"},
			{"Camera zoom (off gives the game's own camera)", function() return SS.DB().camera; end, function(v) SS.DB().camera = v and true or false; SS.Camera(v); end},
			{"Camera distance", function() return SS.CameraDistance(); end, function(v) SS.SetCameraDistance(v); end,
			 choice={{"Close (15)",15},{"Medium (30)",30},{"Far (40)",40},{"Max (50)",50}}},
			{"Mark pulled bosses and Guardians (Skull, X, Circle, Star)", function() return SS.DB().bossMarks; end, function(v) SS.DB().bossMarks = v; end},
			{"   ...and Guardians and lairs before they're pulled", function() return SS.DB().prePullMarks; end, function(v) SS.DB().prePullMarks = v; end},
			{"Raid-mark row when the mouse is over a party member (in a group)", function() return SS.DB().raidRow; end, function(v) SS.DB().raidRow = v and true or false; end},
			{head="Minimap"},
			-- (the minimap's own settings live in its element section and its right-click menu)
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
			{"Teammate revive sound (when you helped revive them)",group="revive",sounds={{"Off","off"},{"Successful revive","reviveSuccess"}}},
			{"Cooldown numbers on the spell squares", function() return SS.DB().cooldowns; end, function(v) SS.DB().cooldowns = v; end},
			{head="Accessibility"},
			{"High-contrast encounter bars", function() return SS.DB().accessibilityContrast; end, function(v) SS.DB().accessibilityContrast = v and true or false; SS.Safe(SS.UpdateBossFrames); end},
			{"Larger encounter names", function() return SS.DB().accessibilityLargeText; end, function(v) SS.DB().accessibilityLargeText = v and true or false; SS.Safe(SS.UpdateBossFrames); end},
			{"Reduce floating combat-text motion", function() return SS.DB().accessibilityReduceMotion; end, function(v) SS.DB().accessibilityReduceMotion = v and true or false; end},
	};
	if SS.AchievementsAvailable() then local achievements=K.Button(hub,SS.T("Side achievements"),170,function() SS.OpenAchievements(); end); achievements:SetPoint("TOPLEFT",hub,"TOPLEFT",4,-300); end;
	local entries={chat={},sounds={},ui={},gameplay={},misc={},nameplates={}};

	for _,row in ipairs(uiEntries) do
		if row.elementSections then
			table.insert(entries.ui,{head="Elements"});
			for _,r in ipairs(ElementSections()) do table.insert(entries.ui,r); end
		else table.insert(entries[row==worldEntry and "gameplay" or "ui"],row); end
	end
	local category="misc";
	for _,row in ipairs(otherEntries) do
		if row.head then
			category=({["Chat mods"]="chat",["Enemy frames"]="nameplates",["Camera and marks"]="gameplay",["Minimap"]="ui",["Deaths and spells"]="sounds",["Accessibility"]="misc"})[row.head] or "misc";
		end
		local destination=category; local label=row[1];
		if label=="Mark where a downed friend can be revived" or label=="Show caches on the minimap" or label=="Show bosses on the minimap" or label=="Show lairs on the minimap, with their 3:00 refill timer" or label=="Show the game's nearest Guardian lair flag on minimap" then destination="gameplay";
		elseif label=="Minimap button" then destination="misc";
		elseif label=="Cooldown numbers on the spell squares" then destination="ui"; end
		table.insert(entries[destination],row);
	end
	table.insert(entries.gameplay,{"Hide the Bag button", function() return SS.DB().hideBagButton; end, function(v) SS.DB().hideBagButton = v and true or false; SS.ApplyBagMapButtons(); end});
	table.insert(entries.gameplay,{"Hide the Map button on the minimap", function() return SS.DB().hideMapButton; end, function(v) SS.DB().hideMapButton = v and true or false; SS.ApplyBagMapButtons(); end});
	if SS.AchievementsAvailable() then 
	table.insert(entries.gameplay,{button="Side achievements",onClick=function() SS.OpenAchievements(); end}); end;
	table.insert(entries.ui,{button="Reset positions",onClick=function() SS.ResetPlaces(); end});
	table.insert(entries.ui,{button="Reset all UI",onClick=function() SS.ResetUI(); end});
	for i,id in ipairs(SS.MODULE_ORDER) do
		local module=id;
		local open=K.Button(hub,SS.T(SS.MODULE_TITLES[id]),170,function() SS.OpenModulePage(module); end);
		open:SetHeight(34); open:SetPoint("TOPLEFT",hub,"TOPLEFT",4,-(i-1)*40); SS.sidebarButtons=SS.sidebarButtons or {}; SS.sidebarButtons[id]=open;
		SU.Flatten(open);
		-- the on/off switch for each module is the Module enabled line at the top of its page
		local toggle=K.Button(hub,"",10,function() SS.SetModuleEnabled(module,not SS.ModuleEnabled(module)); end);
		toggle:Hide(); SS.moduleHubButtons[id]=toggle;
		local scroll,child=K.Scroll("SlimSuiteModule_"..id,SS.win,480);
		scroll:SetPoint("TOPLEFT",SS.win,"TOPLEFT",214,-70); scroll:SetPoint("BOTTOMRIGHT",SS.win,"BOTTOMRIGHT",-22,34);
		local page=AddRows(child,entries[id],-8,nil,id); views[id]={scroll=scroll,page=page};
	end
	-- Changelog, under Accessibility: every release, newest first, read only
	do
		local n=table.getn(SS.MODULE_ORDER)+1;
		local open=K.Button(hub,SS.T("Changelog"),170,function() SS.OpenModulePage("changelog"); end);
		open:SetHeight(34); open:SetPoint("TOPLEFT",hub,"TOPLEFT",4,-(n-1)*40); SS.sidebarButtons.changelog=open; SU.Flatten(open);
		local scroll,child=K.Scroll("SlimSuiteModule_changelog",SS.win,480);
		scroll:SetPoint("TOPLEFT",SS.win,"TOPLEFT",214,-70); scroll:SetPoint("BOTTOMRIGHT",SS.win,"BOTTOMRIGHT",-22,34);
		local page={rows={},parent=child,matchCount=0};
		local y=-8;
		for _,s in ipairs(SS.CHANGELOG or {}) do
			local fs=child:CreateFontString(nil,"OVERLAY","GameFontHighlight"); fs:SetJustifyH("LEFT");
			local parts={"|cffffd100"..s.v.."|r"};
			if s.summary~="" then table.insert(parts,s.summary); end
			for _,item in ipairs(s.items) do table.insert(parts,"|cffffd100-|r "..item); end
			fs:SetText(table.concat(parts,"\n"));
			fs:SetPoint("TOPLEFT",child,"TOPLEFT",8,y);
			y=y-SS.WrappedLabelHeight(fs,440)-14;
			table.insert(page.rows,{kind="text",fs=fs});
		end
		child:SetHeight(math.max(20,-y+12));
		scroll:Hide(); views.changelog={scroll=scroll,page=page};
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
		-- the sidebar is always there; the chosen module's page fills the right side under its title
		if ( not id or not views[id] ) then id = SS.MODULE_ORDER[1]; end
		current=id; SS.currentModule=id;
		for _,view in pairs(views) do view.scroll:Hide(); end
		hub:Show(); back:Hide(); views[id].scroll:Show();
		title:SetText(SS.T(SS.MODULE_TITLES[id]));
		master:Hide(); master.label:Hide();   -- the page on/off switch is retired: every element has its own On / Off
		for sid, b2 in pairs(SS.sidebarButtons or {}) do SU.PaintFlat(b2, sid == id, {1, 0.82, 0.2}); end
		SS.RefreshToggles(); SS.RefreshModuleHub();
	end;
	SS.win:SetScript("OnShow",function() SS.OpenModulePage(nil); end);
	SS.OpenModulePage(nil);
end

function SS.Toggle()
	if ( not SS.win ) then
		local ok, err = SS.Safe(SS.WinBuild);
		if ( not ok ) then K.Print(NAME, "|cffff4040the settings window could not be made:|r " .. tostring(err)); SS.win = nil; return; end
	end
	if ( SS.win:IsShown() ) then SS.win:Hide(); else SS.win:Show(); end
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
	"Getting started: /slim opens the settings. Under Interface > Elements each element has On, Off, Default and Reset; the + next to its name opens its settings.",
	"Type a word in the search box at the top (hide, clock, boss, size, party...) and every setting about it opens.",
	"In HUD Edit Mode, right-click any element and choose Open in settings to jump straight to it.",
	"Undo and Redo at the bottom of the settings (or /slim undo, /slim redo) step through your last 25 changes. /slim log shows every change.",
	"/slim: the settings window.  /slim edit: move and size the UI (/slim lock when done).  /slim setup: the guided setup.",
	"/slim demo: Demo Mode on or off.  /slim levelup: Slim Suite's Level Up button or the game's own.",
	"/slim positions: write where every element sits (position, size, scale) to the action log.",
	"/slim layout: manage named profiles and import/export layouts.  /slim layout save <name>, load <name>, delete <name>, list.",
	"/slim hud: recommended positions for this display.",
	"/slim reset places, /slim reset all: back to where everything started.",
	"/slim camera: the distance now. /slim camera <yards>, +, -, <preset>, save <name> [yards], delete <name>, list, on, off.",
	"/slim hide <words>, /slim unhide <words>, /slim hide: chat lines with those words.",
	"/slim perf: measures what each part of Slim Suite costs for 10 seconds (or /slim perf <seconds>) and lists the busiest.",
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
	if ( cmd == "perf" ) then SS.StartPerf(tonumber(rest) or 10);
	elseif ( cmd == "undo" ) then SS.Undo();
	elseif ( cmd == "redo" ) then SS.Redo();
	elseif ( cmd == "help" or cmd == "?" ) then
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
	elseif ( cmd == "log" ) then
		SS.ShowActionLog();
	elseif ( cmd == "framesize" ) then
		-- measures the game's own player and target frames, to build matching ones: size, and where the parts sit
		for _, name in ipairs({ "PlayerFrame", "TargetFrame" }) do
			local f = getglobal(name);
			if ( f ) then
				local w, h = f:GetWidth() or 0, f:GetHeight() or 0;
				local scale = f:GetScale() or 1;
				SS.LogAction(name .. ": " .. math.floor(w + 0.5) .. " x " .. math.floor(h + 0.5) .. " at scale " .. scale);
				for _, part in ipairs({ "Portrait", "HealthBar", "ManaBar", "Name", "HealthBarText", "ManaBarText", "Texture" }) do
					local p = getglobal(name .. part);
					if ( p and p.GetLeft and p:GetLeft() ) then
						local pw, ph = p:GetWidth() or 0, p:GetHeight() or 0;
						local left = (p:GetLeft() or 0) - (f:GetLeft() or 0);
						local top = (f:GetTop() or 0) - (p:GetTop() or 0);
						SS.LogAction("  " .. part .. ": " .. math.floor(pw + 0.5) .. " x " .. math.floor(ph + 0.5) .. ", " .. math.floor(left + 0.5) .. " from left, " .. math.floor(top + 0.5) .. " from top");
					end
				end
			end
		end
		K.Print(NAME, "frame sizes are in the action log: /slimsuite log");
	elseif ( cmd == "positions" or cmd == "where" ) then
		-- where every element is on screen, to copy a layout: left and bottom edges, size and scale, in screen units
		SS.LogAction("Element positions (left, bottom, width x height, scale; screen " .. math.floor((UIParent:GetWidth() or 0) + 0.5) .. " x " .. math.floor((UIParent:GetHeight() or 0) + 0.5) .. "):");
		for _, m in ipairs(SS.MOVABLE) do
			local name = SS.Shown and SS.Shown(m[1]) or m[1];
			local f = getglobal(name);
			if ( f and f.GetLeft and f:GetLeft() and f.IsShown and f:IsShown() ) then
				local s = (f.GetEffectiveScale and f:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1);
				SS.LogAction(string.format("  %s (%s): %d, %d, %d x %d, scale %.2f", m[2], name, f:GetLeft() * s, f:GetBottom() * s,
					(f:GetWidth() or 0) * s, (f:GetHeight() or 0) * s, f:GetScale() or 1));
			end
		end
		K.Print(NAME, "element positions are in the action log: /slimsuite log");
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
	elseif ( cmd == "camera" ) then SS.CameraCommand(msg and string.sub(msg, 7) or "");
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

-- /slim camera: the distance, a number of yards, +/- steps of 5, a named preset, or saving and deleting presets.
function SS.CameraCommand(text)
	local d = SS.DB();
	local _, _, word, arg = string.find(string.lower(text or ""), "^%s*(%S*)%s*(.-)%s*$");
	word = word or "";
	if ( word == "" ) then
		K.Print(NAME, "camera distance is " .. SS.CameraDistance() .. " yards (zoom " .. (d.camera and "on" or "off") .. ").");
		K.Print(NAME, "/slim camera <yards>, +, -, <preset>, save <name> [yards], delete <name>, list, on, off.");
	elseif ( word == "off" ) then d.camera = false; SS.Camera(false); K.Print(NAME, "camera zoom is the game's own.");
	elseif ( word == "on" ) then SS.SetCameraDistance(SS.CameraDistance()); K.Print(NAME, "camera zoom is on at " .. SS.CameraDistance() .. " yards.");
	elseif ( word == "+" or word == "-" ) then
		SS.SetCameraDistance(SS.CameraDistance() + (word == "+" and 5 or -5));
		K.Print(NAME, "camera distance is " .. SS.CameraDistance() .. " yards.");
	elseif ( tonumber(word) ) then
		local v = SS.SetCameraDistance(tonumber(word));
		K.Print(NAME, "camera distance is " .. v .. " yards" .. (v ~= tonumber(word) and " (the range is " .. SS.CAMERA_MIN .. " to 50)" or "") .. ".");
	elseif ( word == "list" ) then
		local names = {};
		for k, v in pairs(SS.CameraPresets()) do table.insert(names, k .. " " .. v); end
		table.sort(names);
		K.Print(NAME, "camera presets: " .. table.concat(names, ", ") .. ".");
	elseif ( word == "save" ) then
		local _, _, name, yards = string.find(arg or "", "^(%a[%w_]*)%s*(%d*)$");
		if ( not name ) then K.Print(NAME, "usage: /slim camera save <name> [yards]. Names start with a letter."); return; end
		d.cameraPresets = d.cameraPresets or {};
		local v = tonumber(yards) or SS.CameraDistance();
		if ( v < SS.CAMERA_MIN ) then v = SS.CAMERA_MIN; elseif ( v > 50 ) then v = 50; end
		d.cameraPresets[name] = v;
		K.Print(NAME, "saved camera preset \"" .. name .. "\" at " .. v .. " yards.");
	elseif ( word == "delete" ) then
		local name = string.gsub(arg or "", "%s", "");
		if ( d.cameraPresets and d.cameraPresets[name] ) then d.cameraPresets[name] = nil; K.Print(NAME, "deleted camera preset \"" .. name .. "\".");
		else K.Print(NAME, "no saved camera preset called \"" .. name .. "\"."); end
	else
		local p = SS.CameraPresets()[word];
		if ( not p ) then K.Print(NAME, "no camera preset called \"" .. word .. "\". /slim camera list shows them."); return; end
		SS.SetCameraDistance(p);
		K.Print(NAME, "camera distance is " .. p .. " yards.");
	end
end

-- ---------------------------------------------------------------- defaults for each category, and Reset ALL
-- The keys each category owns. Sounds are every default whose name mentions a sound; the rest are listed here.
function SS.CategoryKeys(id)
	local set = {};
	local function add(list) for _, key in ipairs(list) do set[key] = true; end end
	if ( id == "ui" ) then
		add({ "cooldowns", "minimapBar", "minimapCaches", "minimapBosses", "minimapLairs", "minimapTransparent", "minimapSquare",
		      "compassOn", "compassRunClock", "compassBosses", "compassCaches", "compassLairs", "compassStyle",
		      "uiStyle", "uiTextScale", "styleOverrides", "zoneLine", "onTopOfScreens", "showGuardianFlag" });
	elseif ( id == "nameplates" ) then
		add({ "modernEnemyFrames", "enemyBossesOnly", "enemyPlateDebuffs", "enemyPlateGroup", "platerStyle", "plateWidth",
		      "plateBarHeight", "plateNameSize", "plateHpText", "plateBorder", "plateColorEnemy", "plateColorElite", "plateColorBoss" });
	elseif ( id == "chat" ) then
		add({ "hideLevel", "hideNewSpells", "hideRacialInfo", "hideOpeningLine", "hideLairLine", "hideRP", "hideAddonText",
		      "hideLocation", "hideDifficulty", "hideTalentXP" });
	elseif ( id == "sounds" ) then
		for key in pairs(SS.DEFAULTS) do if ( string.find(key, "Sound", 1, true) ) then set[key] = true; end end
		set.teammateDeathSound = true;
	elseif ( id == "gameplay" or id == "misc" ) then
		add(SS.MODULE_KEYS[id] or {});
	end
	local out = {};
	for key in pairs(set) do table.insert(out, key); end
	return out;
end

-- Puts one category back to the defaults; nothing else moves.
function SS.ResetCategory(id)
	local d = SS.DB();
	local keys = SS.CategoryKeys(id);
	for _, key in ipairs(keys) do
		local v = SS.DEFAULTS[key];
		if ( type(v) == "table" ) then d[key] = SS.CopyTable(v); else d[key] = v; end
	end
	if ( id == "ui" ) then d.styleOverrides = {}; end
	if ( id == "chat" or id == "nameplates" or id == "gameplay" or id == "misc" or id == "sounds" ) then
		if ( d.modules ) then d.modules[id] = nil; end
	end
	if ( SS.MarkProfileDirty ) then SS.MarkProfileDirty(); end
	SS.Safe(SS.UpdateEnemyNameplates);
	SS.Safe(SS.Camera, false);
	if ( SS.RefreshLooks ) then SS.Safe(SS.RefreshLooks); end
	if ( SS.RefreshToggles ) then SS.RefreshToggles(); end
	if ( SS.RelayoutAllPages ) then SS.RelayoutAllPages(); end
	if ( SS.RefreshModuleHub ) then SS.RefreshModuleHub(); end
	K.Print(NAME, (SS.MODULE_TITLES[id] or id) .. " is back to its defaults.");
end

-- Asks before wiping everything. Only a confirmed Reset ALL does anything.
function SS.ConfirmResetAll()
	if ( not StaticPopupDialogs or not StaticPopup_Show ) then K.Print(NAME, "Reset ALL needs the game's confirmation window, which is not available here."); return; end
	StaticPopupDialogs["SLIMSUITE_RESET_ALL"] = {
		text = "Reset ALL of Slim Suite to its defaults? This clears every setting, element position, size, look, preset and saved layout, then reloads the UI. It cannot be undone.",
		button1 = YES or "Yes", button2 = NO or "No", timeout = 0, whileDead = 1, hideOnEscape = 1,
		OnAccept = function() SS.ResetEverything(); end };
	StaticPopup_Show("SLIMSUITE_RESET_ALL");
end

-- Wipes the saved settings and rebuilds them from the defaults, then reloads so the game's frames go back too.
function SS.ResetEverything()
	SlimSuiteDB = {};
	SS.preparedDB = nil;
	SS.DB();
	if ( ReloadUI ) then ReloadUI(); end
end


-- ---------------------------------------------------------------- hover text, short labels, undo / redo, warnings
function SS.AddTip(w, text)
	if ( not w or not w.SetScript ) then return; end
	local enter, leave = w:GetScript("OnEnter"), w:GetScript("OnLeave");
	w:SetScript("OnEnter", function()
		if ( enter ) then enter(); end
		local t = text; if ( type(t) == "function" ) then t = t(); end
		if ( t and GameTooltip ) then GameTooltip:SetOwner(this, "ANCHOR_RIGHT"); GameTooltip:SetText(SS.T(t), 1, 1, 1, 1, 1); GameTooltip:Show(); end
	end);
	w:SetScript("OnLeave", function() if ( leave ) then leave(); end if ( GameTooltip ) then GameTooltip:Hide(); end end);
end
-- each says what the button does to the named element (%s), so the whole sentence can be translated
SS.MODE_TIP_TEXT = {
	enabled = "On: use Slim Suite's %s. Its settings open with the + next to its name.",
	disabled = "Off: hide %s completely.",
	default = "Default: give %s back to the game, as it looks without Slim Suite.",
	reset = "Reset: put %s back where it started: its place, size, opacity and cards setting (Undo brings it back).",
};
SS.MODE_TIPS = {};
for key, text in pairs(SS.MODE_TIP_TEXT) do
	local sentence = text;
	SS.MODE_TIPS[key] = function(n) return string.format(SS.T(sentence), n); end;
end
SS.SHORT_LABELS = {
	["Buffs leave their own place and join the player frame"] = "Buffs join the player frame",
	["Group identical monsters into one plate (e.g. Spider x34)"] = "Group identical monsters",
	["HUD Edit Mode (move, resize and turn elements on or off)"] = "HUD Edit Mode",
	["Hide 'Who dares to enter my lair' (English game text only)"] = "Hide the lair greeting",
	["Hide the Oogax Q opening line (English game text only)"] = "Hide Oogax's opening line",
	["Hide the bar's artwork (only the spell squares stay)"] = "Hide the bar's artwork",
	["Join the party yourself: your player frame leaves and you become the first party member"] = "Join the party yourself",
	["Local clock stays inside the minimap (off: its own movable clock)"] = "Clock inside the minimap",
	["Mark pulled bosses and Guardians (Skull, X, Circle, Star)"] = "Mark pulled bosses",
	["Mirror Target: the target frame joins your player frame as one mirrored pair"] = "Mirror Target",
	["Only show bosses and lair guardians on modern enemy frames"] = "Modern frames: bosses only",
	["Party frames join the player frame (and move with it)"] = "Party joins the player frame",
	["Slim nameplates: slim health bar with the name above"] = "Slim nameplates",
	["Raid-mark row when the mouse is over a party member (in a group)"] = "Raid marks on party hover",
	["Run clock at the bottom of the compass (run time, next boss, zone)"] = "Run clock under the compass",
	["Run clock in the compass (run time, next boss, zone)"] = "Run clock in the compass",
	["Separate the local clock from the minimap (use Slim Suite's own)"] = "Separate local clock",
	["Show boss and lair debuffs and remaining time on enemy nameplates (native or modern)"] = "Boss debuffs on nameplates",
	["Show every element above the level-up and new-item cards (each element can still be set on its own)"] = "Everything over the level-up cards",
	["Show green absorb amounts on player and party frames (when the client exposes them)"] = "Absorb amounts",
	["Show lairs on the minimap, with their 3:00 refill timer"] = "Lairs and refill timer",
	["Show the game's nearest Guardian lair flag on minimap"] = "Guardian lair flag",
	["Teammate revive sound (when you helped revive them)"] = "Teammate revive sound",
	["Worn rings / trinkets row joins the build spell row"] = "Rings / trinkets join spells",
	["Show over the level-up / new-item cards"] = "Over the level-up cards",
};

-- the last 25 changes, each with the value before and after; the action log keeps the full trail
SS.HISTORY_MAX = 25; SS.history = {}; SS.historyPos = 0;
local function Said(v)
	if ( v == nil ) then return "default"; elseif ( v == true ) then return "on"; elseif ( v == false ) then return "off";
	elseif ( type(v) == "table" ) then return "saved values"; end
	return tostring(v);
end
function SS.RefreshHistoryButtons()
	local u, r = SS.undoButton, SS.redoButton;
	if ( u ) then if ( SS.historyPos > 0 ) then u:Enable(); else u:Disable(); end end
	if ( r ) then if ( SS.history[SS.historyPos + 1] ) then r:Enable(); else r:Disable(); end end
end
function SS.RecordChange(what, before, after, apply)
	if ( SS.replaying ) then return; end
	while ( table.getn(SS.history) > SS.historyPos ) do table.remove(SS.history); end
	table.insert(SS.history, { what = what, before = before, after = after, apply = apply });
	while ( table.getn(SS.history) > SS.HISTORY_MAX ) do table.remove(SS.history, 1); end
	SS.historyPos = table.getn(SS.history);
	if ( SS.LogAction ) then SS.LogAction("[change] " .. what .. ": " .. Said(before) .. " -> " .. Said(after)); end
	SS.RefreshHistoryButtons();
	SS.Safe(SS.CheckWarnings);
end
local function Replay(c, value, word)
	SS.replaying = true; SS.Safe(c.apply, value); SS.replaying = nil;
	if ( SS.LogAction ) then SS.LogAction("[" .. word .. "] " .. c.what .. ": back to " .. Said(value)); end
	K.Print(NAME, SS.T(word) .. ": " .. c.what .. " (" .. Said(value) .. ")");
	SS.RefreshHistoryButtons(); SS.RelayoutAllPages();
	if ( SS.RefreshToggles ) then SS.Safe(SS.RefreshToggles); end
	SS.Safe(SS.CheckWarnings);
end
function SS.Undo()
	local c = SS.history[SS.historyPos];
	if ( not c ) then K.Print(NAME, SS.T("nothing to undo.")); return; end
	SS.historyPos = SS.historyPos - 1; Replay(c, c.before, "Undo");
end
function SS.Redo()
	local c = SS.history[SS.historyPos + 1];
	if ( not c ) then K.Print(NAME, SS.T("nothing to redo.")); return; end
	SS.historyPos = SS.historyPos + 1; Replay(c, c.after, "Redo");
end

-- Reset an element: its place, size, scale, padding, layout, opacity and over-the-cards choice. Undo puts them back.
local RESET_TABLES = { "places", "sizes", "scales", "padding", "orientations", "opacity", "onTop" };
local function Copy(v) if ( type(v) ~= "table" ) then return v; end local t = {}; for k, x in pairs(v) do t[k] = Copy(x); end return t; end
local function Snapshot(name)
	local d, snap = SS.DB(), {};
	for _, key in ipairs(RESET_TABLES) do snap[key] = d[key] and Copy(d[key][name]); end
	return snap;
end
local function Restore(name, snap)
	local d = SS.DB();
	for _, key in ipairs(RESET_TABLES) do d[key] = d[key] or {}; d[key][name] = Copy(snap[key]); end
	SS.Safe(SS.Place, name); SS.Safe(SS.ApplySize, name, getglobal(name));
	if ( SS.lastOpacity ) then SS.lastOpacity[name] = true; end
	if ( SlimSuiteWorld and SlimSuiteWorld.ApplyOnTop ) then SS.Safe(SlimSuiteWorld.ApplyOnTop); end
end
function SS.ResetElementAll(name, label)
	local before = Snapshot(name);
	SS.Safe(SS.ResetElement, name);
	local d = SS.DB();
	if ( d.opacity ) then d.opacity[name] = nil; end
	if ( d.onTop ) then d.onTop[name] = nil; end
	if ( SS.lastOpacity ) then SS.lastOpacity[name] = true; end
	if ( SlimSuiteWorld and SlimSuiteWorld.ApplyOnTop ) then SS.Safe(SlimSuiteWorld.ApplyOnTop); end
	SS.RecordChange((label or name) .. " > Reset", before, Snapshot(name), function(snap) Restore(name, snap); end);
end

-- A whole group at once (the buttons on Aethus creations, My creations, ...): one entry in Undo / Redo for all of it
SS.GROUP_TIP_TEXT = {
	enabled = "On: turn on every element in %s.",
	disabled = "Off: hide every element in %s.",
	default = "Default: give every element in %s back to the game.",
	reset = "Reset: put every element in %s back where it started (Undo brings them back).",
};
function SS.SetGroupMode(members, mode, label)
	local before, after = {}, {};
	SS.replaying = true;    -- the single entry below stands for all of them
	for _, name in ipairs(members) do
		if ( mode == "reset" ) then
			before[name] = Snapshot(name);
			SS.Safe(SS.ResetElementAll, name, name);
			after[name] = Snapshot(name);
		else
			before[name] = SU.Mode(name);
			if ( before[name] ~= mode ) then SS.Safe(SU.SetMode, name, mode, SS.ELEMENTS[name] and SS.ELEMENTS[name].title); end
			after[name] = mode;
		end
	end
	SS.replaying = nil;
	local apply;
	if ( mode == "reset" ) then
		apply = function(map) for name, snap in pairs(map) do Restore(name, snap); end end;
	else
		apply = function(map) for name, m in pairs(map) do if ( SU.Mode(name) ~= m ) then SS.Safe(SU.SetMode, name, m, SS.ELEMENTS[name] and SS.ELEMENTS[name].title); end end end;
	end
	SS.RecordChange(label .. " > " .. (mode == "reset" and "Reset all" or ("All " .. mode)), before, after, apply);
end

-- Warnings for settings that undo each other, said once each time they become true
local warned = {};
function SS.CheckWarnings()
	local d, list = SS.DB(), {};
	local function Title(n) local e = SS.ELEMENTS and SS.ELEMENTS[n]; return e and (e.label or e.title) or n; end
	for name in pairs(SS.ELEMENTS or {}) do
		if ( SU.Mode(name) == "enabled" and SS.ElementOpacity and SS.ElementOpacity(name) == 0 ) then
			list["opacity" .. name] = string.format(SS.T("%s is On but at 0%% opacity, so it can't be seen."), SS.T(Title(name)));
		end
	end
	if ( d.partyIncludesSelf and SU.Mode("PartyMemberFrame1") == "disabled" ) then
		list.partyself = "Join the party yourself is on, but the party frames are Off, so your player frame has nowhere to go.";
	end
	if ( d.mirrorTarget and d.combineTarget and SU.Mode("PlayerFrame") == "disabled" ) then
		list.mirror = "Mirror Target joins the target frame to your player frame, but the player frame is Off.";
	end
	if ( SS.PartyPosition and SS.PartyPosition() ~= "free" and SU.Mode("PlayerFrame") == "disabled" ) then
		list.partyjoin = "The party frames are joined to the player frame, but the player frame is Off.";
	end
	if ( d.replaceLocalClock and not d.clockDetached and SU.Mode("MinimapCluster") == "disabled" ) then
		list.clock = "The local clock sits inside the minimap, and the minimap is Off, so the clock is hidden too.";
	end
	for key, text in pairs(list) do
		if ( not warned[key] ) then
			K.Print(NAME, "|cffffd000" .. SS.T("Heads up") .. ":|r " .. (string.find(key, "^opacity") and text or SS.T(text)));
			if ( SS.LogAction ) then SS.LogAction("[warning] " .. text); end
		end
	end
	warned = list;
end

-- Right-click > Open in settings: the settings open on the element's section, opened, scrolled to and flashing
function SS.OpenElementSettings(name)
	name = SS.Element and SS.Element(name) or name;
	if ( not (SS.ELEMENTS and SS.ELEMENTS[name]) ) then return false; end
	local w = getglobal("SlimSuiteFrame");
	if ( not (w and w:IsShown()) ) then SS.Toggle(); end
	if ( SS.OpenModulePage ) then SS.OpenModulePage("ui"); end
	local view = SS.settingsViews and SS.settingsViews.ui;
	if ( not view ) then return false; end
	local row;
	for _, r in ipairs(view.page.rows) do if ( r.kind == "fold" and r.element == name ) then row = r; break; end end
	if ( not row ) then return false; end
	if ( SU.Mode(name) == "enabled" ) then SS.openFolds = SS.openFolds or {}; SS.openFolds[row.title] = true; end
	SS.LayoutPage(view.page);
	SS.Safe(function()
		if ( view.scroll.UpdateScrollChildRect ) then view.scroll:UpdateScrollChildRect(); end
		local most = view.scroll.GetVerticalScrollRange and view.scroll:GetVerticalScrollRange() or 0;
		view.scroll:SetVerticalScroll(math.max(0, math.min(most, -(row.y or 0) - 30)));
	end);
	local untilTime, lit = GetTime() + 3, false;
	SS.Every("settingsFlash", 0.25, function()
		if ( GetTime() > untilTime ) then row.b:UnlockHighlight(); SS.Stop("settingsFlash"); return; end
		lit = not lit; if ( lit ) then row.b:LockHighlight(); else row.b:UnlockHighlight(); end
	end);
	return true;
end

-- the first time Slim Suite loads, one line points to /slim help
local tipFrame = CreateFrame("Frame");
tipFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
tipFrame:SetScript("OnEvent", function()
	local d = SS.DB();
	if ( d and not d.seenHelpTip ) then
		d.seenHelpTip = true;
		K.Print(NAME, SS.T("New to Slim Suite? Type /slim help for a quick start, or /slim to open the settings."));
	end
end);
