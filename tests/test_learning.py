from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path('GuildMarketTools')
lua = LuaRuntime()
lua.execute((root / 'MarketCore.lua').read_text(encoding='utf-8'))
lua.execute('CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end')
lua.execute((root / 'RecipeRequirementsDB.lua').read_text(encoding='utf-8'))
lua.execute((root / 'Alchemy.lua').read_text(encoding='utf-8'))
lua.execute('''
local M=GuildMarketTools
-- Tailoring and Enchanting trainer recipes without teaching items.
for _,id in ipairs({1229504,7421}) do
 local skill=M.RecipeMinimumSkill(id)
 assert(type(skill)=='number')
 local r={id=id,learned=false,minSkill=skill}
 assert(M.RecipeCharacterLevel(r)==nil)
 assert(M.RecipeLearnable(r,skill,40))
 assert(M.RecipeLearningStatus(r,skill,40):find('Check trainer',1,true))
 assert(not M.RecipeLearnable(r,skill-1,40))
 r.minCharacterLevel=41
 assert(not M.RecipeLearnable(r,skill,40))
 assert(M.RecipeLearnable(r,skill,41))
 r.learned=true;assert(not M.RecipeLearnable(r,skill,60))
end
-- Item-taught recipes keep the character-level gate, even without AtlasLoot.
local r={id=1250781,learned=false,minSkill=M.RecipeMinimumSkill(1250781)}
GetItemInfo=function(id) assert(id==250368);return 'Recipe',nil,nil,nil,30 end
local level=M.RecipeCharacterLevel(r);assert(level==30);r.minCharacterLevel=level
assert(not M.RecipeLearnable(r,145,29))
assert(M.RecipeLearnable(r,145,30))
r.minCharacterLevel=nil;assert(not M.RecipeLearnable(r,145,60))
assert(not M.RecipeLearnable({id=999999,minSkill=1},100,60))
assert(not M.RecipeLearnable({id=7421,minSkill=1},nil,60))
''')
print('PASS: Tailoring/Enchanting trainer candidates, DB skill/item fallback without AtlasLoot, explicit unknown-level status, known level and skill gates, learned exclusion.')
