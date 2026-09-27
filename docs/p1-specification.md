Yes. I would change the goal one final time and freeze it.

We are **not building a pineapple renderer**.

We are building a **small, real, programmable 3D GPU**, and the pineapple is simply its first showcase workload.

That distinction changes several architectural choices. There will be no ESP32, no soft RISC-V doing the rendering, and no object-specific RTL. The FPGA itself implements the graphics processor: programmable vertex processing, triangle setup/rasterization, depth, perspective-correct attributes, texture sampling, programmable fragment processing, framebuffer, and presentation. A tiny board-side controller exists only to submit draw commands and update the camera from the five buttons.

The target problem is:

> **Pineapple GPU P1: a standalone programmable 3D graphics processor for interactive textured-mesh rendering on the Nexys A7-100T.**

The first showcase is a detailed pineapple that you can orbit with the D-pad. But the architecture must be able to render a cube, teapot, spaceship, etc. without changing the GPU RTL.

And fortunately, Tomato gives us a major head start on everything *outside* the GPU. Your existing FPGA setup already proves the Nexys A7-100T, the JC/JD TFP410 DVI/HDMI path, 25 MHz 640×480 timing, D-pad pins/debouncing, and the entire Yosys → nextpnr-xilinx → Project X-Ray → openFPGALoader flow. :chatgpt-content-reference{index="0"}

# Pineapple GPU P1 — architectural specification

The finished system should look like this:

```text
                        NEXYS A7-100T
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│   Five buttons                                               │
│       │                                                      │
│       ▼                                                      │
│ ┌──────────────┐                                             │
│ │ Demo / Host  │ ───── PineBus commands ─────────────┐       │
│ │ Controller   │                                      │       │
│ └──────────────┘                                      ▼       │
│                                               ┌─────────────┐ │
│                                               │ COMMAND     │ │
│                                               │ PROCESSOR   │ │
│                                               └──────┬──────┘ │
│                                                      │        │
│                                          DRAW_INDEXED / CLEAR │
│                                                      │        │
│                                                      ▼        │
│ ┌────────────┐      ┌──────────────┐       ┌───────────────┐ │
│ │ Vertex RAM │ ───► │ PROGRAMMABLE │ ────► │ PRIMITIVE /   │ │
│ │ Index RAM  │      │ VERTEX CORE  │       │ CLIP / CULL   │ │
│ └────────────┘      └──────────────┘       └───────┬───────┘ │
│                                                    │          │
│                                                    ▼          │
│                                            ┌──────────────┐   │
│                                            │ TRIANGLE     │   │
│                                            │ SETUP        │   │
│                                            └──────┬───────┘   │
│                                                   │           │
│                                                   ▼           │
│                                            ┌──────────────┐   │
│                                            │ RASTERIZER   │   │
│                                            └──────┬───────┘   │
│                                                   │ fragments │
│                                                   ▼           │
│                                            ┌──────────────┐   │
│                                            │ INTERPOLATOR │   │
│                                            └──────┬───────┘   │
│                                                   │           │
│                     ┌─────────────┐               ▼           │
│                     │ Texture RAM │◄──────┐ ┌──────────────┐ │
│                     └─────────────┘       └─│ PROGRAMMABLE │ │
│                                             │ FRAGMENT CORE│ │
│                                             └──────┬───────┘ │
│                                                    │         │
│                                                    ▼         │
│                                               DEPTH TEST     │
│                                                    │         │
│                                                    ▼         │
│                                       ┌────────────────────┐ │
│                                       │ Double Framebuffer │ │
│                                       └──────────┬─────────┘ │
│                                                  │           │
│                                                  ▼           │
│                                              SCANOUT         │
│                                                  │           │
│                                       Tomato DVI output      │
└──────────────────────────────────────────────────┼───────────┘
                                                   ▼
                                                MONITOR
```

That is the architecture I would call a GPU without qualifications.

## What makes it a real GPU

The crucial test is that **none of the graphics logic knows what a pineapple is**.

`pineapple.obj` is data.

The GPU sees vertices, indices, textures, uniforms, shader instructions and draw commands.

The software-facing contract should eventually look approximately like:

```text
SET_VERTEX_BUFFER
SET_INDEX_BUFFER
SET_TEXTURE
SET_VERTEX_SHADER
SET_FRAGMENT_SHADER
SET_UNIFORMS
CLEAR
DRAW_INDEXED
PRESENT
```

