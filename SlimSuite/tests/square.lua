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
