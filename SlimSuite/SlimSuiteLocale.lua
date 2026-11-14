-- Locale selection and text helpers; dictionaries are generated from locales/*.json.
function SS.LocaleCode()
 local locale=SS.DB().language;
 if ( not locale or locale == "auto" ) then locale=GetLocale and GetLocale() or "enUS"; end
 if ( SS.LOCALE_TEXT[locale] ) then return locale; end
 local language=string.sub(tostring(locale),1,2);
 for code in pairs(SS.LOCALE_TEXT) do if ( string.sub(code,1,2)==language ) then return code; end end
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
