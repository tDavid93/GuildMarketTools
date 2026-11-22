from pathlib import Path
from lupa.lua51 import LuaRuntime
lua=LuaRuntime()
for name in ['MarketCore.lua','AHledgerBridge.lua']:
 lua.execute((Path('GuildMarketTools')/name).read_text(encoding='utf-8'))
lua.execute("""
local M=GuildMarketTools
assert(not M.AHledgerPrice(1,100))
AHledgerAPI={VERSION=2,GetPrice=function() error('not called') end}
assert(not M.AHledgerPrice(1,100))
AHledgerAPI.VERSION=1
assert(not M.AHledgerPrice(1,100))
AHledgerAPI.GetPrice=function() return nil end
assert(not M.AHledgerPrice(1,100))
local source={median=100,minBuyout=80,soldPerDay=0,quantity=0,updated=100,market='forever/pvp/horde/eu',snapshot=false,median7d=90,median30d=110}
AHledgerAPI.GetPrice=function(id) assert(id==1);return source end
local p=M.AHledgerPrice(1,110)
assert(p.median==100 and p.minBuyout==80 and p.soldPerDay==0 and p.quantity==0 and p.age==10 and not p.stale)
assert(M.AHledgerPace(p)=='0.0' and p.market=='forever/pvp/horde/eu')
p.median=500;assert(source.median==100)
source.soldPerDay=nil;source.snapshot=true
p=M.AHledgerPrice(1,110);assert(M.AHledgerPace(p)=='--' and p.snapshot)
source.soldPerDay=12.5
assert(M.AHledgerPace(M.AHledgerPrice(1,110))=='12.5*')
source.snapshot=false
p=M.AHledgerPrice(1,4000);assert(p.stale and M.AHledgerPace(p)=='12.5*')
p=M.AHledgerPrice(1,90);assert(not p.age and p.stale)
source.updated=nil;source.median=-10;source.quantity=-1;source.soldPerDay=0/0
p=M.AHledgerPrice(1,100);assert(p.stale and not p.median and not p.quantity and not p.soldPerDay)
source.soldPerDay=math.huge;assert(not M.AHledgerPrice(1,100).soldPerDay)
assert(not M.AHledgerPrice(nil,100))
""")
print('PASS: optional AHledger API, incompatible/failing/missing provider, zero vs unknown sales, fresh/stale/future/snapshot data, numeric validation, market identity and no source mutation.')
