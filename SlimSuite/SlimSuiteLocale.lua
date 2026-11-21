-- Locale selection and text helpers; dictionaries are generated from locales/*.json.
function SS.LocaleCode()
	local locale=SS.DB().language;
	if ( not locale or locale == "auto" ) then locale=GetLocale and GetLocale() or "enUS"; end
	if ( SS.LOCALE_TEXT[locale] ) then return locale; end
	local language=string.sub(tostring(locale),1,2);
	for code in pairs(SS.LOCALE_CODES or SS.LOCALE_SOURCE) do if ( string.sub(code,1,2)==language ) then return code; end end
	return "enUS";
end
function SS.T(text)
	if ( type(text)~="string" ) then return text; end
	local translations=SS.LOCALE_TEXT[SS.LocaleCode()];
	return (translations and translations[text]) or text;
end
function SS.TranslateRecord(record)
	if ( type(record)~="table" ) then return record; end
	for _,key in ipairs({"title","text","short","label","name"}) do
		if ( type(record[key])=="string" ) then record[key]=SS.T(record[key]); end
	end
	return record;
end
-- Only one language is used per session (changing it asks for a reload). Once the saved settings are in, that one is
-- made ready and the text of the others is let go, so it does not sit in memory all session.
local localeLoader=CreateFrame("Frame");
localeLoader:RegisterEvent("PLAYER_LOGIN");
localeLoader:SetScript("OnEvent",function()
	if ( type(SS.LOCALE_SOURCE)~="table" ) then return; end
	local codes={}; for code in pairs(SS.LOCALE_SOURCE) do codes[code]=true; end
	SS.LOCALE_CODES=codes;
	local keep=SS.LocaleCode(); local _=SS.LOCALE_TEXT[keep];
	for code in pairs(codes) do if ( code~=keep ) then SS.LOCALE_SOURCE[code]=nil; end end
	SS.LOCALE_SOURCE[keep]=nil;   -- already made ready
end);
