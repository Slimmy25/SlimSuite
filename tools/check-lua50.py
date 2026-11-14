"""Compile untouched production files with upstream Lua 5.0.3, not the mock's Lua 5.3."""
from pathlib import Path
import hashlib
import importlib.util
import io
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

URL = 'https://www.lua.org/ftp/lua-5.0.3.tar.gz'
SHA256 = '1193a61b0e08acaa6eee0eecf29709179ee49c71baebc59b682a25c3b5a45671'
cache = Path(tempfile.gettempdir()) / ('slimsuite-lua50-' + SHA256[:12])
compiler = cache / ('luac50.exe' if os.name == 'nt' else 'luac50')
if not compiler.exists():
    archive = urllib.request.urlopen(URL, timeout=60).read()
    if hashlib.sha256(archive).hexdigest() != SHA256:
        raise SystemExit('Lua source archive checksum mismatch')
    cache.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:gz') as tar:
        members = [member for member in tar.getmembers() if not member.issym() and not member.islnk()]
        for member in members:
            target = (cache / member.name).resolve()
            if not target.is_relative_to(cache.resolve()):
                raise SystemExit('Unsafe path in Lua archive')
        tar.extractall(cache, members=members, filter='data')
    source = cache / 'lua-5.0.3'
    if shutil.which('gcc'):
        cc = ['gcc']
    elif shutil.which('clang'):
        cc = ['clang']
    elif importlib.util.find_spec('ziglang'):
        cc = [sys.executable, '-m', 'ziglang', 'cc']
    else:
        raise SystemExit('Install GCC/Clang, or run: uv run --with ziglang python tools/check-lua50.py')
    inputs = sorted((source / 'src').glob('*.c'))
    inputs += [source / 'src/lib/lauxlib.c', source / 'src/luac/luac.c', source / 'src/luac/print.c']
    command = cc + ['-O2', '-DLUA_OPNAMES', '-I' + str(source / 'include'), '-I' + str(source / 'src')]
    command += [str(p) for p in inputs] + ['-o', str(compiler)]
    if os.name != 'nt':
        command += ['-lm']
    subprocess.run(command, check=True)

root = Path(__file__).resolve().parents[1] / 'SlimSuite'
files = [root / line.strip() for line in (root / 'SlimSuite.toc').read_text().splitlines()
         if line.strip().endswith('.lua')]
subprocess.run([str(compiler), '-v'], check=True)
for file in files:
    subprocess.run([str(compiler), '-p', str(file)], check=True)
print('Actual Lua 5.0.3 compilation passed for %d manifest modules' % len(files))
