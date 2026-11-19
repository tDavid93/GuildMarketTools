local M=GuildMarketTools
-- Standard unlimited crafting supplies. Prices are per item, not merchant bundle.
-- Vial defaults are neutral estimates; live merchant quotes override them.
local supplies={ [3371]=4,[3372]=40,[8925]=500,[18256]=6000,
    [2320]=true,[2321]=true,[4291]=true,[8343]=true,[14341]=true,
    [2324]=true,[2604]=true,[2605]=true,[4340]=true,[4341]=true,[4342]=true,
    [6260]=true,[6261]=true,[10290]=true,[4289]=true,[4399]=true,[4400]=true,
    [2880]=true,[3466]=true,[3857]=true,[5956]=true,[2678]=true,[2692]=true,
    [3713]=true,[159]=true }
function M.VendorMaterial(id)
    local saved=M.account and M.account.vendorMaterials and M.account.vendorMaterials[id]
    if saved then return {price=saved.price,source="Vendor (last observed)",name=saved.name} end
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
