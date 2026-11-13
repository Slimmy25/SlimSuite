# The game runs Lua 5.0; the harness runs a newer Lua, which hides two kinds of mistake. This looks for them in the text:
#  1. a function made inside a loop that reads the loop's own variable (in 5.0 every pass shares it, so the function
#     sees the last value: copy it to a local inside the loop first)
#  2. things 5.0 does not have: string.match / gmatch, select(), the # length sign and the % operator
import re, sys
KW = {'for','do','end','function','if','then','while','repeat','until','in','local','return','and','or','not','nil','true','false','else','elseif','break'}
def toks(src):
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        if c == '\n': line += 1; i += 1; continue
        if src.startswith('--[[', i):
            j = src.find(']]', i); j = n if j < 0 else j + 2; line += src.count('\n', i, j); i = j; continue
        if src.startswith('--', i):
            j = src.find('\n', i); i = n if j < 0 else j; continue
        if c in '"\'':
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == '\\': j += 1
                j += 1
            i = j + 1; continue
        m = re.match(r'[A-Za-z_][A-Za-z0-9_]*', src[i:])
        if m:
            yield (m.group(0), line, src[i-1] if i else ' '); i += len(m.group(0)); continue
        if c in '=#%': yield (c, line, src[i-1] if i else ' ')
        i += 1
bad = 0
for f in sys.argv[1:]:
    src = open(f, encoding='utf-8').read()
    stack, collect, names = [], None, None
    for t, line, prev in toks(src):
        if t in '#%':
            print(f"{f}:{line}: '{t}' is not in Lua 5.0 <-- BAD"); bad += 1; continue
        if collect is not None:
            if t in ('=', 'in'): names, collect = collect, None; continue
            collect.append(t); continue
        if t == '=': continue
        if t == 'for': collect = []; continue
        if t == 'do':
            stack.append(('for', names, line) if names is not None else ('do', None, line)); names = None; continue
        if t in ('function', 'if', 'repeat'): stack.append((t, None, line)); continue
        if t in ('end', 'until'):
            if stack: stack.pop()
            continue
        if t in ('match', 'gmatch') and prev == '.':
            print(f"{f}:{line}: string.{t} is not in Lua 5.0 <-- BAD"); bad += 1; continue
        if t == 'select' and prev not in '.:':
            print(f"{f}:{line}: select() is not in Lua 5.0 <-- BAD"); bad += 1; continue
        if t in KW or prev in '.:': continue
        infn = False
        for kind, vars_, l in reversed(stack):
            if kind == 'function': infn = True
            elif kind == 'for' and infn and vars_ and t in vars_ and t != '_':
                print(f"{f}:{line}: a function reads the loop variable '{t}' of the loop at line {l} <-- BAD"); bad += 1
print("lua 5.0 problems: %d" % bad)
