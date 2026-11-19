local M=GuildMarketTools
local api=C_AuctionHouse
local initialized,opened,panel,launcher,selected=false,false
local tab,filter="Deals",""
local sortColumn,descending=4,true
local widgets,fields={},{}
local pending,reading={},{}
local alerts={}
local detailTokens={}
local browseAt,epoch=nil,0
local queued=false
local render,show
local now=function() return time() end
local function money(n)
    if n==nil then return "--" end
    local sign=n<0 and "-" or ""; n=math.floor(math.abs(n)+0.5)
    return string.format("%s%dg %02ds %02dc",sign,math.floor(n/10000),math.floor(n/100)%100,n%100)
end
local function message(s) print("Guild Market: "..s) end
local function info(key)
    local get=C_Item and C_Item.GetItemInfo or GetItemInfo
    local link=api and api.GetItemKeySampleLink and api.GetItemKeySampleLink(key)
    local name,baseLink
    if get then name,baseLink=get(link or key.itemID) end
    return name,link or baseLink
end
local function redraw() if panel and panel:IsShown() then render() end end
local function schedule()
    if queued then return end; queued=true
    C_Timer.After(0.5,function() queued=false; redraw(); if M.RefreshAlchemy then M.RefreshAlchemy() end; if M.RefreshMarketDepth then M.RefreshMarketDepth() end; if M.RefreshCraftCosts then M.RefreshCraftCosts() end end)
