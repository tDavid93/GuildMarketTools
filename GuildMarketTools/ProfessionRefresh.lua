-- Explicit, sequential recipe-price queries. Never buys, crafts or runs a full scan.
local M=GuildMarketTools
function M.CreateProfessionRefresh(api,env)
    local Q={active=false}; local serial=0; local own=false; local queue,index,current,notify
    local advance,results
    local missing={}
    local function report(text) if notify then notify(text) end end
    function Q:Cancel(reason)
        if not self.active then return end
        self.active=false; serial=serial+1; current=nil
        report(reason or "Price refresh cancelled.")
    end
    local function allowed()
        if not env.open() or env.combat() then Q:Cancel("Refresh stopped: open the AH and leave combat."); return false end
        return true
    end
    local function send(fn,...)
        own=true; local ok=pcall(fn,...); own=false
        if not ok then Q:Cancel("AH request rejected. Retry Refresh prices.") end
        return ok
    end
    local function ready() return not api.IsThrottledMessageSystemReady or api.IsThrottledMessageSystemReady() end
    local function waitReady(fn)
        if not Q.active or not allowed() then return end
        if ready() then fn(); return end
        local token=serial
        env.after(.5,function() if Q.active and serial==token then waitReady(fn) end end)
    end
    advance=function()
        if not Q.active or not allowed() then return end
        index=index+1
        if index>#queue then Q.active=false; current=nil; serial=serial+1; report("AH refresh complete: "..#queue.." items checked."..(#missing>0 and (" No buyout listings: "..table.concat(missing,", ")..". Previous prices are not current offers.") or " Prices updated.")); return end
        current=queue[index]; current.pages=0; current.sent=false
        serial=serial+1; local token=serial
        report("Refreshing "..index.." / "..#queue..": "..current.name)
        env.after(20,function() if Q.active and serial==token then Q:Cancel("AH timeout for "..current.name..". Existing prices kept; retry.") end end)
        waitReady(function() current.sent=true; send(api.SendSearchQuery,current.key,{},true) end)
    end
    results=function(commodity,arg)
        if not Q.active or not current or not current.sent or not allowed() then return end
        if commodity then if arg~=current.key.itemID then return end
        elseif type(arg)~="table" or M.Key(arg)~=M.Key(current.key) then return end
        local key=current.key
        local full=commodity and api.HasFullCommoditySearchResults or api.HasFullItemSearchResults
        local count=commodity and api.GetNumCommoditySearchResults or api.GetNumItemSearchResults
        local get=commodity and api.GetCommoditySearchResultInfo or api.GetItemSearchResultInfo
        local target=commodity and key.itemID or key
        if not full or not count or not get then Q:Cancel("Client does not support this AH result type."); return end
        if not full(target) then
            if current.loadingMore then return end
            local more=commodity and api.RequestMoreCommoditySearchResults or api.RequestMoreItemSearchResults
            if not more or current.pages>=10 then Q:Cancel("Incomplete AH results; old price retained. Retry later."); return end
            current.loadingMore=true; current.pages=current.pages+1
            waitReady(function() current.loadingMore=false; send(more,target) end)
            return
        end
        local rows={}
        for i=1,(count(target) or 0) do
            local r=get(target,i)
            if r and M.Positive(r.quantity) and (commodity or (r.itemKey and M.Key(r.itemKey)==M.Key(key))) then
                rows[#rows+1]={price=commodity and r.unitPrice or (r.buyoutAmount and r.buyoutAmount/r.quantity),quantity=r.quantity,own=r.containsOwnerItem or r.containsAccountItem,auctionID=not commodity and r.auctionID or nil}
            end
        end
        if commodity then M.MarkCommodity(key.itemID); key={itemID=key.itemID} end
        local priced=false
        for _,row in ipairs(rows) do if M.Positive(row.price) and M.Positive(row.quantity) and not row.own then priced=true;break end end
        if not priced then missing[#missing+1]=current.name end
        M.Detail(key,rows,true,env.now(),current.name,current.link)
        current.sent=false
        local token=serial
        env.after(.3,function() if Q.active and serial==token then advance() end end)
        if env.changed then env.changed() end
    end
    function Q:Start(items,callback)
        if self.active then return false,"A recipe refresh is already running." end
        if not api or not api.SendSearchQuery then return false,"AH search API unavailable." end
        if not env.open() or env.combat() then return false,"Open the auction house and leave combat first." end
        if #items==0 then return false,"Select a recipe with a tradable output." end
        queue=items; index=0; missing={}; notify=callback; self.active=true; advance(); return true
    end
    function Q:Owns(key,commodity)
        if not self.active or not current or not current.sent then return false end
        return commodity and key==current.key.itemID or not commodity and type(key)=="table" and M.Key(key)==M.Key(current.key)
    end
    function Q:ExternalQuery() if not own then self:Cancel("Refresh stopped: another AH search started.") end end
    function Q:Event(event,arg)
        if event=="AUCTION_HOUSE_CLOSED" or event=="PLAYER_REGEN_DISABLED" then self:Cancel("Refresh stopped: AH closed or combat started.")
        elseif event=="ITEM_SEARCH_RESULTS_UPDATED" or event=="ITEM_SEARCH_RESULTS_ADDED" then results(false,arg)
        elseif event=="COMMODITY_SEARCH_RESULTS_UPDATED" or event=="COMMODITY_SEARCH_RESULTS_ADDED" then results(true,arg) end
    end
    return Q
end
local opened=false
local Q=M.CreateProfessionRefresh(C_AuctionHouse,{open=function() return opened end,combat=function() return InCombatLockdown() end,now=function() return time() end,after=function(s,f) C_Timer.After(s,f) end,changed=function() if M.RefreshAlchemy then M.RefreshAlchemy() end end})
function M.RefreshRecipePrices(recipe,callback)
    if not recipe or not recipe.itemID then return false,"Select a recipe first." end
    local ids={recipe.itemID}; for _,mat in ipairs(recipe.mats or {}) do if not (M.VendorMaterial and M.VendorMaterial(mat.id)) then ids[#ids+1]=mat.id end end
    for _,mat in ipairs(M.RecipeSetup and M.RecipeSetup(recipe) or {}) do ids[#ids+1]=mat.id end
    local items,seen={},{}
    for _,id in ipairs(ids) do
        if not seen[id] then
            seen[id]=true; local newest
            for _,v in pairs(M.market.items) do
                local k=v.key
                if k and k.itemID==id and (k.itemSuffix or 0)==0 and (k.battlePetSpeciesID or 0)==0 and (not newest or (v.time or 0)>(newest.time or 0)) then newest=v end
            end
            local key=newest and newest.key
            local get=C_Item and C_Item.GetItemInfo or GetItemInfo
            local name,link,_,level
            if get then name,link,_,level=get(id) end
            if not key and type(level)=="number" then key={itemID=id,itemLevel=level,itemSuffix=0,battlePetSpeciesID=0} end
            if not key then
                if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
                return false,"Item data loading ("..id.."). Retry in a moment."
            end
            items[#items+1]={key={itemID=key.itemID,itemLevel=key.itemLevel or 0,itemSuffix=0,battlePetSpeciesID=0},name=name or newest and newest.name or ("Item "..id),link=link or newest and newest.link}
        end
    end
    return Q:Start(items,callback)
end
function M.RefreshMarketItem(key,callback)
    local id=M.Key(key); if not id then return false,"Select an item first." end
    local item=M.market.items[id]
    return Q:Start({{key={itemID=key.itemID,itemLevel=key.itemLevel or 0,itemSuffix=key.itemSuffix or 0,battlePetSpeciesID=key.battlePetSpeciesID or 0},name=item and item.name or ("Item "..key.itemID),link=item and item.link}},callback)
end
M.CancelRecipeRefresh=function() Q:Cancel() end
M.RecipeRefreshOwns=function(key,commodity) return Q:Owns(key,commodity) end
local frame=CreateFrame("Frame")
for _,e in ipairs({"AUCTION_HOUSE_SHOW","AUCTION_HOUSE_CLOSED","PLAYER_REGEN_DISABLED","ITEM_SEARCH_RESULTS_UPDATED","ITEM_SEARCH_RESULTS_ADDED","COMMODITY_SEARCH_RESULTS_UPDATED","COMMODITY_SEARCH_RESULTS_ADDED"}) do frame:RegisterEvent(e) end
frame:SetScript("OnEvent",function(_,event,arg)
    if event=="AUCTION_HOUSE_SHOW" then opened=true elseif event=="AUCTION_HOUSE_CLOSED" then opened=false end
    Q:Event(event,arg)
end)
if hooksecurefunc and C_AuctionHouse then
    for _,name in ipairs({"SendSearchQuery","SendBrowseQuery","SendSellSearchQuery"}) do
        if C_AuctionHouse[name] then hooksecurefunc(C_AuctionHouse,name,function() Q:ExternalQuery() end) end
    end
end
