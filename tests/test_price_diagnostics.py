from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path('GuildMarketTools')
lua = LuaRuntime()
lua.execute((root / 'MarketCore.lua').read_text(encoding='utf-8'))
lua.execute('CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end')
lua.execute((root / 'Alchemy.lua').read_text(encoding='utf-8'))
lua.execute('''
local M=GuildMarketTools
local recipe={itemID=1,count=1,mats={{id=2,count=2},{id=3,count=1}}}
local p={[1]={price=1000,time=100},[2]={price=50,time=100}}
local r=M.AlchemyEstimate(recipe,p,100,5,0)
assert(r.unitPrice==1000 and r.knownCost==100 and not r.cost and not r.profit)
assert(r.missingDetails[1].role=='Material' and r.missingDetails[1].id==3)
assert(M.RecipePriceStatus(r)=='Missing mats')
p[1]=nil;r=M.AlchemyEstimate(recipe,p,100,5,0)
assert(M.RecipePriceStatus(r)=='No sale price' and #r.missingDetails==2)
p[1]={price=1000,time=100,unavailable=true}
assert(M.AlchemyEstimate(recipe,p,100,5,0).missingDetails[1].reason:find('No buyout',1,true))
p[1].unavailable=nil;p[3]={price=10,time=100}
M.RecipeSetup=function() return {{id=4,count=1}} end
r=M.AlchemyEstimate(recipe,p,100,5,0)
assert(M.RecipePriceStatus(r)=='Missing setup' and r.materialCost==110 and r.unitPrice==1000)
M.VendorMaterial=function(id) if id==4 then return {source='Vendor'} end end
r=M.AlchemyEstimate(recipe,p,100,5,0)
assert(r.missingDetails[1].reason:find('visit a supplier',1,true))
local requests=0
C_Item={GetItemInfo=function() end,RequestLoadItemDataByID=function() requests=requests+1 end}
M.RequirementDatabase={[10]={{id=4,name='Known Tool'}}}
assert(M.RecipeItemName(4,{})=='Known Tool')
assert(M.RecipeItemName(4,{})=='Known Tool' and requests==1)
assert(M.RecipeItemName(8,{}):find('name loading',1,true))
C_Item.GetItemInfo=function() return 'Loaded Item' end
assert(M.RecipeItemName(8,{})=='Loaded Item')
''')
print('PASS: missing output/material/setup/vendor reasons, known subtotal, sale quote retained, asynchronous name request and cached-name recovery.')
