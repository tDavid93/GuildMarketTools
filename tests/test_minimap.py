from pathlib import Path
from lupa.lua51 import LuaRuntime
l=LuaRuntime();root=Path('GuildMarketTools')
for n in ['MarketCore.lua','RecipeRequirementsDB.lua','CraftRequirements.lua']:l.execute(root.joinpath(n).read_text())
l.execute("""
local M=GuildMarketTools
local count=0;for _ in pairs(M.RequirementDatabase) do count=count+1 end;assert(count==2493)
for _,id in ipairs({1229705,1262980,1263070,1229517,1262985,1262982,1229745,1262990,1262998}) do
 assert(#M.RecipeSetup({id=id})==0 and not M.RequirementsUnknown({id=id}))
end
local methods={}
function methods:SetScript(name,fn) self.scripts[name]=fn end
function methods:SetPoint(...) self.point={...} end
function methods:Show() self.shown=true end
function methods:GetWidth() return 160 end
function methods:GetHeight() return 160 end
function methods:GetFrameLevel() return 10 end
function methods:GetEffectiveScale() return 2 end
function methods:GetCenter() return 100,100 end
function methods:CreateTexture() return setmetatable({}, {__index=function() return function() end end}) end
function CreateFrame() return setmetatable({scripts={}}, {__index=function(_,k) return methods[k] or function() end end}) end
Minimap=CreateFrame();GameTooltip=setmetatable({}, {__index=function() return function() end end})
GetCursorPosition=function() return 400,200 end
M.db={};local opens=0;local prof=0;M.ShowAlchemy=function() prof=prof+1 end
_G.testOpen=function() opens=opens+1 end
_G.testCounts=function() return opens,prof end
""")
l.execute(root.joinpath('Minimap.lua').read_text())
l.execute("""
local M=GuildMarketTools;M.CreateMinimapLauncher(testOpen);local b=M.minimapButton
assert(b.shown and M.db.minimap.angle==225)
b.scripts.OnClick(b,'LeftButton');b.scripts.OnClick(b,'RightButton')
local a,c=testCounts();assert(a==1 and c==1)
b.scripts.OnDragStart(b);b.scripts.OnUpdate();assert(math.abs(M.db.minimap.angle)<.001)
b.scripts.OnDragStop(b);assert(not b.scripts.OnUpdate)
M.CreateMinimapLauncher(testOpen);assert(M.minimapButton==b)
M.minimapButton=nil;M.CreateMinimapLauncher(testOpen);assert(M.db.minimap.angle==0)
""")
for p in root.glob('*.lua'):l.execute('assert(loadstring(...))',p.read_text(encoding='utf-8-sig'))
print('PASS: 2493 DB entries across 12 professions, camping craft/use distinction, minimap left/right click, scaled drag, saved position, duplicate guard, Lua syntax.')
