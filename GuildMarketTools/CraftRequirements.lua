local M=GuildMarketTools
local known={
    ["fermenter"]={id=279970,name="Fermenter",camp=true},
    ["campfire"]={id=279981,name="Basic Campfire Kit"},
    ["cooking fire"]={id=279981,name="Basic Campfire Kit"},
    ["basic campfire"]={id=279981,name="Basic Campfire Kit"},
}
local freeStations={forge=true,anvil=true,["black anvil"]=true,["moonwell"]=true}
local function clean(s) return s:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("^%s+",""):gsub("%s+$","") end
function M.ReadRecipeRequirements(recipe)
    local api=C_TradeSkillUI
    if not api or not api.GetRecipeTools then return end
    local values={pcall(api.GetRecipeTools,recipe.id)}
    if not values[1] then return end
    local result={};local valid=true
    local function add(name,available,id)
        if type(name)~="string" or name=="" then valid=false;return end
        name=clean(name);local key=name:lower();local mapped=known[key]
        if not id and not mapped and not freeStations[key] then
            local get=C_Item and C_Item.GetItemInfo or GetItemInfo
            if get then local ok,_,link=pcall(get,name);if ok and type(link)=="string" then id=tonumber(link:match("item:(%d+)")) end end
        end
        result[#result+1]={name=name,id=id or mapped and mapped.id,environment=freeStations[key] or false,
            camp=mapped and mapped.camp or false,available=available==true}
    end
    if type(values[2])=="table" then
        for _,v in ipairs(values[2]) do
            if type(v)=="table" then add(v.name or v.toolName,v.isAvailable or v.available,v.itemID)
            elseif type(v)=="string" then add(v) else valid=false end
        end
    else
        local i=2
        while values[i]~=nil do
            if type(values[i])~="string" then valid=false;break end
            add(values[i],values[i+1]);i=i+2
        end
    end
    if valid then recipe.requirements=result;recipe.requirementsRead=true;recipe.requirementsReadAt=time() end
    if api.GetRecipeCooldown then
        local ok,seconds=pcall(api.GetRecipeCooldown,recipe.id)
        if ok and type(seconds)=="number" then recipe.cooldownUntil=time()+math.max(0,seconds) end
    end
end
function M.RecipeRequirements(recipe)
    local data=M.RequirementDatabase and M.RequirementDatabase[recipe.id]
    if recipe.requirementsRead then
        local live=recipe.requirements or {}
        -- Use static IDs when the client supplies only unresolved names.
        local complete=true
        for _,v in ipairs(live) do if not v.id and not v.environment then complete=false end end
        if complete and (#live>0 or not data or #data==0) then return live,true,"Client" end
    end
    if data then return data,true,(M.RequirementDatabaseSources and M.RequirementDatabaseSources[recipe.id]) or ("Forever DB "..M.RequirementDatabaseBuild) end
    -- Previously verified fallback until the profession is read again.
    if recipe.id==3449 or recipe.itemID==3824 then return {{id=279970,name="Fermenter",camp=true}},true end
    return {},false
end
function M.RecipeSetup(recipe)
    local requirements=M.RecipeRequirements(recipe);local out,seen={},{}
    local function add(id,name) if id and not seen[id] then seen[id]=true;out[#out+1]={id=id,count=1,name=name} end end
    for _,v in ipairs(requirements) do
        if v.camp then add(279981,"Basic Campfire Kit") end
        local owned=false
        local count=C_Item and C_Item.GetItemCount or GetItemCount
        if v.reusable and v.id and count then local ok,n=pcall(count,v.id,false);owned=ok and type(n)=="number" and n>0 end
        if not v.environment and not owned then add(v.id,v.name) end
    end
    return out
end
function M.RequirementsUnknown(recipe)
    local list,read=M.RecipeRequirements(recipe)
    if not read then return "Read open profession to import extra requirements." end
    for _,v in ipairs(list) do if not v.id and not v.environment then return "Unpriced requirement: "..v.name end end
end
function M.SetupPolicy(recipe)
    local p=M.account and M.account.activeShoppingPlan
    if p and p.recipe.id==recipe.id then return p.includeSetup~=false and not p.setupUsed,math.max(1,p.crafts or 1) end
    return true,1
end
function M.CraftRequirementsText(recipe)
    local list,_,source=M.RecipeRequirements(recipe);local lines={};local camping=false
    if source then lines[#lines+1]="Requirements source: "..source end
    local unknown=M.RequirementsUnknown(recipe);if unknown then lines[#lines+1]=unknown end
    for _,v in ipairs(list) do
        lines[#lines+1]="Requires: "..v.name..(v.environment and " (world station; no purchase cost)" or "")
        if v.camp or v.id==279981 then camping=true end
    end
    if camping then
        lines[#lines+1]="Campfire required. Camping placement cooldown: 1 hour shared."
        local get=GetItemCooldown or (C_Item and C_Item.GetItemCooldown)
        if get and GetTime then
            local ok,start,duration=pcall(get,279970)
            if type(start)=="table" then local c=start;start,duration=c.startTime,c.duration end
            if ok and type(start)=="number" and type(duration)=="number" then
                local left=math.max(0,start+duration-GetTime())
                if left>0 then lines[#lines+1]="Placement cooldown: "..math.ceil(left/60).." min remaining." end
            end
        end
    end
    if recipe.cooldownUntil and recipe.cooldownUntil>time() then lines[#lines+1]="Recipe cooldown: "..math.ceil((recipe.cooldownUntil-time())/60).." min remaining." end
    if #list>0 then lines[#lines+1]="Nearby station / tool availability must be checked in the profession window." end
    return #lines>0 and table.concat(lines,"\n") or nil
end
function M.AddSetupNeeds(needs,recipe,plan)
    if not plan or not plan.includeSetup or plan.setupUsed or plan.recipe.id~=recipe.id then return end
    for _,mat in ipairs(M.RecipeSetup(recipe)) do needs[mat.id]=(needs[mat.id] or 0)+mat.count end
end
