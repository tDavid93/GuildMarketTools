from lupa.lua51 import LuaRuntime
from pathlib import Path
l=LuaRuntime();root=Path('GuildMarketTools')
l.execute(root.joinpath('MarketCore.lua').read_text());l.execute(root.joinpath('MarketDepth.lua').read_text())
l.execute("""
local M=GuildMarketTools
local d=M.DepthStats(nil);assert(d.units==0 and not d.median and not d.time)
d=M.DepthStats({full=true,time=500,rows={{price=100,quantity=2,auctionID=1},{price=100,quantity=3,auctionID=2},{price=200,quantity=5,auctionID=3},{price=300,quantity=10,auctionID=4},{price=1,quantity=100,own=true},{price=-1,quantity=1}}})
assert(d.units==20 and #d.levels==3 and d.listings==4 and d.full and d.time==500)
assert(d.minimum==100 and d.maximum==300 and d.q25==100 and d.median==200 and d.q75==300)
assert(d.mean==225 and d.value==4500)
assert(d.levels[1].quantity==5 and d.levels[1].share==25 and d.levels[2].cumulative==10)
d=M.DepthStats({full=false,rows={{price=200,quantity=10},{price=100,quantity=1}}})
assert(not d.full and d.listings==nil and d.median==200 and d.minimum==100)
d=M.DepthStats({full=true,rows={}});assert(d.units==0 and d.minimum==nil and #d.levels==0)
d=M.DepthStats({full=true,rows={{price=10,quantity=1}}});assert(d.q25==10 and d.q75==10 and d.median==10)
""")
print('PASS: quantity aggregation, weighted median/quartiles/mean, cumulative supply/share, own/invalid exclusion, unknown commodity auction count, partial/empty/single-level cases.')

l.execute("""
local M=GuildMarketTools
M.Init({},'Test','Test',100)
assert(not M.RecipeMarketStats({itemID=1}).source)
M.Observe({itemID=1},100,12,100,'Output')
M.Observe({itemID=1,itemSuffix=10},999,99,105,'Variant')
local d=M.RecipeMarketStats({itemID=1});assert(d.source=='browse' and d.units==12 and not d.value)
M.Detail({itemID=1},{{price=100,quantity=2},{price=200,quantity=3},{price=1,quantity=100,own=true}},false,110)
d=M.RecipeMarketStats({itemID=1});assert(d.source=='depth' and d.units==5 and d.value==800 and not d.full and not d.listings)
M.Detail({itemID=1},{},true,120)
d=M.RecipeMarketStats({itemID=1});assert(d.full and d.units==0 and d.time==120)
assert(not M.RecipeMarketStats({itemID=2}).source)
""")
print('PASS: recipe supply uses matching base item; browse has no invented market value; partial depth, own exclusion and newer empty result preserved.')
