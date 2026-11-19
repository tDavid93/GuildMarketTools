local M=GuildMarketTools
-- Quantity-weighted statistics of loaded asking prices, not completed sales.
function M.DepthStats(snapshot)
    local d={levels={},units=0,value=0,listings=0,full=snapshot and snapshot.full==true,time=snapshot and snapshot.time}
    if not snapshot then return d end
    local grouped={}; local exact=true
    for _,r in ipairs(snapshot.rows or {}) do
        if M.Positive(r.price) and M.Positive(r.quantity) and not r.own then
            local level=grouped[r.price]
            if not level then level={price=r.price,quantity=0};grouped[r.price]=level;d.levels[#d.levels+1]=level end
            level.quantity=level.quantity+r.quantity
            d.units=d.units+r.quantity;d.value=d.value+r.price*r.quantity
            if r.auctionID then d.listings=d.listings+1 else exact=false end
        end
    end
    if not exact then d.listings=nil end
    table.sort(d.levels,function(a,b) return a.price<b.price end)
    local cumulative=0
    for _,v in ipairs(d.levels) do
        cumulative=cumulative+v.quantity;v.cumulative=cumulative;v.share=100*v.quantity/d.units
        if not d.q25 and cumulative>=d.units*.25 then d.q25=v.price end
        if not d.median and cumulative>=d.units*.5 then d.median=v.price end
        if not d.q75 and cumulative>=d.units*.75 then d.q75=v.price end
    end
    if d.units>0 then d.minimum=d.levels[1].price;d.maximum=d.levels[#d.levels].price;d.mean=d.value/d.units end
    return d
end
local panel,key,widgets,notice=nil,nil,{},""
local function money(n)
    if not n then return "--" end
    n=math.floor(n+.5);return string.format("%dg %02ds %02dc",math.floor(n/10000),math.floor(n/100)%100,n%100)
end
local render
render=function()
    if not panel or not panel:IsShown() or not key or not M.market then return end
    local id=M.Key(key); local item=M.market.items[id];local snapshot=M.current[id];local d=M.DepthStats(snapshot)
    panel.name:SetText(item and item.name or ("Item "..key.itemID))
    local age=d.time and math.max(0,math.floor((time()-d.time)/60))
    panel.status:SetText((snapshot and (d.full and "Complete loaded results" or "PARTIAL loaded results").." | "..age.."m old"..(age>=15 and " | STALE" or "") or "No detailed listings loaded").."\n"..notice)
    panel.summary:SetText(string.format("Available units: %d    Price levels: %d    Auctions: %s\nLowest: %s    Median: %s    Highest: %s\nMiddle 50%% of units: %s - %s    Weighted average: %s",d.units,#d.levels,d.listings and tostring(d.listings) or "not available",money(d.minimum),money(d.median),money(d.maximum),money(d.q25),money(d.q75),money(d.mean)))
    if not snapshot then panel.summary:SetText("Click Refresh AH depth with the auction house open.\nA browse minimum alone does not reveal the price distribution.") end
    local columns={{"Unit price",170},{"Units",100},{"Share",100},{"Cumulative units",140},{"Supply distribution",230}}
    M.UI.Headers(panel,columns,-178)
    local rows=M.UI.Page(panel,d.levels,render)
    local maxUnits=1;for _,v in ipairs(d.levels) do maxUnits=math.max(maxUnits,v.quantity) end
    for i,v in ipairs(rows) do
        local w=M.UI.Row(panel.content,widgets,i,columns,{money(v.price),v.quantity,string.format("%.1f%%",v.share),v.cumulative,""},false)
        if not w.volume then w.volume=w:CreateTexture(nil,"ARTWORK");w.volume:SetPoint("LEFT",516,0);w.volume:SetHeight(12);w.volume:SetColorTexture(.2,.7,.65,.8) end
        w.volume:SetWidth(math.max(1,215*v.quantity/maxUnits))
        w:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:AddLine(v.quantity.." units at "..money(v.price).." each",1,1,1)
            GameTooltip:AddLine(v.cumulative.." units at this price or cheaper",.5,.9,.85);GameTooltip:Show()
        end)
        w:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    for i=#rows+1,#widgets do widgets[i]:Hide() end
    panel.content:SetHeight(math.max(1,#rows*32))
    panel.empty:SetText(snapshot and #rows==0 and "No competing buyout listings in the loaded results." or "")
end
function M.ShowMarketDepth(itemKey)
    if not M.market or not M.Key(itemKey) then return end
    key={itemID=itemKey.itemID,itemLevel=itemKey.itemLevel or 0,itemSuffix=itemKey.itemSuffix or 0,battlePetSpeciesID=itemKey.battlePetSpeciesID or 0};notice=""
    if not panel then
        panel=M.UI.Window("GuildMarketDepthFrame");panel:SetSize(800,580);panel:SetPoint("CENTER");panel:SetFrameStrata("FULLSCREEN_DIALOG");panel.TitleText:SetText("Market depth")
        panel:SetMovable(true);panel:EnableMouse(true);panel:RegisterForDrag("LeftButton");panel:SetScript("OnDragStart",panel.StartMoving);panel:SetScript("OnDragStop",panel.StopMovingOrSizing)
        table.insert(UISpecialFrames,"GuildMarketDepthFrame")
        panel.name=M.UI.Text(panel,16);panel.name:SetPoint("TOPLEFT",16,-42);panel.name:SetWidth(540)
        local b=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate");b:SetPoint("TOPRIGHT",-16,-38);b:SetSize(180,25);b:SetText("Refresh AH depth");M.UI.Button(b)
        b:SetScript("OnClick",function()
            local ok,msg=M.RefreshMarketItem(key,function(text) notice=text;render() end)
            if not ok then notice=msg;render() end
        end)
        panel.status=M.UI.Text(panel,13);panel.status:SetPoint("TOPLEFT",16,-78);panel.status:SetWidth(750)
        panel.summary=M.UI.Text(panel,13);panel.summary:SetPoint("TOPLEFT",16,-124);panel.summary:SetWidth(750)
        local scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",16,-206);scroll:SetPoint("BOTTOMRIGHT",-32,64);panel.gmtScroll=scroll
        panel.content=CreateFrame("Frame",nil,scroll);panel.content:SetSize(740,1);scroll:SetScrollChild(panel.content)
        panel.empty=M.UI.Text(panel,13);panel.empty:SetPoint("TOPLEFT",22,-214);panel.empty:SetWidth(730)
        local foot=M.UI.Text(panel,12);foot:SetPoint("BOTTOMLEFT",16,38);foot:SetWidth(750);foot:SetText("Asking supply, not sales volume. Own auctions excluded. Median and quartiles are weighted by units.")
    end
    if panel.gmtPager then panel.gmtPager.page=1 end
    panel.gmtScroll:SetVerticalScroll(0);panel:Show();render()
end
M.RefreshMarketDepth=render
function M.ShowRecipeDepth(recipe)
    if not recipe or not recipe.itemID then return end
    local best
    for _,v in pairs(M.market.items) do local k=v.key
        if k and k.itemID==recipe.itemID and (k.itemSuffix or 0)==0 and (k.battlePetSpeciesID or 0)==0 and (not best or v.time>best.time) then best=v end
    end
    if best then M.ShowMarketDepth(best.key)
    else
        local get=C_Item and C_Item.GetItemInfo or GetItemInfo
        local level=get and select(4,get(recipe.itemID))
        if type(level)=="number" then M.ShowMarketDepth({itemID=recipe.itemID,itemLevel=level})
        else print("Market depth: item data not loaded. Refresh the recipe prices first.") end
    end
end
