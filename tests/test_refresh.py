from pathlib import Path
from lupa.lua51 import LuaRuntime
l=LuaRuntime();root=Path('GuildMarketTools')
l.execute(root.joinpath('MarketCore.lua').read_text())
l.execute("CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end")
l.execute(root.joinpath('ProfessionRefresh.lua').read_text())
l.execute(r"""
local M=GuildMarketTools
local t,timers,requests,notes=0,{},{},{}
local open,combat,ready,full=true,false,true,true
local commodity=false; local listings={}; local more=0
local function after(delay,fn) timers[#timers+1]={at=t+delay,fn=fn} end
local function step(dt)
 local untilTime=t+dt
 while true do
  local n; for i,v in ipairs(timers) do if v.at<=untilTime and (not n or v.at<timers[n].at) then n=i end end
  if not n then break end
  local v=table.remove(timers,n); t=v.at;v.fn()
 end;t=untilTime
end
local api={IsThrottledMessageSystemReady=function() return ready end,
 SendSearchQuery=function(key) requests[#requests+1]=key.itemID end,
 HasFullItemSearchResults=function() return full end,HasFullCommoditySearchResults=function() return full end,
 GetNumItemSearchResults=function() return #listings end,GetNumCommoditySearchResults=function() return #listings end,
 GetItemSearchResultInfo=function(_,i) return listings[i] end,GetCommoditySearchResultInfo=function(_,i) return listings[i] end,
 RequestMoreItemSearchResults=function() more=more+1 end}
local env={open=function() return open end,combat=function() return combat end,now=function() return 1000+t end,after=after}
local items={{key={itemID=1},name='Output'},{key={itemID=2},name='Material'}}
local function init() M.Init({},'realm','char',1000); return M.CreateProfessionRefresh(api,env) end
local q=init();open=false;assert(not q:Start(items));open=true;combat=true;assert(not q:Start(items));combat=false
ready=false; assert(q:Start(items,function(s) notes[#notes+1]=s end)); assert(#requests==0)
step(.5);assert(#requests==0);ready=true;step(.5);assert(requests[1]==1)
q:Event('ITEM_SEARCH_RESULTS_UPDATED',{itemID=999});assert(not M.market.items['999:0:0:0'])
full=false;q:Event('ITEM_SEARCH_RESULTS_UPDATED',{itemID=1});assert(more==1 and not M.market.items['1:0:0:0'])
full=true;listings={{itemKey={itemID=1},quantity=2,buyoutAmount=1000,auctionID=10}}
q:Event('ITEM_SEARCH_RESULTS_UPDATED',{itemID=1});assert(M.market.items['1:0:0:0'].price==500)
step(.3);assert(requests[2]==2)
listings={{quantity=10,unitPrice=100}};q:Event('COMMODITY_SEARCH_RESULTS_UPDATED',2);step(.3)
assert(not q.active and M.market.items['2:0:0:0'].price==100)
q=init();assert(q:Start(items));q:ExternalQuery();assert(not q.active);local n=#requests;step(30);assert(#requests==n)
q=init();assert(q:Start(items));step(21);assert(not q.active)
q=init();assert(q:Start(items));q:Event('AUCTION_HOUSE_CLOSED');assert(not q.active)
q=init();assert(q:Start(items));q:Event('PLAYER_REGEN_DISABLED');assert(not q.active)
q=init();M.Observe({itemID=1},777,1,999,'Output');assert(q:Start(items));listings={};full=true
q:Event('ITEM_SEARCH_RESULTS_UPDATED',{itemID=1});assert(M.unavailable['1:0:0:0'] and M.market.items['1:0:0:0'].time==999)
q:Cancel();step(30);assert(not q.active)
""")
print('PASS: closed AH/combat guards, throttle wait, sequential item+commodity queries, matching events, pagination, external-search cancellation, timeout, close/combat cancellation, empty result preserves old timestamp and marks unavailable.')
