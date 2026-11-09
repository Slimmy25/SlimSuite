import re,sys
def bal(src):
    src=re.sub(r'--\[\[.*?\]\]','',src,flags=re.S)
    src=re.sub(r'"(\\.|[^"\\\n])*"|\'(\\.|[^\'\\\n])*\'','S',src)
    src=re.sub(r'--[^\n]*','',src)
    toks=re.findall(r'\b(function|if|do|end|repeat|until|for|while|elseif|then)\b|[(){}\[\]]',src)
    blk=sum(1 for t in toks if t in('function','if','do','repeat'))-sum(1 for t in toks if t in('end','until'))
    # 'for/while ... do' counted via do
    par=src.count('(')-src.count(')'); cur=src.count('{')-src.count('}')
    return blk,par,cur
for f in sys.argv[1:]:
    print(f,bal(open(f,encoding='utf8').read()))
