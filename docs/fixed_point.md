# Fixed point and raster math

Source of truth: `rtl/gpu/shader_core.v`, `rtl/gpu/pineapple_gpu.v:52-87`,
`rtl/gpu/reciprocal.v`, `rtl/gpu/rasterizer.v`,
`tools/reference_renderer.py`. The golden model is integer-only and bit-exact
with RTL — `[s18, mul, edge, project]` must be read as the specification, not
as an approximation.

## S18Q12 (general arithmetic)

Signed 18-bit, 12 fractional bits: `1.0 = 4096`, range ≈ −32.0…+31.999.
`wrap18(v) = ((v+131072) mod 262144) − 131072`. Multiply: `(a·b)>>12`,
truncated, then wrapped. Chosen so a normal 18×18 multiply fits one DSP48
cleanly (brief §4; the current FOSS flow still runs `-nodsp` in fabric — same
widths, shallower timing either way).

## Specialized formats

| Quantity | Format | Converting |
|---|---|---|
| Clip `w` threshold | `p[3] < 512` (≈0.125) kills | Behind/near clip guard |
| `q = 1/w` | `min(131071, 2^24 / w)`, unsigned-in-signed-18 | 32-cycle restoring divider; `denominator==0` saturates to `0xFFFFFFFF` |
| Screen `x/y` | signed 16-bit pixels | `x = 160+((px·160)>>24)`, `y = 90−((py·90)>>24)` with `px = x_clip·q` (36-bit); reject outside ±1024 |
| Depth `z` | unsigned 16-bit | `(pz·q)>>8` clamped to `0…65535`; clear = `0xFFFF` (far); nearer wins, equal fails |
| UV texel | 8-bit each | `u<0?0:(u≥4096?255:u[11:4])` (top 8 of 12 fractional bits); nearest, clamp |
| RGB444 out | 4 bits/channel | `v<0?0:(v≥4096?15:v[11:8])`; texture expand inverts it: `{6'b0,nib,nib,nib}` |
| Edge/area | 32-bit | rasterizer scales ×4; `area = 4·signed_area`; `inv = 2^30/(area<<2)`; weights `(e·inv)>>14` (17-bit), attributes `(Σw·a)>>16` |

## Perspective divide (per vertex and per fragment)

Vertices carry `q` and `u·q, v·q`; the rasterizer interpolates `q, u', v'`
linearly and each fragment reconstructs `u = u'/q` (second 32-cycle divide)
before `TEX2D`. Normals use plain linear interpolation (no renormalization
guarantee — documented approximation, brief §8).

## Edge functions and fill rule

`E(x,y)` evaluated at pixel centers (`2x+1, 2y+1`, ×2 to stay integral),
top-left rule: an edge with `E==0` fills iff it is a top or left edge
(`y_b<y_a || (y_b==y_a && x_b>x_a)`). Shared edges therefore fill exactly once
— `tb_rasterizer` checks 24 randomized triangles under randomized stalls, and
`make verify` requires zero mismatched pixels (57,600) per frame.
