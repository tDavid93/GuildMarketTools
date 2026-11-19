-- Exact-auction buyouts only. No timer or event handler submits a purchase.
local M=GuildMarketTools
function M.CreateVendorBuyer(api,env)
    local config=env.config()
    config.attempted=config.attempted or {}
    local B={state="idle",message="Verify next prepares a fresh quote. One click per purchase.",seen=config.attempted}
    local serial=0
    local function valid(n) return type(n)=="number" and n==n and n>0 and n<1e12 and n==math.floor(n) end
    local function same(a,b)
        return a and b and a.itemID==b.itemID and (a.itemLevel or 0)==(b.itemLevel or 0)
            and (a.itemSuffix or 0)==(b.itemSuffix or 0) and (a.battlePetSpeciesID or 0)==(b.battlePetSpeciesID or 0)
    end
    local function update(state,message)
        B.state=state; B.message=message; if env.changed then env.changed() end
    end
    function B:Cancel(message)
        serial=serial+1; self.quote=nil; self.key=nil
        -- An unacknowledged submission remains locked, even after closing the UI.
        if self.pending then update("pending","Purchase unconfirmed. No retry; reserved budget retained.")
        else update("idle",message or "Quote cleared. Verify next to continue.") end
    end
    local function affordable(cost)
        local c=env.config()
        return cost<=math.max(0,(c.limit or 0)-(c.reserved or 0)) and env.money()-cost>=(c.reserve or 0)
    end
    local function offer(key,i)
        local r=api.GetItemSearchResultInfo(key,i)
        if not r or not same(key,r.itemKey) or not valid(r.auctionID) or not valid(r.quantity)
            or not valid(r.buyoutAmount) or r.containsOwnerItem or r.containsAccountItem or B.seen[r.auctionID]
            or (r.itemKey.battlePetSpeciesID or 0)>0 then return end
        -- Require the exact listing link: do not substitute a base-item vendor price.
        local link=r.itemLink
        if not link and api.GetItemSearchResultItemLink then link=api.GetItemSearchResultItemLink(key,i) end
        if type(link)~="string" then return end
        local name,vendor=env.item(link)
        if not name or not valid(vendor) then return end
        local gain=vendor*r.quantity-r.buyoutAmount
        if gain<100 or not affordable(r.buyoutAmount) or (B.maxUnit and r.buyoutAmount>B.maxUnit*r.quantity) then return end
        return {id=r.auctionID,key=key,link=link,name=name,count=r.quantity,cost=r.buyoutAmount,gain=gain}
    end
    function B:Verify(key,maxUnit)
        if self.pending or self.state=="querying" then return end
        self:Cancel()
        self.maxUnit=maxUnit
        if not valid(maxUnit) then update("idle","No verified snapshot price ceiling. Load fresh candidates."); return end
        if not env.open() or env.combat() then update("idle","Open the AH and leave combat."); return end
        if not api or not api.SendSearchQuery or not api.PlaceBid or not api.GetItemSearchResultInfo
            or not api.GetNumItemSearchResults or not api.HasFullItemSearchResults or not api.GetItemKeyInfo then
            update("idle","Exact-price buying API unavailable. Use the native AH."); return
        end
        if not key or not valid(key.itemID) then update("idle","No more searchable candidates. Load a fresh AH scan."); return end
        local info=api.GetItemKeyInfo(key)
        if not info or not env.isItem(info) then update("idle","Commodity or unknown item type: native AH purchase only."); return end
        if api.IsThrottledMessageSystemReady and not api.IsThrottledMessageSystemReady() then
            update("idle","AH busy. Wait for the active scan, then retry."); return
        end
        self.key={itemID=key.itemID,itemLevel=key.itemLevel,itemSuffix=key.itemSuffix,battlePetSpeciesID=key.battlePetSpeciesID}
        update("querying","Checking fresh listings...")
        local token=serial
        local ok=pcall(api.SendSearchQuery,self.key,{},true)
        if not ok then self:Cancel("Search rejected. No purchase sent."); return end
        env.after(10,function() if serial==token and self.state=="querying" then self:Cancel("Search timed out. Retry verification.") end end)
    end
    function B:Results(key)
        if self.state~="querying" or not same(key,self.key) or not env.open() then return end
        if not api.HasFullItemSearchResults(self.key) then return end
        local best
        for i=1,api.GetNumItemSearchResults(self.key) do
            local q=offer(self.key,i)
            if q and (not best or q.gain>best.gain or (q.gain==best.gain and q.cost<best.cost)) then best=q end
        end
        if not best then self:Cancel("No verified deal >= 1s within budget. Try the next candidate."); return end
        best.at=env.now(); self.quote=best
        update("ready",best.name.." x"..best.count.." | Buy "..env.coins(best.cost).." | Profit +"..env.coins(best.gain))
        if env.alert then env.alert() end
        local token=serial
        env.after(5,function() if serial==token and self.state=="ready" then self:Cancel("Quote expired. Verify again.") end end)
    end
    function B:Buy()
        local q=self.quote
        if self.state~="ready" or not q or self.pending then return end
        if not env.open() or env.combat() or env.now()-q.at>=5 or not affordable(q.cost) then
            self:Cancel("Quote expired or budget changed. Verify again."); return
        end
        if not api.HasFullItemSearchResults(q.key) then self:Cancel("Incomplete results. Verify again."); return end
        local found
        for i=1,api.GetNumItemSearchResults(q.key) do
            local r=offer(q.key,i)
            if r and r.id==q.id and r.link==q.link and r.count==q.count and r.cost==q.cost and r.gain>=100 then found=r; break end
        end
        if not found then self:Cancel("Listing changed or disappeared. Nothing purchased."); return end
        -- Persist before submission. Errors/timeouts never silently refund this budget.
        local c=env.config(); c.reserved=(c.reserved or 0)+q.cost
        self.pending=q; self.seen[q.id]=true; self.quote=nil; serial=serial+1
        update("pending","Submitting exact buyout "..env.coins(q.cost)..". Waiting for confirmation...")
        local ok=pcall(api.PlaceBid,q.id,q.cost)
        if not ok then update("pending","Submission failed or uncertain. No retry; budget remains reserved.") end
    end
    function B:Event(event,arg)
        if event=="ITEM_SEARCH_RESULTS_UPDATED" or event=="ITEM_SEARCH_RESULTS_ADDED" then self:Results(arg)
        elseif event=="AUCTION_HOUSE_PURCHASE_COMPLETED" and self.pending and arg==self.pending.id then
            self.pending=nil; self:Cancel("Purchase confirmed. Verify next for another deal.")
        elseif event=="AUCTION_HOUSE_SHOW_ERROR" and self.pending then
            update("pending","AH reported an error. No retry; budget retained. Reopen UI after checking mail/gold.")
        elseif event=="COMMODITY_SEARCH_RESULTS_UPDATED" and self.state=="querying" and self.key and arg==self.key.itemID then
            self:Cancel("Commodity: exact-auction fast buying is unavailable.")
        elseif event=="AUCTION_HOUSE_CLOSED" or event=="PLAYER_REGEN_DISABLED" then self:Cancel() end
    end
    return B
end
