-- Snapping never anchors two frames to each other: a frame whose saved anchor leads back is skipped.
local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SS.SetupEnd(true); Tick(3,.1)
local d=SS.DB()
d.places.BuffFrame={relative="PlayerFrame",point="TOPLEFT",relativePoint="BOTTOMLEFT",dx=0,dy=0}
d.places.PlayerFrame={relative="BuffFrame",point="TOPLEFT",relativePoint="BOTTOMLEFT",dx=0,dy=0}
check("a two-frame loop is detected", SS.DependsOn("PlayerFrame","BuffFrame"))
check("a frame anchored to nothing is not in a loop", not SS.DependsOn("MinimapCluster","BuffFrame"))
SS.DB().places.TargetFrame={relative="BuffFrame",point="TOPLEFT",relativePoint="BOTTOMLEFT",dx=0,dy=0}
check("a frame hanging off another is detected", SS.DependsOn("TargetFrame","BuffFrame"))
print("snap loop problems: "..bad)
assert(bad==0 and #ERRORS==0,"snap loop regressions")
