-- Passive market analysis. Prices are copper; quantities are never inferred from browse minima.
GuildMarketTools = {}
local M = GuildMarketTools
local DAY = 86400
local function positive(n) return type(n)=="number" and n>0 and n<1e12 and n==n end
M.Positive = positive
function M.Key(k)
    if type(k)~="table" or not positive(k.itemID) then return end
    if M.market and M.market.commodities and M.market.commodities[k.itemID] and (k.itemSuffix or 0)==0 and (k.battlePetSpeciesID or 0)==0 then return k.itemID..":0:0:0" end
    return table.concat({k.itemID,k.itemLevel or 0,k.itemSuffix or 0,k.battlePetSpeciesID or 0},":")
end
function M.Init(db,scope,character,now)
    db.version=1; db.markets=db.markets or {}; db.characters=db.characters or {}
    db.markets[scope]=db.markets[scope] or {items={},watch={}}
    db.characters[character]=db.characters[character] or {ledger={},seen={}}
    M.db=db; M.market=db.markets[scope]; M.account=db.characters[character]
    M.market.commodities=M.market.commodities or {}
    M.settings=db.settings or {fee=5,discount=30,minProfit=1000,deposit=0}; db.settings=M.settings
    M.current={}; M.auctions={}; M.unavailable={}; M.now=now
    for id,item in pairs(M.market.items) do
        if now-(item.time or 0)>30*DAY and not M.market.watch[id] then M.market.items[id]=nil end
    end
    for id,t in pairs(M.account.seen) do if now-t>30*DAY then M.account.seen[id]=nil end end
