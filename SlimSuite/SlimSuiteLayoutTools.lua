-- Slim Suite: row or column layouts, the chat dock, the detached XP bar and the joined build rows.
local K, SU, NAME = SS.Kit, SS.SU, SS.NAME;   -- the three names every Slim Suite file uses (SlimSuiteCore.lua)

function SS.ToggleMovableOrientation(name)
	if ( name == "SlimSuiteItemRowFrame" or name == "SlimSuiteSpellRowFrame" ) then
		SS.SetBuildOrientation(name, SS.CurrentOrientation(name) ~= "vertical");
		return;
	end
	if ( name == "SlimSuiteTallyFrame" ) then
		SS.DB().tallyVertical = not SS.DB().tallyVertical;
		SS.ApplyTallyLayout(true);
		return;
	end
	local nextOrientation = SS.CurrentOrientation(name) == "vertical" and "horizontal" or "vertical";
	SS.DB().orientations[name] = nextOrientation;
	if ( name == "SlimSuiteClockFrame" ) then
		local w, h = nextOrientation == "vertical" and 220 or 360, nextOrientation == "vertical" and 54 or 32;
		SS.clockFrame:SetWidth(w); SS.clockFrame:SetHeight(h);
		SS.DB().sizes[name] = { w = w, h = h };
		SS.ApplyClockLayout();
		SS.PlaceAll();
		SS.UpdateClock();
		return;
	end
	if ( name == "BuffFrame" ) then SS.DB().buffCustomLayout = true; end
	if ( name == "SlimSuiteBossFrames" ) then SS.DB().sizes[name] = nil; end

	if ( name == "MainMenuExpBar" or name == "MainMenuBar" ) then
		local f = getglobal(name);
		if ( f ) then
			-- Rotate the current dimensions, including a user's custom length. Using only the
			-- Blizzard base size here discards resizing and leaves a horizontal footprint behind.
			local saved = SS.DB().sizes[name];
			local w = type(saved) == "table" and saved.w or f:GetWidth();
			local h = type(saved) == "table" and saved.h or f:GetHeight();
			w, h = h, w;
			f:SetWidth(w); f:SetHeight(h); SS.DB().sizes[name] = { w = w, h = h };
		end
	end
	SS.ApplyMovableOrientation(name);
	SS.PlaceAll();
end

function SS.ApplyMovablePadding(name)
	if ( name == "SlimSuiteClockFrame" ) then SS.ApplyClockLayout();
	elseif ( name == "SlimSuiteBossFrames" ) then SS.UpdateBossFrames();
	elseif ( name == "SlimSuiteTallyFrame" ) then SS.ApplyTallyLayout(false);
	elseif ( name == "SlimSuiteAnnouncementFrame" and SS.announcementFrame and SS.announcementFrame.text ) then
		local padding = SS.FramePadding(name);
		SS.announcementFrame.text:ClearAllPoints();
		SS.announcementFrame.text:SetPoint("TOPLEFT", SS.announcementFrame, "TOPLEFT", padding + 10, -padding);
		SS.announcementFrame.text:SetPoint("BOTTOMRIGHT", SS.announcementFrame, "BOTTOMRIGHT", -(padding + 10), padding);
	elseif ( name == "BuffFrame" ) then
		SS.DB().buffCustomLayout = true;
		SS.Safe(SS.ApplyBuffOrientation);
	end
end


-- Keep the native dock intact: it owns tab selection and which message window is visible.
-- General establishes the tab baseline; other docked tabs share it even after a native dock refresh.
local chatDockHooked = false;
local chatOriginals = {};
function SS.ChatIsCustom()
	local d = SS.DB();
	local mode = d.elementModes and d.elementModes.ChatFrame1;
	if ( mode == "default" or mode == "disabled" or (d.frameDefault and d.frameDefault.ChatFrame1) ) then return false; end
	local place = d.places.ChatFrame1;
	return mode == "enabled" or d.unlocked or (type(place) == "table" and not place.displayDefault);
end
local function ChatInput()
	return (ChatFrame1 and ChatFrame1.editBox) or getglobal("ChatFrameEditBox") or getglobal("ChatFrame1EditBox");
end
local function EachDockedChat(fn)
	if ( type(DOCKED_CHAT_FRAMES) == "table" and table.getn(DOCKED_CHAT_FRAMES) > 0 ) then
		for i = 1, table.getn(DOCKED_CHAT_FRAMES) do fn(DOCKED_CHAT_FRAMES[i]); end
	else
		for i = 2, (NUM_CHAT_WINDOWS or 7) do local f = getglobal("ChatFrame" .. i); if ( f and f.isDocked ) then fn(f); end end
	end
