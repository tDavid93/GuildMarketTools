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
C_Timer={After=function(_,f) f() end}; GetItemInfo=function() return 'Item' end
C_AuctionHouse={GetBrowseResults=function() return {} end}
function fire(event) local copy={unpack(frames)}; for _,f in ipairs(copy) do if f.scripts.OnEvent then f.scripts.OnEvent(f,event) end end end
""")
for n in ['MarketCore.lua','UI.lua','CraftRequirements.lua','VendorBuyer.lua','VendorDeals.lua','Alchemy.lua','Market.lua']:
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
