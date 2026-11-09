import re,sys
for f in sys.argv[1:]:
    L=open(f,encoding='utf8').read().replace('\r','').split('\n')
    defs={};fwd=set()
    for i,l in enumerate(L,1):
        m=re.match(r'^local function (\w+)',l)
        if m: defs.setdefault(m.group(1),i)
        m=re.match(r'^local ([\w, ]+?)\s*(=.*)?;?\s*(--.*)?$',l)
        if m and not l.startswith('local function'):
            for n in m.group(1).split(','): fwd.add(n.strip())
    for name,d in defs.items():
        if name in fwd: continue
        for i,l in enumerate(L[:d-1],1):
            code=l.split('--')[0]
            if re.search(r'(?<![\w.:])'+name+r'\s*\(',code) or re.search(r'pcall\(\s*'+name+r'\b',code):
                print(f'{f}: {name} (defined {d}) used at {i}: {l.strip()[:100]}')
