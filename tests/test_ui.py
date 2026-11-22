from pathlib import Path
from lupa.lua51 import LuaRuntime
l=LuaRuntime(); root=Path('GuildMarketTools')
l.execute("""
frames={}; buttons={}; named={}; SlashCmdList={}; UISpecialFrames={}; GuildMarketToolsDB={}
local noop=function() end
local methods={}
function methods:SetText(s) self.text=s; buttons[s]=self end
function methods:GetText() return self.text or '' end
function methods:GetObjectType() return self.kind end
function methods:GetChildren() return unpack(self.children) end
function methods:GetFontString() return self.font end
function methods:GetStringHeight() return 80 end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:IsShown() return self.shown end
function methods:SetShown(v) self.shown=v end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:GetParent() return self.parent end
function methods:CreateFontString() return CreateFrame('FontString') end
function methods:CreateTexture() return CreateFrame('Texture') end
function CreateFrame(kind,name,parent,template)
 local f={kind=kind,children={},scripts={},shown=true,parent=parent}
 setmetatable(f,{__index=function(_,k)
 if k=='Left' or k=='Middle' or k=='Right' or k=='gmtStyled' or k=='gmtPager' or k=='gmtHeaders' then return nil end
 return methods[k] or noop end})
 if parent and parent.children then parent.children[#parent.children+1]=f end
 if kind=='Button' then f.font=CreateFrame('FontString') end
 frames[#frames+1]=f; if name then named[name]=f end; return f
end
UIParent=CreateFrame('Frame'); GameTooltip=CreateFrame('Frame')
time=function() return 100000 end; date=function() return '17 Nov' end
GetMoney=function() return 1000000 end; GetTime=time
GetRealmName=function() return 'Test' end; UnitName=function() return 'Test' end; UnitFactionGroup=function() return 'Horde' end
UnitLevel=function() return 42 end
C_Timer={After=function(_,f) f() end}; GetItemInfo=function() return 'Item' end
C_AuctionHouse={GetBrowseResults=function() return {} end}
function fire(event) local copy={unpack(frames)}; for _,f in ipairs(copy) do if f.scripts.OnEvent then f.scripts.OnEvent(f,event) end end end
""")
for n in ['MarketCore.lua','UI.lua','CraftRequirements.lua','VendorBuyer.lua','VendorDeals.lua','MarketDepth.lua','AHledgerBridge.lua','Alchemy.lua','Market.lua']:
 l.execute(root.joinpath(n).read_text(encoding='utf-8-sig'))
l.execute("""
fire('PLAYER_LOGIN')
local M=GuildMarketTools
M.account.alchemy={[1]={id=1,name='Potion',learned=true,itemID=1,count=1,mats={{id=2,count=1}}}}
M.market.items={['1:0:0:0']={key={itemID=1},name='Potion',price=1000,time=100000,history={}},['2:0:0:0']={key={itemID=2},name='Herb',price=100,time=100000,history={}}}
for _,tab in ipairs({'Deals','History','Watchlist','Ledger','Settings','Professions'}) do M.OpenTab(tab) end
assert(M.account.professions[171].recipes[1].name=='Potion')
buttons['All professions'].scripts.OnClick(buttons['All professions'])
assert(buttons['Alchemy'])
local row
for _,f in ipairs(frames) do if type(f.parent)=='table' and f.parent.parent==named.GuildMarketAlchemyFrame.gmtScroll and type(f.cells)=='table' and f.cells[1]:GetText()=='Potion' and f.scripts.OnClick then row=f; break end end
assert(row);row.scripts.OnClick()
assert(named.GuildMarketAlchemyFrame.recipeTitle:GetText()=='Potion')
for _,label in ipairs({'Summary','Materials','Market','Setup'}) do
 named.GuildMarketAlchemyFrame.detailTabs[label].scripts.OnClick()
end
local link='|cffffffff|Hitem:1::::::::|h[Potion]|h|r'
GetItemInfo=function() return 'Potion',link end
local inserted,opened
ChatEdit_InsertLink=function(s) inserted=s;return true end
ChatFrame_OpenChat=function(s) opened=s end
buttons['Link to chat'].scripts.OnClick();assert(inserted==link and not opened)
inserted=nil;IsShiftKeyDown=function() return true end;row.scripts.OnClick();assert(inserted==link)
ChatEdit_InsertLink=function() return false end
assert(M.LinkRecipeToChat({itemID=1}));assert(opened==link)
-- Forever exposes only the modern namespace: old globals must not be required.
ChatEdit_InsertLink=nil;ChatFrame_OpenChat=nil;inserted=nil;opened=nil
ChatFrameUtil={InsertLink=function(s) inserted=s;return true end,OpenChat=function(s) opened=s end}
assert(M.LinkRecipeToChat({itemID=1}));assert(inserted==link and not opened)
ChatFrameUtil.InsertLink=function() return false end
assert(M.LinkRecipeToChat({itemID=1}));assert(opened==link)
AHledgerAPI={VERSION=1,GetPrice=function() return {median=900,soldPerDay=12.5,updated=99900,market='forever/pvp/horde/eu'} end}
M.RefreshAlchemy();assert(row.cells[5]:GetText()=='12.5')
for _,label in ipairs({'Summary','Market'}) do named.GuildMarketAlchemyFrame.detailTabs[label].scripts.OnClick() end
AHledgerAPI=nil
GetItemInfo=function() return 'Potion' end
local requested;C_Item={RequestLoadItemDataByID=function(id) requested=id end}
assert(not M.LinkRecipeToChat({itemID=2}));assert(requested==2)
assert(M.RecipeWowheadURL({name="Potion & Oil"})=='https://www.wowhead.com/forever/search?q=Potion%20%26%20Oil')
assert(M.RecipeWowheadURL({id=1251749,itemID=250951,name='Caustic Smog Potion'})=='https://www.wowhead.com/forever/spell=1251749')
assert(M.RecipeWowheadURL({id=0,itemID=250951})=='https://www.wowhead.com/forever/item=250951')
assert(M.RecipeWowheadURL({id=-1,itemID=1.5,name='Potion'})=='https://www.wowhead.com/forever/search?q=Potion')
buttons['Copy Wowhead link'].scripts.OnClick()
assert(named.GuildMarketRecipeLinkFrame.box:GetText()=='https://www.wowhead.com/forever/spell=1')
C_Item=nil;IsShiftKeyDown=nil
M.ShowVendor()
for _,name in ipairs({'GuildMarketToolsFrame','GuildMarketAlchemyFrame','GuildMarketVendorFrame'}) do assert(named[name].gmtHeaders and named[name].gmtPager) end
local a={{id=1,v=4},{id=2,v=2},{id=3}}
M.UI.Sort(a,1,true,function(r) return r.v end); assert(a[1].v==4 and a[3].v==nil)
M.UI.Sort(a,1,false,function(r) return r.v end); assert(a[1].v==2 and a[3].v==nil)
local list={}; for i=1,250 do list[i]=i end
local frame=CreateFrame('Frame'); local page=M.UI.Page(frame,list,function() end); assert(#page==100)
frame.gmtPager.page=3; page=M.UI.Page(frame,list,function() end); assert(#page==50 and page[1]==201)
frame.gmtPager.page=99; page=M.UI.Page(frame,{},function() end); assert(#page==0 and frame.gmtPager.page==1)
""")
print('PASS: all seven pages construct/render, legacy Alchemy migration, profession selector, nil-safe numeric sorting, bounded pagination and empty-page clamp. Mocked WoW UI, not visual verification.')
