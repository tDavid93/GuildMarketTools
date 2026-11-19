from pathlib import Path
import hashlib
import re
import zipfile

root = Path(__file__).resolve().parents[1]
addon = root / 'GuildMarketTools'
toc = (addon / 'GuildMarketTools.toc').read_text()
version = re.search(r'^## Version: ([0-9.]+)$', toc, re.M).group(1)
names = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith('#')]
names += ['GuildMarketTools.toc', 'README.txt', 'README.hu.md', 'LICENSE', 'LICENSE-Profit.txt']
assert len(names) == len(set(names))
for name in names:
    assert '/' not in name and chr(92) not in name and (addon / name).is_file(), name
out = root / 'dist'
out.mkdir(exist_ok=True)
archive = out / f'GuildMarketTools-{version}.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as z:
    for name in sorted(names):
        z.write(addon / name, 'GuildMarketTools/' + name)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert set(z.namelist()) == {'GuildMarketTools/' + n for n in names}
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
(out / 'SHA256SUMS.txt').write_text(f'{digest}  {archive.name}\n')
print(f'PASS: {archive.name}, {len(names)} allowlisted files, SHA256 {digest}')
