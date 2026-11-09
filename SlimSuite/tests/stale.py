import re,glob,sys
src={f:open(f,encoding='latin-1').read() for f in glob.glob('*.lua')}
def strip(s):
    s=re.sub(r'--\[\[.*?\]\]','',s,flags=re.S)
    s=re.sub(r'--[^\n]*','',s)
    s=re.sub(r'"(\\.|[^"\\\n])*"','""',s)
    s=re.sub(r"'(\\.|[^'\\\n])*'","''",s)
    s=re.sub(r'\[\[.*?\]\]','""',s,flags=re.S)
    return s
allt='\n'.join(strip(s) for s in src.values())
ss=set(re.findall(r'function\s+SS\.(\w+)',allt))|set(re.findall(r'\bSS\.(\w+)\s*=',allt))
defined=set()
t=allt
defined|=set(re.findall(r'(?:^|\n)\s*function\s+(\w+)\s*\(',t))
defined|=set(re.findall(r'local\s+function\s+(\w+)',t))
for m in re.findall(r'local\s+([\w \t,]+?)\s*(?:=|\n|;)',t):
    defined|=set(x.strip() for x in m.split(','))
defined|=set(re.findall(r'(?:^|\n|;)\s*(\w+)\s*=[^=]',t))
for m in re.findall(r'function\s*[\w.:]*\(([^)]*)\)',t):
    defined|=set(x.strip() for x in m.split(','))
for m in re.findall(r'for\s+([\w \t,]+?)\s+(?:=|in)',t):
    defined|=set(x.strip() for x in m.split(','))
for f,s in src.items():
    for i,line in enumerate(strip(s).split('\n'),1):
        for m in re.finditer(r'(?<![\w.:])(\w+)\b',line):
            n=m.group(1)
            if n in ss and n not in defined:
                print(f,i,n,'-> only SS.'+n+' exists')
