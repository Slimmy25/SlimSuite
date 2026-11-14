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

local cachedContext;
function SS.DisplayContext()
 local l, r, b, t = SS.ScreenBounds(); local w, h = math.max(1,r-l), math.max(1,t-b);
 -- Placement visits every element repeatedly. Recalculate template scores only after a resize.
 if ( cachedContext and cachedContext.left==l and cachedContext.bottom==b and cachedContext.width==w and cachedContext.height==h ) then return cachedContext; end
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
 cachedContext = { left=l, bottom=b, width=w, height=h, template=best, resolution=closest,
  scale=math.min(h/1080 * best.density, w/1800) };
 return cachedContext;
end
function SS.DisplayEnabled(name)
 local element=SS.Element and SS.Element(name) or name;
 if ( element == "GameTooltip" ) then
  local d=SS.DB();
  return (d.tooltipCustom or (d.elementModes and d.elementModes.GameTooltip=="enabled")) and true or false;
 end
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
function SS.ApplyRecommendedHUD()
	if ( SS.MarkProfileDirty ) then SS.MarkProfileDirty(); end
 if ( not SS.DisplayContext or not SS.DISPLAY_ANCHORS ) then return false; end
 local d=SS.DB();
 d.places=type(d.places)=="table" and d.places or {};
 local applied, appliedElements=0, {};
 for name in pairs(SS.DISPLAY_ANCHORS) do
  if ( SS.DisplayEnabled(name) ) then
   d.places[name]={ displayDefault=true };
   local element=SS.Element and SS.Element(name) or name;
   if ( not appliedElements[element] ) then appliedElements[element]=true; applied=applied+1; end
  end
 end
 local context=SS.DisplayContext();
 d.recommendedHudTemplate=context.template.id;
 if ( PlaceAll ) then SS.Safe(PlaceAll); end
 return applied, context;
end
function SS.ShowHUDRecommendation()
 local f=getglobal("SlimSuiteHUDRecommendationFrame");
 if ( not f ) then
  f=K.Window("SlimSuiteHUDRecommendationFrame", "Recommended HUD preset", 430, 220);
  f.note=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
  f.note:SetPoint("TOPLEFT",f,"TOPLEFT",24,-48); f.note:SetWidth(380); f.note:SetHeight(78);
  f.note:SetJustifyH("LEFT"); f.note:SetJustifyV("TOP");
  local apply=K.Button(f,"Apply recommended positions",210,function()
   local count, context=SS.ApplyRecommendedHUD();
   f.note:SetText(string.format(SS.T("Applied %s preset for %sx%s. Repositioned %d enabled elements; Default and Disabled elements stayed in place. Save a profile first if you want an easy way back."),context.template.id,context.resolution[1],context.resolution[2],count));
  end);
  apply:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",24,20);
  local profiles=K.Button(f,"Profiles & import/export",170,function() f:Hide(); SS.ShowLayoutWindow(); end);
  profiles:SetPoint("LEFT",apply,"RIGHT",8,0);
 end
 local context=SS.DisplayContext();
 f.note:SetText(string.format(SS.T("Recommended HUD preset for this display: %s at %sx%s. Positions stay proportional to the reference HUD and sizes continue to follow screen height. Applying changes positions only for Enabled elements."),context.template.id,context.resolution[1],context.resolution[2]));
 f:Show();
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