end
local function browse()
    if not initialized or not opened or not browseAt or not api or not api.GetBrowseResults then return end
    if reading.browse then reading.again=true; return end
    reading.browse=true
    local results=api.GetBrowseResults() or {}; local i=1
    local observed,session=browseAt,epoch
    local function batch()
        if session~=epoch then return end
        if not opened then reading.browse=nil; return end
        local last=math.min(i+99,#results)
        for n=i,last do
            local r=results[n]
            if r.itemKey and not r.containsOwnerItem and M.Positive(r.minPrice) then
                local name,link=info(r.itemKey)
                M.Observe(r.itemKey,r.minPrice,r.totalQuantity,observed,name,link)
            end
        end
        i=last+1
        if i<=#results then C_Timer.After(0,batch)
        else
            reading.browse=nil; schedule()
            local hits=0
            for id in pairs(M.market.watch) do
                local d=M.Deal(id,now())
                if d and d.watched and not alerts[id] then alerts[id]=true; hits=hits+1 end
            end
            if hits>0 then message(hits.." watchlist item(s) below your buy limits. Open Market Tools > Watchlist.") end
            if reading.again then reading.again=nil; browse() end
        end
    end
    batch()
end
local function details(key,commodity)
    -- The explicit recipe refresh commits only complete results.
    if M.RecipeRefreshOwns and M.RecipeRefreshOwns(key,commodity) then return end
    if not initialized or not opened or not api then return end
    if commodity then M.MarkCommodity(key); key={itemID=key} end
    local id=M.Key(key); if not id then return end
    local count=commodity and api.GetNumCommoditySearchResults or api.GetNumItemSearchResults
    local get=commodity and api.GetCommoditySearchResultInfo or api.GetItemSearchResultInfo
    local complete=commodity and api.HasFullCommoditySearchResults or api.HasFullItemSearchResults
    if not count or not get then return end
    local arg=commodity and key.itemID or key
    local rows={}; local name,link=info(key)
    local token={}; detailTokens[id]=token
    local total=count(arg); local index=1; local observed=now()
    local function batch()
        if not opened or detailTokens[id]~=token then return end
        local last=math.min(index+99,total)
        for i=index,last do
            local r=get(arg,i)
            if r and M.Positive(r.quantity) and (commodity or M.Key(r.itemKey)==id) then
                rows[#rows+1]={price=commodity and r.unitPrice or (r.buyoutAmount and r.buyoutAmount/r.quantity),
                    quantity=r.quantity,own=r.containsOwnerItem or r.containsAccountItem,
                    auctionID=not commodity and r.auctionID or nil}
            end
        end
        index=last+1
        if index<=total then C_Timer.After(0,batch)
        else M.Detail(key,rows,complete and complete(arg),observed,name,link); schedule() end
    end
    batch()
end
local function search(item)
    if not opened then message("Open the auction house first."); return end
    if InCombatLockdown() then message("Leave combat before opening auctions."); return end
    local ah=AuctionHouseFrame
    if not ah or not ah.SearchBar or not ah.SearchBar.StartSearch then message("Search for this item in the AH manually."); return end
    local name=info(item.key)
    if not name then message("Item name is not loaded yet. Hover the item and try again."); return end
    -- Use the native search controls; never send custom queries or change filters in the background.
    local ok=pcall(function()
        ah:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
        ah:GetCategoriesList():SetSelectedCategory(nil)
        ah:SetSearchText(name); ah.SearchBar:StartSearch()
    end)
    if ok then panel:Hide() else message("Search could not start. Use the native AH Search button.") end
end
local function inputNumber(id,scale)
    local v=tonumber(((fields[id]:GetText() or ""):gsub(",",".")))
    return v and v*(scale or 1)
end
local function resetFields()
    for _,f in pairs(fields) do f:Hide(); f.label:Hide() end
end
local function setField(id,label,value,y)
    local f=fields[id]
    f.label:SetText(label); f.label:ClearAllPoints(); f.label:SetPoint("TOPLEFT",panel,850,y)
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",panel,850,y-18); f:SetText(value or ""); f:Show(); f.label:Show()
end
local function button(parent,text,width,x,y,callback)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(width,24); b:SetPoint("TOPLEFT",x,y); b:SetText(text); b:SetScript("OnClick",callback); return M.UI.Button(b)
end
local function addTooltip(w,d)
    w:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:AddLine(d.item.name,1,1,1)
        GameTooltip:AddLine(string.format("Variant: %s",d.id),0.7,0.7,0.7)
        GameTooltip:AddLine(string.format("Source: %s | %d history days",d.source,d.days),1,1,1)
        GameTooltip:AddLine("Target / unit: "..money(d.target).." | fee: "..M.settings.fee.."%",1,1,1)
        if M.market.watch[d.id] and M.market.watch[d.id].target then GameTooltip:AddLine("Target is your manual override.",1,0.8,0.3) end
        GameTooltip:AddLine("Relist reserve / unit: "..money(M.settings.deposit),1,1,1)
        GameTooltip:AddLine("Competing units at/below target: "..(d.below or "unknown"),1,1,1)
        GameTooltip:AddLine(d.partial and "Partial / summary data. Stock at the minimum is unknown." or "Full loaded results; prices may have changed.",1,0.8,0.3,true)
        GameTooltip:AddLine("Asking prices are not sales. Recheck price, quantity and variant.",1,0.8,0.3,true)
        if tab=="History" then
            local h=d.item.history
            GameTooltip:AddLine("Recent daily minimum asking prices",0.4,0.8,1)
            for i=math.max(1,#h-13),#h do GameTooltip:AddDoubleLine(date("%d %b",h[i].day*86400),money(h[i].price),1,1,1,1,1,1) end
        end
        GameTooltip:Show()
    end)
    w:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
local function selection()
    resetFields()
    for _,b in pairs(panel.actions) do b:Hide() end
    panel.detail:SetText("Select an item to inspect it.\n\nAll prices use gold inputs: 0.10 = 10 silver.\n\nData comes from your scans and searches. No background queries.")
    if tab=="Settings" then
        panel.detail:SetText("Profit assumptions\n\nSet the fee for your auction house. The relist reserve covers possible lost deposits; it is not an exact deposit quote.")
        setField("cap","AH cut (%)",M.settings.fee,-220)
        setField("target","Minimum discount (%)",M.settings.discount,-275)
        setField("quantity","Minimum profit / unit (gold)",M.settings.minProfit/10000,-330)
        setField("total","Relist reserve / unit (gold)",M.settings.deposit/10000,-385)
        panel.actions.settings:Show(); panel.actions.tooltip:Show(); return
    end
    if not selected then return end
    if tab=="Ledger" then
        local lot=selected; local remain,profit=M.Balance(lot)
        panel.detail:SetText(lot.name.."\nBought: "..lot.quantity.." for "..money(lot.cost).."\nRemaining: "..remain.."\nRealized P/L: "..money(profit).."\n"..lot.source.."\n"..date("%d %b %H:%M",lot.time))
        setField("quantity","Quantity sold",remain,-270)
        setField("total","Net received (gold), after all fees","",-325)
        panel.actions.sale:Show(); panel.actions.undo:Show(); return
    end
    local d=M.Deal(selected,now()); if not d then selected=nil; return end
    local watch=M.market.watch[selected]
    panel.detail:SetText(d.item.name.."\nBuy / unit: "..money(d.price).."\nReference: "..money(d.reference).."\nEst. profit / unit: "..money(d.profit).."\nConfidence: "..d.confidence.."\nAge: "..math.floor((now()-d.time)/60).." min")
    setField("cap","Watch buy limit / unit (gold)",watch and watch.cap/10000 or d.price/10000,-240)
    setField("target","Resale target / unit (gold, optional)",watch and watch.target and watch.target/10000 or "",-295)
    setField("quantity","Purchased quantity (manual entry)",d.quantity or 1,-380)
    setField("total","Actual total paid (gold)","",-435)
    panel.actions.depth:Show(); panel.actions.search:Show(); panel.actions.watch:Show(); panel.actions.remove:Show(); panel.actions.buy:Show()
end
render=function()
    if not initialized or not panel then return end
    local list={}; local t=now()
    if tab=="Deals" then list=M.Candidates(t)
    elseif tab=="History" or tab=="Watchlist" then
        for id in pairs(tab=="Watchlist" and M.market.watch or M.market.items) do
            local d=M.Deal(id,t); if d then list[#list+1]=d end
        end
        table.sort(list,function(a,b)
            if a.watched~=b.watched then return a.watched end
            if a.item.name==b.item.name then return a.id<b.id end
            return a.item.name<b.item.name
        end)
    elseif tab=="Ledger" then list=M.account.ledger end
    local visible={}
    for _,r in ipairs(list) do
        local name=r.item and r.item.name or r.name
        if filter=="" or name:lower():find(filter,1,true) then visible[#visible+1]=r end
    end
    panel.status:SetText(tab=="Settings" and "Settings apply immediately. History and journal are saved on logout / reload."
        or string.format("%s | %d matches | %s",tab,#visible,opened and "AH open" or "AH closed - cached data"))
    local columns={{"Item",265},{"Buy / unit",125},{"Reference",125},{"Profit / unit",125},{"Age",140}}
    if tab=="History" then columns[4][1]="History days"
    elseif tab=="Watchlist" then columns[3][1]="Buy limit"; columns[4][1]="Status"
    elseif tab=="Ledger" then columns[2][1]="Total paid"; columns[3][1]="Remaining"; columns[4][1]="Realized P/L"; columns[5][1]="Purchased" end
    local function value(r,c)
        if c==1 then return (r.item and r.item.name or r.name):lower() end
        if tab=="Ledger" then local left,profit=M.Balance(r); return ({r.name,r.cost,left,profit,r.time})[c] end
        if c==2 then return r.price elseif c==3 then return tab=="Watchlist" and M.market.watch[r.id].cap or r.reference
        elseif c==4 then return tab=="History" and r.days or tab=="Watchlist" and (r.watched and 1 or 0) or r.profit else return t-r.time end
    end
    M.UI.Sort(visible,sortColumn,descending,value)
    M.UI.Headers(panel,columns,-130,function(c) if c==sortColumn then descending=not descending else sortColumn=c; descending=c~=1 end; render() end)
    for _,h in ipairs(panel.gmtHeaders) do h:SetShown(tab~="Settings") end
    M.UI.Tabs(panel,tab)
    visible=M.UI.Page(panel,visible,render)
    local shown=#visible
    for i=1,shown do
        local r=visible[i]; local values
        if tab=="Ledger" then
            local remain,profit=M.Balance(r)
            values={r.name,money(r.cost),remain,money(profit),date("%d %b %H:%M",r.time)}
        else
            values={r.item.name,money(r.price),money(r.reference),money(r.profit),math.floor((t-r.time)/60).."m"}
            if tab=="History" then values[4]=r.days
            elseif tab=="Watchlist" then values[3]=money(M.market.watch[r.id].cap); values[4]=r.unavailable and "Unavailable" or t-r.time>900 and "Stale" or r.watched and "Below limit" or "Above limit" end
        end
        local w=M.UI.Row(panel.content,widgets,i,columns,values,selected==(tab=="Ledger" and r or r.id))
        w:SetScript("OnClick",function() selected=tab=="Ledger" and r or r.id; selection(); render() end)
        if tab=="Ledger" then w:SetScript("OnEnter",nil); w:SetScript("OnLeave",nil) else addTooltip(w,r) end
    end
    for i=shown+1,#widgets do widgets[i]:Hide() end
    panel.content:SetHeight(math.max(1,shown*32))
    panel.empty:SetText(#visible==0 and (tab=="Deals" and "No supported deals yet.\nOpen an item's auctions to compare its listings.\nHistory references need observations on 3 earlier days.\nOnly fresh data and deals above your profit threshold appear here."
        or tab=="History" and "Run your usual AH scan or search for an item.\nDaily minimum asking prices will appear here."
        or tab=="Watchlist" and "Select an item in History, enter a buy limit, then Save watch."
        or tab=="Ledger" and "Confirmed purchases appear here when exact costs are available.\nYou can also record a purchase from History.\nSales are reconciled manually using actual net proceeds."
        or "Profit settings\n\nAH cut reduces the estimated sale proceeds.\nMinimum discount and profit filter the Deals page.\nRelist reserve accounts for potentially lost deposits.\n\nAll money inputs are in gold: 0.10 = 10 silver.\nClick Save settings to apply changes.") or "")
    panel.footer:SetText("Click a column to sort. Select a row for details and actions.")
end
local function build()
    panel=M.UI.Window("GuildMarketToolsFrame")
    panel:SetSize(1160,680); panel:SetPoint("CENTER"); panel:SetFrameStrata("DIALOG")
    panel.TitleText:SetText("Guild Market Tools")
    panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart",panel.StartMoving); panel:SetScript("OnDragStop",panel.StopMovingOrSizing)
    table.insert(UISpecialFrames,"GuildMarketToolsFrame")
    for i,name in ipairs({"Deals","History","Watchlist","Ledger","Settings","Vendor","Professions"}) do
        button(panel,name,112,16+(i-1)*120,-32,function() if name=="Professions" then panel:Hide(); M.ShowAlchemy(); return end; if name=="Vendor" then panel:Hide(); M.ShowVendor(); return end; tab=name; selected=nil; sortColumn=name=="Deals" and 4 or name=="Ledger" and 5 or 1; descending=name=="Deals" or name=="Ledger"; if panel.gmtPager then panel.gmtPager.page=1 end; panel.scroll:SetVerticalScroll(0); render(); selection() end)
    end
    local searchBox=CreateFrame("EditBox",nil,panel,"InputBoxTemplate")
    searchBox:SetSize(220,22); searchBox:SetPoint("TOPLEFT",20,-69); searchBox:SetAutoFocus(false); searchBox:SetMaxLetters(80)
    searchBox:SetScript("OnTextChanged",function(self) filter=self:GetText():lower(); if panel.gmtPager then panel.gmtPager.page=1 end; panel.scroll:SetVerticalScroll(0); render() end)
    searchBox:SetScript("OnEscapePressed",searchBox.ClearFocus)
    button(panel,"Filter by name",125,250,-68,function() searchBox:SetFocus() end)
    button(panel,"Read loaded data",170,425,-68,function() browse(); redraw() end)
    panel.status=M.UI.Text(panel,13)
    panel.status:SetPoint("TOPLEFT",16,-102); panel.status:SetWidth(780); panel.status:SetJustifyH("LEFT")
    panel.scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
    panel.gmtScroll=panel.scroll
    panel.scroll:SetPoint("TOPLEFT",16,-158); panel.scroll:SetPoint("BOTTOMRIGHT",-335,48)
    panel.content=CreateFrame("Frame",nil,panel.scroll); panel.content:SetSize(780,1); panel.scroll:SetScrollChild(panel.content)
    panel.empty=panel:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    panel.empty:SetPoint("TOPLEFT",25,-180); panel.empty:SetWidth(560); panel.empty:SetJustifyH("LEFT")
    panel.detail=M.UI.Text(panel,13)
    panel.detail:SetPoint("TOPLEFT",850,-100); panel.detail:SetWidth(285); panel.detail:SetJustifyH("LEFT")
    panel.footer=M.UI.Text(panel,13)
    panel.footer:SetPoint("BOTTOMLEFT",16,18); panel.footer:SetWidth(780); panel.footer:SetJustifyH("LEFT")
    for _,id in ipairs({"cap","target","quantity","total"}) do
        local f=CreateFrame("EditBox",nil,panel,"InputBoxTemplate"); f:SetSize(260,22); f:SetAutoFocus(false); f:SetMaxLetters(16)
        f.label=M.UI.Text(panel,13); f:SetScript("OnEscapePressed",f.ClearFocus); fields[id]=f
    end
    panel.actions={}
    panel.actions.depth=button(panel,"Market depth",280,850,-535,function() local item=selected and M.market.items[selected]; if item then M.ShowMarketDepth(item.key) end end)
    panel.actions.search=button(panel,"Open auctions",280,850,-204,function() if selected then search(M.market.items[selected]) end end)
    panel.actions.watch=button(panel,"Save watch",135,850,-347,function()
        if fields.target:GetText()~="" and not inputNumber("target",10000) then message("Enter a valid resale target or leave it blank."); return end
        if M.Watch(selected,inputNumber("cap",10000),inputNumber("target",10000)) then alerts[selected]=nil; message("Watch saved."); redraw()
        else message("Enter a positive buy limit and an optional positive resale target.") end
    end)
    panel.actions.remove=button(panel,"Remove watch",135,995,-347,function() M.market.watch[selected]=nil; redraw(); selection() end)
    panel.actions.buy=button(panel,"Record manual purchase",280,850,-490,function()
        local item=M.market.items[selected]
        if item and M.Purchase(item.key,inputNumber("quantity"),inputNumber("total",10000),now(),"Manual") then
            message("Purchase recorded. Do not duplicate an automatic journal entry."); fields.total:SetText("")
        else message("Enter the purchased quantity and the actual total paid.") end
    end)
    panel.actions.sale=button(panel,"Record sale / vendor proceeds",280,850,-380,function()
        if M.Sale(selected,inputNumber("quantity"),inputNumber("total",10000),now()) then redraw(); selection()
        else message("Enter a valid remaining quantity and actual net proceeds.") end
    end)
    panel.actions.undo=button(panel,"Undo last sale entry",280,850,-415,function()
        if selected and #selected.sales>0 then table.remove(selected.sales); redraw(); selection() end
    end)
    panel.actions.tooltip=button(panel,"Toggle price tooltip",280,850,-480,function()
        local enabled=M.ToggleTooltip()
        message("Price tooltip: "..(enabled and "ON" or "OFF"))
    end)
    panel.actions.settings=button(panel,"Save settings",280,850,-445,function()
        local fee,discount,profit,deposit=inputNumber("cap"),inputNumber("target"),inputNumber("quantity",10000),inputNumber("total",10000)
        if fee and fee>=0 and fee<=30 and discount and discount>=1 and discount<=95 and profit and profit>=0 and deposit and deposit>=0 then
            M.settings.fee=fee; M.settings.discount=discount; M.settings.minProfit=profit; M.settings.deposit=deposit
            message("Settings saved."); redraw()
        else message("Fee: 0-30%; discount: 1-95%; profit and reserve must be non-negative.") end
    end)
    panel:SetScript("OnShow",function() render(); selection() end)
end
show=function()
    if not initialized then message("Wait until login is complete."); return end
    if M.HideAlchemy then M.HideAlchemy() end
    if not panel then build() end
    panel:Show(); render(); selection(); browse()
end
local function hooks()
    if not api or not hooksecurefunc then return end
    if api.PlaceBid then hooksecurefunc(api,"PlaceBid",function(id,amount)
        local r=M.auctions[id] or (M.FindShoppingAuction and M.FindShoppingAuction(id,amount))
        if r and amount==r.cost then pending[id]={row=r,time=now(),shopping=M.GetShoppingContext and M.GetShoppingContext(r.key.itemID)} end
    end) end
    if api.StartCommoditiesPurchase then hooksecurefunc(api,"StartCommoditiesPurchase",function(id,quantity)
        pending.commodity={id=id,quantity=quantity,time=now(),shopping=M.GetShoppingContext and M.GetShoppingContext(id)}
    end) end
    if api.ConfirmCommoditiesPurchase then hooksecurefunc(api,"ConfirmCommoditiesPurchase",function(id,quantity)
        local p=pending.commodity
        if p and p.id==id and p.quantity==quantity and now()-p.time<60 then p.confirmedCost=p.cost end
    end) end
    if api.CancelCommoditiesPurchase then hooksecurefunc(api,"CancelCommoditiesPurchase",function() pending.commodity=nil end) end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","AUCTION_HOUSE_SHOW","AUCTION_HOUSE_CLOSED","AUCTION_HOUSE_BROWSE_RESULTS_UPDATED","AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
    "ITEM_SEARCH_RESULTS_UPDATED","ITEM_SEARCH_RESULTS_ADDED","COMMODITY_SEARCH_RESULTS_UPDATED","COMMODITY_SEARCH_RESULTS_ADDED",
    "AUCTION_HOUSE_PURCHASE_COMPLETED","COMMODITY_PRICE_UPDATED","COMMODITY_PURCHASED","COMMODITY_PURCHASE_SUCCEEDED","COMMODITY_PURCHASE_FAILED","COMMODITY_PRICE_UNAVAILABLE"}) do
    pcall(events.RegisterEvent,events,event)
end
events:SetScript("OnEvent",function(_,event,a,b)
    if event=="PLAYER_LOGIN" then
        -- Copy legacy local data after all enabled addons have loaded. Never ship it.
        local function copy(value)
            if type(value)~="table" then return value end
            local result={}; for k,v in pairs(value) do result[k]=copy(v) end; return result
        end
        GuildMarketToolsDB=GuildMarketToolsDB or copy(AngusMarketDB) or {}
        local realm=GetRealmName(); local faction=UnitFactionGroup("player") or "Unknown"
        M.Init(GuildMarketToolsDB,realm..":"..faction,realm..":"..UnitName("player"),now()); initialized=true; hooks(); if M.CreateMinimapLauncher then M.CreateMinimapLauncher(show) end
    elseif not initialized then return
    elseif event=="AUCTION_HOUSE_SHOW" then
        opened=true
        if not launcher then
            local parent=AuctionHouseFrame or UIParent
            launcher=button(parent,"|TInterface\\Icons\\INV_Misc_Coin_01:16:16|t Market Tools",160,0,0,show)
            launcher:ClearAllPoints()
            launcher:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-36,-2)
            launcher:SetScript("OnEnter",function(self)
                GameTooltip:SetOwner(self,"ANCHOR_BOTTOM")
                GameTooltip:AddLine("Market Tools",1,0.82,0)
                GameTooltip:AddLine("Deals, price history, watchlist and purchase journal.",1,1,1)
                GameTooltip:Show()
            end)
            launcher:SetScript("OnLeave",function() GameTooltip:Hide() end)
        end
        -- Stock AH title chrome sits above ordinary child buttons. The EUI skin
        -- hid that chrome, so the launcher previously only appeared with it on.
        local parent=launcher:GetParent()
        launcher:SetFrameStrata("DIALOG")
        launcher:SetFrameLevel(parent:GetFrameLevel()+20)
        launcher:Show(); schedule()
    elseif event=="AUCTION_HOUSE_CLOSED" then
        opened=false; pending={}; detailTokens={}; browseAt=nil; epoch=epoch+1
        reading.browse=nil; reading.again=nil
        if launcher then launcher:Hide() end; schedule()
    elseif event=="AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event=="AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then browseAt=now(); browse()
    elseif event=="ITEM_SEARCH_RESULTS_UPDATED" or event=="ITEM_SEARCH_RESULTS_ADDED" then details(a,false)
    elseif event=="COMMODITY_SEARCH_RESULTS_UPDATED" or event=="COMMODITY_SEARCH_RESULTS_ADDED" then details(a,true)
    elseif event=="COMMODITY_PRICE_UPDATED" then
        local p=pending.commodity
        if p and M.Positive(b) and now()-p.time<60 then p.cost=b end
    elseif event=="COMMODITY_PURCHASE_FAILED" or event=="COMMODITY_PRICE_UNAVAILABLE" then pending.commodity=nil
    elseif event=="COMMODITY_PURCHASED" or event=="COMMODITY_PURCHASE_SUCCEEDED" then
        local p=pending.commodity; pending.commodity=nil
        if p and p.confirmedCost and (event=="COMMODITY_PURCHASE_SUCCEEDED" or (p.id==a and p.quantity==b)) and now()-p.time<60 then
            local lot=M.Purchase({itemID=p.id},p.quantity,p.confirmedCost,now(),"Confirmed commodity purchase"); if M.RecordShoppingPurchase then M.RecordShoppingPurchase(lot,p.shopping) end; schedule()
        elseif p then message("Purchase received without a verified price. Record it manually in Market Tools.") end
    elseif event=="AUCTION_HOUSE_PURCHASE_COMPLETED" then
        local p=pending[a]; pending[a]=nil
        if p and now()-p.time<120 then
            local r=p.row; local lot=M.Purchase(r.key,r.quantity,r.cost,now(),"Confirmed AH purchase","auction:"..a); if M.RecordShoppingPurchase then M.RecordShoppingPurchase(lot,p.shopping) end; schedule()
        else message("Purchase received without a verified price. Record it manually in Market Tools.") end
    end
end)
SLASH_ANGUSMARKET1="/angusmarket"
SlashCmdList.ANGUSMARKET=show

M.OpenTab=function(name)
    if name=="Professions" or name=="Alchemy" then M.ShowAlchemy(); return end
    tab=name or "Deals"; selected=nil
    if M.HideVendor then M.HideVendor() end
    show()
end
M.HideMarket=function() if panel then panel:Hide() end end
SLASH_GUILDMARKETTOOLS1="/gmtools"
SLASH_GUILDMARKETTOOLS2="/guildmarket"
SlashCmdList.GUILDMARKETTOOLS=show
