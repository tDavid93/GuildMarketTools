local M=GuildMarketTools
local panel,content,status,detail,selected
local selectedRecipe
local widgets={}
local learnedOnly=false
local learnableOnly=false
local skillCheck,learnedCheck
local professionFilter,filter=nil,""
local sortColumn,descending=4,true
local note="Open a crafting profession to import its recipes."
local function money(n)
    if not n then return "--" end
    local sign=n<0 and "-" or ""; n=math.floor(math.abs(n)+0.5)
    return string.format("%s%dg %02ds %02dc",sign,math.floor(n/10000),math.floor(n/100)%100,n%100)
end
local function itemID(link) return type(link)=="string" and tonumber(link:match("item:(%d+)")) end
local function professions()
    if not M.account then return {} end
    M.account.professions=M.account.professions or {}
    if M.account.alchemy and not M.account.professions[171] then
        M.account.professions[171]={name="Alchemy",recipes=M.account.alchemy}
    end
    -- A transient closed/loading profession returned ID 0 in older versions.
    -- Keep those records for recovery, but never display them as a profession.
    if M.account.professions[0] then
        M.account.invalidProfessionBackup=M.account.invalidProfessionBackup or M.account.professions[0]
        M.account.professions[0]=nil
    end
    return M.account.professions
end
-- AtlasLoot's profession entry stores the minimum learning rank at index 3.
-- Do not substitute maxTrivialLevel (the grey skill-up threshold).
function M.RecipeMinimumSkill(id)
    local entry=M.RecipeLearningDB and M.RecipeLearningDB[id]
    if entry and type(entry.minSkill)=="number" then return entry.minSkill,"Forever DB" end
    local data=AtlasLoot and AtlasLoot.Data and AtlasLoot.Data.Profession
    if data and data.GetProfessionData then
        local ok,r=pcall(data.GetProfessionData,id)
        if ok and type(r)=="table" and type(r[3])=="number" and r[3]>=0 then return r[3],"AtlasLoot" end
    end
end
function M.RecipeLearnableAtSkill(recipe,skill)
    return not recipe.learned and type(skill)=="number" and type(recipe.minSkill)=="number" and skill>=recipe.minSkill
end
local levelRequests={}
function M.RecipeCharacterLevel(recipe)
    local data=AtlasLoot and AtlasLoot.Data and AtlasLoot.Data.Recipe
    local entry=M.RecipeLearningDB and M.RecipeLearningDB[recipe.id]
    local id=recipe.recipeItemID or (entry and entry.recipeItemID)
    if not id and data and data.GetRecipeForSpell then
        local ok,value=pcall(data.GetRecipeForSpell,recipe.id)
        if ok and type(value)=="number" and value>0 then id=value;recipe.recipeItemID=id end
    end
    -- Only the teaching recipe item is relevant. The crafted output's level
    -- requirement says nothing about whether the recipe can be learned.
    if not id then return nil end
    local get=C_Item and C_Item.GetItemInfo or GetItemInfo
    if get then
        local itemName,_,_,_,level=get(id)
        if itemName and type(level)=="number" and level>=0 then
            return level,"Recipe item "..id
        end
    end
    if not levelRequests[id] and C_Item and C_Item.RequestLoadItemDataByID then
        levelRequests[id]=true;C_Item.RequestLoadItemDataByID(id)
    end
end
function M.RecipeLearningStatus(recipe,skill,level)
    if not M.RecipeLearnableAtSkill(recipe,skill) or type(level)~="number" then return nil end
    if type(recipe.minCharacterLevel)=="number" then
        if level<recipe.minCharacterLevel then return nil end
        return "Level requirements met"
    end
    local entry=M.RecipeLearningDB and M.RecipeLearningDB[recipe.id]
    if entry and entry.trainer then return "Check trainer: character level / other requirements unverified" end
end
function M.RecipeLearnable(recipe,skill,level)
    return M.RecipeLearningStatus(recipe,skill,level)~=nil
end