end
-- Commodity events identify fungible items unambiguously. The Forever browse
-- scan includes their item level while commodity search events contain only ID.
function M.MarkCommodity(itemID)
    if M.market.commodities[itemID] then return end
    M.market.commodities[itemID]=true
    local canonical=itemID..":0:0:0"
    local latest,history,remove=nil,{},{}
    for id,item in pairs(M.market.items) do
        if M.Key(item.key)==canonical then
            if not latest or (item.time or 0)>(latest.time or 0) then latest=item end
            for _,h in ipairs(item.history or {}) do history[h.day]=math.min(history[h.day] or h.price,h.price) end
            if id~=canonical then
                remove[#remove+1]=id
                if M.market.watch[id] then
                    M.market.watch[canonical]=M.market.watch[canonical] or M.market.watch[id]
                    M.market.watch[id]=nil
                end
                local snapshot=M.current[id]
                if snapshot and (not M.current[canonical] or snapshot.time>M.current[canonical].time) then M.current[canonical]=snapshot end
                M.current[id]=nil; M.unavailable[id]=nil
            end
        end
    end
    for _,id in ipairs(remove) do M.market.items[id]=nil end
    if latest then
        latest.key={itemID=itemID}; latest.history={}
        local days={}; for day in pairs(history) do days[#days+1]=day end; table.sort(days)
        for i=math.max(1,#days-29),#days do latest.history[#latest.history+1]={day=days[i],price=history[days[i]]} end
        M.market.items[canonical]=latest
    end
end
function M.Median(values)
    if #values==0 then return end
    table.sort(values)
    local middle=math.floor(#values/2)+1
    if #values%2==0 then return (values[middle-1]+values[middle])/2 end
    return values[middle]
end
function M.HistoryReference(item,now)
    local prices={}; local today=math.floor(now/DAY)
    for _,h in ipairs(item.history or {}) do
        if h.day<today and h.day>=today-14 then prices[#prices+1]=h.price end
    end
    return #prices>=3 and M.Median(prices) or nil,#prices
end
function M.Observe(key,price,quantity,now,name,link)
    local id=M.Key(key)
    if not id or not positive(price) or (key.battlePetSpeciesID or 0)>0 then return end
    local item=M.market.items[id] or {key=key,history={}}
    if item.time and item.time>now then return id,item end
    local snapshot=M.current[id]
    if snapshot and snapshot.time<now and snapshot.rows[1] and snapshot.rows[1].price~=price then M.current[id]=nil end
    M.unavailable[id]=nil
    M.market.items[id]=item
    item.name=name or item.name or ("Item "..key.itemID); item.link=link or item.link
    item.price=price; item.quantity=quantity; item.time=now
    local day=math.floor(now/DAY); local h=item.history
    if h[#h] and h[#h].day==day then h[#h].price=math.min(h[#h].price,price)
    else h[#h+1]={day=day,price=price} end
    while #h>30 or (#h>0 and h[1].day<day-29) do table.remove(h,1) end
    return id,item
end
function M.Detail(key,rows,full,now,name,link)
    local clean={}
    for _,r in ipairs(rows) do
        if positive(r.price) and positive(r.quantity) and not r.own then clean[#clean+1]=r end
    end
    table.sort(clean,function(a,b) return a.price<b.price end)
    local id=M.Key(key)
    if not id then return end
    if M.market.items[id] and M.market.items[id].time>now then return end
    M.current[id]={rows=clean,full=full==true,time=now}
    if #clean==0 then if full==true then M.unavailable[id]=now end; return end
    local quantity=0
    for _,r in ipairs(clean) do
        quantity=quantity+r.quantity
        if r.auctionID then M.auctions[r.auctionID]={key=key,quantity=r.quantity,cost=r.price*r.quantity,name=name,link=link,time=now} end
    end
    M.Observe(key,clean[1].price,quantity,now,name,link)
end
function M.Deal(id,now)
    local item=M.market.items[id]; if not item then return end
    local historical,days=M.HistoryReference(item,now)
    local snapshot=M.current[id]; local fresh=snapshot and now-snapshot.time<=300 and #snapshot.rows>0
    local price,qty,peer,nextPrice,below,ownCost=item.price,nil,nil,nil,nil,nil
    if fresh then
        local rows=snapshot.rows; price=rows[1].price; qty=rows[1].quantity
        local peers={}
        for i=2,#rows do peers[#peers+1]=rows[i].price end
        -- One vote per listing / commodity price level, not per unit of stock.
        local median=M.Median(peers)
        if median then
            local trimmed={}
            for _,v in ipairs(peers) do if v<=median*3 then trimmed[#trimmed+1]=v end end
            if #trimmed>=3 then peer=M.Median(trimmed) end
        end
        nextPrice=rows[2] and rows[2].price
        ownCost=price*qty
    end
    local reference=peer and historical and math.min(peer,historical) or peer or historical
    local watch=M.market.watch[id]
    local target=watch and watch.target or reference
    if not (watch and watch.target) and target then target=math.max(1,math.min(target,nextPrice or target)-1) end
    if fresh and target then
        below=0
        for i=2,#snapshot.rows do if snapshot.rows[i].price<=target then below=below+snapshot.rows[i].quantity end end
    end
    local net=target and math.floor(target*(1-M.settings.fee/100))
    local profit=net and net-price-M.settings.deposit
    return {id=id,item=item,price=price,quantity=qty,cost=ownCost,reference=reference,target=target,
        discount=reference and (1-price/reference)*100,profit=profit,below=below,days=days,
        confidence=fresh and snapshot.full and peer and historical and "Medium" or "Low",
        source=peer and (historical and "Peers + history" or "Loaded peers") or "History",
        partial=not (fresh and snapshot.full),time=fresh and snapshot.time or item.time,
        unavailable=M.unavailable[id]~=nil,
        watched=watch and not M.unavailable[id] and now-item.time<=900 and price<=watch.cap or false}
end
function M.Candidates(now)
    local result={}
    for id in pairs(M.market.items) do
        local d=M.Deal(id,now)
        if not d.unavailable and now-d.time<=900 and d.reference and d.discount>=M.settings.discount and d.profit>=M.settings.minProfit then result[#result+1]=d end
    end
    table.sort(result,function(a,b) if a.profit==b.profit then return a.id<b.id end return a.profit>b.profit end)
    return result
end
function M.Watch(id,cap,target)
    if not M.market.items[id] or not positive(cap) or cap<1 or (target~=nil and (not positive(target) or target<1)) then return false end
    M.market.watch[id]={cap=math.floor(cap),target=target and math.floor(target)}; return true
end
function M.Purchase(key,quantity,cost,now,source,receipt)
    if not M.Key(key) or not positive(quantity) or quantity%1~=0 or not positive(cost) or cost<1 then return false end
    if receipt and M.account.seen[receipt] then return false end
    local id=M.Key(key); local item=M.market.items[id]
    local lot={key=key,name=item and item.name or ("Item "..key.itemID),quantity=quantity,cost=math.floor(cost),time=now,source=source,sales={}}
    table.insert(M.account.ledger,1,lot)
    if receipt then M.account.seen[receipt]=now end
    return lot
end
function M.Balance(lot)
    local sold,received=0,0
    for _,s in ipairs(lot.sales) do sold=sold+s.quantity; received=received+s.net end
    return lot.quantity-sold-(lot.craftUsed or 0),received-lot.cost*sold/lot.quantity,received
end
function M.Sale(lot,quantity,net,now)
    if not positive(quantity) or quantity%1~=0 or type(net)~="number" or net<0 or net>=1e12 or net~=net or quantity>M.Balance(lot) then return false end
    lot.sales[#lot.sales+1]={quantity=quantity,net=math.floor(net),time=now}; return true
end
