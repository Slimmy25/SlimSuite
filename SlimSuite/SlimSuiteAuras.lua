-- Bounded unit-frame aura layout. All collision calculations use physical screen units.
if ( setfenv ) then setfenv(1, SS.ENV); end
local function Rect(frame)
	if ( not frame or not frame.GetLeft ) then return nil; end
	local l = frame:GetLeft(); local r=frame.GetRight and frame:GetRight();
	local t=frame.GetTop and frame:GetTop();
	local b=frame.GetBottom and frame:GetBottom();
	if ( not b and t ) then b=t-(frame.GetHeight and frame:GetHeight() or 0); end
	if ( not l or not r or not b or not t ) then return nil; end
	local scale = SS.EffectiveScale(frame);
	return { left=l*scale, right=r*scale, bottom=b*scale, top=t*scale };
end
function SS.AuraFrameBounds(frame, portrait)
	local bounds = Rect(frame); if ( not bounds ) then return nil; end
	local face = Rect(portrait or SS.UnitPortrait(frame));
	if ( face ) then bounds = face; end
	if ( not face and portrait and portrait.GetLeft and portrait:GetLeft() ) then bounds.left=math.min(bounds.left,portrait:GetLeft()*SS.EffectiveScale(portrait)); end
	local name = frame.GetName and frame:GetName();
	local bars = { frame.hp or frame.bar, frame.mp or frame.power };
	if ( type(name) == "string" ) then
		table.insert(bars, getglobal(name .. "HealthBar")); table.insert(bars, getglobal(name .. "ManaBar"));
	end
	for _, bar in pairs(bars) do
		local box = Rect(bar);
		if ( box ) then
			bounds.left=math.min(bounds.left,box.left); bounds.right=math.max(bounds.right,box.right);
			bounds.bottom=math.min(bounds.bottom,box.bottom); bounds.top=math.max(bounds.top,box.top);
		end
	end
	return bounds;
end
local function Visible(frame)
	return frame and frame.IsShown and frame:IsShown() and (not frame.IsVisible or frame:IsVisible()) and (not frame.GetAlpha or frame:GetAlpha()>0);
end
function SS.AuraObstacles(owner)
	local result, seen = {}, {};
	local function Add(frame)
		if ( frame == owner or seen[frame] or not Visible(frame) ) then return; end
		seen[frame]=true; local rect=SS.AuraFrameBounds(frame);
		if ( rect ) then table.insert(result,rect); end
	end
	Add(SS.PlayerAnchor()); Add(getglobal(SS.Shown("TargetFrame")));
	for i=1,4 do Add(getglobal("PartyMemberFrame"..i)); end
	local lines=getglobal("SlimSuitePartyLines");
	if ( Visible(lines) ) then for _, line in ipairs(lines.lines or {}) do Add(line); end end
	for _,entry in ipairs(MOVABLE or {}) do
		local name=entry[1];
		-- Aura owners and the thin-party container are handled above; tooltips are intentional popovers.
		if ( name~="BuffFrame" and name~="GameTooltip" and name~="SlimSuitePartyLines" ) then Add(getglobal(name)); end
	end
	-- Lay the player out first: party auras must also avoid the player's aura rectangle.
	if ( owner ~= SS.PlayerAnchor() and SS.playerAuraBounds ) then table.insert(result,SS.playerAuraBounds); end
	return result;
end
function SS.RestoreAuraButton(button)
	local original=button.slimAuraOriginal;
	if ( not original ) then return; end
	button:SetScale(original.scale); button:SetAlpha(original.alpha);
	if ( button.EnableMouse ) then button:EnableMouse(original.mouse); end
	button.slimAuraOriginal=nil;
end
local function Suppress(button)
	button:SetAlpha(0); if ( button.EnableMouse ) then button:EnableMouse(false); end
end
local function Overlaps(a,b)
	return a.left<b.right and a.right>b.left and a.bottom<b.top and a.top>b.bottom;
