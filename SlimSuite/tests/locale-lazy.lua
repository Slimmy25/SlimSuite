-- Translations are compiled on first use. This must work on every Lua the checks run on (5.0 in the client, 5.3 in CI).
local bad=0
local function check(label,ok) if not ok then bad=bad+1; print("MISMATCH "..label) end end
-- after login only the language in use is kept
check("after login the other languages are let go", SS.LOCALE_CODES and SS.LOCALE_CODES.deDE and SS.LOCALE_SOURCE.deDE == nil)
check("the language in use still translates", SS.T("+1 hour") ~= nil)
-- the checks below look at every language, as loaded before login
dofile("../SlimSuiteLocaleExtra.lua"); SS.LOCALE_CODES = nil
check("every language is listed as source", SS.LOCALE_SOURCE and SS.LOCALE_SOURCE.deDE and SS.LOCALE_SOURCE.enUS and true or false)
check("a language is not compiled until it is asked for", rawget(SS.LOCALE_TEXT, "frFR") == nil)
local fr = SS.LOCALE_TEXT.frFR
check("asking for a language compiles it", type(fr) == "table" and fr["+1 hour"] ~= nil)
local de = SS.LOCALE_TEXT.deDE
check("a German translation is found", type(de) == "table" and de["+1 hour"] == "+1 Stunde")
check("an unknown language gives nothing", SS.LOCALE_TEXT.xxXX == nil)
print("locale lazy problems: "..bad)
assert(bad==0,"locale lazy regressions")