end
function SS.ChatCompanions()
	local out, seen = {}, {};
	local function Add(f)
		local name = f and f.GetName and f:GetName();
		if ( type(name) == "string" and name ~= "ChatFrame1" and not seen[name] ) then seen[name] = true; table.insert(out, name); end
	end
	Add(ChatFrame1Tab); Add(ChatInput()); Add(getglobal("ChatFrameMenuButton"));
	EachDockedChat(function(f)
		if ( f and f ~= ChatFrame1 and f.isDocked and f.GetName ) then Add(f); Add(getglobal(f:GetName() .. "Tab")); end
	end);
	return out;
end
function SS.CaptureChatLayout()
	if ( not SS.ChatIsCustom() ) then return; end
	local names = SS.ChatCompanions(); table.insert(names, "ChatFrame1");
	for i = 1, table.getn(names) do
		local f = getglobal(names[i]);
		if ( f and not chatOriginals[f] ) then
			local original = { points = {}, scale = f.GetScale and f:GetScale() or 1 };
			for p = 1, (f.GetNumPoints and f:GetNumPoints() or 0) do
				local point, relative, relativePoint, x, y = f:GetPoint(p);
				original.points[p] = { point, relative, relativePoint, x, y };
			end
			if ( f == ChatFrame1 ) then
				original.w, original.h = f:GetWidth(), f:GetHeight();
				original.userPlaced = f.IsUserPlaced and f:IsUserPlaced() and true or false;
			end
			chatOriginals[f] = original;
		end
	end
end
function SS.SyncChatLayout()
	local chat, first = ChatFrame1, ChatFrame1Tab;
	if ( chat and first and SS.ChatIsCustom() ) then
		SS.CaptureChatLayout();
		local scale = SS.EffectiveScale(chat);
		local function MatchScale(f)
			if ( f and f.SetScale and f.GetParent ) then f:SetScale(scale / SS.EffectiveScale(f:GetParent())); end
		end
		MatchScale(first);
		first:ClearAllPoints(); first:SetPoint("BOTTOMLEFT", getglobal("ChatFrame1Background") or chat, "TOPLEFT", 2, 0);
		local previous = first;
		EachDockedChat(function(f)
			if ( f and f ~= chat and f.isDocked and f.GetName ) then
				MatchScale(f);
				f:ClearAllPoints(); f:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, 0); f:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", 0, 0);
				local tab = getglobal(f:GetName() .. "Tab"); MatchScale(tab);
				if ( tab and tab.IsShown and tab:IsShown() ) then
					tab:ClearAllPoints(); tab:SetPoint("BOTTOMLEFT", previous, "BOTTOMRIGHT", 0, 0); previous = tab;
				end
			end
		end);
		local input = ChatInput(); MatchScale(input);
		if ( input and input.SetPoint ) then
			-- The original 1.12 edit box has two anchors: preserve its width as chat resizes.
			input:ClearAllPoints(); input:SetPoint("TOPLEFT", chat, "BOTTOMLEFT", -5, -2); input:SetPoint("TOPRIGHT", chat, "BOTTOMRIGHT", 5, -2);
		end
		MatchScale(getglobal("ChatFrameMenuButton"));
		SS.UserPlace(chat); -- otherwise the native dock-position updater can move it back
	end
	SS.Safe(SS.ApplyFeatureMute, "ChatFrame1");
end
function SS.RefreshChatDock()
	if ( type(FCF_DockUpdate) == "function" ) then SS.Safe(FCF_DockUpdate); end
	SS.SyncChatLayout();
end
function SS.RestoreChatLayout(clearSaved)
	local current = { [ChatFrame1] = true };
	for _, name in ipairs(SS.ChatCompanions()) do current[getglobal(name)] = true; end
	for f, original in pairs(chatOriginals) do
		if ( current[f] ) then
			f:ClearAllPoints();
			for _, p in ipairs(original.points) do f:SetPoint(p[1], p[2], p[3], p[4], p[5]); end
			if ( f.SetScale ) then f:SetScale(original.scale); end
			if ( f == ChatFrame1 ) then
				f:SetWidth(original.w); f:SetHeight(original.h);
				if ( f.SetUserPlaced ) then f:SetUserPlaced(original.userPlaced); end
			end
		end
	end
	chatOriginals = {};
	if ( clearSaved ) then
		local d = SS.DB(); d.sizes.ChatFrame1, d.scales.ChatFrame1 = nil, nil;
		d.muted.ChatFrame1 = nil;
		d.chatOffsets.ChatFrame1Tab, d.chatOffsets.ChatFrame1EditBox = nil, nil;
	end
	SS.RefreshChatDock();
end
function SS.PrepareChatWindow()
	if ( not ChatFrame1 or not SS.ChatIsCustom() ) then return; end
	SS.CaptureChatLayout();
	if ( not chatDockHooked and type(FCF_DockUpdate) == "function" ) then
		local original = FCF_DockUpdate;
		FCF_DockUpdate = function() original(); SS.Safe(SS.SyncChatLayout); end;
		chatDockHooked = true;
	end
	SS.RefreshChatDock();
