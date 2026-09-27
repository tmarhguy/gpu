#!/usr/bin/env python3
import random
from pathlib import Path
from pineasm import assemble
from reference_renderer import shader,fragments,s18
r=random.Random(41); out=Path('build');out.mkdir(exist_ok=True)
def vec(v): return sum((a&262143)<<(18*i) for i,a in enumerate(v))
tex=[]
for word in Path('assets/packed/texture.mem').read_text().split(): tex.extend((int(word,16)>>(j*12))&4095 for j in range(4))
programs=[]; inputs=[]; expected=[]
ops=['MOV','ADD','SUB','MUL','MAD','DP3','DP4','MIN','MAX','SAT','CMP','SEL','TEX2D','LDI','LDU']
for case in range(96):
    inp=[[r.randint(-131072,131071) for j in range(4)] for i in range(3)]
    text=[]
    for j in range(12):
        op=ops[(case+j)%len(ops)];d=r.randrange(3,10);a=r.randrange(10);b=r.randrange(10);c=r.randrange(10)
        mask=r.choice(['','.x','.yz','.w','.xz'])
        args={'MOV':f'r{a}','ADD':f'r{a}, r{b}','SUB':f'r{a}, r{b}','MUL':f'r{a}, r{b}','MAD':f'r{a}, r{b}, r{c}',
              'DP3':f'r{a}, r{b}','DP4':f'r{a}, r{b}','MIN':f'r{a}, r{b}','MAX':f'r{a}, r{b}','SAT':f'r{a}',
              'CMP':f'r{a}, r{b}','SEL':f'r{a}, r{b}, r{c}','TEX2D':f'r{a}','LDI':str(r.randint(-31,31)), 'LDU':'u0'}[op]
        text.append(f'{op} r{d}{mask}, {args}')
    text+=['OUT 0, r3','OUT 1, r5','OUT 2, r9','END']
    p=assemble('\n'.join(text)); programs+=p+[0]*(64-len(p));inputs.extend(map(vec,inp))
    expected.extend(map(vec,shader(p,inp,[[4096,-4096,2048,17]]*64,tex)))
for name,values,width in [('shader-programs',programs,8),('shader-inputs',inputs,18),('shader-expected',expected,18)]:
    (out/(name+'.mem')).write_text(''.join(f'{v:0{width}x}\n' for v in values))
# Shared diagonal plus clipped/offscreen and reversed triangles; normalize winding as setup does.
triangles=[[(0,0),(8,0),(8,8)],[(0,0),(8,8),(0,8)],[(-5,-8),(30,0),(0,21)],[(318,178),(340,179),(319,200)]]
for i in range(20): triangles.append([(r.randrange(-10,50),r.randrange(-10,40)) for _ in range(3)])
coords=[];expected=[];counts=[]
for t in triangles:
    area=(t[1][0]-t[0][0])*(t[2][1]-t[0][1])-(t[1][1]-t[0][1])*(t[2][0]-t[0][0])
    if area<0:t[1],t[2]=t[2],t[1]
    coords.extend(a&65535 for p in t for a in p)
    f=list(fragments([list(p)+[0]*7 for p in t]));counts.append(len(f));expected.extend(y*320+x for x,y,_ in f)
for name,values in [('raster-coords',coords),('raster-counts',counts),('raster-expected',expected+[0]*(16384-len(expected)))]:
    (out/(name+'.mem')).write_text(''.join(f'{x:04x}\n' for x in values))
print('generated 96 shader programs, 24 raster cases,',len(expected),'fragments')
