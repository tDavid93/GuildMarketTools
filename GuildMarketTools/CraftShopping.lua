local M=GuildMarketTools
local panel,recipe,notice=nil,nil,"";local widgets={};local render
local function copy(v) if type(v)~="table" then return v end;local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
function M.StartCraftShopping(r,crafts)
    if not M.account or not r or r.unsupported or not M.Positive(crafts) or crafts%1~=0 or not r.mats or #r.mats==0 then return false,"Choose a supported recipe and a whole craft count." end
    M.account.shoppingPlans=M.account.shoppingPlans or {}
    local plan=M.account.activeShoppingPlan
    if plan and M.account.shoppingPlans[plan.id] then plan=M.account.shoppingPlans[plan.id];M.account.activeShoppingPlan=plan end
    if not plan or plan.recipe.id~=r.id or plan.finished then
        M.account.nextShoppingID=(M.account.nextShoppingID or 0)+1
        plan={id=M.account.nextShoppingID,recipe=copy(r),started=time(),includeSetup=M.RecipeSetup and #M.RecipeSetup(r)>0 or false}
        M.account.shoppingPlans[plan.id]=plan;M.account.activeShoppingPlan=plan
    end
    if plan.includeSetup==nil then plan.includeSetup=M.RecipeSetup and #M.RecipeSetup(r)>0 or false end
    plan.recipe=copy(r)
    plan.crafts=crafts;plan.needs={}
    for _,mat in ipairs(r.mats) do plan.needs[mat.id]=(plan.needs[mat.id] or 0)+mat.count*crafts end
    if M.AddSetupNeeds then M.AddSetupNeeds(plan.needs,r,plan) end
    return plan
end
-- Freeze the selected shopping intent when a purchase starts, not on success.
function M.GetShoppingContext(itemID)
    local p=M.account and M.account.activeShoppingPlan
    if p and not p.finished and p.selectedItem==itemID and p.needs[itemID] then return {planID=p.id,itemID=itemID} end
end
-- Capture the exact loaded native buyout when the passive cache has not caught up.
function M.FindShoppingAuction(auctionID,amount)
    local plan=M.account and M.account.activeShoppingPlan
    local api=C_AuctionHouse
    if not plan or not plan.selectedItem or not api or not api.GetNumItemSearchResults or not api.GetItemSearchResultInfo then return end
    local key=plan.selectedKey
    if not key then return end
    for i=1,(api.GetNumItemSearchResults(key) or 0) do
        local r=api.GetItemSearchResultInfo(key,i)
        if r and r.auctionID==auctionID and r.buyoutAmount==amount and M.Positive(r.quantity)
            and r.itemKey and r.itemKey.itemID==plan.selectedItem and not r.containsOwnerItem and not r.containsAccountItem then
            return {key=copy(r.itemKey),quantity=r.quantity,cost=amount,name=plan.selectedName,link=r.itemLink,time=time()}
        end
    end
end
function M.RecordShoppingPurchase(lot,context)
    if not lot or not context or lot.key.itemID~=context.itemID then return false end
    local p=M.account.shoppingPlans and M.account.shoppingPlans[context.planID]
    if not p or not p.needs[context.itemID] then return false end
    lot.shoppingPlanID=context.planID;lot.shoppingRecipeID=p.recipe.id
    if M.RefreshCraftShopping then M.RefreshCraftShopping() end
    if M.RefreshCraftCosts then M.RefreshCraftCosts() end
    return true
end
function M.ShoppingTotals(plan,itemID)
    local quantity,cost=0,0
    for _,lot in ipairs(M.account.ledger) do
        if lot.shoppingPlanID==plan.id and lot.key.itemID==itemID then quantity=quantity+lot.quantity;cost=cost+lot.cost end
    end
    return quantity,cost
end
function M.OpenShoppingMaterial(itemID)
    local plan=M.account and M.account.activeShoppingPlan
    if not plan or not plan.needs[itemID] then return false,"Start a shopping plan first." end
    local vendor=M.VendorMaterial and M.VendorMaterial(itemID)
    if vendor then plan.selectedItem=nil;return false,"Buy this material from a vendor. Open the supplier to update its unit price." end
    local ah=AuctionHouseFrame
    if not ah or not ah:IsShown() then return false,"Open the auction house first." end
    if InCombatLockdown() then return false,"Leave combat before searching." end
    local get=C_Item and C_Item.GetItemInfo or GetItemInfo
    local name=get and get(itemID)
    if not name then if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end;return false,"Item name loading; click again in a moment." end
    if M.CancelRecipeRefresh then M.CancelRecipeRefresh() end
    plan.selectedItem=itemID
    local api=C_AuctionHouse
    local results=api and api.GetBrowseResults and api.GetBrowseResults() or {}
    local found
    for _,r in ipairs(results) do local k=r.itemKey;if k and k.itemID==itemID and (k.itemSuffix or 0)==0 and (k.battlePetSpeciesID or 0)==0 then found=r;break end end
    plan.selectedName=name;plan.selectedKey=found and copy(found.itemKey) or nil
    if not plan.selectedKey then
        local latest
        for _,v in pairs(M.market.items) do if v.key and v.key.itemID==itemID and (v.key.itemSuffix or 0)==0 and (not latest or v.time>latest.time) then latest=v end end
        if latest then plan.selectedKey=copy(latest.key)
        elseif get then local level=select(4,get(itemID));if type(level)=="number" then plan.selectedKey={itemID=itemID,itemLevel=level,itemSuffix=0,battlePetSpeciesID=0} end end
    end
    local ok=pcall(function()
        if found and ah.SelectBrowseResult then ah:SelectBrowseResult(found)
        else
            if not ah.SearchBar or not ah.SearchBar.StartSearch then error("Native AH search unavailable") end
            ah:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
            ah:GetCategoriesList():SetSelectedCategory(nil)
            ah:SetSearchText(name);ah.SearchBar:StartSearch()
        end
    end)
    if not ok then plan.selectedItem=nil;return false,"Could not open the native AH search." end
    -- Never hide this panel: native AH handles price confirmation and purchase.
    return true,"Buying "..name..": successful purchases are tracked automatically."
end
local function money(n) n=math.floor(n+.5);return string.format("%dg %02ds %02dc",math.floor(n/10000),math.floor(n/100)%100,n%100) end
local function itemName(id) local get=C_Item and C_Item.GetItemInfo or GetItemInfo;return get and get(id) or ("Item "..id) end
local function button(text,x,y,width,fn) local b=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate");b:SetPoint("TOPLEFT",x,y);b:SetSize(width,25);b:SetText(text);b:SetScript("OnClick",fn);return M.UI.Button(b) end
render=function()
    if not panel or not panel:IsShown() or not M.account then return end
    local plan=M.account.activeShoppingPlan;if not plan then return end
    panel.title:SetText(plan.recipe.name)
    if panel.requirements then panel.requirements:SetText(M.CraftRequirementsText and M.CraftRequirementsText(plan.recipe) or "") end
    local order={};for id in pairs(plan.needs) do order[#order+1]=id end;table.sort(order)
    local total=0;local ready=true
    for i,id in ipairs(order) do
        local vendor=M.VendorMaterial and M.VendorMaterial(id)
        local quantity,cost=M.ShoppingTotals(plan,id);total=total+cost
        local remaining=math.max(0,plan.needs[id]-quantity);if remaining>0 then ready=false end
        local row=widgets[i]
        if not row then
            row=CreateFrame("Button",nil,panel.content);row:SetSize(410,68)
            row.title=M.UI.Text(row,14);row.title:SetPoint("TOPLEFT",8,-6);row.title:SetWidth(390)
            row.info=M.UI.Text(row,12);row.info:SetPoint("TOPLEFT",8,-29);row.info:SetWidth(390)
            local h=row:CreateTexture(nil,"HIGHLIGHT");h:SetAllPoints();h:SetColorTexture(.2,.7,.65,.15);row:SetHighlightTexture(h)
            widgets[i]=row
        end
        row:SetPoint("TOPLEFT",0,-(i-1)*70)
        row.title:SetText(itemName(id)..(vendor and "  |cffffcc66[Buy from vendor]|r" or "  |cff55ddcc[Search AH]|r"))
        row.info:SetText("Needed "..plan.needs[id].." | Bought "..quantity.." | Still needed "..remaining.."\nPaid "..money(cost)..(quantity>0 and (" | Average "..money(cost/quantity).." / unit") or ""))
        if vendor then
            row.info:SetText("Needed "..plan.needs[id].." | Buy from vendor\n"..(vendor.price and (money(vendor.price).." / unit | Total "..money(vendor.price*plan.needs[id]).." (estimate)") or "Open a supplier to learn its price."))
        end
        row:SetScript("OnClick",function() local ok,msg=M.OpenShoppingMaterial(id);notice=msg;render() end)
        row:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_LEFT");GameTooltip:SetItemByID(id);GameTooltip:Show() end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end);row:Show()
    end
    for i=#order+1,#widgets do widgets[i]:Hide() end;panel.content:SetHeight(math.max(1,#order*70))
    panel.summary:SetText("Total paid for this plan: "..money(total).."\n"..(ready and "Planned quantities purchased." or "AH links open searches; vendor supplies are bought from NPCs.").."\n"..notice)
end
function M.ShowCraftShopping(r,crafts)
    local plan,msg=M.StartCraftShopping(r,crafts or 1)
    if not plan then print("Market Tools: "..msg);return end
    recipe=r;notice="Native AH confirms every purchase; this panel stays open."
    if not panel then
        panel=M.UI.Window("GuildMarketShoppingFrame");panel:SetSize(460,580);panel:SetFrameStrata("DIALOG");panel.TitleText:SetText("Market Tools - Craft shopping")
        panel:SetMovable(true);panel:EnableMouse(true);panel:RegisterForDrag("LeftButton");panel:SetScript("OnDragStart",panel.StartMoving);panel:SetScript("OnDragStop",panel.StopMovingOrSizing);table.insert(UISpecialFrames,"GuildMarketShoppingFrame")
        panel.title=M.UI.Text(panel,15);panel.title:SetPoint("TOPLEFT",16,-42);panel.title:SetWidth(420)
        local label=M.UI.Text(panel,12);label:SetPoint("TOPLEFT",16,-78);label:SetText("Crafts to make")
        panel.count=CreateFrame("EditBox",nil,panel,"InputBoxTemplate");panel.count:SetSize(65,23);panel.count:SetPoint("TOPLEFT",125,-73);panel.count:SetAutoFocus(false);panel.count:SetScript("OnEscapePressed",panel.count.ClearFocus)
        button("Update plan",205,-73,120,function() local p,e=M.StartCraftShopping(recipe,tonumber(panel.count:GetText()));notice=p and "Planned quantities updated." or e;if M.RefreshAlchemy then M.RefreshAlchemy() end;render() end)
        panel.setup=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate");panel.setup:SetPoint("TOPLEFT",16,-104);panel.setup:SetSize(24,24)
        local setupLabel=M.UI.Text(panel,12);panel.setupLabel=setupLabel;setupLabel:SetPoint("TOPLEFT",44,-110);setupLabel:SetText("Buy required setup (once per batch)")
        panel.setup:SetScript("OnClick",function(self)
            local p=M.account.activeShoppingPlan;if p then p.includeSetup=self:GetChecked()==true;if p.includeSetup then p.setupUsed=nil end;M.StartCraftShopping(recipe,p.crafts);if M.RefreshAlchemy then M.RefreshAlchemy() end;render() end
        end)
        panel.requirements=M.UI.Text(panel,12);panel.requirements:SetPoint("TOPLEFT",16,-138);panel.requirements:SetWidth(420)
        local scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate");panel.materialScroll=scroll;scroll:SetPoint("TOPLEFT",16,-210);scroll:SetPoint("BOTTOMRIGHT",-32,170)
        panel.content=CreateFrame("Frame",nil,scroll);panel.content:SetSize(410,1);scroll:SetScrollChild(panel.content)
        panel.summary=M.UI.Text(panel,13);panel.summary:SetPoint("BOTTOMLEFT",16,72);panel.summary:SetWidth(420)
        button("Production costs",16,-530,170,function() panel:Hide();M.ShowCraftCosts(recipe) end)
        button("Stop tracking",200,-530,150,function() local p=M.account.activeShoppingPlan;if p then p.selectedItem=nil end;notice="Purchase tracking paused. Click a material to resume.";render() end)
    end
    if M.HideAlchemy then M.HideAlchemy() end
    if M.HideMarket then M.HideMarket() end
    if M.HideCraftCosts then M.HideCraftCosts() end
    panel:ClearAllPoints()
    local ah=AuctionHouseFrame
    if ah and ah:IsShown() then panel:SetPoint("TOPLEFT",ah,"TOPRIGHT",12,0) else panel:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-20,-160) end
    local hasSetup=M.RecipeSetup and #M.RecipeSetup(r)>0
    if hasSetup then panel.setup:Show();panel.setupLabel:Show() else panel.setup:Hide();panel.setupLabel:Hide() end
    panel.materialScroll:SetPoint("TOPLEFT",16,(M.CraftRequirementsText and M.CraftRequirementsText(r)) and -250 or -114)
    panel.setup:SetChecked(plan.includeSetup and not plan.setupUsed);panel.count:SetText(tostring(plan.crafts));panel:Show();render()
end
M.RefreshCraftShopping=render
