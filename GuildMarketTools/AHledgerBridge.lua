local M=GuildMarketTools
M.AHledgerCredit="Prices from AHledger (ahledger.com)"

-- Read through the provider's public API. Do not persist or mix its estimates
-- into local scan history, purchase quotes or crafting-cost calculations.
function M.AHledgerPrice(itemID,now)
    local api=AHledgerAPI
    if not api or type(api.GetPrice)~="function" then return nil,"AHledger not loaded" end
    if api.VERSION~=1 then return nil,"Unsupported AHledger API" end
    if not M.Positive(itemID) then return nil,"No crafted item" end
    local ok,p=pcall(api.GetPrice,itemID)
    if not ok or type(p)~="table" then return nil,"No AHledger data for this item / market" end
    local r={}
    for _,key in ipairs({"median","minBuyout","median7d","median30d","low30d","high30d"}) do
        if M.Positive(p[key]) then r[key]=p[key] end
    end
    for _,key in ipairs({"soldPerDay","quantity"}) do
        local v=p[key];if type(v)=="number" and v>=0 and v<1e12 then r[key]=v end
    end
    r.market=type(p.market)=="string" and p.market or "Unknown market"
    r.snapshot=p.snapshot==true
    r.updated=M.Positive(p.updated) and p.updated or nil
    r.age=r.updated and now>=r.updated and now-r.updated or nil
    r.stale=not r.age or r.age>3600
    return r
end

function M.AHledgerPace(p)
    if not p or p.soldPerDay==nil then return "--" end
    return string.format("%.1f",p.soldPerDay)..((p.stale or p.snapshot) and "*" or "")
end
