-- Geometry regression: the default mock does not resolve anchors or inherit scale.
-- Here the root can occupy only 90% of the physical viewport, as in the report.
-- Resolve every authored position back to physical pixels before checking it.
local bad = 0
local function near(label, actual, expected)
    if math.abs(actual - expected) > 0.01 then
        bad = bad + 1; print("MISMATCH " .. label .. ": " .. actual .. " expected " .. expected)
    end
end
local name = "SlimSuiteEdgeTestFrame"
local frame = CreateFrame("Frame", name, UIParent)
frame:SetWidth(210); frame:SetHeight(110)
local uiScale, ownScale, originX, originY = 1, 1, 0, 0
local viewportWidth, viewportHeight = 1705, 958
local rootWidth, rootHeight = viewportWidth, viewportHeight
UIParent.GetEffectiveScale = function() return uiScale end
UIParent.GetLeft = function() return originX / uiScale end
UIParent.GetBottom = function() return originY / uiScale end
UIParent.GetRight = function() return originX / uiScale + rootWidth end
UIParent.GetTop = function() return originY / uiScale + rootHeight end
UIParent.GetWidth = function() return rootWidth end
UIParent.GetHeight = function() return rootHeight end
WorldFrame.GetEffectiveScale = function() return 1 end
WorldFrame.GetLeft = function() return 0 end
WorldFrame.GetBottom = function() return 0 end
WorldFrame.GetRight = function() return viewportWidth end
WorldFrame.GetTop = function() return viewportHeight end
frame.GetEffectiveScale = function() return uiScale * ownScale end
frame.GetScale = function() return ownScale end
frame.SetScale = function(self, scale) ownScale = scale end
local function physicalLeft()
    return originX + (frame.points[1][4] or 0) * uiScale * ownScale
end
local function physicalBottom()
    return originY + (frame.points[1][5] or 0) * uiScale * ownScale
end
frame.GetLeft = function() return physicalLeft() / (uiScale * ownScale) end
frame.GetBottom = function() return physicalBottom() / (uiScale * ownScale) end
frame.GetRight = function() return frame:GetLeft() + frame:GetWidth() end
frame.GetTop = function() return frame:GetBottom() + frame:GetHeight() end
local rootPosition = SS.ENV.SetRootPosition
SS.FollowHandle = function() end
SS.DB().mirrorTarget = false
IsMouseButtonDown = function() return true end
local mouseX, mouseY = 0, 0
GetCursorPosition = function() return mouseX, mouseY end
local function checkCorner(label, upper)
    local scale = uiScale * ownScale
    near(label .. " horizontal", physicalLeft() + (upper and frame:GetWidth() * scale or 0), upper and viewportWidth or 0)
    near(label .. " vertical", physicalBottom() + (upper and frame:GetHeight() * scale or 0), upper and viewportHeight or 0)
end
for _, rootScale in ipairs({ 0.9, 0.75, 1, 1.2 }) do
    uiScale = rootScale
    for _, elementScale in ipairs({ 0.65, 1, 1.5 }) do
        ownScale = elementScale
        for _, inset in ipairs({ 0, 72 }) do
            originX, originY = inset, inset / 2
            -- Keep the root within the world viewport for the scale > 1 case too.
            rootWidth = (viewportWidth - originX) * 0.9 / uiScale
            rootHeight = (viewportHeight - originY) * 0.9 / uiScale
            SS.DB().scales[name] = ownScale
            for _, upper in ipairs({ false, true }) do
                local far = upper and 10000 or -10000
                rootPosition(frame, 100, 100)
                mouseX, mouseY = far * uiScale, far * uiScale
                local handle = { mover = name, dragStartX = 0, dragStartY = 0, frameStartX = 100, frameStartY = 100 }
                SS.DragStep(handle, name)
                checkCorner("drag", upper)
                SS.Place(name)
                checkCorner("saved restore", upper)
                rootPosition(frame, far, far)
                SS.ClampToClient(name, frame)
                checkCorner("layout clamp", upper)
                rootPosition(frame, far, far)
                SS.DB().unlocked = false
                SS.ClampAbsoluteFrame(name, frame)
                checkCorner("live refresh", upper)
            end
        end
    end
end
-- A viewport smaller than UIParent must not reduce the available UI area.
uiScale, ownScale, originX, originY = 1, 1, 0, 0
rootWidth, rootHeight = viewportWidth + 200, viewportHeight + 100
local l, r, b, t = SS.ScreenBounds()
near("full UI retained width", r - l, rootWidth)
near("full UI retained height", t - b, rootHeight)
-- Resolved edges take precedence over an inconsistent reported width/height.
UIParent.GetWidth = function() return 100 end
UIParent.GetHeight = function() return 100 end
l, r, b, t = SS.ScreenBounds()
near("resolved width", r - l, rootWidth)
near("resolved height", t - b, rootHeight)
near("caught runtime errors", #ERRORS, 0)
print("screen edge problems: " .. bad)
assert(bad == 0, "screen edge regression")

-- A custom location saved on one display adapts proportionally and returns exactly.
uiScale, ownScale, originX, originY = 1, 1, 0, 0
viewportWidth, viewportHeight = 1920,1080
rootWidth,rootHeight=1920,1080
UIParent.GetWidth=function() return rootWidth end
UIParent.GetHeight=function() return rootHeight end
rootPosition(frame,600,400)
SS.SavePlace(name,frame)
local original=SS.CopyTable(SS.DB().places[name])
for i=1,5 do
 viewportWidth,viewportHeight=1280,720;rootWidth,rootHeight=1280,720
 SS.Place(name)
 near("custom resized horizontal",physicalLeft(),400)
 near("custom resized vertical",physicalBottom(),400*720/1080)
 viewportWidth,viewportHeight=1920,1080;rootWidth,rootHeight=1920,1080
 SS.Place(name)
 near("custom return horizontal",physicalLeft(),600)
 near("custom return vertical",physicalBottom(),400)
end
near("stored horizontal unchanged",SS.DB().places[name].x,original.x)
near("stored vertical unchanged",SS.DB().places[name].y,original.y)
print("resize return problems: "..bad)
assert(bad==0,"resize return regression")
