# Pine shader ISA

Source of truth: `rtl/gpu/shader_core.v`, `tools/pineasm.py`,
`tools/reference_renderer.py:shader()`. One ISA, two stages (vertex +
fragment share the core RTL, selected by `program_base`).

## Machine model

- 16 vector registers `r0…r15`, each 4× S18Q12 lanes (`{x,y,z,w}` = bits
  `[17:0] [35:18] [53:36] [71:54]`). Straight-line only: no branches, no
  predication. Max 64 instructions per program (`steps==63` faults without
  `END`); 512 program words total (8 slots × 64, see [upload](shader_upload.md)).
- 32-bit encoding: `op[31:26] dst[25:22] a[21:18] b[17:14] c[13:10] mask[9:6]
  uaddr[5:0]`. `LDI` repurposes the low 18 bits as `{mask[21:18], imm[17:0]}`.
  `OUT` repurposes as `{a[21:18], …, slot[1:0]}`.
- Per-instruction latency in RTL is ~5 cycles (fetch → operand → multiply →
  execute → writeback); `TEX2D` pays the texture RAM latency on top. The
  integer golden model is bit-exact: wrap-18 arithmetic, `(a*b)>>12`
  truncation, same masks, same texture quantize.

## Opcodes

| # | Mnemonic | Form | Semantics (per masked lane) |
|---|---|---|---|
| 0 | `END` | `END` | Halt, success. Missing `END`, unknown `op>16`, or `steps==63` → `fault`, DRAW aborts with `error` |
| 1 | `MOV` | `MOV rD[.m], rA` | `rD = rA` |
| 2 | `LDI` | `LDI rD[.m], imm` | `rD = s18(imm)`; assembler takes float ×4096, range −131072…131071 |
| 3 | `LDU` | `LDU rD[.m], uN` | `rD = uniform[N]` (whole vec4 addressed by `uaddr`) |
| 4 | `ADD` | `ADD rD[.m], rA, rB` | `rD = rA+rB` (wrapped) |
| 5 | `SUB` | `SUB rD[.m], rA, rB` | `rD = rA−rB` |
| 6 | `MUL` | `MUL rD[.m], rA, rB` | `rD = (rA·rB)>>12` |
| 7 | `MAD` | `MAD rD[.m], rA, rB, rC` | `rD = ((rA·rB)>>12)+rC` |
| 8 | `DP3` | `DP3 rD[.m], rA, rB` | `rD = (Σ rA[0..2]·rB[0..2])>>12` broadcast to masked lanes |
| 9 | `DP4` | `DP4 rD[.m], rA, rB` | 4-lane dot, broadcast |
| 10 | `MIN` | `MIN rD[.m], rA, rB` | `min` |
| 11 | `MAX` | `MAX rD[.m], rA, rB` | `max` |
| 12 | `SAT` | `SAT rD[.m], rA` | clamp to `0…4096` (0.0…1.0) |
| 13 | `CMP` | `CMP rD[.m], rA, rB` | `rA<rB ? 4096 : 0` |
| 14 | `SEL` | `SEL rD[.m], rA, rB, rC` | `rA!=0 ? rB : rC` |
| 15 | `TEX2D` | `TEX2D rD, rA` | Sample 256×256 RGB444 at `(u,v)=rA.xy` (nearest, clamp); `rD = {1.0, b', g', r'}` with nibble expansion `{6'b0,nib,nib,nib}`. Counts `texture_requests` |
| 16 | `OUT` | `OUT slot, rA` | `slot 0→out0, 1→out1, 2→out2`; any other slot faults |

Write mask `.xyzw` defaults to all lanes. Destination register indexes are
4 bits; uniform addresses 6 bits (low 4 select the vec4).

## Stage ABIs (fixed by `pineapple_gpu.v`, not by shaders)

- Vertex in: `r0={1.0,x,y,z} r1={0,nx,ny,nz} r2={0,0,u,v}` (+ uniforms).
  Vertex out: `OUT 0` = clip `p`, `OUT 1` = normal, `OUT 2` = uv.
  Canonical `basic.vert`: four `LDU+DP4` rows for `p_clip = M·mvp·p`.
- Fragment in: `r0={1,0,v,u} r1={0,nz,ny,nx} r2={1,z,z,z}`.
  Fragment out: `OUT 0` = linear RGB (quantized to RGB444 at writeback).
- Six showcase fragment slots (`fs_base = (mode+1)*64`): 0 unlit, 1 diffuse,
  2 toon, 3 normal-viz, 4 uv-viz, 5 depth-viz (yaw-0 cube CRC `641A94BF` is
  mode 0). New programs must obey the same ABI; the screen is the only
  acknowledgement (UART is write-only).
