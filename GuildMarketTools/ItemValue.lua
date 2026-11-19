
-- Independent, read-only tooltip module. All prices and thresholds are per item.
do
    local defaults = { enabled=true, fee=5, minimum=1000, percent=25, age=1, loss=0 }
    local transient = {}
    local function config()
        GuildMarketToolsDB=GuildMarketToolsDB or {}
        local root = GuildMarketToolsDB
        root.itemValue = root.itemValue or {}
        local c = root.itemValue
        for k,v in pairs(defaults) do if c[k] == nil then c[k] = v end end
        return c
    end
    local function money(n)
        n = math.floor(math.abs(n or 0))
        if n >= 10000 then return string.format("%dg %ds %dc", math.floor(n/10000), math.floor(n/100)%100, n%100) end
        if n >= 100 then return string.format("%ds %dc", math.floor(n/100), n%100) end
        return string.format("%dc", n)
    end
    local function safe(fn, ...)
        if type(fn) ~= "function" then return nil end
        local ok, value = pcall(fn, ...)
        if ok and not (issecretvalue and issecretvalue(value)) then return value end
    end
    local function price(link)
        local api = Auctionator and Auctionator.API and Auctionator.API.v1
        if not api or type(api.GetAuctionPriceByItemLink) ~= "function" then
            return nil, nil, "Auctionator unavailable"
        end
        -- Exact link only: never silently substitute a base-ID price for random-stat gear.
        local ok, value = pcall(api.GetAuctionPriceByItemLink, "GuildMarketTools", link)
        if not ok or (issecretvalue and issecretvalue(value)) then
            return nil, nil, "Auctionator query failed"
        end
        if type(value) ~= "number" or value <= 0 then return nil, nil, "No saved AH price" end
        return value, safe(api.GetAuctionAgeByItemLink, "GuildMarketTools", link)
    end
    local function evaluate(vendor, auction, age, protected, c)
        if protected then return "Keep / review", 1, .8, .2 end
        if type(vendor) ~= "number" then return "Waiting for item data", 1, .8, .2 end
        if type(auction) ~= "number" or auction <= 0 or type(age) ~= "number" or age < 0 or age > c.age then
            return "Fresh AH price needed", 1, .8, .2
        end
        local net = math.floor(auction * (1-c.fee/100)) - c.loss
        local gain = net - vendor
        if gain >= math.max(c.minimum, vendor*c.percent/100) then
            return "Try the AH", .3, 1, .5, net, gain
        end
        if vendor <= 0 then return "Review needed", 1,.8,.2,net,gain end
        return "Vendor suggested", .8, .8, .8, net, gain
    end
    local function inEquipmentSet(link)
        local id=tonumber(link and link:match("item:(%d+)"))
        local sets=C_EquipmentSet
        if not id or not sets or not sets.GetEquipmentSetIDs or not sets.GetItemIDs then return false end
        for _,setID in ipairs(sets.GetEquipmentSetIDs() or {}) do
            for _,itemID in pairs(sets.GetItemIDs(setID) or {}) do if itemID==id then return true end end
        end
        return false
    end
    GuildMarketTools.ToggleTooltip=function()
        local c=config(); c.enabled=not c.enabled; return c.enabled
    end
    local done, context = {}, {}
    local modern = TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType
    local function render(tip, link)
        local c = config()
        if not c.enabled or done[tip] or not link then return end
        local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
        if not getInfo then return end
        local name, _, quality, _, _, _, _, _, _, _, vendor, classID, _, bindType = getInfo(link)
        if not name then return end
        local auction, age, priceStatus = price(link)
        local ctx = context[tip]
        local protected = quality and quality >= 3 or classID == 12 or bindType == 1
        local equipped = C_Item and C_Item.IsEquippedItem or IsEquippedItem
        protected = protected or safe(equipped, link) or inEquipmentSet(link)
        if ctx and C_Container and C_Container.GetContainerItemQuestInfo then
            local q = C_Container.GetContainerItemQuestInfo(ctx.bag, ctx.slot)
            protected = protected or (q and (q.isQuestItem or q.questID))
        end
        local bound
        if ctx and ItemLocation and C_Item and C_Item.IsBound then
            bound = safe(C_Item.IsBound, ItemLocation:CreateFromBagAndSlot(ctx.bag, ctx.slot))
            protected = protected or bound
        end
        local label, r,g,b,net,gain = evaluate(vendor, auction, age, protected, c)
        if bound or bindType == 1 then label = "Soulbound - cannot auction"
        elseif protected then label = "Keep / review"
        elseif priceStatus then label = priceStatus
        elseif net then label = gain >= math.max(c.minimum, vendor*c.percent/100) and "Try the AH" or "Vendor suggested"
            if vendor <= 0 and label == "Vendor suggested" then label = "Review needed" end
        else label = "Fresh AH price needed" end
        done[tip] = true
        tip:AddLine("Market: " .. label, r,g,b)
        local ahText = (bound or bindType == 1) and "not auctionable" or (auction and money(auction) or "--")
        tip:AddDoubleLine("Vendor: " .. (type(vendor)=="number" and money(vendor) or "--"), "AH: " .. ahText .. " /item", 1,1,1, 1,1,1)
        local summary = net and ("AH gain ~" .. (gain<0 and "-" or "+") .. money(gain) .. "/item") or "Details"
        tip:AddLine(summary .. "  |  Shift", .7,.7,.7)
        if not safe(IsShiftKeyDown) then return end
        if not bound and bindType ~= 1 then
            tip:AddLine(priceStatus or ("Price age: " .. (type(age)=="number" and (age .. " days") or "unknown")), .7,.7,.7)
            tip:AddLine(string.format("Est. fee: %g%%; lost deposits: %s/item",c.fee,money(c.loss)), .65,.65,.65)
            tip:AddLine(c.loss==0 and "Deposits excluded; sale not guaranteed." or "Asking price; sale not guaranteed.",.65,.65,.65)
        end
        if classID==2 or classID==4 then tip:AddLine("Check upgrades, spare sets and disenchant value.",1,.8,.2) end
    end
    local function append(tip)
        if done[tip] or (tip.IsForbidden and tip:IsForbidden()) then return end
        -- Modern post-calls run before the engine sizes/shows the tooltip.
        -- No timer or Show(): either would expose a short tooltip followed by
        -- the expanded one on every periodic bag-tooltip refresh.
        local ok,err = pcall(function()
            local info = tip.GetPrimaryTooltipInfo and tip:GetPrimaryTooltipInfo()
            if info and info.getterName == "GetBagItem" and info.getterArgs then
                context[tip] = {bag=info.getterArgs[1],slot=info.getterArgs[2]}
            end
            local _,link = tip:GetItem()
            render(tip,link)
        end)
        if not ok and not transient.reported then
            transient.reported = true
            print("Guild Market Value: tooltip error: "..tostring(err))
        end
    end
    local function hook(tip)
        if not tip then return end
        tip:HookScript("OnTooltipCleared",function() done[tip]=nil;context[tip]=nil end)
        if not modern and tip:HasScript("OnTooltipSetItem") then tip:HookScript("OnTooltipSetItem",append) end
    end
    hook(GameTooltip)
    hook(ItemRefTooltip)
    if modern then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(tip)
            if tip==GameTooltip or tip==ItemRefTooltip then append(tip) end
        end)
    end
    SLASH_GUILDMARKETVALUE1 = "/gmvalue"
    SlashCmdList.GUILDMARKETVALUE = function(text)
        local c = config()
        local cmd,arg = (text or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
        local n = tonumber(arg)
        if cmd=="on" then c.enabled=true
        elseif cmd=="off" then c.enabled=false
        elseif cmd=="reset" then for k,v in pairs(defaults) do c[k]=v end
        elseif n and n==n and n>=0 and n<=100000 then
            if cmd=="fee" and n<=100 then c.fee=n
            elseif cmd=="min" then c.minimum=math.floor(n*100)
            elseif cmd=="percent" then c.percent=n
            elseif cmd=="age" and n<=21 then c.age=n
            elseif cmd=="loss" then c.loss=math.floor(n*100) end
        end
        print(string.format("Guild Market Value: %s | est. fee %g%%, minimum %s + %g%%, price age <=%g days, lost deposits %s/item",
            c.enabled and "ON" or "OFF",c.fee,money(c.minimum),c.percent,c.age,money(c.loss)))
        print("/gmvalue on|off|reset; fee <percent>; min <silver>; percent <percent>; age <days>; loss <silver/item>. Hover over the item again.")
    end
end
