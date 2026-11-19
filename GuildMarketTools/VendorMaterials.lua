local M=GuildMarketTools
-- Standard unlimited crafting supplies. Prices are per item, not merchant bundle.
-- Neutral per-unit estimates; live merchant quotes override them.
-- Thread/dye/supply defaults: Profit Data/Items.lua, build 1.60.1.70888,
-- commit bbf0b653f8c14544e77d261fc2cb8b4606656b69; see LICENSE-Profit.txt.
local supplies={ [3371]=4,[3372]=40,[8925]=500,[18256]=6000,
    [2320]=10,[2321]=100,[4291]=500,[8343]=2000,[14341]=5000,
    [2324]=25,[2604]=50,[2605]=100,[4340]=350,[4341]=500,[4342]=2500,
    [6260]=50,[6261]=1000,[10290]=2500,[4289]=50,[4399]=200,[4400]=2000,
    [2880]=100,[3466]=2000,[3857]=500,[5956]=true,[2678]=2,[2692]=40,
    [3713]=160,[159]=5 }
function M.VendorMaterial(id)
    local saved=M.account and M.account.vendorMaterials and M.account.vendorMaterials[id]
    if saved and M.Positive(saved.price) then return {price=saved.price,source="Vendor (last observed)",name=saved.name} end
    if supplies[id] then return {price=type(supplies[id])=="number" and supplies[id] or nil,source="Vendor (base estimate)"} end
end
function M.ReadVendorMaterials()
    if not M.account or not GetMerchantNumItems or not GetMerchantItemInfo or not GetMerchantItemLink then return end
    M.account.vendorMaterials=M.account.vendorMaterials or {}
    for i=1,GetMerchantNumItems() do
        local name,_,price,quantity,available,_,extended=GetMerchantItemInfo(i)
        local link=GetMerchantItemLink(i);local id=link and tonumber(link:match("item:(%d+)"))
        -- Limited stock and token purchases are not reliable material sources.
        if id and available==-1 and not extended and M.Positive(price) and M.Positive(quantity) then
            M.account.vendorMaterials[id]={name=name,price=price/quantity,time=time()}
        end
    end
    if M.RefreshAlchemy then M.RefreshAlchemy() end
    if M.RefreshCraftShopping then M.RefreshCraftShopping() end
end
local f=CreateFrame("Frame");f:RegisterEvent("MERCHANT_SHOW");f:RegisterEvent("MERCHANT_UPDATE")
f:SetScript("OnEvent",M.ReadVendorMaterials)
