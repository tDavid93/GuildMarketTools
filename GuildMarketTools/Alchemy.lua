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

local function inspect(r,prices)
    local text={r.recipe.name,r.recipe.learned and "Learned" or "Not learned", "Output / craft: "..tostring(r.recipe.count or "?"),""}
    local requirements=M.CraftRequirementsText and M.CraftRequirementsText(r.recipe)
    if requirements then
        text[#text+1]=requirements
        text[#text+1]="Setup / planned batch: "..(r.setupComplete and money(r.setupCost) or "Missing prices").." across "..r.setupCrafts.." craft(s)."
        text[#text+1]=r.includeSetup and "Profit includes setup allocation." or "Existing setup selected; no new setup purchase allocated."
        if r.requirementsUnknown then text[#text+1]="Profit unavailable: "..r.requirementsUnknown end
    end
    text[#text+1]="Profession skill: "..tostring(r.recipe.currentSkill or "--").." | Minimum: "..tostring(r.recipe.minSkill or "--")
    text[#text+1]="Minimum source: "..(r.recipe.minSkillSource or "Unknown")
    text[#text+1]="Character level: "..tostring(UnitLevel("player")).." | Required: "..tostring(r.recipe.minCharacterLevel or "Unknown")
    text[#text+1]="Level source: "..(r.recipe.characterLevelSource or "Unknown")
    local learning=M.RecipeLearningStatus(r.recipe,r.recipe.currentSkill,UnitLevel("player"))
    if learning then text[#text+1]="Learning: "..learning end
    text[#text+1]="Recipe acquisition and other requirements still apply."
    text[#text+1]=""
    local function age(id)
        local p=prices[id]
        if not p then return "NO PRICE" end
        if p.unavailable then return "NO LISTINGS" end
        local seconds=time()-p.time
        if seconds<0 then return "INVALID TIME" end
        return math.floor(seconds/60).."m"..(seconds>900 and " - STALE" or " - fresh")
    end
    text[#text+1]="Output price: "..age(r.recipe.itemID)
    for _,mat in ipairs(r.mats) do text[#text+1]=mat.count.." x "..name(mat.id,prices).."\n  "..money(mat.price).." / unit | "..(mat.vendor and (mat.vendor.price and mat.vendor.source or "Vendor - visit supplier for price") or age(mat.id)) end
    text[#text+1]="\nAH price / unit: "..money(r.unitPrice)
    text[#text+1]="Materials / craft: "..money(r.materialCost)
    text[#text+1]="Total cost / craft: "..money(r.cost)
    if not r.cost then text[#text+1]="Known cost subtotal / craft: "..money(r.knownCost).." (incomplete)" end
    text[#text+1]="Gross sale: "..money(r.gross)
    text[#text+1]="After AH cut: "..money(r.net)
    text[#text+1]="Profit / craft: "..money(r.profit)
    text[#text+1]="\nAH / vendor material estimates. Owned herbs are not free. Recipe purchase cost / cooldown opportunity cost excluded."
    if r.recipe.unsupported then text[#text+1]=r.recipe.unsupported end
    if #r.missing>0 then
        text[#text+1]="\nMissing / unavailable prices:"
        for _,v in ipairs(r.missingDetails) do text[#text+1]=v.role..": "..name(v.id,prices).." ["..v.id.."]\n  "..v.reason end
    end
    detail:SetText(table.concat(text,"\n"))
    panel.detailContent:SetHeight(math.max(1,detail:GetStringHeight()+15))
end
local function render()
    if not panel or not panel:IsShown() or not M.market then return end
    local prices=M.AlchemyPrices(M.market.items,M.unavailable); local rows={}
    for _,recipe in pairs(recipes()) do
        if (not learnedOnly or recipe.learned) and (not learnableOnly or M.RecipeLearnable(recipe,recipe.currentSkill,UnitLevel("player"))) and (filter=="" or recipe.name:lower():find(filter,1,true)) then
            rows[#rows+1]=M.AlchemyEstimate(recipe,prices,time(),M.settings.fee,M.settings.deposit)
        end
    end
    local state=M.RecipePriceStatus
    local columns={{"Recipe",190},{"Cost / craft",110},{"AH / unit",110},{"Profit / craft",120},{"Price status",95},{"Age",65},{"Min. skill",90}}
    M.UI.Sort(rows,sortColumn,descending,function(r,c)
        if c==1 then return r.recipe.name:lower() elseif c==2 then return r.cost elseif c==3 then return r.unitPrice
        elseif c==4 then return r.profit elseif c==5 then return state(r) elseif c==6 then return r.age else return r.recipe.minSkill end
    end)
    M.UI.Headers(panel,columns,-164,function(c) if c==sortColumn then descending=not descending else sortColumn=c; descending=c~=1 end; render() end)
    M.UI.Tabs(panel,"Professions")
    status:SetText(string.format("%d recipes  |  AH cut %.1f%%  |  %s",#rows,M.settings.fee,note))
    rows=M.UI.Page(panel,rows,render)
    local found=false; selectedRecipe=nil
    for i,r in ipairs(rows) do
        local key=r.recipe.professionID..":"..r.recipe.id
        local w=M.UI.Row(content,widgets,i,columns,{r.recipe.name,money(r.cost),money(r.unitPrice),money(r.profit),state(r),math.floor(r.age/60).."m",r.recipe.minSkill or "--"},selected==key)
        w.cells[4]:SetTextColor(r.profit and not r.stale and r.profit>0 and .4 or 1,r.profit and r.profit<0 and .5 or .9,.7)
        w:SetScript("OnClick",function() selected=key; panel.detailScroll:SetVerticalScroll(0); render() end)
        w:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(r.recipe.name,1,1,1)
            GameTooltip:AddLine(r.recipe.profession.." | "..(r.recipe.learned and "Learned" or "Not learned"),.6,.9,.9)
            local learning=M.RecipeLearningStatus(r.recipe,r.recipe.currentSkill,UnitLevel("player"));if learning then GameTooltip:AddLine(learning,1,.82,.3,true) end;GameTooltip:Show()
        end)
        w:SetScript("OnLeave",function() GameTooltip:Hide() end)
        if selected==key then selectedRecipe=r.recipe; inspect(r,prices); found=true end
    end
    for i=#rows+1,#widgets do widgets[i]:Hide() end
    content:SetHeight(math.max(1,#rows*32))
    if not found then panel.detailContent:SetHeight(300); detail:SetText(#rows==0 and "No matching recipes\n\nOpen each crafting profession once to import its recipes.\n\nLearning filter checks known skill and character levels. Trainer recipes with unknown character requirements are included for verification.\n\nTry another profession or clear the filters." or "Recipe details\n\nSelect a recipe for its materials and calculation.\n\nProfit is estimated from asking prices, after the AH cut and your relist reserve.\n\nPrices older than 15 minutes are marked Stale.") end
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
        button(panel,"Market depth",850,-98,170,function() if selectedRecipe then M.ShowRecipeDepth(selectedRecipe) else note="Select a recipe first.";render() end end)
        button(panel,"Buy materials",600,-98,170,function() if selectedRecipe then M.ShowCraftShopping(selectedRecipe,1) else note="Select a recipe first.";render() end end)
        button(panel,"Production costs",410,-98,170,function() if selectedRecipe then M.ShowCraftCosts(selectedRecipe) else note="Select a recipe first.";render() end end)
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
        skillCheck=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate"); skillCheck:SetPoint("TOPLEFT",16,-96); skillCheck:SetSize(24,24)
        local sl=M.UI.Text(skillCheck,13); sl:SetPoint("LEFT",skillCheck,"RIGHT"); sl:SetText("Learnable / check trainer")
        skillCheck:SetScript("OnClick",function(self)
            learnableOnly=not not self:GetChecked()
            if learnableOnly then learnedOnly=false; learnedCheck:SetChecked(false) end
            resetList()
        end)
        skillCheck:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine("Unlearned recipes within your skill AND character level",1,1,1)
            GameTooltip:AddLine("Unknown skill or character-level requirements are excluded. Level comes from the teaching recipe item, not the crafted output. Trainer-only recipes without level data are excluded. Other learning requirements still apply.",.8,.85,.9,true); GameTooltip:Show()
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
        local scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate"); panel.gmtScroll=scroll; scroll:SetPoint("TOPLEFT",16,-192); scroll:SetPoint("BOTTOMRIGHT",-335,48)
        content=CreateFrame("Frame",nil,scroll); content:SetSize(780,1); scroll:SetScrollChild(content)
        local ds=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate"); ds:SetPoint("TOPLEFT",850,-192); ds:SetPoint("BOTTOMRIGHT",-32,50)
        local dc=CreateFrame("Frame",nil,ds); dc:SetSize(270,1); ds:SetScrollChild(dc)
        detail=M.UI.Text(dc,13); detail:SetPoint("TOPLEFT"); detail:SetWidth(270)
        panel.detailContent=dc; panel.detailScroll=ds
        detail:SetText("Click a recipe for its material breakdown.\n\nProfit is an estimate at asking prices, not guaranteed sales.\n\nPrices older than 15 minutes are marked STALE.\n\nUse Settings to change AH cut and relist reserve.")
        local foot=M.UI.Text(panel,13); foot:SetPoint("BOTTOMLEFT",16,18); foot:SetWidth(780); foot:SetJustifyH("LEFT"); foot:SetText("Per craft, minimum output. AH minima do not guarantee stock or sales. Recipe costs excluded.")
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
