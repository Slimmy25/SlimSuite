-- Preset designs offered first in Quick setup ("Would you like to use a pre-set design?"). Up to 5.
-- To add one: arrange the HUD the way you want, open /slim layout, export the layout and paste its text
-- (it starts with "SSL1;") as the third value below. Name and description are what players see.
-- Its picture is textures/quick/preset<n>.tga (n = its place among the filled-in presets): python3 tools/quick-image.py shot.jpg preset1
-- A preset with no text is skipped, so the question only appears once at least one preset is filled in.
if ( setfenv ) then setfenv(1, SS.ENV); end

SS.PRESETS = {
	-- { "Name", "One line about this design.", "SSL1;..." },
	-- { "Name", "One line about this design.", "SSL1;..." },
	-- { "Name", "One line about this design.", "SSL1;..." },
	-- { "Name", "One line about this design.", "SSL1;..." },
	-- { "Name", "One line about this design.", "SSL1;..." },
};

local function Parse(text)
	if ( not SS.LayoutFromText ) then return nil; end
	local ok, layout = SS.Safe(SS.LayoutFromText, text);
	return ok and type(layout) == "table" and layout or nil;
end

-- the presets that are filled in and can be read, at most 5
function SS.UsablePresets()
	local out = {};
	for _, p in ipairs(SS.PRESETS or {}) do
		if ( table.getn(out) >= 5 ) then break; end
		if ( type(p) == "table" and type(p[1]) == "string" and type(p[3]) == "string" and p[3] ~= ""
			and Parse(p[3]) ) then
			p.picture = "preset" .. (table.getn(out) + 1);   -- textures/quick/preset<n>.tga, made with tools/quick-image.py
			table.insert(out, p);
		end
	end
	return out;
end

function SS.ApplyPreset(p)
	local layout = p and Parse(p[3]);
	if ( not layout ) then return false; end
	SS.LayoutApply(layout);
	if ( SS.LogAction ) then SS.LogAction("Preset design applied: " .. p[1]); end
	return true;
end
