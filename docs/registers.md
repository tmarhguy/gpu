# PineBus register map

Source of truth: `rtl/gpu/pineapple_gpu.v:109-164` (reads) and
`rtl/host/demo_host.v:19-33` (the only writer). 16-bit addresses, 32-bit data.
`write + valid → ready`; writes commit **only while the GPU is idle**
(`ready = (state==0) || read`). Reads are combinatorial and always ready;
there is no read handshake. `demo_host` freezes its stream on `hold` during
shader-upload commits so no command double-issues
(`rtl/gpu/shader_loader.v`, [upload](shader_upload.md)).

## Control / geometry (write; some readable back)

| Addr | Name | Bits | Writer | Meaning |
|---|---|---|---|---|
| `0x00` | STATUS | `{30'b0, error, busy}` (read) | GPU | `busy = state!=0`; `error` sticks until reset. Write has no effect |
| `0x04` | CLEAR_COLOR | `[11:0]` RGB444 | demo_host every frame | Grape-dark blue `0x013` in the showcase |
| `0x08` | VERTEX_BASE | `[10:0]` | — (0) | Word base into `vertex_mem[2048]` |
| `0x0C` | INDEX_BASE | `[13:0]` | — (0) | Word base into `index_mem[16384]` |
| `0x10` | INDEX_COUNT | `[13:0]` | demo_host (`INDEX_COUNT` param) | 3216 pineapple, 36 cube. Must be a multiple of 3 and satisfy `base+count ≤ 16384`; anything else raises `error` and aborts the DRAW |
| `0x14` | VS_PROGRAM | `[8:0]` | — (0) | Vertex program slot base (words, 0..511) |
| `0x18` | FS_PROGRAM | `[8:0]` | demo_host (`(mode+1)*64`) | Fragment slot: 64/128/…/384 for modes 0..5 |
| `0x1C` | CULL | `[0]` | — (0) | Write-only. Backface culling enable. Not readable |
| `0x50` | COMMAND | `wdata` | demo_host | `1`=CLEAR (fill color+`0xFFFF` depth), `2`=DRAW_INDEXED, `3`=PRESENT (vblank swap). Anything else raises `error` |

## Uniform window (write-only)

Any address with `addr[15:8]==1` writes one S18 lane:
`u{addr[3:2]}[addr[7:4]] <= wdata[17:0]` — 16 vec4 uniforms (`u0…u3[0…15]`).
The demo host fills the 4 MVP rows as `0x100+component*4` (16 words/frame from
`assets/camera.mem`) plus light/ambient constants at `0x140/0x144/0x148/0x14C`.
Shader `LDU` reads the addressed vec4; see [shader ISA](shader_isa.md).

## Counters (read-only, reset-cleared)

| Addr | Name | Counts |
|---|---|---|
| `0x20` | FRAMES | Presented frames |
| `0x24` | FRAME_CYCLES | `gpu_clk` cycles in the last frame (host overhead included) |
| `0x28` / `0x2C` / `0x30` / `0x34` | VERTICES / TRIANGLES / CULLED / RASTERIZED | Geometry flow |
| `0x38` / `0x3C` / `0x40` | FRAGMENTS / KILLED / SHADED | Early-Z kills vs shaded |
| `0x44` / `0x48` | TEXTURE_REQUESTS / INSTRUCTIONS | `TEX2D` executions / shader instructions retired |
| `0x4C` | PROG_LOADS | Committed UART shader uploads |

Unmapped reads return 0. There is no interrupt, no DMA, no burst: one 32-bit
register per idle-window write is the whole P1 host contract, by design.