end

-- The native XP bar is anchored to MainMenuBar. Reparent it while preserving its on-screen bounds so its
-- independent move handle can reposition it without moving or resizing the action buttons.
function SS.DetachExperienceBar()
	if ( SS.xpBarDetached or not MainMenuExpBar or not UIParent ) then return; end
	if ( SS.DB().frameDefault and SS.DB().frameDefault.MainMenuExpBar ) then return; end
	if ( not SS.xpNativeLayout ) then
		SS.xpNativeLayout = { parent = MainMenuExpBar:GetParent(), strata = MainMenuExpBar:GetFrameStrata(), level = MainMenuExpBar:GetFrameLevel() };
	end
	local left, right, bottom = SS.RootBounds(MainMenuExpBar);
	local width, height = MainMenuExpBar:GetWidth(), MainMenuExpBar:GetHeight();
	MainMenuExpBar:SetParent(UIParent);
	MainMenuExpBar:ClearAllPoints();
	if ( left and bottom ) then
		SS.SetRootPosition(MainMenuExpBar, left, bottom);
	else
		MainMenuExpBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 8);
	end
	if ( width and width > 0 ) then MainMenuExpBar:SetWidth(width); end
	if ( height and height > 0 ) then MainMenuExpBar:SetHeight(height); end
	-- a new parent puts it at the bottom of the drawing order, under the bar's frame and gryphons: lift it above them
	local art = MainMenuBarArtFrame or MainMenuBar;
	if ( art and MainMenuExpBar.SetFrameStrata ) then
		MainMenuExpBar:SetFrameStrata(art:GetFrameStrata() or "MEDIUM");
		MainMenuExpBar:SetFrameLevel((art:GetFrameLevel() or 1) + 5);
	end
	SS.xpBarDetached = true;
end

function SS.RestoreExperienceBar()
	local xp, original = MainMenuExpBar, SS.xpNativeLayout;
	if ( not xp ) then return; end
	if ( original ) then
		xp:SetParent(original.parent); xp:SetFrameStrata(original.strata); xp:SetFrameLevel(original.level);
	end
	SS.xpBarDetached = nil;
	if ( xp.SetOrientation ) then SS.Safe(xp.SetOrientation, xp, "HORIZONTAL"); end
	if ( xp.SetClipsChildren ) then SS.Safe(xp.SetClipsChildren, xp, false); end
	SS.Safe(SS.StyleExpBar, false); SS.Safe(SS.LayoutXpSegments);
end

-- Vertical or horizontal for a build row (spells or worn jewelry). Joined, the two rows turn together (a column of
-- spells with the jewelry column beside it); split, each turns on its own. A row takes its own size for the new way.
function SS.SetBuildOrientation(name, vertical)
	local rows = SS.DB().buildRowsAttached and { "SlimSuiteSpellRowFrame", "SlimSuiteItemRowFrame" } or { name };
	for i = 1, table.getn(rows) do
		SS.DB().orientations[rows[i]] = vertical and "vertical" or "horizontal";
		SS.DB().sizes[rows[i]] = nil;
	end
	SS.LayoutSpellRow(); SS.LayoutItemRow();
	if ( SS.MatchBuildRowSizes ) then SS.MatchBuildRowSizes(name); end
	if ( SS.DB().buildRowsAttached ) then SS.DB().places.SlimSuiteItemRowFrame = SS.BuildRowDefaultPlace("SlimSuiteItemRowFrame"); end
	SS.Safe(SS.PlaceAll);
end

function SS.ToggleBuildRowsAttached()
	if ( not SS.itemRow or not SS.spellRow or not MainMenuBar ) then return; end
	if ( SS.DB().buildRowsAttached ) then
		for _, name in ipairs({ "SlimSuiteSpellRowFrame", "SlimSuiteItemRowFrame" }) do
			local frame = getglobal(name);
			SS.SavePlace(name, frame);
			local p = SS.DB().places[name];
			if ( p ) then p.relative, p.point, p.relativePoint, p.dx, p.dy = nil, nil, nil, nil, nil; end
		end
		SS.DB().buildRowsAttached = false;
	else
		-- Keep the spell row where the player left it; attach only the jewelry row beneath it.
		SS.SavePlace("SlimSuiteSpellRowFrame", SS.spellRow);
		local spellPlace = SS.DB().places.SlimSuiteSpellRowFrame;
		if ( spellPlace ) then spellPlace.relative, spellPlace.point, spellPlace.relativePoint, spellPlace.dx, spellPlace.dy = nil, nil, nil, nil, nil; end
		SS.DB().buildRowsAttached = true;
		SS.DB().places.SlimSuiteItemRowFrame = SS.BuildRowDefaultPlace("SlimSuiteItemRowFrame");
	end
	SS.PlaceAll();
end
