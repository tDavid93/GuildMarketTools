from pathlib import Path
from lupa.lua51 import LuaRuntime
l=LuaRuntime();root=Path('GuildMarketTools')
for name in ['MarketCore.lua','CraftCosts.lua']:l.execute(root.joinpath(name).read_text())
l.execute("""
local M=GuildMarketTools;M.Init({},'realm','char',100)
local recipe={id=100,itemID=9,name='Potion',count=1,mats={{id=1,count=2},{id=2,count=1}}}
local a=M.Purchase({itemID=1},10,1000,1,'Manual');local b=M.Purchase({itemID=1},10,2000,2,'Manual')
local vial=M.Purchase({itemID=2},20,200,3,'Manual')
local p=M.PlanCraftCost(recipe,6);assert(p.complete and p.cost==1460)
local batch=M.RecordCraftBatch(recipe,6,6,100);assert(batch and batch.cost==1460)
assert(M.Balance(a)==0 and M.Balance(b)==8 and M.Balance(vial)==14)
local p2=M.PlanCraftCost(recipe,4);assert(p2.complete and p2.cost==1640)
local before=#M.account.ledger;assert(not M.RecordCraftBatch(recipe,5,5,101));assert(#M.account.ledger==before and M.Balance(b)==8)
local x=M.CraftSaleEstimate(batch.cost,batch.quantity,400,5,10)
local y=M.CraftSaleEstimate(batch.cost,batch.quantity,200,5,10)
assert(x.profit>0 and y.profit<0 and x.unitCost==y.unitCost and x.breakEven==267)
assert(M.UndoCraftBatch(batch));assert(M.Balance(a)==10 and M.Balance(b)==10 and M.Balance(vial)==20)
assert(not M.UndoCraftBatch(nil))
batch=M.RecordCraftBatch(recipe,2,3,102);assert(batch.cost==420 and batch.quantity==3)
local out;for _,lot in ipairs(M.account.ledger) do if lot.lotID==batch.outputLotID then out=lot end end
assert(out.cost==420 and out.quantity==3)
assert(M.Sale(out,1,200,103));assert(not M.UndoCraftBatch(batch))
assert(not M.Sale(a,8,10,103)) -- 4 consumed already
assert(not M.PlanCraftCost(recipe,0));assert(not M.RecordCraftBatch(recipe,1,0,104))
local duplicate={id=101,itemID=10,name='Repeated ingredient',count=1,mats={{id=1,count=1},{id=1,count=1}}}
p=M.PlanCraftCost(duplicate,1);assert(#p.materials==1 and p.materials[1].needed==2)
M.Observe({itemID=1},99999,1,105,'Herb');assert(M.PlanCraftCost(duplicate,1).cost==200)
assert(M.CraftSaleEstimate(100,1,nil,5,0).profit==nil)
""")
print('PASS: FIFO split lots, actual unit cost, shortages/atomic failure, consumed balance, fixed basis across AH changes, break-even and profit/loss, variable actual output, undo guards/restoration, duplicate ingredient aggregation.')
