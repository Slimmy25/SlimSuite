-- Resolution templates use the reference HUD's screen fractions and height-based sizing.
if ( setfenv ) then setfenv(1, SS.ENV); end
SS.DISPLAY_TEMPLATES = {
 { id = "4:3", width = 1440, height = 1080, density = .90 },
 { id = "5:4", width = 1280, height = 1024, density = .88 },
 { id = "16:10", width = 1920, height = 1200, density = .96 },
 { id = "16:9", width = 1920, height = 1080, density = 1 },
 { id = "21:9", width = 2560, height = 1080, density = 1 },
 { id = "32:9", width = 3840, height = 1080, density = 1 },
 { id = "portrait", width = 1080, height = 1920, density = .70 }
};
SS.DISPLAY_RESOLUTIONS = {
 {800,600}, {1024,768}, {1280,1024}, {1280,720}, {1366,768}, {1600,900},
 {1920,1080}, {2560,1440}, {3840,2160}, {7680,4320}, {1280,800},
 {1920,1200}, {2560,1600}, {2560,1080}, {3440,1440}, {5120,2160},
 {3840,1080}, {5120,1440}, {1080,1920}
};
SS.DISPLAY_ANCHORS = {
 PlayerFrame = { "TOPLEFT", .02, .98 }, TargetFrame = { "TOPLEFT", .165, .98 },
 PartyMemberFrame1 = { "TOPLEFT", .02, .87 },
 SlimSuitePlayerCard = { "TOPLEFT", .02, .98 }, SlimSuiteTargetCard = { "TOPLEFT", .165, .98 },
 SlimSuitePartyLines = { "TOPLEFT", .02, .87 },
 SlimSuiteBossFrames = { "TOP", .5, .92 }, SlimSuiteClockFrame = { "TOP", .5, .995 },
 BuffFrame = { "TOPRIGHT", .88, .985 }, MinimapCluster = { "TOPRIGHT", .995, .995 },
 SlimSuiteLocalClockFrame = { "TOPRIGHT", .965, .80 },
 SlimSuiteMeterFrame = { "BOTTOMLEFT", .70, 0 }, SlimSuiteStoredLevelsButton = { "CENTER", .5, .23 },
 SlimSuiteTallyFrame = { "BOTTOM", .5, .006 }, MainMenuBar = { "BOTTOM", .5, 0 },
 MainMenuExpBar = { "BOTTOM", .5, .049 }, SlimSuiteSpellRowFrame = { "TOPLEFT", .275, .38 },
 SlimSuiteItemRowFrame = { "TOPLEFT", .275, .34 }, ChatFrame1 = { "BOTTOMLEFT", .005, .17 },
 SlimSuiteAnnouncementFrame = { "CENTER", .5, .70 }, GameTooltip = { "BOTTOMRIGHT", .995, .005 }
};
function SS.DisplayContext()
 local l, r, b, t = SS.ScreenBounds(); local w, h = math.max(1,r-l), math.max(1,t-b);
 local best, distance;
 for _, candidate in ipairs(SS.DISPLAY_TEMPLATES) do
  local d = math.abs(math.log((w/h)/(candidate.width/candidate.height)));
  if ( not distance or d < distance ) then best, distance = candidate, d; end
 end
 local closest, score;
 for _, resolution in ipairs(SS.DISPLAY_RESOLUTIONS) do
  local difference=math.abs(math.log(w/resolution[1]))+math.abs(math.log(h/resolution[2]));
  if ( not score or difference<score ) then closest, score=resolution, difference; end
 end
 return { left=l, bottom=b, width=w, height=h, template=best, resolution=closest,
  scale=math.min(h/1080 * best.density, w/1800) };
end
function SS.DisplayEnabled(name)
 local element=SS.Element and SS.Element(name) or name;
 return SU and SU.Mode and SU.Mode(element)=="enabled";
end
function SS.DisplayElementScale(name, base)
 if ( not SS.DISPLAY_ANCHORS[name] or not SS.ScreenBounds or not SS.DisplayEnabled(name) ) then return base; end
 local d=SS.DB();
 if ( d.frameDefault and d.frameDefault[name] ) then return base; end
 return base * SS.DisplayContext().scale;
end
function SS.PlaceDisplayDefault(name, frame)
 local a=SS.DISPLAY_ANCHORS[name]; if ( not a or not SS.DisplayEnabled(name) ) then return false; end
 local c=SS.DisplayContext(); local f=RootFactor(frame);
 frame:ClearAllPoints();
 frame:SetPoint(a[1], UIParent, "BOTTOMLEFT", (c.left+c.width*a[2])/f, (c.bottom+c.height*a[3])/f);
 return true;
end
-- A resize is coalesced by this shared ticker. Dragging never triggers a rebuild.
local previous;
SS.Every("displayTemplates", .5, function()
 if ( not SS.ScreenBounds or not SS.DB or not PlaceAll ) then return; end
 for _, handle in ipairs(handleList or {}) do if ( handle.dragging ) then return; end end
 local c=SS.DisplayContext();
 local signature=c.left..":"..c.bottom..":"..c.width..":"..c.height..":"..SS.EffectiveScale(UIParent);
 if ( signature == previous ) then return; end
 previous=signature;
 SS.currentDisplayTemplate=c.template.id;
 SS.currentDisplayResolution=c.resolution[1].."x"..c.resolution[2];
 SS.displayReflow=true;
 local ok, err=pcall(PlaceAll);
 SS.displayReflow=nil;
 if ( not ok ) then SS.Report(err); end
end);
