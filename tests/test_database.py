from pathlib import Path
from lupa.lua51 import LuaRuntime
l=LuaRuntime();r=Path('GuildMarketTools')
l.execute((r/'MarketCore.lua').read_text())
l.execute("CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end;time=function() return 1000 end")
for n in ['RecipeRequirementsDB.lua','CraftRequirements.lua','Alchemy.lua']:l.execute((r/n).read_text())
l.execute("""
local M=GuildMarketTools;M.Init({},'realm','char',1000)
local cleric={id=1250781,itemID=250332,count=1,mats={{id=3819,count=2},{id=4625,count=2},{id=3372,count=1}}}
local prices={[250332]={price=5000,time=1000},[3819]={price=100,time=1000},[4625]={price=200,time=1000},[3372]={price=40,time=1000}}
assert(not M.RequirementsUnknown(cleric))
local result=M.AlchemyEstimate(cleric,prices,1000,5,0)
assert(result.cost==640 and result.profit==4110 and result.setupCost==0)
assert(#M.RecipeSetup({id=3449})==2)
assert(#M.RecipeSetup({id=11479})==1) -- transmutation requires Philosopher's Stone
GetItemCount=function(id) return id==9149 and 1 or 0 end
assert(#M.RecipeSetup({id=11479})==0)
local live={id=3449,requirementsRead=true,requirements={}}
assert(#M.RecipeSetup(live)==2) -- empty API cannot erase a known station
live.requirements={{name='Fermenter'}};assert(not M.RequirementsUnknown(live))
assert(M.RequirementsUnknown({id=99999999}))
local count=0;for _,list in pairs(M.RequirementDatabase) do count=count+1;for _,v in ipairs(list) do assert(v.id or v.environment) end end
assert(count==2493)
""")
for p in r.glob('*.lua'):l.execute('assert(loadstring(...))',p.read_text(encoding='utf-8-sig'))
print('PASS: Clerics price/profit restored without recipe API; Shadow Oil extra setup preserved; owned reusable tool exclusion; empty/unresolved client fallback; unknown recipes explicit; 2493 mapped records; Lua syntax.')
