#!/usr/bin/env python3
"""Integer-only Pine reference: wrap18, arithmetic truncation, exact RTL coverage."""
import zlib
Q=4096
def s18(v): return ((v+131072)&262143)-131072
def mul(a,b): return s18((a*b)>>12)
def shader(program,inputs,uniforms,texture):
    r=[[0]*4 for _ in range(16)]
    for i,v in enumerate(inputs): r[i]=list(v)
    out=[[0]*4 for _ in range(3)]
    for ins in program:
        op=ins>>26; d=(ins>>22)&15; a=(ins>>18)&15; b=(ins>>14)&15; c=(ins>>10)&15; mask=(ins>>6)&15
        if op==0: return out
        if op==16: out[ins&3]=r[a][:]; continue
        if op==2: vals=[s18(ins&262143)]*4; mask=(ins>>18)&15
        elif op==3: vals=uniforms[ins&63]
        elif op==15:
            u=max(0,min(4095,r[a][0])); v=max(0,min(4095,r[a][1])); t=texture[(v>>4)*256+(u>>4)]
            vals=[((t>>shift)&15)*273 for shift in (8,4,0)]+[4096]
        elif op in (8,9): vals=[s18(sum(r[a][j]*r[b][j] for j in range(3 if op==8 else 4))>>12)]*4
        else:
            vals=[]
            for j in range(4):
                av,bv,cv=r[a][j],r[b][j],r[c][j]
                vals.append(s18({1:lambda:av,4:lambda:av+bv,5:lambda:av-bv,6:lambda:(av*bv)>>12,
                 7:lambda:((av*bv)>>12)+cv,10:lambda:min(av,bv),11:lambda:max(av,bv),
                 12:lambda:max(0,min(Q,av)),13:lambda:Q if av<bv else 0,14:lambda:bv if av else cv}[op]()))
        for j in range(4):
            if mask>>j&1: r[d][j]=vals[j]
    raise ValueError('shader failed to END')
def edge(a,b,x,y): return (b[0]-a[0])*(y-a[1])-(b[1]-a[1])*(x-a[0])
def top_left(a,b): return b[1]<a[1] or (b[1]==a[1] and b[0]>a[0])
def fragments(vertices,width=320,height=180):
    """vertices=(screen x,y,z,q,uq,vq,nx,ny,nz); integer screen coordinates."""
    v=[list(a) for a in vertices]; area=edge(v[0],v[1],v[2][0],v[2][1])
    if area==0: return
    if area<0: v[1],v[2]=v[2],v[1]; area=-area
    xy=[(a[0]*2,a[1]*2) for a in v]; inv=(1<<30)//(area*4)
    for y in range(max(0,min(a[1] for a in v)),min(height-1,max(a[1] for a in v))+1):
        for x in range(max(0,min(a[0] for a in v)),min(width-1,max(a[0] for a in v))+1):
            e=[edge(xy[1],xy[2],2*x+1,2*y+1),edge(xy[2],xy[0],2*x+1,2*y+1),edge(xy[0],xy[1],2*x+1,2*y+1)]
            tl=[top_left(xy[1],xy[2]),top_left(xy[2],xy[0]),top_left(xy[0],xy[1])]
            if not all(a>0 or (a==0 and t) for a,t in zip(e,tl)): continue
            w=[(a*inv)>>14 for a in e]
            attrs=[sum(w[i]*v[i][k] for i in range(3))>>16 for k in range(2,9)]
            yield x,y,attrs

def project(outputs):
    p,n,uv=outputs
    if p[3]<512: return None
    q=min(131071,(1<<24)//p[3])
    x=160+((p[0]*q*160)>>24); y=90-((p[1]*q*90)>>24)
    if not(-1024<=x<=1023 and -1024<=y<=1023): return None
    z=max(0,min(65535,(p[2]*q)>>8))
    return [x,y,z,q,mul(uv[0],q),mul(uv[1],q),*n[:3]]
def render(vertices,indices,texture,vs,fs,uniforms,width=320,height=180,clear=0x013):
    color=[clear]*(width*height); depth=[65535]*(width*height)
    for start in range(0,len(indices),3):
        vv=[]
        for idx in indices[start:start+3]:
            p=vertices[idx]; v=project(shader(vs,[p[:3]+[Q],p[3:6]+[0],p[6:8]+[0,0]],uniforms,texture))
            if v is None: break
            vv.append(v)
        if len(vv)!=3: continue
        for x,y,a in fragments(vv,width,height):
            z,q,uq,vq,nx,ny,nz=a; addr=y*width+x
            if z>=depth[addr] or q<=0: continue
            iq=min(131071,(1<<24)//q)
            rgb=shader(fs,[[mul(uq,iq),mul(vq,iq),0,Q],[nx,ny,nz,0],[z>>4]*3+[Q]],uniforms,texture)[0]
            c=[max(0,min(15,t>>8)) for t in rgb[:3]]
            color[addr]=c[0]<<8|c[1]<<4|c[2]; depth[addr]=z
    return color

def crc(pixels): return zlib.crc32(b''.join(v.to_bytes(2,'little') for v in pixels))
def ppm(path,pixels,w=320,h=180):
    from pathlib import Path
    Path(path).write_bytes(f'P6\n{w} {h}\n255\n'.encode()+bytes(((v>>s)&15)*17 for v in pixels for s in (8,4,0)))
