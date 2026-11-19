
-- Snapshots identify candidates; the separate buyer verifies exact-price buyouts.
do
    local panel, output, status
    local opened, generation, source = false, 0, "list"
    local observedAt, rows, pending, scanned = nil, {}, 0, 0
    local browseMode = false
    local displayedRows = {}
    local lineWidgets = {}
    local sortColumn,descending=4,true
    local buyer, buyButton, verifyButton, quoteText, budgetText
    local nextCandidate=1
    local categoryOnly=false
    local ownCategoryRequest=false
    local categories={{"Weapons",2},{"Armor",4},{"Containers",1},{"Consumables",0},{"Trade Goods",7},{"Recipes",9},{"Miscellaneous",15}}
    local function categoryConfig()
        GuildMarketToolsDB=GuildMarketToolsDB or {}
        GuildMarketToolsDB.vendorCategories=GuildMarketToolsDB.vendorCategories or {[2]=true,[4]=true}
        return GuildMarketToolsDB.vendorCategories
    end
    local function buyConfig()
        GuildMarketToolsDB=GuildMarketToolsDB or {}
        GuildMarketToolsDB.vendorBuy=GuildMarketToolsDB.vendorBuy or {limit=10000,reserve=100000,reserved=0}
        return GuildMarketToolsDB.vendorBuy
    end
    local function navigate(_,href)
        local index=tonumber(href:match("^angusdeal:(%d+)$"))
        local row=index and displayedRows[index]
        if not row then return end
        if not opened then status:SetText("Open the auction house first."); return end
        if InCombatLockdown and InCombatLockdown() then status:SetText("Leave combat before opening auction results."); return end
        local ah=AuctionHouseFrame
        if not row.browseResult or not ah or type(ah.SelectBrowseResult)~="function" then
            status:SetText("Direct navigation unavailable. Search in the AH: "..row.name); return
        end
        local ok=pcall(ah.SelectBrowseResult,ah,row.browseResult)
        if not ok and ah.SearchBar and ah.SearchBar.StartSearch and ah.SetSearchText and AuctionHouseFrameDisplayMode then
            -- Summary scans may lack metadata required for direct selection.
            local getInfo=C_Item and C_Item.GetItemInfo or GetItemInfo
            local name=(getInfo and getInfo(row.browseResult.itemKey.itemID)) or row.name
            ok=pcall(function()
                ah:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
                ah:GetCategoriesList():SetSelectedCategory(nil)
                ah:SetSearchText(name)
                ah.SearchBar:StartSearch()
            end)
        end
        if ok then panel:Hide()
        else status:SetText("Could not open results. Refresh the AH and try again.") end
    end
    local function hasReplicate()
        local api=C_AuctionHouse
        return api and type(api.GetNumReplicateItems)=="function"
            and type(api.GetReplicateItemInfo)=="function" and type(api.GetReplicateItemLink)=="function"
    end
    local function coins(value)
        return string.format("%dg %ds %dc",math.floor(value/10000),math.floor(value/100)%100,value%100)
    end
    local function buyerUI()
        if not quoteText or not buyer then return end
        quoteText:SetText(buyer.message)
        buyButton:SetEnabled(buyer.state=="ready")
        buyButton:SetText(buyer.quote and ("Buy exact: "..coins(buyer.quote.cost)) or "Buy exact quote")
        verifyButton:SetEnabled(buyer.state~="pending" and buyer.state~="querying")
        local c=buyConfig()
        budgetText:SetText("Remaining budget: "..coins(math.max(0,c.limit-c.reserved)).." | Keep: "..coins(c.reserve))
    end
    local function createBuyer()
        if buyer then return end
        buyer=GuildMarketTools.CreateVendorBuyer(C_AuctionHouse,{
            config=buyConfig,open=function() return opened and panel and panel:IsShown() end,
            combat=function() return InCombatLockdown and InCombatLockdown() end,
            now=GetTime,money=GetMoney,after=C_Timer.After,coins=coins,changed=buyerUI,
            isItem=function(info)
                return Enum and Enum.ItemCommodityStatus and info.commodityStatus==Enum.ItemCommodityStatus.Item
            end,
            item=function(link)
                local get=C_Item and C_Item.GetItemInfo or GetItemInfo
                local name,_,_,_,_,_,_,_,_,_,vendor=get(link)
                return name,vendor
            end,
            alert=function() if PlaySound then PlaySound(8959,"Master") end end,
        })
    end
    local function verifyNext()
        if buyer.state=="querying" or buyer.state=="pending" then return end
        -- Candidates only seed searches; no purchase is submitted here.
        local row=rows[nextCandidate]
        if not row then nextCandidate=1; row=rows[1] end
        if row then nextCandidate=nextCandidate+1 end
        buyer:Verify(row and row.browseResult and row.browseResult.itemKey,row and row.cost)
    end
    local function adapter()
        browseMode=false
        local api=C_AuctionHouse
        if api and type(api.GetBrowseResults)=="function" then
            local results=api.GetBrowseResults()
            if type(results)=="table" and (#results>0 or categoryOnly) then
                browseMode=true
                local getInfo=C_Item and C_Item.GetItemInfo or GetItemInfo
                local function linkFor(i)
                    local key=results[i].itemKey
                    if not key then return end
                    local link=api.GetItemKeySampleLink and api.GetItemKeySampleLink(key)
                    -- Summary scans can omit sample links. Item IDs are also
                    -- accepted by GetItemInfo for the base item's vendor price.
                    if link and getInfo and type(select(11,getInfo(link)))=="number" then return link end
                    return key.itemID
                end
                return #results,function(i)
                    local r=results[i]
                    local link=linkFor(i)
                    local name=link and getInfo and getInfo(link)
                    -- Browse minimums are not a complete stack quote. Compare
                    -- against ONE item's vendor value, never totalQuantity.
                    return name or "Unknown item",nil,1,nil,nil,nil,nil,nil,nil,
                        r.containsOwnerItem and 0 or r.minPrice
                end,linkFor,function(i)
                    local r=results[i]
                    local key=r.itemKey
                    return {itemKey={itemID=key.itemID,itemLevel=key.itemLevel,itemSuffix=key.itemSuffix,
                        battlePetSpeciesID=key.battlePetSpeciesID},minPrice=r.minPrice,
                        totalQuantity=r.totalQuantity,containsOwnerItem=r.containsOwnerItem}
                end
            end
        end
        local legacy=GetNumAuctionItems and GetAuctionItemInfo and GetAuctionItemLink
        if hasReplicate() and (source=="replicate" or not legacy) then
            return C_AuctionHouse.GetNumReplicateItems(), function(i)
                return C_AuctionHouse.GetReplicateItemInfo(i-1)
            end, function(i) return C_AuctionHouse.GetReplicateItemLink(i-1) end
        end
        if legacy then
            return GetNumAuctionItems("list"),function(i) return GetAuctionItemInfo("list",i) end,
                function(i) return GetAuctionItemLink("list",i) end
        end
    end
    local function draw()
        if not panel then return end
        local age = observedAt and math.floor(GetTime()-observedAt)
        status:SetText(not opened and "Auction house closed - reopen and refresh listings."
            or not age and string.format("%d results checked | %d missing item prices | cache age unknown",scanned,pending)
            or string.format("%d listings checked | %d missing item prices | snapshot %ds old",scanned,pending,age))
        if categoryOnly and opened then
            local full=C_AuctionHouse.HasFullBrowseResults and C_AuctionHouse.HasFullBrowseResults()
            status:SetText(string.format("Category results: %d checked | %d missing prices | %s",scanned,pending,
                full and "All returned results loaded" or "Partial / waiting - Load more for the next page"))
        end
        displayedRows=rows
        local columns={{"Item",420},{browseMode and "AH min / unit" or "Buy stack",185},{browseMode and "Vendor / unit" or "Vendor stack",185},{"Difference",180},{"Qty",120}}
        GuildMarketTools.UI.Sort(rows,sortColumn,descending,function(r,c)
            if c==1 then return r.name:lower() elseif c==2 then return r.cost elseif c==3 then return r.vendor elseif c==4 then return r.gain else return r.count end
        end)
        GuildMarketTools.UI.Headers(panel,columns,-148,function(c) if c==sortColumn then descending=not descending else sortColumn=c; descending=c~=1 end; draw() end)
        GuildMarketTools.UI.Tabs(panel,"Vendor")
        local pageRows,offset=GuildMarketTools.UI.Page(panel,rows,draw)
        for i,row in ipairs(pageRows) do
            local w=GuildMarketTools.UI.Row(output,lineWidgets,i,columns,{row.name,coins(row.cost),coins(row.vendor),coins(row.gain),browseMode and "?" or row.count},false)
            w.dealIndex=i+offset
            w:SetScript("OnClick",function(self) navigate(self,"angusdeal:"..self.dealIndex) end)
            w:SetScript("OnEnter",function(self)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(row.name,1,1,1)
                GameTooltip:AddLine("Click to open auctions. Verify before buying.",.5,.9,.85)
                GameTooltip:AddLine(browseMode and "Browse minimum only; stack price must be verified." or "Snapshot listing; availability may have changed.",1,.8,.4,true); GameTooltip:Show()
            end)
            w:SetScript("OnLeave",function() GameTooltip:Hide() end)
        end
        for i=#pageRows+1,#lineWidgets do lineWidgets[i]:Hide(); lineWidgets[i].dealIndex=nil end
        output:SetHeight(math.max(1,#pageRows*32))
        panel.empty:SetText(#rows==0 and (scanned==0 and "No auction data loaded. Search selected categories or read cached data." or "No vendor opportunities in the loaded results.") or "")

    end
    local function scan()
        generation=generation+1
        local token=generation
        rows,pending,scanned={},0,0
        if not opened then draw(); return end
        local ok,count,getRow,getLink,getBrowseResult=pcall(adapter)
        if not ok or type(count)~="number" or not getRow then
            observedAt=nil; draw()
            if status then status:SetText("No compatible auction results API. No prices assumed.") end
            return
        end
        local getInfo=C_Item and C_Item.GetItemInfo or GetItemInfo
        if not getInfo then return end
        local index=1
        local function batch()
            if token~=generation or not opened then return end
            local last=math.min(index+99,count)
            for i=index,last do
                local valid,name,_,quantity,_,_,_,_,_,_,buyout,_,_,_,owner,fullOwner,saleStatus=pcall(getRow,i)
                if valid and name and type(quantity)=="number" and quantity>0 and type(buyout)=="number" and buyout>0 and (not saleStatus or saleStatus==0) then
                    local linkOK,link=pcall(getLink,i)
                    local vendor=linkOK and link and select(11,getInfo(link))
                    if type(vendor)~="number" then pending=pending+1
                    elseif vendor>0 and vendor*quantity-buyout>=(browseMode and 1 or 100) and owner~=UnitName("player") then
                        rows[#rows+1]={name=name,count=quantity,cost=buyout,vendor=vendor*quantity,gain=vendor*quantity-buyout,owner=fullOwner or owner,
                            browseResult=getBrowseResult and getBrowseResult(i)}
                    end
                end
                scanned=scanned+1
            end
            index=last+1
            if index<=count then C_Timer.After(0,batch)
            else
                table.sort(rows,function(a,b) return a.gain>b.gain end)
                draw()
            end
        end
        batch()
    end
    local function useCache()
        scan()
        if status and opened and scanned==0 and not categoryOnly then
            status:SetText("No cached listings yet. Search selected categories or run your usual AH scan.")
        end
    end
    local function categorySearch(more)
        if not opened then status:SetText("Open the auction house first."); return end
        if InCombatLockdown and InCombatLockdown() then status:SetText("Leave combat before searching."); return end
        if buyer and (buyer.state=="pending" or buyer.state=="querying") then
            status:SetText("Wait for the current verification / purchase to finish."); return
        end
        local api=C_AuctionHouse
        if not api or not api.SendBrowseQuery or not api.GetBrowseResults then
            status:SetText("Category search API unavailable. Use the native AH filters."); return
        end
        if api.IsThrottledMessageSystemReady and not api.IsThrottledMessageSystemReady() then
            status:SetText("AH busy. Wait for the current scan, then retry."); return
        end
        if more then
            if not categoryOnly or not api.RequestMoreBrowseResults or not api.HasFullBrowseResults then
                status:SetText("Search selected categories first."); return
            end
            if api.HasFullBrowseResults() then status:SetText("All category results already loaded."); return end
        end
        local filters={}
        for _,entry in ipairs(categories) do
            if categoryConfig()[entry[2]] then filters[#filters+1]={classID=entry[2]} end
        end
        if #filters==0 then status:SetText("Select at least one category. No full-AH search sent."); return end
        if buyer then buyer:Cancel() end
        nextCandidate=1
        categoryOnly=true
        local ok
        if more then ok=pcall(api.RequestMoreBrowseResults)
        else
            generation=generation+1; rows={}; scanned=0; pending=0; observedAt=nil; draw()
            ownCategoryRequest=true
            ok=pcall(api.SendBrowseQuery,{searchString="",sorts={},filters={},itemClassFilters=filters})
            ownCategoryRequest=false
        end
        status:SetText(ok and "Waiting for category results. No full-AH scan requested."
            or "Category request rejected. Retry when the AH is ready.")
    end
    local function show()
        if GuildMarketTools.HideAlchemy then GuildMarketTools.HideAlchemy() end
        if not panel then
            panel=GuildMarketTools.UI.Window("GuildMarketVendorFrame")
            panel:SetSize(1160,680); panel:SetPoint("CENTER"); panel:SetFrameStrata("DIALOG")
            panel.TitleText:SetText("Guild Market Tools")
            panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
            panel:SetScript("OnDragStart",panel.StartMoving); panel:SetScript("OnDragStop",panel.StopMovingOrSizing)
            status=GuildMarketTools.UI.Text(panel,13)
            status:SetPoint("TOPLEFT",16,-122); status:SetWidth(920); status:SetJustifyH("LEFT")
            for i,entry in ipairs(categories) do
                local id=entry[2]
                local check=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
                check:SetSize(24,24); check:SetPoint("TOPLEFT",16+(i-1)*130,-65)
                check:SetChecked(categoryConfig()[id])
                local label=check:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                label:SetPoint("LEFT",check,"RIGHT",0,0); label:SetText(entry[1])
                check:SetScript("OnClick",function(self) categoryConfig()[id]=not not self:GetChecked() end)
            end
            local search=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
            search:SetSize(200,24); search:SetPoint("TOPLEFT",16,-94); search:SetText("Search selected categories")
            search:SetScript("OnClick",function() categorySearch(false) end)
            local more=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
            more:SetSize(120,24); more:SetPoint("TOPLEFT",224,-94); more:SetText("Load more")
            more:SetScript("OnClick",function() categorySearch(true) end)
            local scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate"); panel.gmtScroll=scroll
            scroll:SetPoint("TOPLEFT",16,-178); scroll:SetPoint("BOTTOMRIGHT",-32,140)
            local content=CreateFrame("Frame",nil,scroll); content:SetSize(1090,1); scroll:SetScrollChild(content)
            output=content
            panel.empty=GuildMarketTools.UI.Text(panel,14); panel.empty:SetPoint("TOPLEFT",24,-195); panel.empty:SetWidth(1070)
            local refresh=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
            refresh:SetSize(200,24); refresh:SetPoint("BOTTOMLEFT",16,14); refresh:SetText("Use cached data (no request)")
            refresh:SetScript("OnClick",function() buyer:Cancel(); nextCandidate=1; useCache() end)
            quoteText=GuildMarketTools.UI.Text(panel,13)
            quoteText:SetPoint("BOTTOMLEFT",16,112); quoteText:SetWidth(920); quoteText:SetJustifyH("LEFT")
            budgetText=GuildMarketTools.UI.Text(panel,13)
            budgetText:SetPoint("BOTTOMLEFT",16,91)
            verifyButton=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
            verifyButton:SetSize(160,26); verifyButton:SetPoint("BOTTOMLEFT",16,54); verifyButton:SetText("Verify next")
            verifyButton:SetScript("OnClick",verifyNext)
            buyButton=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
            buyButton:SetSize(230,26); buyButton:SetPoint("BOTTOMLEFT",184,54)
            buyButton:SetScript("OnClick",function() buyer:Buy() end)
            local function field(label,x,value)
                local f=CreateFrame("EditBox",nil,panel,"InputBoxTemplate")
                f:SetSize(70,24); f:SetPoint("BOTTOMLEFT",x,54); f:SetAutoFocus(false); f:SetMaxLetters(8); f:SetText(tostring(value/10000))
                local l=GuildMarketTools.UI.Text(panel,13); l:SetPoint("BOTTOMLEFT",x,80); l:SetText(label)
                return f
            end
            local c=buyConfig()
            local limit=field("Total cap (gold)",435,c.limit)
            local reserve=field("Keep (gold)",555,c.reserve)
            local save=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
            save:SetSize(150,24); save:SetPoint("BOTTOMLEFT",650,54); save:SetText("Save limits")
            save:SetScript("OnClick",function()
                local a,b=tonumber(limit:GetText()),tonumber(reserve:GetText())
                if not a or not b or a~=a or b~=b or a<0 or b<0 or a>100000 or b>100000 then return end
                buyer:Cancel(); c.limit=math.floor(a*10000+0.5); c.reserve=math.floor(b*10000+0.5)
                limit:ClearFocus(); reserve:ClearFocus(); buyerUI()
            end)
            createBuyer()
            panel:SetScript("OnHide",function() buyer:Cancel() end)
            for i,name in ipairs({"Deals","History","Watchlist","Ledger","Settings","Vendor","Professions"}) do
                local b=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
                b:SetSize(112,24); b:SetPoint("TOPLEFT",16+(i-1)*120,-32); b:SetText(name)
                b:SetScript("OnClick",function()
                    if name=="Vendor" then useCache() else GuildMarketTools.OpenTab(name) end
                end)
            end
            table.insert(UISpecialFrames,"GuildMarketVendorFrame")
        end
        panel:Show(); useCache(); buyerUI()
    end
    local events=CreateFrame("Frame")
    if hooksecurefunc and C_AuctionHouse and C_AuctionHouse.SendBrowseQuery then
        hooksecurefunc(C_AuctionHouse,"SendBrowseQuery",function()
            if not ownCategoryRequest then categoryOnly=false end
        end)
    end
    for _,event in ipairs({"AUCTION_HOUSE_SHOW","AUCTION_HOUSE_CLOSED","AUCTION_ITEM_LIST_UPDATE","REPLICATE_ITEM_LIST_UPDATE","AUCTION_HOUSE_BROWSE_RESULTS_UPDATED","AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
        "ITEM_SEARCH_RESULTS_UPDATED","ITEM_SEARCH_RESULTS_ADDED","COMMODITY_SEARCH_RESULTS_UPDATED","AUCTION_HOUSE_PURCHASE_COMPLETED","AUCTION_HOUSE_SHOW_ERROR","PLAYER_REGEN_DISABLED"}) do
        pcall(events.RegisterEvent,events,event)
    end
    events:SetScript("OnEvent",function(_,event,arg)
        if buyer then buyer:Event(event,arg) end
        if event=="AUCTION_HOUSE_SHOW" then
            categoryOnly=false
            opened=true; source=hasReplicate() and "replicate" or "list"; observedAt=nil; rows={}
            draw()
        elseif event=="AUCTION_HOUSE_CLOSED" then
            categoryOnly=false
            opened=false; generation=generation+1; rows={}; draw()
        elseif event=="AUCTION_ITEM_LIST_UPDATE" or event=="REPLICATE_ITEM_LIST_UPDATE" or event=="AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event=="AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
            source=event=="REPLICATE_ITEM_LIST_UPDATE" and "replicate" or "list"
            observedAt=GetTime()
            scan()
        end
    end)
    SLASH_ANGUSDEALS1="/angusdeals"
    SlashCmdList.ANGUSDEALS=show
    SLASH_GUILDVENDOR1="/gmvendor"
    SlashCmdList.GUILDVENDOR=show
    GuildMarketTools.ShowVendor=show
    GuildMarketTools.HideVendor=function() if panel then panel:Hide() end end
end
