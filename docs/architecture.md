# Architecture contract

P1 is an accelerator: PineBus command submission → indexed vertex fetch →
programmable vertex shader → primitive assembly/cull/setup → top-left edge
rasterizer → perspective interpolation → early Z → programmable fragment shader
and texture unit → RGB444 back buffer → vblank presentation → board scanout.
No CPU, object-specific RTL, or DDR prerequisite.

The two programmable stages share a Pine core design: 16 four-component
registers, signed 18-bit components with 12 fractional bits, straight-line
32-bit instructions. Instruction encoding, rounding, saturation and intermediate
widths must be specified with the golden model before implementation; the brief's
assembly is illustrative, not an existing binary ABI.

PineBus has 16-bit addresses, 32-bit data, read/write/valid/ready. The demo host
may only use this boundary for GPU control. It owns camera matrices and button
interpretation. rtl/gpu must never know board pins or asset identity.

Memory target: two 320×180 RGB444 color buffers, one 16-bit Z buffer, a 256×256
RGB444 texture, packed vertices, 16-bit indices, shader and uniform memories.
Scanout doubles to 640×360 centered between 60-line black bars. Presentation
must handshake across clock domains and swap only at vertical blank; reset must
establish deterministic buffer ownership before display or rendering.

BRAM feasibility must be checked using physical primitive packing, not only bit
counts. Color+depth+texture payload alone is 3,090,432 bits (about 84 RAMB36 at
ideal packing); port-width/depth rounding and mesh storage consume additional
blocks. The device limit is 135 RAMB36. Confirm the complete memory layout before
committing capacity promises. Thirty FPS is a measured target, not a guarantee.

M1 currently runs all board logic at 25 MHz. The later GPU clock/reset domain
and presentation CDC belong to M2. No near-plane clipping is claimed in M1;
initial geometry work will explicitly constrain/reject unsupported near crossings.
