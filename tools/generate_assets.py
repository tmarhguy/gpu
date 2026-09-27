#!/usr/bin/env python3
"""Original procedural showcase assets; MIT, see root LICENSE. No object-specific GPU logic."""
import math,json
from pathlib import Path
from pinepack import pack
from pineasm import assemble
from reference_renderer import render,ppm,crc
A=Path('assets'); A.mkdir(exist_ok=True)
verts=[]; faces=[]
def add(p,n,uv):
    verts.append((p,n,uv)); return len(verts)
N=24; L=20
for j in range(L+1):
    t=math.pi*j/L; y=-.95+1.7*j/L; radius=.66*math.sin(t)**.65
    for i in range(N+1):
        a=2*math.pi*i/N; n=[math.cos(a),-.7*math.cos(t),math.sin(a)]
        add([radius*math.cos(a),y,radius*math.sin(a)],n,[i/N,.74*j/L])
for j in range(L):
    for i in range(N):
        a=j*(N+1)+i+1; b=a+N+1
        faces.extend([(a,b,a+1),(a+1,b,b+1)])
for leaf in range(14):
    a=leaf*2.39996; height=.65+.35*((leaf*7)%11)/10; spread=.4+.35*(leaf%3)/2
    base=len(verts)+1
    for j in range(5):
        t=j/4; rad=spread*t*t; y=.6+height*t
        width=.105*(1-t)+.005
        for side in (-1,1):
            add([math.cos(a)*rad-side*math.sin(a)*width,y,math.sin(a)*rad+side*math.cos(a)*width],
                [math.cos(a)*.4,.8,math.sin(a)*.4],[.2+side*.1,.82+.16*t])
    for j in range(4):
        x=base+j*2; faces.extend([(x,x+1,x+2),(x+1,x+3,x+2)])
def obj(path,verts,faces):
    text=['# Original procedural Pineapple GPU asset, MIT, see root LICENSE']
    for p,n,uv in verts: text.append('v '+' '.join(map(str,p)))
    for p,n,uv in verts: text.append('vt '+' '.join(map(str,uv)))
    for p,n,uv in verts: text.append('vn '+' '.join(map(str,n)))
    for f in faces: text.append('f '+' '.join(f'{i}/{i}/{i}' for i in f))
    path.write_text('\n'.join(text)+'\n')
obj(A/'pineapple.obj',verts,faces)
pixels=[]
for y in range(256):
    for x in range(256):
        if y>=200:
            c=(30+(x%17),105+(x%29),18+(y%13))
        else:
            u=(x/16+y/17)%1; v=(x/16-y/17)%1; edge=min(u,1-u,v,1-v)
            c=(115,65,10) if edge<.09 else ((235,171,35) if edge>.19 else (186,118,18))
        pixels.extend(c)
(A/'pineapple.ppm').write_bytes(b'P6\n256 256\n255\n'+bytes(pixels))
# A separate cube exercises the identical asset interface.
cv=[]; cf=[]
for n,corners in [([0,0,1],[(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]),([0,0,-1],[(1,-1,-1),(-1,-1,-1),(-1,1,-1),(1,1,-1)]),([1,0,0],[(1,-1,1),(1,-1,-1),(1,1,-1),(1,1,1)]),([-1,0,0],[(-1,-1,-1),(-1,-1,1),(-1,1,1),(-1,1,-1)]),([0,1,0],[(-1,1,1),(1,1,1),(1,1,-1),(-1,1,-1)]),([0,-1,0],[(-1,-1,-1),(1,-1,-1),(1,-1,1),(-1,-1,1)])]:
    base=len(cv)+1
    cv += [([x*.6 for x in p],n,uv) for p,uv in zip(corners,[(0,0),(1,0),(1,1),(0,1)])]
    cf.extend([(base,base+1,base+2),(base,base+2,base+3)])
obj(A/'cube.obj',cv,cf)
v,idx,tex=pack(A/'pineapple.obj',A/'pineapple.ppm',A/'packed')
pack(A/'cube.obj',A/'pineapple.ppm',A/'cube')
program=[]
for name in ['basic.vert','diffuse.frag','normal.frag','toon.frag','unlit.frag','uv.frag','depth.frag']:
    words=assemble(Path('shaders',name).read_text()); program += words+[0]*(64-len(words))
program += [0]*(512-len(program))
(A/'program.mem').write_text(''.join(f'{x:08x}\n' for x in program))
# Camera is data owned by the board host, never by the GPU.
matrices=[]
for zoom in range(4):
 for pitch in range(9):
  for yaw in range(32):
    a=yaw*2*math.pi/32; b=(pitch-4)*math.pi/36; ca,sa,cb,sb=math.cos(a),math.sin(a),math.cos(b),math.sin(b)
    dist=2.7+.6*zoom
    z=[-sa*cb,sb,ca*cb]
    m=[[ca*1.05,0,sa*1.05,0],[sa*sb*1.85,cb*1.85,-ca*sb*1.85,-.65],[-q*1.01 for q in z]+[dist*1.01-.1],[-q for q in z]+[dist]]
    matrices.extend(round(q*4096)&262143 for row in m for q in row)
(A/'camera.mem').write_text(''.join(f'{x:05x}\n' for x in matrices))
def uniforms(cam):
    from reference_renderer import s18
    return [[s18(matrices[cam*16+i*4+j]) for j in range(4)] for i in range(4)]+[[1638,3277,1638,0]]+[[0]*4 for _ in range(59)]
Path('build').mkdir(exist_ok=True)
for name,vertices,indices in [('pineapple',v,idx),('cube',*pack(A/'cube.obj',A/'pineapple.ppm',A/'cube')[:2])]:
    image=render(vertices,indices,tex,program[:64],program[64:128],uniforms(4*32))
    ppm(f'build/{name}-reference.ppm',image)
    print(name,len(vertices),len(indices)//3,hex(crc(image)))
