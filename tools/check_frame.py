#!/usr/bin/env python3
import argparse,json
from pathlib import Path
from reference_renderer import render,crc,ppm,s18
p=argparse.ArgumentParser(); p.add_argument('--asset',default='cube');p.add_argument('--mode',type=int,default=0);p.add_argument('--yaw',type=int,default=0);p.add_argument('--rtl',default='build/rtl-frame.mem');a=p.parse_args()
folder=Path('assets/cube' if a.asset=='cube' else 'assets/packed')
meta=json.loads((folder/'asset.json').read_text())
v=[[s18((int(x,16)>>(18*j))&262143) for j in range(8)] for x in (folder/'vertices.mem').read_text().split()][:meta['vertices']]
idx=[int(x,16) for x in (folder/'indices.mem').read_text().split()][:meta['indices']]
t=[]
for x in (folder/'texture.mem').read_text().split():
 word=int(x,16);t.extend([(word>>(12*j))&4095 for j in range(4)])
program=[int(x,16) for x in Path('assets/program.mem').read_text().split()]
mat=[s18(int(x,16)) for x in Path('assets/camera.mem').read_text().split()]
base=(128+a.yaw)*16
uniforms=[mat[base+i*4:base+i*4+4] for i in range(4)]+[[1638,3277,1638,0]]+[[0]*4 for _ in range(59)]
expected=render(v,idx,t,program[:64],program[(a.mode+1)*64:(a.mode+2)*64],uniforms)
actual=[int(x,16) for x in Path(a.rtl).read_text().split()]
ppm('build/reference.ppm',expected);ppm('build/rtl.ppm',actual)
errors=[i for i,(e,v) in enumerate(zip(expected,actual)) if e!=v]
print(f'{a.asset} mode={a.mode} yaw={a.yaw}: reference CRC={crc(expected):08X} RTL CRC={crc(actual):08X}; mismatches={len(errors)}')
for i in errors[:12]: print(i%320,i//320,f'expected={expected[i]:03x} actual={actual[i]:03x}')
assert len(actual)==len(expected) and not errors
