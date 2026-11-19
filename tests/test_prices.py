from pathlib import Path
from lupa.lua51 import LuaRuntime
l=LuaRuntime();root=Path('GuildMarketTools')
l.execute(root.joinpath('MarketCore.lua').read_text())
l.execute("CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end")
l.execute(root.joinpath('Alchemy.lua').read_text())
l.execute("""
local M=GuildMarketTools;M.Init({},'realm','char',1000)
local key={itemID=250332};local id=M.Key(key)
local recipe={itemID=250332,count=1,mats={{id=3819,count=2}}}
M.Observe(key,5545,183,1000,"Cleric's Elixir")
local function estimate() return M.AlchemyEstimate(recipe,M.AlchemyPrices(M.market.items,M.unavailable),1010,5,0) end
assert(estimate().unitPrice==5545)
M.Detail(key,{},false,1001)
assert(estimate().unitPrice==5545 and not M.unavailable[id])
assert(M.market.items[id].time==1000) -- no fake fresh price
M.Detail(key,{},true,1002)
assert(not estimate().unitPrice and M.unavailable[id]) -- real empty results still hide quote
M.Detail(key,{{price=6000,quantity=10}},true,1003)
assert(estimate().unitPrice==6000 and M.market.items[id].time==1003 and not M.unavailable[id])
M.Detail(key,{{price=1,quantity=1,own=true}},false,1004)
assert(estimate().unitPrice==6000) -- partial own-only result is not no listings
""")
# Exercise completion feedback through the real refresh queue.
l.execute(root.joinpath('ProfessionRefresh.lua').read_text())
l.execute("""
local M=GuildMarketTools;local tasks={};local note
local api={SendSearchQuery=function() end,HasFullItemSearchResults=function() return true end,
 GetNumItemSearchResults=function() return 0 end,GetItemSearchResultInfo=function() end}
local q=M.CreateProfessionRefresh(api,{open=function() return true end,combat=function() return false end,
 now=function() return 1010 end,after=function(delay,fn) if delay<1 then tasks[#tasks+1]=fn end end})
assert(q:Start({{key={itemID=250332},name="Cleric's Elixir"}},function(s) note=s end))
q:Event('ITEM_SEARCH_RESULTS_UPDATED',{itemID=250332})
for _,f in ipairs(tasks) do f() end
assert(not q.active and note:find("No buyout listings: Cleric's Elixir",1,true))
""")
for p in root.glob('*.lua'):l.execute('assert(loadstring(...))',p.read_text(encoding='utf-8-sig'))
print('PASS: Clerics partial-empty/own-only price retention, real empty result, successful price recovery, exact refreshed timestamp, named no-listings summary, Lua syntax.')
