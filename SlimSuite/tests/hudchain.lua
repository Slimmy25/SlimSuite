-- Chaining: a partner sits directly ahead of or behind its primary; everything else keeps its order.
local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
SS.SetupEnd(true); Tick(3,.1)
local d=SS.DB()
local base={}; for _,n in ipairs(SS.HUDOrder()) do table.insert(base,n) end
local function index(name) for i,n in ipairs(SS.HUDOrder()) do if n==name then return i end end end
local function without(list,name) local out={} for _,n in ipairs(list) do if n~=name then table.insert(out,n) end end return out end
local a,b,c=base[1],base[5],base[9]
SS.HUDChain(b,a,"ahead")
check("ahead puts the partner directly above its primary", index(b)==index(a)-1 or (index(a)==1 and index(b)==1))
local now=SS.HUDOrder(); check("ahead keeps the other rows in order", table.concat(without(now,b),",")==table.concat(without(base,b),","))
SS.HUDChain(b,c,"behind")
check("behind puts the partner directly below its primary", index(b)==index(c)+1)
local rest={} for _,n in ipairs(SS.HUDOrder()) do if n~=b then table.insert(rest,n) end end
check("moving a partner keeps the rest in order", table.concat(rest,",")==table.concat(without(base,b),","))
check("a chain cannot loop back", SS.HUDChain(c,b,"ahead")==false)
check("an element cannot chain to itself", SS.HUDChain(a,a,"ahead")==false)
SS.HUDUnchain(b); SS.HUDLayout()
check("unchaining leaves the chain record gone", d.hudChains[b]==nil)
SS.HUDChain(b,a,"behind")
SS.HUDUnchain(b); d.hudChains={}; SS.HUDLayout()
print("hud chain problems: "..bad)
assert(bad==0 and #ERRORS==0,"HUD chain regressions")
