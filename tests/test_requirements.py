from pathlib import Path
from lupa.lua51 import LuaRuntime
l=LuaRuntime();root=Path('GuildMarketTools')
l.execute(root.joinpath('MarketCore.lua').read_text())
l.execute("CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end;time=function() return 1000 end")
for n in ['CraftRequirements.lua','Alchemy.lua','CraftShopping.lua','CraftCosts.lua']:l.execute(root.joinpath(n).read_text())
l.execute("""
local M=GuildMarketTools;M.Init({},'realm','char',1000)
local recipe={id=999,itemID=100,count=2,name='Different recipe',mats={{id=200,count=3}}}
C_TradeSkillUI={GetRecipeTools=function() return 'Fermenter',false,'Campfire',false,'Anvil',true end,GetRecipeCooldown=function() return 120 end}
M.ReadRecipeRequirements(recipe)
assert(recipe.requirementsRead and #recipe.requirements==3 and recipe.cooldownUntil==1120)
assert(#M.RecipeSetup(recipe)==2) -- dependency deduplicated
local prices={[100]={price=1000,time=1000},[200]={price=100,time=1000},[279970]={price=500,time=1000},[279981]={price=100,time=1000}}
local e=M.AlchemyEstimate(recipe,prices,1000,5,10)
assert(e.cost==900 and e.profit==980 and e.setupCost==600)
local p=M.StartCraftShopping(recipe,10)
assert(p.needs[279970]==1 and p.needs[279981]==1 and p.needs[200]==30)
e=M.AlchemyEstimate(recipe,prices,1000,5,10);assert(e.cost==360 and e.profit==1520)
p.includeSetup=false;M.StartCraftShopping(recipe,10)
e=M.AlchemyEstimate(recipe,prices,1000,5,10);assert(e.cost==300 and e.profit==1580)
p.includeSetup=true;prices[279970]=nil
e=M.AlchemyEstimate(recipe,prices,1000,5,0);assert(not e.profit and not e.cost and #e.missing==1)
prices[279970]={price=500,time=1};assert(M.AlchemyEstimate(recipe,prices,1000,5,0).stale)
C_TradeSkillUI.GetRecipeTools=function() return 'Unknown Station',false end
M.ReadRecipeRequirements(recipe);assert(M.RequirementsUnknown(recipe))
assert(not M.AlchemyEstimate(recipe,prices,1000,5,0).profit)
assert(not M.PlanCraftCost(recipe,10))
C_TradeSkillUI.GetRecipeTools=function() return 'Anvil',true end
M.ReadRecipeRequirements(recipe);assert(#M.RecipeSetup(recipe)==0 and not M.RequirementsUnknown(recipe))
C_TradeSkillUI.GetRecipeTools=function() return end
M.ReadRecipeRequirements(recipe);assert(recipe.requirementsRead and #recipe.requirements==0)
assert(M.AlchemyEstimate(recipe,prices,1000,5,0).cost==300)
C_TradeSkillUI.GetRecipeTools=function() return {{name='Hammer',itemID=555,isAvailable=false}} end
M.ReadRecipeRequirements(recipe);assert(M.RecipeSetup(recipe)[1].id==555)
C_TradeSkillUI.GetRecipeTools=nil
local old={id=20000,itemID=1,mats={{id=200,count=1}},count=1}
assert(M.RequirementsUnknown(old) and not M.AlchemyEstimate(old,prices,1000,5,0).profit)
-- Known tool resolved from native item cache, arbitrary profession.
GetItemInfo=function(name) return name,'item:555' end
C_TradeSkillUI.GetRecipeTools=function() return 'Hammer',true end
M.ReadRecipeRequirements(recipe);assert(M.RecipeSetup(recipe)[1].id==555)
""")
for p in root.glob('*.lua'):l.execute('assert(loadstring(...))',p.read_text(encoding='utf-8-sig'))
print('PASS: generic recipe tools, station dependencies/deduplication, per-batch amortized profit, existing setup, unknown/missing/stale costs, cooldowns, cached tools, syntax.')
