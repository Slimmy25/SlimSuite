-- the XP bar keeps the game's own border: copies of its four pieces follow the bar's size and turn when it stands up
local function upvalue(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i) if not n then return SS.ENV and SS.ENV[want] end if n == want then return v end i = i + 1 end end
SU = upvalue(SS.SetupHide, "SU")
local bad = 0
local function check(label, ok) if not ok then bad = bad + 1; print("  MISMATCH " .. label) end end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 0.01 end
check("the four pieces were read at load", SS.xpArt.pieces and #SS.xpArt.pieces == 4)
local p1 = SS.xpArt.pieces[1]
check("piece 1 sits at the left quarter", near(p1.u, -384 / 1024) and near(p1.w, 0.25))
SU.SetVertical("MainMenuExpBar", true); Tick(3)
local art = SlimSuiteXpArt
check("upright: the copies show", art and art.shown)
check("upright: the game's pieces step aside", MainMenuXPBarTexture0.alpha == 0)
local t = art.tex[1]
check("upright: a piece lies along the bar", near(t.h, p1.w * MainMenuExpBar.h) and near(t.w, p1.h * MainMenuExpBar.w))
SU.SetVertical("MainMenuExpBar", false); Tick(3)
check("flat again: the copies show", art.shown)
check("flat: a piece lies along the bar", near(t.w, p1.w * MainMenuExpBar.w) and near(t.h, p1.h * MainMenuExpBar.h))
MainMenuExpBar:SetWidth(512); SS.LayoutXpSegments(); Tick(1)
check("resized: the pieces follow", near(t.w, 0.25 * 512))
print("xp art problems: " .. bad)
print("errors: " .. #ERRORS); for _, e in ipairs(ERRORS) do print("  " .. e) end
