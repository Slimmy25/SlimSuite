-- Slim Suite: the setup and the settings window.
if ( setfenv ) then setfenv(1, SS.ENV); end   -- Slim Suite's files share one set of private names (SS.ENV, in SlimSuiteCore.lua)

-- ---------------------------------------------------------------- first-time setup of the movable UI
-- The first time "Toggle UI Settings" is turned on, Slim Suite walks the player through the interface one element
-- at a time: only that element's green handle shows, outlined in pulsing gold, with a short note and Back / Next.
-- It starts with the unit frame, then the party frames, then the action bar (with its two questions), then the
-- rest of the game's frames and every Slim Suite replacement that is turned on. Locking the UI part way through
-- picks the setup up at the same step next time; "Skip setup" or finishing it ends it for good, and the move
-- panel's "Run setup again" starts it over.
SU = {};                                           -- the setup's panel, outline and steps
SU.statCounterPlaceholder = CreateFrame("Frame", "SlimSuiteStatCounterFrame", UIParent);
SU.statCounterPlaceholder:SetWidth(150); SU.statCounterPlaceholder:SetHeight(28);
SU.statCounterPlaceholder:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
SU.statCounterPlaceholder:SetBackdropColor(0.04, 0.035, 0.07, 0.9); SU.statCounterPlaceholder:SetBackdropBorderColor(0.85, 0.65, 0.2, 1);
SU.statCounterPlaceholder.label = SU.statCounterPlaceholder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
SU.statCounterPlaceholder.label:SetPoint("CENTER", SU.statCounterPlaceholder, "CENTER"); SU.statCounterPlaceholder.label:SetText("Stat counter [WIP]");
SU.statCounterPlaceholder:Hide();

function SU.Steps()
 local d, steps = SS.DB(), {};
 for i = 1, table.getn(SS.SETUP_ORDER) do
  local name = SS.SETUP_ORDER[i]; local element = SS.ELEMENTS[name];
  if ( getglobal(name) and not (d.setupDisabled and d.setupDisabled[name]) ) then
   local title = name == "PlayerFrame" and d.combineTarget and "Player + target" or element.title;
   table.insert(steps, { frame=name, title=title, text=element.text });
  end
 end
 table.insert(steps, { title="All set", text="That's everything. Press Finish to lock the UI. You can move anything again with Toggle UI Settings. Done closes the list." });
 if ( SS.TranslateRecord ) then for i=1,table.getn(steps) do SS.TranslateRecord(steps[i]); end end
 return steps;
end

