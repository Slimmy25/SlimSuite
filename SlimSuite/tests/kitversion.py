# AZSKit.lua is shared: every AZS addon carries a copy and the copy with the highest VERSION wins. So a change to the
# file must raise VERSION, or players keep whichever older copy loaded first. This keeps the file's fingerprint per
# version (tests/azskit-versions.txt) and fails when the file changed but VERSION did not.
import hashlib, re, os, sys
here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, '..', 'AZSKit.lua'), 'rb').read().replace(b'\r\n', b'\n')
m = re.search(rb'local VERSION = (\d+);', src)
version = m.group(1).decode() if m else '?'
digest = hashlib.sha256(src).hexdigest()[:16]
book = os.path.join(here, 'azskit-versions.txt')
known = dict(l.split() for l in open(book) if l.strip()) if os.path.exists(book) else {}
if version in known and known[version] != digest:
    print("AZSKit.lua changed but its VERSION is still %s: raise it (and copy the file to the launcher) <-- BAD" % version)
    sys.exit(1)
if version not in known:
    with open(book, 'a') as f: f.write("%s %s\n" % (version, digest))
print("AZSKit version %s ok" % version)
