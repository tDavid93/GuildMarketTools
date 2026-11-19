from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path('GuildMarketTools')
lua = LuaRuntime()
lua.execute((root / 'MarketCore.lua').read_text(encoding='utf-8'))
lua.execute('CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end')
for name in ['VendorMaterials.lua', 'Alchemy.lua']:
    lua.execute((root / name).read_text(encoding='utf-8'))
lua.execute('''
local M=GuildMarketTools;M.Init({},'realm','character',100)
assert(M.VendorMaterial(2320).price==10 and M.VendorMaterial(2321).price==100)
assert(M.VendorMaterial(4291).price==500 and M.VendorMaterial(14341).price==5000)
-- Screenshot case: 5 bolts at 62c plus 2 Coarse Thread; 79s99c output.
local recipe={itemID=1,count=1,mats={{id=2996,count=5},{id=2320,count=2}}}
local prices={[1]={price=7999,time=100},[2996]={price=62,time=100}}
local r=M.AlchemyEstimate(recipe,prices,100,5,0)
assert(r.cost==330 and math.abs(r.profit-7269.05)<.001 and #r.missing==0)
-- Saved merchant discount takes precedence; stale thread AH quotes are ignored.
M.account.vendorMaterials={[2320]={price=9,name='Coarse Thread'}}
prices[2320]={price=99999,time=1}
r=M.AlchemyEstimate(recipe,prices,100,5,0)
assert(r.cost==328 and not r.stale)
M.account.vendorMaterials[2320].price=nil
assert(M.VendorMaterial(2320).price==10)
-- A missing output quote does not suppress a now-complete material cost.
recipe.mats[2]={id=2321,count=4};prices[1]=nil
r=M.AlchemyEstimate(recipe,prices,100,5,0)
assert(r.cost==710 and not r.unitPrice and not r.profit)
assert(#r.missing==1 and r.missingDetails[1].role=='Output')
assert(M.RecipePriceStatus(r)=='No sale price')
''')
print('PASS: screenshot Tailoring cost/profit, thread defaults, merchant-discount priority, invalid saved quote fallback, missing output retains material cost.')
