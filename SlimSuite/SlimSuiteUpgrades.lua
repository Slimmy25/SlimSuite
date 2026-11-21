-- Slim Suite: one-time upgrades of saved settings, in order. Each runs once per character, a moment after login
-- (when every frame exists), and the number of the last one done is saved, so none runs twice. A new upgrade is added
-- at the end of the list; an old one is never renumbered or removed. Plain renames and removals that need no frame
-- are done when the saved settings are read (SS.PrepareDB in SlimSuite.lua).
local K, SU, NAME = SS.Kit, SS.SU, SS.NAME;   -- the three names every Slim Suite file uses (SlimSuiteCore.lua)

SS.UPGRADES = {
	-- 1: the transparent minimap is retired (per-element Opacity replaces it): the normal minimap comes back
	function(d)
		if ( d.minimapTransparent and SS.SetMinimapTransparent ) then SS.SetMinimapTransparent(false); end
		d.minimapTransparent = false;
	end,
	-- 2: the page on/off switch is retired: a page that was switched off is switched back on, with its earlier settings
	function(d)
		if ( d.pageSwitchRetired or type(d.modules) ~= "table" ) then return; end
		for _, id in ipairs(SS.MODULE_ORDER) do
			if ( d.modules[id] == false ) then SS.Safe(SS.SetModuleEnabled, id, true); d.modules[id] = nil; end
		end
	end,
	-- 3: "buffs on the target frame" has no setting any more: the buffs go back to their own place
	function(d)
		if ( d.buffsOnTarget ) then
			d.buffsOnTarget = false;
			local sc = d.scales and d.scales.BuffFrame;
			if ( BuffFrame and BuffFrame.SetScale ) then BuffFrame:SetScale(type(sc) == "number" and sc or 1); end
			SS.Safe(SS.Place, "BuffFrame");
		end
	end,
	-- 4: the old marker for upgrade 2, which the list now keeps track of
	function(d)
		d.pageSwitchRetired = nil;
	end,
};

SS.Every("upgrades", 2, function()
	local d = SS.DB();
	SS.Stop("upgrades");
	local done = tonumber(d.upgradesDone) or 0;
	for i = done + 1, table.getn(SS.UPGRADES) do
		local ok = SS.Safe(SS.UPGRADES[i], d);
		if ( SS.LogAction ) then SS.LogAction("[upgrade] " .. i .. (ok and " done" or " failed (see /slim errors)")); end
		d.upgradesDone = i;
	end
end);
