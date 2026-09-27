#!/usr/bin/env python3
"""Pack ordinary OBJ (v/vt/vn, polygons) + PPM/PNG into Pine GPU BRAM images."""
import argparse,json,math
from pathlib import Path

def pack(obj,texture,out):
    out=Path(out); out.mkdir(parents=True,exist_ok=True)
    positions=[]; normals=[]; uvs=[]; vertices=[]; indices=[]; cache={}
    def resolve(i,n): return int(i)-1 if int(i)>0 else n+int(i)
    for line in Path(obj).read_text().splitlines():
        t=line.split('#')[0].split()
        if not t: continue
        if t[0]=='v': positions.append(list(map(float,t[1:4])))
        elif t[0]=='vn': normals.append(list(map(float,t[1:4])))
        elif t[0]=='vt': uvs.append(list(map(float,t[1:3])))
        elif t[0]=='f':
            face=[]
            for spec in t[1:]:
                a=spec.split('/'); pi=resolve(a[0],len(positions)); ti=resolve(a[1],len(uvs)) if len(a)>1 and a[1] else None; ni=resolve(a[2],len(normals)) if len(a)>2 and a[2] else None
                key=(pi,ti,ni)
                if key not in cache:
                    p=positions[pi]; n=normals[ni] if ni is not None else p
                    length=math.sqrt(sum(x*x for x in n)) or 1
                    v=p+[x/length for x in n]+(uvs[ti] if ti is not None else [0,0])
                    if any(abs(x)>=32 for x in v): raise ValueError('Q6.12 vertex out of range')
                    cache[key]=len(vertices); vertices.append([round(x*4096) for x in v])
                face.append(cache[key])
            for j in range(1,len(face)-1): indices.extend([face[0],face[j],face[j+1]])
    if len(vertices)>2048 or len(indices)>16384: raise ValueError('P1 capacity: 2048 split vertices, 16384 indices')
    data=Path(texture).read_bytes()
    if data.startswith(b'P6\n256 256\n255\n'): rgb=data.split(b'\n',3)[3]
    else:
        try:
            from PIL import Image
            im=Image.open(texture).convert('RGB')
            if im.size!=(256,256): raise ValueError('texture must be 256x256')
            rgb=im.tobytes()
        except ImportError as e: raise ValueError('PNG/arbitrary PPM requires Pillow; canonical P6 supported without it') from e
    tex=[(rgb[i]>>4)<<8|(rgb[i+1]>>4)<<4|(rgb[i+2]>>4) for i in range(0,len(rgb),3)]
    def write(name,values,width,size):
        Path(out,name).write_text(''.join(f'{v:0{width}x}\n' for v in values+[0]*(size-len(values))))
    write('vertices.mem',[sum((x&262143)<<(18*j) for j,x in enumerate(v)) for v in vertices],36,2048)
    write('indices.mem',indices,4,16384)
    write('texture.mem',[sum(tex[i+j]<<(12*j) for j in range(min(4,len(tex)-i))) for i in range(0,len(tex),4)],12,16384)
    meta={'vertices':len(vertices),'indices':len(indices),'triangles':len(indices)//3,'texture':[256,256],'format':'8 signed Q6.12 lanes, position normal uv; lane0 least significant'}
    Path(out,'asset.json').write_text(json.dumps(meta,indent=2)+'\n')
    Path(out,'asset.vh').write_text(f'`define PINE_INDEX_COUNT {len(indices)}\n')
    return vertices,indices,tex
if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('obj'); p.add_argument('texture'); p.add_argument('--out',default='assets/packed'); a=p.parse_args(); pack(a.obj,a.texture,a.out)