end
SS.auraLayouts={};
function SS.LayoutBoundedAuras(buttons, plate, portrait, nextFrame, side)
	local own=SS.AuraFrameBounds(plate,portrait); local count=table.getn(buttons);
	if ( count==0 ) then
		SS.auraLayouts[plate]=nil;
		if ( plate==SS.PlayerAnchor() ) then SS.playerAuraBounds=nil; end
		return;
	end
	if ( not own ) then
		SS.auraLayouts[plate]=nil;
		if ( plate==SS.PlayerAnchor() ) then SS.playerAuraBounds=nil; end
		for _,button in ipairs(buttons) do
			if ( not button.slimAuraOriginal ) then button.slimAuraOriginal={scale=button:GetScale() or 1,alpha=button:GetAlpha() or 1,mouse=not button.IsMouseEnabled or button:IsMouseEnabled()}; end
			Suppress(button);
		end
		return;
	end
	side=side or "above";
	local ui=Rect(UIParent); if ( not ui ) then return; end
	local margin=2*SS.EffectiveScale(UIParent);
	local left,right=math.max(own.left,ui.left),math.min(own.right,ui.right);
	local nextBox=Visible(nextFrame) and SS.AuraFrameBounds(nextFrame);
	if ( nextBox and nextBox.left>left and SS.CurrentOrientation("PartyMemberFrame1")=="horizontal" ) then right=math.min(right,nextBox.left-margin); end
	local obstacles=SS.AuraObstacles(plate);
	local base=side=="below" and own.bottom-margin or own.top+margin;
	local limit=side=="below" and ui.bottom or ui.top;
	for _, box in ipairs(obstacles) do
		if ( box.left<right and box.right>left ) then
			if ( side=="above" and box.bottom>=base ) then limit=math.min(limit,box.bottom-margin);
			elseif ( side=="below" and box.top<=base ) then limit=math.max(limit,box.top+margin); end
		end
	end
	local room=math.max(0,side=="below" and base-limit or limit-base);
	local width,height=0,0;
	for _,button in ipairs(buttons) do
		SS.RestoreAuraButton(button);
		button.slimAuraOriginal={scale=button:GetScale() or 1,alpha=button:GetAlpha() or 1,mouse=not button.IsMouseEnabled or button:IsMouseEnabled()};
		local scale=SS.EffectiveScale(button);
		local text=button.time;
		local name=button.GetName and button:GetName();
		if ( not text and type(name)=="string" ) then text=getglobal(name.."Duration"); end
		local tw,th=0,0;
		if ( text and text.IsShown and text:IsShown() ) then
			tw=(text:GetStringWidth() or 0)*scale;
			local gap=4;
			if ( text.GetPoint ) then local _,_,_,_,y=text:GetPoint(1); gap=math.max(gap,-(y or 0)); end
			th=((text:GetHeight() or 0)+gap)*scale;
		end
		local shrink=math.min(1,16*SS.EffectiveScale(plate)/math.max(1,(button:GetHeight() or 16)*scale));
		button:SetScale(button.slimAuraOriginal.scale*shrink);
		width=math.max(width,math.max((button:GetWidth() or 16)*scale+margin,tw)*shrink);
		height=math.max(height,((button:GetHeight() or 16)*scale+th)*shrink);
	end
	local columns=math.max(0,math.floor((right-left+margin)/math.max(1,width+margin)));
	local rows=math.min(2,math.max(0,math.floor((room+margin)/math.max(1,height+margin))));
	local capacity=columns*rows;
	local usedRows=columns>0 and math.min(rows,math.ceil(count/columns)) or 0;
	local bottom=side=="below" and base-usedRows*(height+margin)+margin or base;
	local layout={left=left,right=right,bottom=bottom,top=bottom+math.max(0,usedRows*(height+margin)-margin),columns=columns,rows=usedRows,shown=0,hidden=0};
	for i,button in ipairs(buttons) do
		local row=columns>0 and math.floor((i-1)/columns) or 0;
		local column=columns>0 and math.mod(i-1,columns) or 0;
		local cell={left=left+column*(width+margin),right=left+column*(width+margin)+width,
			bottom=bottom+(usedRows-1-row)*(height+margin),top=bottom+(usedRows-1-row)*(height+margin)+height};
		local blocked=i>capacity or cell.left<ui.left or cell.right>right or cell.bottom<ui.bottom or cell.top>ui.top;
		for _,box in ipairs(obstacles) do if ( Overlaps(cell,box) ) then blocked=true; end end
		if ( blocked ) then Suppress(button); layout.hidden=layout.hidden+1;
		else
			local scale=SS.EffectiveScale(button);
			button:ClearAllPoints();
			-- The icon's duration is beneath it; include that space inside the cell.
			local iconHeight=(button:GetHeight() or 16)*scale;
			local iconWidth=(button:GetWidth() or 16)*scale;
			button:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",(cell.left-ui.left+(width-iconWidth)/2)/scale,(cell.top-ui.bottom-iconHeight)/scale);
			layout.shown=layout.shown+1;
		end
	end
	SS.auraLayouts[plate]=layout;
	if ( plate==SS.PlayerAnchor() ) then SS.playerAuraBounds=layout.shown>0 and layout or nil; end
	return layout;
end
