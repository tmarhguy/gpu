# Ordered implementation gates

Status as of v0.2.0 (2026-09-26): stages 1-8 and 10 implemented, simulated,
synthesized, and timed shut at 50 MHz; stage 9 demonstrated on silicon for the
pineapple showcase. See validation.md for what has actually been verified.

1. Board skeleton, Tomato toolchain/DVI, test pattern, keypad, simulation,
   bitstream and physical program/display verification. Done; the bring-up top
   is preserved as `rtl/board/bringup_top.v`.
2. 320×180 double framebuffer, clear command, PineBus, vblank PRESENT handshake.
   Done (`render_target.v`, `tb_framebuffer.v`).
3. Bit-accurate Python golden renderer, triangle setup and top-left rasterizer;
   exact pixel/CRC match for shared edges and stalls. Done
   (`reference_renderer.py`, `tb_rasterizer.v`, `make verify`).
4. Indexed geometry, common programmable shader core, vertex stage, viewport,
   culling and D-pad cube. Done (`pineapple_gpu.v`, `shader_core.v`, cube CRC
   match in all modes).
5. Z16 interpolation, early depth compare/write; intersecting geometry parity.
   Done (early-Z kill path, `killed` counter, depth-mode shader).
6. Reciprocal, perspective UV, texture RAM/TEX2D; textured cube parity. Done
   (`reciprocal.v`, `texture_mem.v`, perspective divide per fragment).
7. Programmable fragment stage, independently replaceable shader programs.
   Done (six modes: unlit/diffuse/toon/normal/depth/uv, center-tap cycling).
8. OBJ/texture packer, shader assembler, licensed pineapple asset. Done
   (`pinepack.py`, `pineasm.py`, MIT procedural asset).
9. Lit pineapple, orbit/zoom, shader modes, second asset with unchanged GPU RTL.
   Done on silicon for both assets: pineapple (`TOP=pineapple_top`) and cube
   (`TOP=cube_top`, `rtl/gpu/` untouched) with HDMI photos in validation.md.
   Remaining: physical D-pad confirmation.
10. Counters, measured optimization and frame-rate reporting. Done
    (`frames/cycles/vertices/triangles/fragments/killed/shaded/instructions`
    registers; serial mod-3 DRAW validation after the `%` divider missed timing).

Each stage should be a separately reviewable PR with passing Icarus tests and
synthesis for hardware changes. No PR has been opened by this initial local work.
P1 is complete after the physical D-pad pass.
