local M=GuildMarketTools
function M.CreateMinimapLauncher(openMarket)
    if M.minimapButton or not Minimap or not M.db then return end
    M.db.minimap=M.db.minimap or {angle=225}
    local config=M.db.minimap
    local b=CreateFrame("Button","GuildMarketToolsMinimapButton",Minimap)
    b:SetSize(32,32);b:SetFrameStrata("MEDIUM");b:SetFrameLevel(Minimap:GetFrameLevel()+10)
    b:EnableMouse(true);b:RegisterForClicks("LeftButtonUp","RightButtonUp");b:RegisterForDrag("LeftButton")
    local icon=b:CreateTexture(nil,"ARTWORK");icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01");icon:SetSize(22,22);icon:SetPoint("CENTER")
    local border=b:CreateTexture(nil,"OVERLAY");border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder");border:SetSize(54,54);border:SetPoint("TOPLEFT")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local function position()
        local a=math.rad(tonumber(config.angle) or 225)
        local x=(Minimap:GetWidth()/2+12)*math.cos(a)
        local y=(Minimap:GetHeight()/2+12)*math.sin(a)
        b:ClearAllPoints();b:SetPoint("CENTER",Minimap,"CENTER",x,y)
    end
    b:SetScript("OnClick",function(_,which)
        if which=="RightButton" then M.ShowAlchemy() else openMarket() end
    end)
    b:SetScript("OnDragStart",function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate",function()
            local x,y=GetCursorPosition();local cx,cy=Minimap:GetCenter();local scale=Minimap:GetEffectiveScale()
            if cx and cy then config.angle=math.deg(math.atan2(y/scale-cy,x/scale-cx));position() end
        end)
    end)
    b:SetScript("OnDragStop",function(self) self:SetScript("OnUpdate",nil);position() end)
    b:SetScript("OnHide",function(self) self:SetScript("OnUpdate",nil) end)
    b:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_LEFT");GameTooltip:AddLine("Guild Market Tools",1,.82,0)
        GameTooltip:AddLine("Left click: Market Tools",1,1,1)
        GameTooltip:AddLine("Right click: Professions",1,1,1)
        GameTooltip:AddLine("Drag: move around the minimap",.7,.7,.7);GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    M.minimapButton=b;position();b:Show()
end