local function recipes()
    local all={}
    for id,p in pairs(professions()) do
        if not professionFilter or professionFilter==id then
            for _,r in pairs(p.recipes) do r.profession=p.name; r.professionID=id; r.currentSkill=p.skillLevel
                if r.minSkill==nil or (M.RecipeLearningDB and M.RecipeLearningDB[r.id]) then r.minSkill,r.minSkillSource=M.RecipeMinimumSkill(r.id) end
                r.minCharacterLevel,r.characterLevelSource=M.RecipeCharacterLevel(r)
                all[#all+1]=r end
        end
    end
    return all
end
-- Only use the newest observation for each exact base item, never an older low.
function M.AlchemyPrices(items,unavailable)
    local prices={}
    for key,v in pairs(items or {}) do
        local k=v.key
        if k and (k.itemSuffix or 0)==0 and (k.battlePetSpeciesID or 0)==0 and M.Positive(v.price) and type(v.time)=="number" then
            local old=prices[k.itemID]
            if not old or v.time>old.time then
                prices[k.itemID]={price=v.price,time=v.time,name=v.name,unavailable=unavailable and unavailable[key]}
            end
        end
    end
    return prices
end
function M.AlchemyEstimate(recipe,prices,now,fee,reserve)
    local r={recipe=recipe,cost=0,age=0,missing={},missingDetails={},mats={}}
    local function missing(id,role,reason)
        r.missing[#r.missing+1]=id
        r.missingDetails[#r.missingDetails+1]={id=id,role=role,reason=reason}
    end
    local function price(id,role)
        local p=prices[id]
        if not p then missing(id,role,"No AH observation - refresh this recipe");return nil end
        if p.unavailable then missing(id,role,"No buyout offers in the last complete search");return nil end
        if not M.Positive(p.price) or not p.time or p.time>now then missing(id,role,"Invalid price or timestamp - refresh this recipe");return nil end
        r.age=math.max(r.age,now-p.time);return p.price
    end
    if recipe.itemID then r.unitPrice=price(recipe.itemID,"Output") end
    local materialsComplete=true
    for _,mat in ipairs(recipe.mats or {}) do
        local vendor=M.VendorMaterial and M.VendorMaterial(mat.id)
        local p
        if vendor then p=vendor.price;if not p then missing(mat.id,"Material","Vendor price unknown - visit a supplier") end else p=price(mat.id,"Material") end
        r.mats[#r.mats+1]={id=mat.id,count=mat.count,price=p,vendor=vendor,time=not vendor and prices[mat.id] and prices[mat.id].time}
        if p then r.cost=r.cost+p*mat.count else materialsComplete=false end
    end
    r.materialCost=materialsComplete and r.cost or nil;r.setupCost=0;r.setupComplete=true
    r.requirementsUnknown=M.RequirementsUnknown and M.RequirementsUnknown(recipe)
    local include,crafts=true,1
    if M.SetupPolicy then include,crafts=M.SetupPolicy(recipe) end
    r.setupCrafts=crafts;r.includeSetup=include
    if include then
        for _,mat in ipairs(M.RecipeSetup and M.RecipeSetup(recipe) or {}) do
            local vendor=M.VendorMaterial and M.VendorMaterial(mat.id)
            local p
            if vendor then p=vendor.price;if not p then missing(mat.id,"Setup","Vendor price unknown - visit a supplier") end else p=price(mat.id,"Setup") end
            if p then r.setupCost=r.setupCost+p*mat.count else materialsComplete=false;r.setupComplete=false end
        end
    end
    r.cost=r.cost+r.setupCost/crafts
    r.knownCost=r.cost
    r.stale=r.age>900
    -- A missing material must not hide a known output price / sale value.
    if r.unitPrice and M.Positive(recipe.count) then
        r.gross=r.unitPrice*recipe.count
        r.net=r.gross*(1-fee/100)
    end
    if not materialsComplete or recipe.unsupported or r.requirementsUnknown or #r.mats==0 then r.cost=nil end
    if r.net and r.cost and not recipe.unsupported then
        r.profit=r.net-r.cost-reserve*recipe.count
        r.roi=r.cost>0 and 100*r.profit/r.cost or nil
    end
    return r
end
-- Read actual client recipe data. Unknown/alternative required reagents are
-- explicitly unsupported instead of silently assuming they are free.
function M.ReadProfession()
    local api=C_TradeSkillUI
    if not M.account or not api or not api.GetBaseProfessionInfo or not api.GetRecipeSchematic then return 0,"Open a profession first (recipe API unavailable)." end
    if (api.IsTradeSkillLinked and api.IsTradeSkillLinked()) or (api.IsTradeSkillGuild and api.IsTradeSkillGuild()) then return 0,"Open your own crafting profession." end
    local prof=api.GetBaseProfessionInfo()
    if not prof or not M.Positive(prof.professionID) then return 0,"Open your own crafting profession first." end
    local ids=api.GetAllRecipeIDs and api.GetAllRecipeIDs() or api.GetFilteredRecipeIDs and api.GetFilteredRecipeIDs()
    if not ids then return 0,"Profession recipe data is not ready yet." end
    local all=professions(); local pid=prof.professionID
    all[pid]=all[pid] or {name=prof.professionName or prof.name or ("Profession "..pid),recipes={}}
    all[pid].skillLevel=type(prof.skillLevel)=="number" and prof.skillLevel or nil
    local saved=all[pid].recipes; local n=0
    local staged={}
    if pid==171 then M.account.alchemy=saved end
    for _,id in ipairs(ids) do
        local ok,info=pcall(api.GetRecipeInfo,id)
        local good,s=pcall(api.GetRecipeSchematic,id,false)
        if ok and good and info and s and (not s.professionID or s.professionID==pid) then
            local link=api.GetRecipeItemLink and api.GetRecipeItemLink(id)
            local output=s.outputItemID or itemID(link)
            if info.name then
                local r={id=id,name=info.name or s.name or ("Recipe "..id),itemID=output,count=s.quantityMin,
                    learned=info.learned==true,mats={},readAt=time()}
                r.minSkill,r.minSkillSource=M.RecipeMinimumSkill(id)
                if not output then r.unsupported="No tradable output item" end
                if not M.Positive(r.count) then r.unsupported="Unknown output quantity" end
                for _,slot in ipairs(s.reagentSlotSchematics or {}) do
                    local basic=Enum and Enum.CraftingReagentType and slot.reagentType==Enum.CraftingReagentType.Basic
                    if basic or slot.required then
                        local reagents=slot.reagents or {}
                        if #reagents~=1 or not reagents[1].itemID or not M.Positive(slot.quantityRequired) then
                            r.unsupported="Alternative / unknown required reagents"
                        else r.mats[#r.mats+1]={id=reagents[1].itemID,count=slot.quantityRequired} end
                    end
                end
                if #r.mats==0 then r.unsupported="No supported reagent data" end
                if M.ReadRecipeRequirements then M.ReadRecipeRequirements(r) end
                staged[id]=r; n=n+1
            end
        end
    end
    local current=api.GetBaseProfessionInfo()
    if not current or current.professionID~=pid then return 0,"Profession changed while reading. Reopen it and retry." end
    for id,r in pairs(staged) do saved[id]=r end
    return n,n>0 and (n.." recipes imported from "..all[pid].name..".") or "Recipe data not ready. Reopen your profession and retry."
end
function M.RecipeItemName(id,prices)
    local get=C_Item and C_Item.GetItemInfo or GetItemInfo
    local found=get and get(id)
    if found then return found end
    if not levelRequests[id] and C_Item and C_Item.RequestLoadItemDataByID then
        levelRequests[id]=true;C_Item.RequestLoadItemDataByID(id)
    end
    if prices[id] and prices[id].name then return prices[id].name end
    for _,list in pairs(M.RequirementDatabase or {}) do for _,v in ipairs(list) do if v.id==id then return v.name end end end
    return "Item "..tostring(id).." (name loading)"
end
local name=M.RecipeItemName
function M.RecipePriceStatus(r)
    if r.recipe.unsupported then return "Unsupported" end
    if r.requirementsUnknown then return "Requirements?" end
    local roles={};for _,v in ipairs(r.missingDetails or {}) do roles[v.role]=true end
    if roles.Output then return "No sale price" end
    if roles.Material then return "Missing mats" end
    if roles.Setup then return "Missing setup" end
    return #r.missing>0 and "Missing prices" or r.stale and "Stale" or r.profit and r.profit>0 and "Est. profit" or "Loss"
end

local detailTab="Summary"
function M.RecipeWowheadURL(recipe)
    -- Forever adds custom spell/item IDs: name search avoids linking an unrelated retail ID.
    local query=tostring(recipe.name or ""):gsub("[^%w%-_%.~]",function(c) return string.format("%%%02X",string.byte(c)) end)
    return "https://www.wowhead.com/search?q="..query
end
function M.LinkRecipeToChat(recipe)
    if not recipe then return false,"Select a recipe first." end
    local get=C_Item and C_Item.GetItemInfo or GetItemInfo
    local link=recipe.itemID and get and select(2,get(recipe.itemID))
    if type(link)~="string" or not link:find("|Hitem:",1,true) then
        if recipe.itemID and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(recipe.itemID) end
        return false,"Item link loading. Try Link to chat again."
    end
    local insert=ChatFrameUtil and ChatFrameUtil.InsertLink or ChatEdit_InsertLink
    local open=ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
    if insert and insert(link) then return true end
    if open then open(link); return true end
    return false,"Chat input is unavailable."
end
local copyPanel
function M.CopyRecipeWowhead(recipe)
    if not recipe then return end
    if not copyPanel then
        copyPanel=M.UI.Window("GuildMarketRecipeLinkFrame");copyPanel:SetSize(540,150);copyPanel:SetPoint("CENTER");copyPanel:SetFrameStrata("FULLSCREEN_DIALOG")
        copyPanel.TitleText:SetText("Copy Wowhead search link")
        local hint=M.UI.Text(copyPanel,13);hint:SetPoint("TOPLEFT",16,-40);hint:SetWidth(508)
        hint:SetText("Ctrl+C to copy. Forever recipes may differ from Wowhead.")
        local box=CreateFrame("EditBox",nil,copyPanel,"InputBoxTemplate");box:SetSize(500,28);box:SetPoint("TOPLEFT",20,-76);box:SetAutoFocus(false)
        box:SetScript("OnEscapePressed",function() copyPanel:Hide() end)
        box:SetScript("OnEnterPressed",function() copyPanel:Hide() end)
        copyPanel:SetScript("OnHide",function() box:ClearFocus() end);copyPanel.box=box
        table.insert(UISpecialFrames,"GuildMarketRecipeLinkFrame")
    end
    copyPanel:Show();copyPanel.box:SetText(M.RecipeWowheadURL(recipe));copyPanel.box:SetFocus();copyPanel.box:HighlightText()
end
local function inspect(r,prices)
    panel.recipeTitle:SetText(r.recipe.name)
    local text={}
    local function heading(s) text[#text+1]="|cff66dcd6"..s.."|r" end
    local function age(id)
        local p=prices[id]
        if not p then return "NO PRICE" end
        if p.unavailable then return "NO LISTINGS" end
        local seconds=time()-p.time
        if seconds<0 then return "INVALID TIME" end
        return math.floor(seconds/60).."m"..(seconds>900 and " - STALE" or " - fresh")
    end
    if detailTab=="Summary" then
        heading("PER CRAFT  /  "..tostring(r.recipe.count or "?").." output")
        text[#text+1]="AH / unit: "..money(r.unitPrice).."  ("..age(r.recipe.itemID)..")"
        text[#text+1]="Total cost: "..money(r.cost)
        text[#text+1]="After AH cut: "..money(r.net)
        text[#text+1]=(r.profit and r.profit<0 and "|cffff8899" or "|cff66dcd6").."Estimated profit: "..money(r.profit).."|r"
        text[#text+1]=""
        heading(M.RecipePriceStatus(r))
        if not r.cost then text[#text+1]="Known subtotal: "..money(r.knownCost).." (incomplete)" end
        if r.recipe.unsupported then text[#text+1]=r.recipe.unsupported end
        if r.requirementsUnknown then text[#text+1]=r.requirementsUnknown end
        for _,v in ipairs(r.missingDetails) do text[#text+1]=v.role..": "..name(v.id,prices).." — "..v.reason end
        text[#text+1]="\nSetup allocation: "..(r.setupComplete and money(r.setupCost) or "Missing prices").." / "..r.setupCrafts.." crafts."
        text[#text+1]="Asking prices, not guaranteed sales. Recipe purchase and cooldown opportunity costs excluded."
        text[#text+1]="\nAHledger median / unit: "..money(r.ahl and r.ahl.median)
        text[#text+1]="Est. sold / day: "..M.AHledgerPace(r.ahl).."  (whole market)"
        text[#text+1]=r.ahl and ((r.ahl.snapshot and "Bundled snapshot. " or "")..(r.ahl.stale and "Old / unknown age. " or "").."See Market for source details.") or r.ahlStatus
    elseif detailTab=="Materials" then
        heading("MATERIALS  /  per craft")
        for _,mat in ipairs(r.mats) do
            text[#text+1]="\n"..mat.count.." x "..name(mat.id,prices)
            text[#text+1]=money(mat.price).." each  |  "..(mat.vendor and (mat.vendor.price and mat.vendor.source or "Vendor price unknown") or age(mat.id))
        end
        text[#text+1]="\nMaterials total: "..money(r.materialCost)
        text[#text+1]="Owned materials still have value. Use Buy materials to plan purchases."
    elseif detailTab=="Market" then
        heading("AHLEDGER  /  COMMUNITY ESTIMATES")
        local p=r.ahl
        if p then
            text[#text+1]=p.market
            text[#text+1]=(p.snapshot and "Bundled snapshot" or "Provider table").." | Age: "..(p.age and math.floor(p.age/60).."m" or "unknown")..(p.stale and " - OLD / UNKNOWN" or "")
            text[#text+1]="Est. sold / day: "..M.AHledgerPace(p).." (whole market)"
            text[#text+1]="Listed units: "..tostring(p.quantity or "Unknown")
            text[#text+1]="Minimum / unit: "..money(p.minBuyout)
            text[#text+1]="Median / unit: "..money(p.median)
            text[#text+1]="7d / 30d median: "..money(p.median7d).." / "..money(p.median30d)
            text[#text+1]="30d range: "..money(p.low30d).." - "..money(p.high30d)
            text[#text+1]="Sales/day is a provider estimate, not your expected sales. * = old/unknown age or bundled snapshot."
        else text[#text+1]=r.ahlStatus end
        text[#text+1]=""
        heading("CURRENT ASKING SUPPLY")
        local d=M.RecipeMarketStats and M.RecipeMarketStats(r.recipe) or {}
        if not d.source then text[#text+1]="No observations. Open Market depth and refresh at the AH."
        else
            local minutes=d.time and math.floor(math.max(0,time()-d.time)/60)
            text[#text+1]=(d.source=="depth" and (d.full and "Complete loaded results" or "PARTIAL loaded results") or "Browse observation; coverage unknown")
            text[#text+1]="Age: "..tostring(minutes or "?").."m"..(minutes and minutes>=15 and " - STALE" or "")
            text[#text+1]="Available units: "..tostring(d.units or "Unknown")
            if d.source=="depth" then
                text[#text+1]="Auctions: "..tostring(d.listings or "Unknown").."  |  Price levels: "..#d.levels
                text[#text+1]="Total asking value: "..money(d.value)
                text[#text+1]="Lowest / unit: "..money(d.minimum)
                text[#text+1]="Median / unit: "..money(d.median)
                text[#text+1]="Middle 50%: "..money(d.q25).." – "..money(d.q75)
            else text[#text+1]="Refresh depth for asking value and distribution." end
        end
        text[#text+1]="\nLocal listings alone do not measure sales. Removals can be cancellations or expirations."
    else
        heading(r.recipe.learned and "LEARNED" or "NOT LEARNED")
        text[#text+1]="Profession: "..tostring(r.recipe.currentSkill or "--").." / requires "..tostring(r.recipe.minSkill or "?")
        text[#text+1]="Character: "..tostring(UnitLevel("player")).." / requires "..tostring(r.recipe.minCharacterLevel or "?")
        local learning=M.RecipeLearningStatus(r.recipe,r.recipe.currentSkill,UnitLevel("player"))
        if learning then text[#text+1]=learning end
        text[#text+1]="\n"..(M.CraftRequirementsText and M.CraftRequirementsText(r.recipe) or "Requirements unknown")
        text[#text+1]="\nSkill source: "..(r.recipe.minSkillSource or "Unknown")
        text[#text+1]="Level source: "..(r.recipe.characterLevelSource or "Unknown")
        text[#text+1]=r.includeSetup and "Profit includes setup allocation." or "Existing setup; no new setup purchase allocated."
    end
    detail:SetText(table.concat(text,"\n"));panel.detailContent:SetHeight(math.max(1,detail:GetStringHeight()+16))
end
local function render()
    if not panel or not panel:IsShown() or not M.market then return end
    local prices=M.AlchemyPrices(M.market.items,M.unavailable); local rows={}
    for _,recipe in pairs(recipes()) do
        if (not learnedOnly or recipe.learned) and (not learnableOnly or M.RecipeLearnable(recipe,recipe.currentSkill,UnitLevel("player"))) and (filter=="" or recipe.name:lower():find(filter,1,true)) then
            local r=M.AlchemyEstimate(recipe,prices,time(),M.settings.fee,M.settings.deposit)
            r.ahl,r.ahlStatus=M.AHledgerPrice(recipe.itemID,time())
            rows[#rows+1]=r
        end
    end
    local state=M.RecipePriceStatus
    local columns={{"Recipe",190},{"Cost / craft",110},{"AH / unit",110},{"Profit / craft",110},{"Est. sold/day",110},{"Skill",70}}
    M.UI.Sort(rows,sortColumn,descending,function(r,c)
        if c==1 then return r.recipe.name:lower() elseif c==2 then return r.cost elseif c==3 then return r.unitPrice
        elseif c==4 then return r.profit elseif c==5 then return r.ahl and r.ahl.soldPerDay else return r.recipe.minSkill end
    end)
    M.UI.Headers(panel,columns,-164,function(c) if c==sortColumn then descending=not descending else sortColumn=c; descending=c~=1 end; render() end)
    M.UI.Tabs(panel,"Professions")
    status:SetText(string.format("%d recipes  |  AH cut %.1f%%  |  %s",#rows,M.settings.fee,note))
    rows=M.UI.Page(panel,rows,render)
    local found=false; selectedRecipe=nil
    for i,r in ipairs(rows) do
        local key=r.recipe.professionID..":"..r.recipe.id
        local w=M.UI.Row(content,widgets,i,columns,{r.recipe.name,money(r.cost),money(r.unitPrice),money(r.profit),M.AHledgerPace(r.ahl),r.recipe.minSkill or "--"},selected==key)
        w.cells[4]:SetTextColor(r.profit and not r.stale and r.profit>0 and .4 or 1,r.profit and r.profit<0 and .5 or .9,.7)
        w:SetScript("OnClick",function()
            selected=key; panel.detailScroll:SetVerticalScroll(0)
            if IsShiftKeyDown and IsShiftKeyDown() then local ok,msg=M.LinkRecipeToChat(r.recipe); if not ok then note=msg end end
            render()
        end)
        w:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(r.recipe.name,1,1,1)
            GameTooltip:AddLine("Shift-click: link crafted item to chat",.7,.8,.9)
            GameTooltip:AddLine("Local prices: "..state(r),1,.82,.3)
            GameTooltip:AddLine("AHledger est. sold/day: "..M.AHledgerPace(r.ahl).." (whole market)",.7,.8,.9)
            GameTooltip:AddLine(r.ahl and ("AHledger median: "..money(r.ahl.median).." | "..r.ahl.market) or r.ahlStatus,.7,.8,.9,true)
            GameTooltip:AddLine("* = old / unknown age or bundled snapshot",.7,.8,.9)
            GameTooltip:AddLine(M.AHledgerCredit,.7,.8,.9)
            GameTooltip:AddLine(r.recipe.profession.." | "..(r.recipe.learned and "Learned" or "Not learned"),.6,.9,.9)
            local learning=M.RecipeLearningStatus(r.recipe,r.recipe.currentSkill,UnitLevel("player"));if learning then GameTooltip:AddLine(learning,1,.82,.3,true) end;GameTooltip:Show()
        end)
        w:SetScript("OnLeave",function() GameTooltip:Hide() end)
        if selected==key then selectedRecipe=r.recipe; inspect(r,prices); found=true end
    end
    for i=#rows+1,#widgets do widgets[i]:Hide() end
    content:SetHeight(math.max(1,#rows*32))
    if not found then
        panel.recipeTitle:SetText("Select a recipe");panel.detailContent:SetHeight(160)
        detail:SetText(#rows==0 and "No matching recipes.\n\nOpen your profession to import recipes, or clear the filters." or "Select a recipe to review profit, materials and market supply.\n\nShift-click a row to link its crafted item to chat.")
    end
    for _,b in ipairs(panel.recipeActions) do b:SetEnabled(selectedRecipe~=nil) end
    for label,b in pairs(panel.detailTabs) do b:SetAlpha(label==detailTab and 1 or .6) end
end
local function button(parent,text,x,y,width,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate"); b:SetSize(width,24); b:SetPoint("TOPLEFT",x,y); b:SetText(text); b:SetScript("OnClick",fn); return M.UI.Button(b)
end
function M.ShowAlchemy()
    if not M.market then return end
    if M.HideVendor then M.HideVendor() end
    if M.HideMarket then M.HideMarket() end
    if not panel then
        panel=M.UI.Window("GuildMarketAlchemyFrame")
        panel:SetSize(1160,680); panel:SetPoint("CENTER"); panel:SetFrameStrata("DIALOG"); panel.TitleText:SetText("Guild Market Tools")
        panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton"); panel:SetScript("OnDragStart",panel.StartMoving); panel:SetScript("OnDragStop",panel.StopMovingOrSizing)
        table.insert(UISpecialFrames,"GuildMarketAlchemyFrame")
        for i,n in ipairs({"Deals","History","Watchlist","Ledger","Settings","Vendor","Professions"}) do
            button(panel,n,16+(i-1)*120,-32,112,function() if n=="Professions" then render() elseif n=="Vendor" then panel:Hide(); M.ShowVendor() else panel:Hide(); M.OpenTab(n) end end)
        end
        button(panel,"Read open profession",16,-68,185,function() local n,msg=M.ReadProfession(); note=msg; render() end)
        button(panel,"Refresh prices",210,-68,135,function()
            local ok,msg=M.RefreshRecipePrices(selectedRecipe,function(text) note=text; render() end)
            if not ok then note=msg; render() end
        end)
        panel.recipeActions={}
        panel.recipeActions[1]=button(panel,"Market depth",16,-98,160,function() if selectedRecipe then M.ShowRecipeDepth(selectedRecipe) else note="Select a recipe first.";render() end end)
        panel.recipeActions[2]=button(panel,"Buy materials",752,-240,180,function() if selectedRecipe then M.ShowCraftShopping(selectedRecipe,1) else note="Select a recipe first.";render() end end)
        panel.recipeActions[3]=button(panel,"Production costs",940,-240,180,function() if selectedRecipe then M.ShowCraftCosts(selectedRecipe) else note="Select a recipe first.";render() end end)
        button(panel,"Cancel refresh",250,-98,135,function() if M.CancelRecipeRefresh then M.CancelRecipeRefresh() end end)
        local check=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate"); check:SetPoint("TOPLEFT",365,-65); check:SetSize(24,24)
        local label=check:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); label:SetPoint("LEFT",check,"RIGHT"); label:SetText("Learned only")
        learnedCheck=check
        local function resetList() selected=nil; if panel.gmtPager then panel.gmtPager.page=1 end; if panel.gmtScroll then panel.gmtScroll:SetVerticalScroll(0) end; render() end
        check:SetScript("OnClick",function(self)
            learnedOnly=not not self:GetChecked()
            if learnedOnly then learnableOnly=false; skillCheck:SetChecked(false) end
            resetList()
        end)
        skillCheck=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate"); skillCheck:SetPoint("TOPLEFT",410,-96); skillCheck:SetSize(24,24)
        local sl=M.UI.Text(skillCheck,13); sl:SetPoint("LEFT",skillCheck,"RIGHT"); sl:SetText("Learnable / check trainer")
        skillCheck:SetScript("OnClick",function(self)
            learnableOnly=not not self:GetChecked()
            if learnableOnly then learnedOnly=false; learnedCheck:SetChecked(false) end
            resetList()
        end)
        skillCheck:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine("Unlearned recipes within your skill AND character level",1,1,1)
            GameTooltip:AddLine("Unknown skill requirements are excluded. Trainer recipes with unknown character-level requirements remain visible for verification. Other learning requirements still apply.",.8,.85,.9,true); GameTooltip:Show()
        end)
        skillCheck:SetScript("OnLeave",function() GameTooltip:Hide() end)
        local profButton=button(panel,"All professions",520,-68,180,function(self)
            local ids={}; for id in pairs(professions()) do ids[#ids+1]=id end; table.sort(ids)
            local nextID=ids[1]
            if professionFilter then for i,id in ipairs(ids) do if id==professionFilter then nextID=ids[i+1]; break end end end
            professionFilter=nextID; selected=nil
            self:SetText(nextID and professions()[nextID].name or "All professions"); render()
        end)
        local search=CreateFrame("EditBox",nil,panel,"InputBoxTemplate"); search:SetSize(225,22); search:SetPoint("TOPLEFT",730,-70); search:SetAutoFocus(false)
        search:SetScript("OnTextChanged",function(self) filter=self:GetText():lower(); render() end)
        search:SetScript("OnEscapePressed",search.ClearFocus)
        local hint=M.UI.Text(panel,12); hint:SetPoint("TOPLEFT",970,-75); hint:SetText("Filter recipes")
        status=M.UI.Text(panel,13); status:SetPoint("TOPLEFT",16,-140); status:SetWidth(920); status:SetJustifyH("LEFT")
        local scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate"); panel.gmtScroll=scroll; scroll:SetPoint("TOPLEFT",16,-192); scroll:SetPoint("BOTTOMRIGHT",-430,68)
        content=CreateFrame("Frame",nil,scroll); content:SetSize(700,1); scroll:SetScrollChild(content)
        panel.recipeTitle=M.UI.Text(panel,17);panel.recipeTitle:SetPoint("TOPLEFT",752,-164);panel.recipeTitle:SetSize(368,40)
        panel.recipeActions[4]=button(panel,"Link to chat",752,-204,180,function()
            local ok,msg=M.LinkRecipeToChat(selectedRecipe);if not ok then note=msg;render() end
        end)
        panel.recipeActions[5]=button(panel,"Copy Wowhead link",940,-204,180,function() M.CopyRecipeWowhead(selectedRecipe) end)
        panel.detailTabs={}
        for i,label in ipairs({"Summary","Materials","Market","Setup"}) do
            panel.detailTabs[label]=button(panel,label,752+(i-1)*94,-280,90,function() detailTab=label;panel.detailScroll:SetVerticalScroll(0);render() end)
        end
        local ds=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate"); ds:SetPoint("TOPLEFT",752,-316); ds:SetPoint("BOTTOMRIGHT",-32,68)
        local dc=CreateFrame("Frame",nil,ds); dc:SetSize(368,1); ds:SetScrollChild(dc)
        detail=M.UI.Text(dc,13); detail:SetPoint("TOPLEFT"); detail:SetWidth(368)
        panel.detailContent=dc; panel.detailScroll=ds
        detail:SetText("Click a recipe for its material breakdown.\n\nProfit is an estimate at asking prices, not guaranteed sales.\n\nPrices older than 15 minutes are marked STALE.\n\nUse Settings to change AH cut and relist reserve.")
        local credit=M.UI.Text(panel,12);credit:SetPoint("BOTTOMLEFT",16,42);credit:SetWidth(850);credit:SetText(M.AHledgerCredit.." | Est. sold/day: whole-market estimate. * = old / snapshot.")
        local foot=M.UI.Text(panel,13); foot:SetPoint("BOTTOMLEFT",16,18); foot:SetWidth(850); foot:SetJustifyH("LEFT"); foot:SetText("Estimates per craft. Asking prices do not guarantee sales. Shift-click a recipe to link its item.")
    end
    panel:Show(); render()
end
M.HideAlchemy=function() if panel then panel:Hide() end end
M.RefreshAlchemy=render
local events=CreateFrame("Frame")
for _,e in ipairs({"TRADE_SKILL_SHOW","TRADE_SKILL_LIST_UPDATE"}) do pcall(events.RegisterEvent,events,e) end
local queued=false
events:SetScript("OnEvent",function()
    if queued then return end; queued=true
    C_Timer.After(0.5,function()
        queued=false
        local ok,n,msg=pcall(M.ReadProfession)
        if ok and n>0 then note=msg; render() end
    end)
end)

-- Compatibility with existing launchers and saved Alchemy data.
M.ReadAlchemy=M.ReadProfession
M.ShowProfessions=M.ShowAlchemy

-- Item-cache completion and level-ups update eligibility without re-importing recipes.
local levelEvents=CreateFrame("Frame")
levelEvents:RegisterEvent("GET_ITEM_INFO_RECEIVED")
levelEvents:RegisterEvent("PLAYER_LEVEL_UP")
local levelQueued=false
levelEvents:SetScript("OnEvent",function(_,event,id)
    if event=="GET_ITEM_INFO_RECEIVED" and not levelRequests[id] then return end
    if levelQueued then return end;levelQueued=true
    C_Timer.After(.1,function() levelQueued=false;render() end)
end)
