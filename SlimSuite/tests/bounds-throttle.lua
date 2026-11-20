-- The containment task checks a shown movable frame on a slow safety interval while it stays still,
-- straight away when it moves, and settles back afterwards. Only the task's own checks are counted.
local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SS.SetupEnd(true); Tick(3,.1)
local f=PlayerFrame; f:Show()
local calls=0; local real=SS.EnforceElementBounds
local taskTable; for k=1,200 do local n,v=debug.getupvalue(SS.Every,k); if not n then break end; if n=="tasks" then taskTable=v end end
local task=taskTable.contentBounds; local taskFn=task.fn
task.fn=function() SS.EnforceElementBounds=function(frame,...) if frame==f then calls=calls+1; end; return real(frame,...) end; taskFn(); SS.EnforceElementBounds=real end
Tick(5,.1); calls=0; Tick(20,.05)
local still=calls
check("a still frame is checked on the safety interval, not every tick (got "..still.." in 1s)", still>=1 and still<=3)
f:SetWidth(f:GetWidth()+10); calls=0; Tick(2,.05)
check("a resized frame is checked within a tenth of a second", calls>=1)
calls=0; Tick(10,.05)
check("after the change it settles back to the safety interval", calls<=3)
task.fn=taskFn
print("bounds throttle problems: "..bad)
assert(bad==0 and #ERRORS==0,"bounds throttle regressions")
