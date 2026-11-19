local M=GuildMarketTools
local function integer(n) return M.Positive(n) and n%1==0 end
local function ids()
    M.account.nextLotID=M.account.nextLotID or 0
    for _,lot in ipairs(M.account.ledger) do
        if not lot.lotID then M.account.nextLotID=M.account.nextLotID+1;lot.lotID=M.account.nextLotID end
    end
end
function M.PlanCraftCost(recipe,crafts)
    if not recipe or recipe.unsupported or not integer(crafts) or not integer(recipe.count) or not recipe.itemID or type(recipe.mats)~="table" or #recipe.mats==0 then return nil,"Unsupported recipe or invalid craft count." end
    if M.RequirementsUnknown and M.RequirementsUnknown(recipe) then return nil,M.RequirementsUnknown(recipe) end
    ids()
    local plan={materials={},allocations={},cost=0,complete=true,crafts=crafts,recipe=recipe}
    local needs={};for _,mat in ipairs(recipe.mats) do if not integer(mat.count) then return nil,"Invalid material quantity." end;needs[mat.id]=(needs[mat.id] or 0)+mat.count*crafts end
    if M.AddSetupNeeds then M.AddSetupNeeds(needs,recipe,(M.account.activeShoppingPlan and M.account.activeShoppingPlan.recipe.id==recipe.id) and M.account.activeShoppingPlan or {recipe=recipe,includeSetup=true}) end
    local order={};for id in pairs(needs) do order[#order+1]=id end;table.sort(order)
    for _,id in ipairs(order) do
        local entry={id=id,needed=needs[id],recorded=0,cost=0};local lots={}
        for _,lot in ipairs(M.account.ledger) do
            local k=lot.key
            if k.itemID==id and (k.itemSuffix or 0)==0 and (k.battlePetSpeciesID or 0)==0 and M.Balance(lot)>0 then lots[#lots+1]=lot end
        end
        table.sort(lots,function(a,b)
            local p=M.account.activeShoppingPlan
            if p and p.recipe.id==recipe.id then
                local ap,bp=a.shoppingPlanID==p.id,b.shoppingPlanID==p.id
                if ap~=bp then return ap end
            end
            if a.time==b.time then return a.lotID<b.lotID end;return a.time<b.time end)
        for _,lot in ipairs(lots) do
            local available=M.Balance(lot)
            local take=math.min(entry.needed-entry.recorded,available)
            if take>0 then
                local cost=take*lot.cost/lot.quantity
                plan.allocations[#plan.allocations+1]={lotID=lot.lotID,quantity=take,cost=cost}
                entry.recorded=entry.recorded+take;entry.cost=entry.cost+cost;plan.cost=plan.cost+cost
            end
        end
        if entry.recorded<entry.needed then plan.complete=false end
        plan.materials[#plan.materials+1]=entry
    end
    return plan
end
function M.RecordCraftBatch(recipe,crafts,output,now)
    if not integer(output) then return false,"Enter the actual number of items produced." end
    local plan,err=M.PlanCraftCost(recipe,crafts)
    if not plan then return false,err end
    if not plan.complete then return false,"Missing purchase records. Enter the actual material costs first." end
    local lot=M.Purchase({itemID=recipe.itemID},output,plan.cost,now,"Crafted: "..recipe.name)
    if not lot then return false,"Could not record the output cost." end
    lot.cost=plan.cost;lot.name=recipe.name;ids()
    for _,a in ipairs(plan.allocations) do for _,input in ipairs(M.account.ledger) do if input.lotID==a.lotID then input.craftUsed=(input.craftUsed or 0)+a.quantity;break end end end
    M.account.craftBatches=M.account.craftBatches or {}
    local batch={recipeID=recipe.id,itemID=recipe.itemID,name=recipe.name,crafts=crafts,quantity=output,cost=plan.cost,time=now,outputLotID=lot.lotID,allocations=plan.allocations}
    local shopping=M.account.activeShoppingPlan
    if shopping and shopping.recipe.id==recipe.id and shopping.includeSetup and not shopping.setupUsed then batch.setupPlanID=shopping.id;shopping.setupUsed=true end
    table.insert(M.account.craftBatches,1,batch);return batch
end
function M.UndoCraftBatch(batch)
    local batches=M.account.craftBatches or {};if not batch or batches[1]~=batch then return false,"Only the most recent batch can be undone." end
    local output,index
    for i,lot in ipairs(M.account.ledger) do if lot.lotID==batch.outputLotID then output=lot;index=i;break end end
    if not output or #output.sales>0 or (output.craftUsed or 0)>0 then return false,"Output already sold or used; cannot undo." end
    for _,a in ipairs(batch.allocations) do for _,lot in ipairs(M.account.ledger) do if lot.lotID==a.lotID then lot.craftUsed=(lot.craftUsed or 0)-a.quantity;break end end end
    local shopping=batch.setupPlanID and M.account.shoppingPlans and M.account.shoppingPlans[batch.setupPlanID]
    if shopping then shopping.setupUsed=nil end
    table.remove(M.account.ledger,index);table.remove(batches,1);return true
end
function M.CraftSaleEstimate(cost,quantity,price,fee,reserve)
    local unit=cost/quantity;local factor=1-fee/100
    return {unitCost=unit,breakEven=math.ceil((unit+reserve)/factor),profit=price and (price*factor-unit-reserve)*quantity or nil}
end
local panel,recipe,selectedMat,selectedBatch,mode,notice=nil,nil,nil,nil,"plan",""
local widgets={};local render
local function money(n) if not n then return "--" end;local sign=n<0 and "-" or "";n=math.floor(math.abs(n)+.5);return string.format("%s%dg %02ds %02dc",sign,math.floor(n/10000),math.floor(n/100)%100,n%100) end
local function name(id) local get=C_Item and C_Item.GetItemInfo or GetItemInfo;return get and get(id) or ("Item "..id) end
local function button(text,x,y,w,fn) local b=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate");b:SetPoint("TOPLEFT",x,y);b:SetSize(w,25);b:SetText(text);b:SetScript("OnClick",fn);return M.UI.Button(b) end
local function field(label,x,y,value)
    local l=M.UI.Text(panel,12);l:SetPoint("TOPLEFT",x,y);l:SetText(label)
    local f=CreateFrame("EditBox",nil,panel,"InputBoxTemplate");f:SetPoint("TOPLEFT",x,y-20);f:SetSize(110,22);f:SetAutoFocus(false);f:SetText(value);f:SetScript("OnEscapePressed",f.ClearFocus);return f
end
render=function()
    if not panel or not panel:IsShown() then return end
    panel.title:SetText(recipe.name.." - actual purchase costs")
    local prices=M.AlchemyPrices(M.market.items,M.unavailable);local p=prices[recipe.itemID]
    local price=p and not p.unavailable and p.price or nil
    local age=p and math.floor((time()-p.time)/60)
    local priceText="AH / unit: "..money(price)..(age and (" | "..age.."m"..(age>15 and " STALE" or "")) or "")
    local rows={};local cols;local plan
    if mode=="plan" then
        plan=M.PlanCraftCost(recipe,tonumber(panel.crafts:GetText()))
        cols={{"Material",240},{"Needed",85},{"Recorded",85},{"Paid cost",130}}
        if plan then rows=plan.materials end
    else
        cols={{"Batch",215},{"Output",85},{"Cost / unit",110},{"Total cost",130}}
        for _,b in ipairs(M.account.craftBatches or {}) do if b.recipeID==recipe.id then rows[#rows+1]=b end end
    end
    M.UI.Headers(panel,cols,-150)
    rows=M.UI.Page(panel,rows,render)
    for i,r in ipairs(rows) do
        local values=mode=="plan" and {name(r.id),r.needed,r.recorded,money(r.cost)} or {date("%d %b %H:%M",r.time),r.quantity,money(r.cost/r.quantity),money(r.cost)}
        local w=M.UI.Row(panel.content,widgets,i,cols,values,mode=="plan" and selectedMat==r.id or selectedBatch==r)
        w:SetScript("OnClick",function() if mode=="plan" then selectedMat=r.id else selectedBatch=r end;render() end)
    end
    for i=#rows+1,#widgets do widgets[i]:Hide() end;panel.content:SetHeight(math.max(1,#rows*32))
    local cost,output
    if mode=="plan" then cost=plan and plan.complete and plan.cost;output=tonumber(panel.output:GetText())
    elseif selectedBatch then cost=selectedBatch.cost;output=selectedBatch.quantity end
    local text={priceText}
    if cost and integer(output) then
        local e=M.CraftSaleEstimate(cost,output,price,M.settings.fee,M.settings.deposit)
        text[#text+1]="Paid cost: "..money(cost).." | Cost / output: "..money(e.unitCost)
        text[#text+1]="Break-even AH price / unit: "..money(e.breakEven)
        if mode=="batches" and selectedBatch then
            for _,lot in ipairs(M.account.ledger) do
                if lot.lotID==selectedBatch.outputLotID then
                    local remaining,realized=M.Balance(lot)
                    text[#text+1]="Remaining: "..remaining.." | Estimated unsold P/L: "..money(e.profit and e.profit*remaining/output)
                    text[#text+1]="Recorded sales P/L: "..money(realized)
                    break
                end
            end
        else text[#text+1]="Estimated batch P/L at current AH: "..money(e.profit) end
    else text[#text+1]=mode=="plan" and "Missing cost records or invalid quantities. No profit assumed." or "Select a recorded batch." end
    text[#text+1]=notice;panel.summary:SetText(table.concat(text,"\n"))
    panel.material:SetText(selectedMat and ("Record missing purchase\n"..name(selectedMat)) or "Select a material on the left.\nEnter actual quantity and TOTAL paid.")
end
function M.ShowCraftCosts(r)
    if not r then return end
    recipe=r;selectedMat=nil;selectedBatch=nil;mode="plan";notice=""
    if not panel then
        panel=M.UI.Window("GuildMarketCraftCostsFrame");panel:SetSize(950,660);panel:SetPoint("CENTER");panel:SetFrameStrata("FULLSCREEN_DIALOG");panel.TitleText:SetText("Production costs")
        panel:SetMovable(true);panel:EnableMouse(true);panel:RegisterForDrag("LeftButton");panel:SetScript("OnDragStart",panel.StartMoving);panel:SetScript("OnDragStop",panel.StopMovingOrSizing);table.insert(UISpecialFrames,"GuildMarketCraftCostsFrame")
        panel.title=M.UI.Text(panel,16);panel.title:SetPoint("TOPLEFT",16,-42)
        panel.crafts=field("Crafts completed",20,-78,"1");panel.output=field("Actual output",155,-78,"1")
        panel.crafts:SetScript("OnTextChanged",function(self) local n=tonumber(self:GetText());if n and recipe and recipe.count then panel.output:SetText(tostring(n*recipe.count)) end;render() end)
        panel.output:SetScript("OnTextChanged",render)
        button("Plan costs",300,-98,110,function() mode="plan";render() end)
        button("Recorded batches",420,-98,140,function() mode="batches";selectedBatch=nil;render() end)
        local scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",16,-180);scroll:SetSize(550,210);panel.gmtScroll=scroll
        panel.content=CreateFrame("Frame",nil,scroll);panel.content:SetSize(540,1);scroll:SetScrollChild(panel.content)
        panel.material=M.UI.Text(panel,13);panel.material:SetPoint("TOPLEFT",610,-154);panel.material:SetWidth(315)
        panel.qty=field("Purchased quantity",615,-215,"");panel.paid=field("Total paid (gold)",760,-215,"")
        button("Record material purchase",610,-280,300,function()
            local q,total=tonumber(panel.qty:GetText()),tonumber(panel.paid:GetText())
            if selectedMat and total and M.Purchase({itemID=selectedMat},q,total*10000,time(),"Manual material cost") then
                notice="Purchase recorded. Do not duplicate an automatic Ledger entry.";panel.qty:SetText("");panel.paid:SetText("")
            else notice="Select a material and enter positive quantity / total cost." end;render()
        end)
        button("Open purchase ledger",610,-320,300,function() panel:Hide();M.OpenTab("Ledger") end)
        panel.summary=M.UI.Text(panel,13);panel.summary:SetPoint("TOPLEFT",16,-416);panel.summary:SetWidth(900)
        button("Record completed batch",16,-535,240,function()
            if mode~="plan" then notice="Choose Plan costs before recording another completed batch.";render();return end
            local batch,msg=M.RecordCraftBatch(recipe,tonumber(panel.crafts:GetText()),tonumber(panel.output:GetText()),time())
            if batch then selectedBatch=batch;mode="batches";notice="Batch saved. Actual costs are locked; AH estimates can change." else notice=msg end;render()
        end)
        button("Undo latest batch",270,-535,180,function() local ok,msg=M.UndoCraftBatch(selectedBatch);notice=ok and "Batch undone; material quantities restored." or msg;selectedBatch=nil;render() end)
        button("Buy materials",610,-116,300,function() M.ShowCraftShopping(recipe,tonumber(panel.crafts:GetText()) or 1) end)
        button("Refresh sale price",610,-360,300,function()
            local ok,msg=M.RefreshRecipePrices({itemID=recipe.itemID,mats={}},function(text) notice=text;render() end);if not ok then notice=msg;render() end
        end)
        local foot=M.UI.Text(panel,12);foot:SetPoint("BOTTOMLEFT",16,42);foot:SetWidth(900);foot:SetText("FIFO purchase costs; no physical bag tracking. Record only completed crafts. Sales are recorded in Ledger.\nP/L assumes all batch units sell at the current asking price, after AH cut and relist reserve.")
    end
    if panel.gmtPager then panel.gmtPager.page=1 end
    panel.crafts:SetText("1");panel.output:SetText(tostring(recipe.count or 1));panel:Show();render()
end
M.RefreshCraftCosts=render

M.HideCraftCosts=function() if panel then panel:Hide() end end
