#!/usr/bin/env python3
"""Pine straight-line vector ISA assembler. See docs/shader_isa.md."""
import argparse
from pathlib import Path
OPS={name:i for i,name in enumerate('END MOV LDI LDU ADD SUB MUL MAD DP3 DP4 MIN MAX SAT CMP SEL TEX2D OUT'.split())}
def assemble(text):
    words=[]
    for lineno,line in enumerate(text.splitlines(),1):
        line=line.split('#')[0].replace(',',' ').strip()
        if not line: continue
        try:
            t=line.split(); op=t.pop(0).upper(); code=OPS[op]<<26
            if op=='END': words.append(code); continue
            if op=='OUT':
                slot=int(t[0]); a=int(t[1][1:]); code|=a<<18|slot
            else:
                dest=t.pop(0).split('.'); d=int(dest[0][1:]); mask=sum(1<<'xyzw'.index(c) for c in dest[1]) if len(dest)>1 else 15
                if not 0<=d<16: raise ValueError('register')
                code|=d<<22
                if op=='LDI':
                    v=round(float(t[0])*4096)
                    if not -131072<=v<=131071: raise ValueError('immediate range')
                    code|=mask<<18|(v&0x3ffff)
                else:
                    code|=mask<<6
                    if op=='LDU': code|=int(t[0].lstrip('u'))
                    else:
                        for token,shift in zip(t,[18,14,10]):
                            r=int(token.lstrip('r'))
                            if not 0<=r<16: raise ValueError('register')
                            code|=r<<shift
            words.append(code)
        except (ValueError,KeyError,IndexError) as e: raise ValueError(f'line {lineno}: {line}: {e}') from e
    if not words or words[-1]>>26!=0: raise ValueError('program must end with END')
    if len(words)>64: raise ValueError('program exceeds 64 instructions')
    return words
if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('source'); p.add_argument('output'); a=p.parse_args()
    Path(a.output).write_text(''.join(f'{w:08x}\n' for w in assemble(Path(a.source).read_text())))
