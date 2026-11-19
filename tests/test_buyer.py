from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
l=LuaRuntime()
l.execute('GuildMarketTools={}')
l.execute((root/'GuildMarketTools/VendorBuyer.lua').read_text(encoding='utf-8-sig'))
l.execute('''
function setup()
 clock=0; opened=true; combat=false; ready=true; full=true; kind=1; funds=200000
 cfg={limit=10000,reserve=100000,reserved=0}; calls={}; timers={}; sounds=0
 key={itemID=123,itemLevel=10,itemSuffix=0,battlePetSpeciesID=0}
 results={{auctionID=7,itemKey=key,itemLink='item:123:exact',quantity=2,buyoutAmount=300}}
 api={
 GetItemKeyInfo=function() return {commodityStatus=kind} end,
 IsThrottledMessageSystemReady=function() return ready end,
 SendSearchQuery=function() calls.search=(calls.search or 0)+1 end,
 HasFullItemSearchResults=function() return full end,
 GetNumItemSearchResults=function() return #results end,
 GetItemSearchResultInfo=function(_,i) return results[i] end,
 PlaceBid=function(id,cost) calls.buy=(calls.buy or 0)+1; calls.id=id; calls.cost=cost end
 }
 env={config=function() return cfg end,open=function() return opened end,
 combat=function() return combat end,now=function() return clock end,money=function() return funds end,
 after=function(delay,fn) timers[#timers+1]={delay,fn} end,coins=tostring,
 item=function(link) if link=='item:123:exact' then return 'Test',200 end end,
 isItem=function(i) return i.commodityStatus==1 end,alert=function() sounds=sounds+1 end}
 b=GuildMarketTools.CreateVendorBuyer(api,env)
end
function quote() b:Verify(key,150); b:Event('ITEM_SEARCH_RESULTS_UPDATED',key) end
setup(); quote(); assert(b.state=='ready' and b.quote.gain==100 and sounds==1 and not calls.buy)
b:Buy(); b:Buy(); assert(calls.buy==1 and calls.id==7 and calls.cost==300 and cfg.reserved==300)
b:Event('AUCTION_HOUSE_PURCHASE_COMPLETED',999); assert(b.pending)
b:Event('AUCTION_HOUSE_PURCHASE_COMPLETED',7); assert(not b.pending and b.state=='idle')
b=GuildMarketTools.CreateVendorBuyer(api,env); quote(); assert(b.state=='idle') -- attempted IDs survive reload
setup(); quote(); results[1].buyoutAmount=301; b:Buy(); assert(not calls.buy and b.state=='idle')
setup(); quote(); results[1].quantity=1; b:Buy(); assert(not calls.buy)
setup(); quote(); results[1].auctionID=8; b:Buy(); assert(not calls.buy)
setup(); quote(); results={}; b:Buy(); assert(not calls.buy)
setup(); quote(); clock=5; b:Buy(); assert(not calls.buy)
setup(); quote(); combat=true; b:Buy(); assert(not calls.buy)
setup(); quote(); funds=100100; b:Buy(); assert(not calls.buy)
setup(); quote(); cfg.limit=299; b:Buy(); assert(not calls.buy)
setup(); results[1].containsOwnerItem=true; quote(); assert(b.state=='idle' and not calls.buy)
setup(); results[1].itemLink=nil; quote(); assert(b.state=='idle')
setup(); results[1].itemKey={itemID=123,itemSuffix=99}; quote(); assert(b.state=='idle')
setup(); results[1].buyoutAmount=301; quote(); assert(b.state=='idle') -- 99c profit
setup(); results[1].buyoutAmount=250; b:Verify(key,100); b:Results(key); assert(b.state=='idle') -- snapshot ceiling
setup(); kind=2; quote(); assert(not calls.search and not calls.buy)
setup(); ready=false; quote(); assert(not calls.search)
setup(); b:Verify(key,150); full=false; b:Results(key); assert(b.state=='querying'); timers[1][2](); assert(b.state=='idle')
setup(); quote(); b:Event('AUCTION_HOUSE_CLOSED'); b:Buy(); assert(not calls.buy)
setup(); quote(); api.PlaceBid=function() error('uncertain') end; b:Buy(); assert(b.pending and cfg.reserved==300)
b:Verify(key,150); assert(b.state=='pending')
setup(); quote(); b:Buy(); b:Event('AUCTION_HOUSE_SHOW_ERROR'); b:Buy(); assert(calls.buy==1 and cfg.reserved==300)
setup(); b:Verify(key,150); b:Results({itemID=999}); assert(b.state=='querying' and not b.quote)
setup(); results[2]={auctionID=8,itemKey=key,itemLink='item:123:exact',quantity=5,buyoutAmount=700}
quote(); assert(b.quote.id==8 and b.quote.gain==300) -- total-profit order
''')
print('PASS: 24 scenarios: exact price/ID, >=1s threshold, changed price/quantity/identity, vanished/expired quote, combat, funds/cap, own items, missing link, snapshot ceiling, commodities, throttle, timeout, close, duplicate submission, persisted attempts, mismatched confirmation, uncertain failure, total-profit ordering.')
