from pathlib import Path
import os
import subprocess
import sys
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
os.chdir(root)
lua = LuaRuntime()
for path in (root / 'GuildMarketTools').glob('*.lua'):
    lua.execute('assert(loadstring(...))', path.read_text(encoding='utf-8-sig'))
for test in sorted((root / 'tests').glob('test_*.py')):
    subprocess.run([sys.executable, str(test)], check=True, cwd=root)
print('PASS: Lua 5.1 syntax and all test scripts')
