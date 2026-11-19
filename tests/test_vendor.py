from pathlib import Path
from lupa.lua51 import LuaRuntime
l=LuaRuntime(); root=Path('GuildMarketTools')
l.execute(root.joinpath('MarketCore.lua').read_text())
l.execute("CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end; time=function() return 1000 end")
for n in ['VendorMaterials.lua','Alchemy.lua','CraftShopping.lua']:l.execute(root.joinpath(n).read_text())
l.execute("""
local M=GuildMarketTools
M.account={};M.market={items={}}
local recipe={id=7,itemID=1,count=1,mats={{id=3372,count=2},{id=2,count=1}}}
local prices={[1]={price=1000,time=1000},[2]={price=100,time=1000},[3372]={price=99999,time=1}}
local r=M.AlchemyEstimate(recipe,prices,1000,5,0)
assert(r.cost==180 and not r.stale and #r.missing==0 and r.mats[1].vendor)
GetMerchantNumItems=function() return 4 end
GetMerchantItemLink=function(i) return 'item:'..({3372,2320,777,888})[i] end
GetMerchantItemInfo=function(i)
 if i==1 then return 'Leaded Vial',nil,180,5,-1,true,false end
 if i==2 then return 'Thread',nil,10,1,-1,true,false end
 if i==3 then return 'Limited herb',nil,10,1,2,true,false end
 return 'Token item',nil,10,1,-1,true,true
end
M.ReadVendorMaterials()
assert(M.VendorMaterial(3372).price==36)
assert(not M.VendorMaterial(777) and not M.VendorMaterial(888))
r=M.AlchemyEstimate(recipe,prices,1000,5,0);assert(r.cost==172 and not r.stale)
recipe.mats[1].id=4291
r=M.AlchemyEstimate(recipe,prices,1000,5,0);assert(not r.cost and r.missing[1]==4291)
recipe.mats[1].id=3372
assert(M.StartCraftShopping(recipe,1))
assert(not M.OpenShoppingMaterial(3372)) -- vendor guard before any AH API
-- Capture the actual refresh wrapper's queue, not an imitation of its filtering.
C_AuctionHouse={};C_Timer={After=function() end};InCombatLockdown=function() return false end
""")
s=root.joinpath('ProfessionRefresh.lua').read_text()
# Replace only queue construction for this wrapper test.
a=s.index('local Q=M.CreateProfessionRefresh(');b=s.index('\nfunction M.RefreshRecipePrices',a)
s=s[:a]+"local Q={Start=function(self,items) GuildMarketTools.testQueue=items;return true end}"+s[b:]
l.execute(s)
l.execute("""
local M=GuildMarketTools
GetItemInfo=function(id) return 'Item '..id,nil,nil,1 end
assert(M.RefreshRecipePrices({itemID=1,mats={{id=3372,count=1},{id=2320,count=1},{id=2,count=1}}}))
assert(#M.testQueue==2 and M.testQueue[1].key.itemID==1 and M.testQueue[2].key.itemID==2)
""")
for p in root.glob('*.lua'):l.execute('assert(loadstring(...))',p.read_text(encoding='utf-8-sig'))
print('PASS: vendor unit/bundle prices, merchant discounts, unknown prices, limited/token exclusion, no stale AH contamination, shopping AH guard, refresh queue excludes vendor materials, all Lua syntax.')
