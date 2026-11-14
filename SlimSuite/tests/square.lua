-- the square layout: zoom on the right, the rest in a column on the left
for _, n in ipairs({"MinimapZoomIn","MinimapZoomOut","MiniMapTrackingFrame","MiniMapMailFrame"}) do local f = CreateFrame("Button", n, Minimap); f.w, f.h = 32, 32 end
GameTimeFrame.parent = MinimapCluster; GameTimeFrame.w, GameTimeFrame.h = 40, 40; MinimapCluster.children = MinimapCluster.children or {}; table.insert(MinimapCluster.children, GameTimeFrame)
Minimap.w, Minimap.h = 140, 140
MiniMapMailFrame:Hide()
local pts = {}
local orig = Frame and nil
for _, n in ipairs({"MinimapZoomIn","MinimapZoomOut","MiniMapTrackingFrame","GameTimeFrame","SlimSuiteMinimapButton"}) do
  local f = _G[n]; local old = f.SetPoint
  f.SetPoint = function(self, p, rel, rp, x, y) pts[n] = string.format("%s %s %.0f,%.0f", p, rel and rel.name or "?", x or 0, y or 0) end
end
SS.SetMinimapSquare(true); Tick(12)
print("square:"); for k, v in pairs(pts) do print("  ", k, v) end
pts = {}
SS.SetMinimapSquare(false); Tick(2)
print("round:"); for k, v in pairs(pts) do print("  ", k, v) end
Minimap:GetScript("OnMouseWheel")
Minimap.zoom = 2
this, arg1 = Minimap, 1; Minimap.scripts.OnMouseWheel(); print("wheel up ->", Minimap.zoom)
arg1 = -1; Minimap.scripts.OnMouseWheel(); Minimap.scripts.OnMouseWheel(); print("wheel down x2 ->", Minimap.zoom)
print(table.concat(ERRORS, "\n"))
local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("MISMATCH " .. label) end end
local zone = CreateFrame("Button", "MinimapZoneTextButton", MinimapCluster)
zone:SetWidth(180); zone:SetHeight(20); zone:SetPoint("TOPLEFT", MinimapCluster, "TOPLEFT", 0, 0)
local close = CreateFrame("Button", "MinimapToggleButton", MinimapCluster)
close:SetWidth(20); close:SetHeight(20); close:SetPoint("LEFT", zone, "RIGHT", 0, 0)
MinimapBorder = CreateFrame("Frame", "MinimapBorder", Minimap)
MinimapBorderTop = CreateFrame("Frame", "MinimapBorderTop", MinimapCluster)
MinimapZoneText = zone:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
MinimapZoneText:SetText("Kel'Thuzad Chamber") -- differs from GetRealZoneText's broader zone name
Minimap.SetMaskTexture = function(self, path) self.mask = path end
SS.DB().elementModes.MinimapCluster = "enabled"
for i = 1, 3 do
    for _, square in ipairs({ true, false }) do
        Minimap:SetAlpha(0); Minimap:Hide(); MinimapCluster:SetAlpha(0); MinimapBorderTop:Hide()
        SS.SetMinimapSquare(square); Tick(12)
        check("enabled map remains visible: " .. tostring(square), Minimap:IsShown() and Minimap:GetAlpha() > 0 and MinimapCluster:GetAlpha() > 0)
        check("correct shape mask: " .. tostring(square), Minimap.mask == (square and SlimSuiteMinimapMask.square or SlimSuiteMinimapMask.round))
        check("native title stays readable and exact", zone:GetAlpha() == 1 and MinimapZoneText:GetText() == "Kel'Thuzad Chamber" and MinimapBorderTop:IsShown())
        check("close button remains attached to native title", close.points[1][2] == zone and close.points[1][3] == "RIGHT" and not close.slimSquareOrig)
        check("square mode does not replace the native header", not SS.squareTitle or not SS.squareTitle:IsShown())
    end
end
SS.SetMinimapSquare(true); SS.SetMinimapTransparent(true); Tick(12)
check("transparent square stays borderless between ticks", not SS.squareRing:IsShown() and not MinimapBorderTop:IsShown() and Minimap:GetAlpha() > 0)
SS.SetMinimapTransparent(false); SS.SetMinimapSquare(false)
check("round native border returns", MinimapBorder:IsShown() and MinimapBorderTop:IsShown())
print("minimap problems: " .. bad)