That distinction is enormously important.

A state machine whose states happen to draw a pineapple is a renderer.

This is a graphics processor.

---

# 1. Resolution: I would actually choose 320×180

I'm changing my earlier 320×240 recommendation after thinking seriously about the BRAM architecture.

We still output:

**640×480 @ ~60 Hz**

because that is the path Tomato already knows works. Your existing `videoout.v` actually already contains a 320×240 RGB444 image path that doubles pixels to 640×480, so the scaling concept is already physically proven on this board. :chatgpt-content-reference{index="1"}

But Pineapple renders internally at:

**320×180**, 16:9.

We double it to:

**640×360**

and center it vertically in the 640×480 signal:

```text
640 × 480 monitor
┌─────────────────────────────────────────┐
│              black bar                  │ 60 px
├─────────────────────────────────────────┤
│                                         │
│             640 × 360                   │
│                                         │
│        2× GPU framebuffer               │
│                                         │
├─────────────────────────────────────────┤
│              black bar                  │ 60 px
└─────────────────────────────────────────┘
```

That isn't because the FPGA lacks compute.

It's because **BRAM is our VRAM** in P1.

At 320×180:

\[
57,600\text{ pixels}
\]

At 30 rendered frames/sec:

\[
1.728\text{ million visible pixels/sec}
\]

At a 100 MHz GPU clock:

\[
\frac{100M}{1.728M}\approx57.9
\]

We have nearly **58 GPU cycles per visible pixel** before accounting for overdraw.

That gives us enough performance budget to build an actually interesting GPU instead of spending all of it moving framebuffer bits around.

---

# 2. Memory architecture

P1 deliberately treats Artix-7 BRAM as the GPU's VRAM.

We'll have:

| Memory | Format | Purpose |
|---|---|---|
| Front color buffer | RGB444 | current displayed frame |
| Back color buffer | RGB444 | frame being rendered |
| Z buffer | 16-bit | hidden-surface removal |
| Texture memory | RGB444 | initial 256×256 texture |
| Vertex memory | packed | mesh vertices |
| Index memory | 16-bit | indexed triangles |
| Shader program RAM | 32-bit | VS + FS programs |
| Uniform RAM | 18-bit/vector | matrices, light, constants |

Double buffering is mandatory.

The display reads **front** while the GPU writes **back**.

At `PRESENT`, they swap on vertical blank.

No tearing.

Later external DDR2 can become actual VRAM. But I do **not** want DDR2 to block P1; implementing or integrating a DDR controller teaches us much less about GPUs than implementing shaders, interpolation, caches and rasterization.

The 100T has 135 RAMB36 blocks and 240 DSP48E1 units available, so this resource strategy is realistic. Tomato currently uses only a fraction of those resources, although Pineapple will obviously be a completely separate design. :chatgpt-content-reference{index="2"}

---

# 3. Color format: RGB444

This is another deliberate board-specific choice.

Your physical display interface already sends:

```text
R[3:0]
G[3:0]
B[3:0]
```

into the TFP410. :chatgpt-content-reference{index="3"}

Therefore our logical render target is:

```text
rrrr gggg bbbb
```

12 bits.

There is no benefit in using a 32-bit framebuffer just to throw most of it away at scanout.

Internally, shader arithmetic has much higher precision. Only the final render target quantizes to RGB444.

---

# 4. A real programmable shader architecture

This is the biggest upgrade over the earlier plan.

There will be **two programmable stages**:

```text
programmable vertex shader
        ↓
fixed-function rasterization
        ↓
programmable fragment shader
```

Both use the **same Pine shader ISA** and essentially the same shader-core RTL.

That means we're actually learning about GPU execution architecture, not merely attaching a tiny shader gimmick to a fixed renderer.

## Pine Shader Core

I would make it a small vector processor.

Conceptually:

```text
16 vector registers

r0  = {x,y,z,w}
r1  = {x,y,z,w}
...
r15 = {x,y,z,w}
```

Each component is **18-bit fixed point**.

Why 18?

Because it maps beautifully onto the Artix-7's DSP48 arithmetic instead of requiring large multi-DSP multipliers. Tomato encountered routing trouble specifically when 33×33 arithmetic had to span multiple DSPs; Pineapple should intentionally keep the normal multiply width small enough to fit cleanly. :chatgpt-content-reference{index="4"}

Our general signed arithmetic format can use 12 fractional bits:

```text
18-bit signed
≈ -32.0 ... +31.999
12 fractional bits
```

Specialized coordinates such as UV and depth can use formats appropriate to their jobs.

The initial shader ISA should contain roughly:

| Family | Instructions |
|---|---|
| Data | `MOV`, `LDI`, `LDU` |
| Arithmetic | `ADD`, `SUB`, `MUL`, `MAD` |
| Vector | `DP3`, `DP4` |
| Limits | `MIN`, `MAX`, `SAT` |
| Comparison | `CMP`, `SEL` |
| Texture | `TEX2D` |
| Output | `OUT` |
| Control | `END` |

No branch instructions initially.

That is deliberate.

Straight-line shader programs are enough for the showcase, while avoiding the entire divergence/control-flow problem until the base processor works.

Later Pineapple can add predication and branching.

---

# 5. Vertex shader

The input vertex should be a general packed structure containing:

```text
position.xyz
normal.xyz
uv.xy
```

The vertex shader gets those as input registers plus uniforms.

Example Pine shader:

```asm
DP4   r8.x, r0, u0
DP4   r8.y, r0, u1
DP4   r8.z, r0, u2
DP4   r8.w, r0, u3

MOV   oPosition, r8
MOV   oNormal,   r1
MOV   oUV,       r2
END
```

So the familiar equation:

\[
p_{clip}=M_{MVP}p
\]

isn't hardwired into the vertex hardware.

It's a program.

That matters.

Eventually someone could write a vertex shader that bends the pineapple, waves its leaves, deforms a mesh, etc.

No new bitstream.

That's a GPU.

---

# 6. Primitive assembly, clipping and culling

The primitive assembler consumes three processed vertices.

It calculates the signed screen-space area:

\[
A =
(x_1-x_0)(y_2-y_0)
-
(y_1-y_0)(x_2-x_0)
\]

The sign handles backface culling.

The magnitude also becomes useful for barycentric interpolation.

For initial bring-up, we will support:

**triangle list topology.**

No lines, strips, fans, patches, etc.

The rasterizer clamps triangle bounding boxes to the viewport, so geometry completely offscreen disappears naturally.

Full homogeneous near-plane clipping can arrive after the first working 3D pipeline. We constrain the demo camera initially so it never intersects the pineapple.

That's one of the few places where I deliberately accept an incomplete GPU feature in P1.

---

# 7. Rasterizer

The rasterizer is fixed-function hardware.

Three edge equations:

\[
E_i(x,y)=A_ix+B_iy+C_i
\]

determine triangle coverage.

Walking right:

\[
E(x+1,y)=E(x,y)+A
\]

Walking downward:

\[
E(x,y+1)=E(x,y)+B
\]

So the inner loop is overwhelmingly adds and compares.

Implement the **top-left fill rule** correctly.

That gives deterministic shared edges without holes or double-filling.

Target:

> Rasterizer should be capable of generating a candidate fragment every GPU cycle whenever the downstream pipeline can accept one.

We may not *consume* one per cycle yet.

That's okay.

`ready/valid` backpressure lets the shader pipeline stall it.

---

# 8. Perspective-correct interpolation

This is one thing I now want in P1 rather than postponing.

We're claiming we're learning real graphics architecture.

So let's learn this properly.

At vertices, calculate:

\[
q=\frac{1}{w}
\]

and:

\[
u'=u q
\]

\[
v'=v q
\]

Rasterization linearly interpolates:

\[
q,\quad u',\quad v'
\]

Then each fragment reconstructs:

\[
u=\frac{u'}{q}
\]

\[
v=\frac{v'}{q}
\]

That's how we avoid obvious affine texture warping.

We can use a small reciprocal lookup table, normalization and optional refinement rather than a giant generic divider.

Normals can initially use ordinary interpolation and normalization approximation. We don't need mathematical perfection everywhere simultaneously.

---

# 9. Texture unit

A **real texture unit**, not a lookup hidden inside the pineapple logic.

P1:

```text
1 texture
256 × 256
RGB444
nearest-neighbor filtering
clamp or wrap addressing
```

`TEX2D` sends:

```text
u,v
```

and receives:

```text
r,g,b,a
```

The alpha component can simply return 1 for now.

Because texture memory is read-only during rendering, we can pack RGB444 texels efficiently into BRAM. This is much easier than packing writable framebuffers.

Later:

```text
nearest
   ↓
bilinear
   ↓
mipmaps
   ↓
texture cache
```

becomes a beautiful progression of actual GPU architecture work.

---

# 10. Fragment shader

A default pineapple shader might be:

```asm
TEX2D r4, rUV

DP3   r5, rNormal, uLightDir
MAX   r5, r5, zero

MUL   r6, r4, r5
MAD   r6, r4, uAmbient, r6

SAT   r6
OUT   r6
END
```

But nothing about the fragment processor knows that's the pineapple shader.

We should eventually include several shader programs:

```text
textured diffuse
normal visualization
depth visualization
toon shading
UV visualization
unlit texture
```

Pressing center could cycle them.

That would actually make a fantastic demo of programmability.

---

# 11. Depth pipeline

Every fragment gets an interpolated depth.

P1 uses:

**16-bit unsigned Z.**

We should perform early depth testing before expensive fragment work whenever possible:

```text
fragment
   ↓
Z read
   ↓
compare
   ├─ fail ─────► discard
   │
   └─ pass
       ↓
     shader
       ↓
     color write
       ↓
     Z write
```

Because the first architecture only processes a small number of fragments concurrently, we can avoid the complicated depth hazards that appear once many fragments are in flight.

Again: the architecture leaves room to pipeline later.

---

# 12. Commands and host boundary

This is another thing I want Astra to get right from day one.

The board demo must **not directly reach inside GPU modules**.

It controls Pineapple through a host interface.

Call it `PineBus`.

Very simple:

```text
addr[15:0]
wdata[31:0]
rdata[31:0]
write
read
valid
ready
```

Registers expose things such as:

```text
STATUS
CLEAR_COLOR
VERTEX_BASE
INDEX_BASE
INDEX_COUNT
VS_PROGRAM
FS_PROGRAM
TEXTURE_BASE
UNIFORM_BASE
COMMAND
FRAME_COUNTER
TRIANGLE_COUNTER
FRAGMENT_COUNTER
```

Commands include at minimum:

```text
CLEAR
DRAW_INDEXED
PRESENT
```

The board-side demo controller is simply the first PineBus host.

Later:

```text
demo FSM
   ↓
RISC-V
   ↓
ESP32
   ↓
USB bridge
   ↓
PCIe host
```

could replace it without touching the graphics architecture.

---

# 13. No CPU in P1

I specifically **do not want an ESP32 or RISC-V softcore right now**.

That was useful when we were thinking primarily about future discrete replacement.

It's wrong for the current goal.

A CPU introduces:

firmware, buses, booting, compiler concerns and integration work that teach us almost nothing about how GPUs work.

Instead:

```text
camera_controller.v
demo_host.v
```

are tiny finite-state machines outside the GPU.

They update uniforms and submit the same commands a future CPU would.

The GPU is therefore a clean accelerator.

---

# 14. Buttons

Tomato already has exactly the input behavior we need.

Its `keypad.v` synchronizes and debounces all five Nexys buttons, produces one-shot presses, and already supports arrow-key autorepeat. The physical mappings are also known: center N17, up M18, down P18, left P17 and right M17. :chatgpt-content-reference{index="5"}

Use it.

For Pineapple:

```text
LEFT     yaw -
RIGHT    yaw +
UP       pitch +
DOWN     pitch -

CENTER tap:
    cycle shader/render mode

CENTER + UP:
    zoom in

CENTER + DOWN:
    zoom out
```

A small sine/cosine ROM and matrix-builder FSM can regenerate the MVP uniform once per frame.

This logic belongs in the **demo host**, not GPU core.

---

# 15. Asset pipeline

Astra should also create:

```text
tools/pinepack.py
```

Pinepack takes something like:

```text
pineapple.obj
pineapple.ppm/png
```

and emits:

```text
vertices.mem
indices.mem
texture.mem
asset.json
```

The initial implementation may use `$readmemh()`.

That means changing the model requires rebuilding the bitstream in P1. **I am okay with that.**

Why?

Because generality comes from the architecture, not necessarily runtime upload on version one.

The important thing is:

```text
pinepack cube.obj
pinepack pineapple.obj
pinepack teapot.obj
```

all produce legal GPU input without editing a line of RTL.

Runtime UART loading can come afterward.

Do not make serial loaders a prerequisite for learning graphics architecture.

---

# 16. The showcase pineapple

I would target approximately:

**2,000 unique vertices / 4,000 triangles / 256×256 texture** initially.

Don't obsess over polygon count.

Smooth vertex normals and the texture will contribute vastly more perceived detail than blindly multiplying triangles.

If this looks insufficient, then we solve the actual measured bottleneck rather than guessing today.

And the final model should ideally be a proper CC0/open-licensed asset that we can distribute in the repository.

---

# 17. What we reuse from Tomato

Astra should inspect Tomato rather than inventing these systems again.

The specific references are:

| Pineapple need | Tomato reference |
|---|---|
| FPGA target | `hardware/fpga/core/` |
| Build infrastructure | `hardware/fpga/common.mk` |
| Tool wrapper | `hardware/fpga/scripts/env.sh` |
| Board constraints | `hardware/fpga/core/constr/nexys.xdc` |
| Working display pinout | `hardware/fpga/hdmi_test/` |
| 640×480 timing | `hardware/fpga/core/rtl/board/videoout.v` |
| TFP410 output register/ODDR | `hardware/fpga/core/rtl/board/dvi_out.v` |
| Five-button input | `hardware/fpga/core/rtl/board/keypad.v` |

The current Tomato path already sends 12-bit RGB and sync through the JC/JD TFP410 PMOD and generates the forwarded clock using an ODDR; that should be reused essentially unchanged. :chatgpt-content-reference{index="6"}

And the existing common build system already targets `xc7a100tcsg324-1` and programs it using:

```text
openFPGALoader -b nexys_a7_100
```

so Pineapple should inherit that rather than creating another FPGA environment. :chatgpt-content-reference{index="7"}

The one thing **not** to copy wholesale is Tomato's `videoout.v`, because that is a text/tile renderer.

Pineapple needs its own:

```text
gpu_scanout.v
```

that reads a pixel framebuffer.

Reuse the **timing and board interface**, not the text renderer.

---

# 18. Repository architecture

I would tell Astra to build this hierarchy:

```text
pineapple/
│
├── Makefile
├── README.md
│
├── docs/
│   ├── architecture.md
│   ├── shader_isa.md
│   ├── registers.md
│   └── fixed_point.md
│
├── rtl/
│   ├── pineapple_top.v
│   │
│   ├── board/
│   │   ├── clock_reset.v
│   │   ├── keypad.v
│   │   ├── gpu_scanout.v
│   │   └── dvi_out.v
│   │
│   ├── host/
│   │   ├── demo_host.v
│   │   ├── camera_controller.v
│   │   └── sincos_rom.v
│   │
│   ├── gpu/
│   │   ├── pineapple_gpu.v
│   │   ├── pinebus_regs.v
│   │   ├── command_processor.v
│   │   ├── vertex_fetch.v
│   │   ├── shader_core.v
│   │   ├── primitive_assembly.v
│   │   ├── triangle_setup.v
│   │   ├── rasterizer.v
│   │   ├── interpolator.v
│   │   ├── reciprocal.v
│   │   ├── texture_unit.v
│   │   ├── depth_unit.v
│   │   ├── framebuffer.v
│   │   └── perf_counters.v
│   │
│   └── memory/
│       ├── vertex_mem.v
│       ├── index_mem.v
│       ├── texture_mem.v
│       ├── shader_mem.v
│       └── render_target.v
│
├── shaders/
│   ├── basic.vert
│   ├── diffuse.frag
│   ├── normal.frag
│   └── toon.frag
│
├── assets/
│   └── ...
│
├── tools/
│   ├── pinepack.py
│   ├── pineasm.py
│   └── reference_renderer.py
│
├── tb/
│   ├── tb_shader.v
│   ├── tb_triangle_setup.v
│   ├── tb_rasterizer.v
│   ├── tb_depth.v
│   ├── tb_texture.v
│   └── tb_gpu.v
│
└── constr/
    └── nexys.xdc
```

And critically:

**`rtl/gpu/` must contain zero board-specific pin knowledge.**

That discipline worked extremely well in Tomato: its machine core exposes interfaces, while clocks, buttons, display and pins live under the board harness. :chatgpt-content-reference{index="8"}

Do the same thing here.

---

# 19. Verification is part of the GPU

Before Astra writes the full RTL, it should write:

```text
reference_renderer.py
```

That renderer is **not** a pretty conventional floating-point renderer.

It emulates Pineapple's exact rules:

same fixed-point widths, same rounding, same edge equations, same top-left rule, same depth quantization, same texture coordinate precision, same shader ISA.

Then we can render a scene in Python and RTL and compare output CRCs.

That lets us debug statements like:

```text
expected framebuffer CRC = E48A712C
RTL framebuffer CRC      = E48A712C

PASS
```

rather than staring at a broken pineapple and wondering which of fifteen pipeline stages is wrong.

This is mandatory.

---

# 20. Performance counters

The final hardware should expose at least:

```text
frames
cycles/frame

vertices submitted
vertices shaded

triangles submitted
triangles culled
triangles rasterized

fragments generated
fragments depth-killed
fragments shaded

texture requests
shader instructions executed
```

Then later we can ask actual GPU questions:

Why did FPS fall?

Geometry bound?

Fragment bound?

Too much overdraw?

Shader too long?

That's where this starts becoming the learning experience you're after.

---

# 21. The PR sequence I would give Astra

Do **not** ask Astra to implement the entire architecture in one giant PR. I would enforce this order:

1. **PR 1 — Pineapple skeleton.** Create repository/build structure, reuse Tomato's DVI/constraints/toolchain, produce a 640×480 test pattern, reuse keypad, and prove `make fpga` + `make program`.
2. **PR 2 — GPU framebuffer.** Create 320×180 double-buffered render targets, 2× scanout into centered 640×360, clear engine, `PRESENT`, and front/back swapping only at vertical blank.
3. **PR 3 — Golden model + rasterizer.** Create Python bit-accurate reference renderer and RTL edge-function triangle rasterizer. Solid flat triangle must match the reference exactly.
4. **PR 4 — Geometry pipeline.** Implement indexed vertex fetch, programmable Pine shader core, vertex shader, viewport transform, backface culling and triangle setup. Render a joystick/D-pad-rotated cube.
5. **PR 5 — Depth.** Add 16-bit Z interpolation/test/write. Intersecting cubes/triangles must occlude correctly and match the reference renderer.
6. **PR 6 — Perspective interpolation + textures.** Add \(1/w\), perspective-correct UVs, reciprocal path, texture RAM and `TEX2D`. Render a textured cube.
7. **PR 7 — Fragment shader.** Use the common Pine shader core as a programmable fragment stage. Shader programs must be replaceable independently of GPU RTL.
8. **PR 8 — Asset toolchain.** `pinepack.py`, indexed mesh format, texture packer, Pine shader assembler, and initial pineapple asset.
9. **PR 9 — Pineapple showcase.** Detailed textured pineapple, smooth normals, directional/ambient light, button-controlled orbit/zoom, runtime shader-mode cycling, stable double-buffered animation.
10. **PR 10 — Profiling and optimization.** Add performance counters, measure bottlenecks, then pipeline/parallelize only what measurements justify. Target a showcase frame rate around 30 FPS rather than prematurely building multiple rasterizers.

Every PR must pass Icarus tests.

Every hardware-facing PR should still synthesize.

No PR is allowed to bury basic correctness under a giant new subsystem.

---

# 22. The definition of P1 complete

I'm setting a higher bar now than simply “pineapple appears.”

Pineapple GPU P1 is finished when you can power the Nexys A7 and demonstrate:

```text
                  Pineapple GPU

       custom programmable vertex processor
                       │
            hardware rasterizer
                       │
         perspective interpolation
                       │
             texture sampling
                       │
       programmable fragment processor
                       │
                  Z-buffer
                       │
             double framebuffer
                       │
                     HDMI
```

A textured, lit 3D pineapple appears.

You press:

**left/right** — orbit horizontally.

**up/down** — orbit vertically.

**center + up/down** — zoom.

**center** — change shader.

And at least one shader change must visibly alter the image **without changing the graphics pipeline RTL**.

Then load another asset through the same tooling and demonstrate that the architecture wasn't hardcoded for a pineapple.

At that point I would be entirely comfortable with the sentence:

> **“I built a programmable 3D GPU from scratch on an FPGA.”**

Not “graphics demo.”

Not “FPGA renderer.”

A small GPU.

And after that is when the project gets genuinely fun, because we can start adding the things real GPU architects spend their careers worrying about: multiple shader lanes, multithreading, texture caches, bilinear filtering, mipmaps, tiled rendering, memory bandwidth, early-Z hierarchies, blending, branching/divergence, eventually external VRAM—and perhaps much later replacing FPGA subsystems with physical chips.

But **none of those are allowed to prevent Pineapple P1 from existing first.**

That is the specification I would hand Astra.