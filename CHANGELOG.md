# Changelog

All notable changes to Pineapple GPU P1 are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [0.3.0] - 2026-09-26

Second asset on silicon with unchanged GPU RTL (`rtl/gpu/` untouched).

### Added
- `rtl/cube_top.v`: wrapper instantiating `pineapple_top` with the cube
  asset. `pineapple_top` takes `ASSET`/`INDEX_COUNT` parameters through to
  the GPU and demo host; `demo_host` takes plain `INDEX_COUNT` (3216 default)
  instead of including a per-asset header.
- Makefile `fpga-cube`, `program-cube`, `synth-cube` targets (`TOP=cube_top`,
  same XDC/flow, shared chipdb).

### Verified
- Cube build: `gpu_clk` 60.88 MHz post-route PASS at 50 MHz.
- `make program-cube`: PASS, DONE set. HDMI capture
  ([photo](docs/validation/hardware-cube.jpg)) shows the diffuse-shaded
  front-face cube, matching the sim/reference frame for mode 0 yaw 0
  (CRC 641A94BF, 0 mismatches) — the yaw-0 camera looks straight at a face,
  so it fills the frame, unlike the rotated yaw-5 views.
- Board reprogrammed with the pineapple build afterwards and confirmed on
  screen; pineapple rebuild also re-timed clean (`gpu_clk` 55.43 MHz).
- Measured frame loop at 50 MHz (sim `frame_cycles`, incl. host overhead):
  cube ≈1.36M cycles ≈ 37 fps, pineapple ≈2.0M cycles ≈ 25 fps; hardware
  PRESENT can add up to one 16.7 ms vblank wait on top.

## [0.2.0] - 2026-09-26

Full P1 GPU: programmable pipeline, demo host, and on-silicon pineapple.
Milestones 2-10 implemented back to back against the frozen brief.

### Added
- `rtl/gpu/pineapple_gpu.v`: board-independent PineBus command processor
  (CLEAR/DRAW_INDEXED/PRESENT), indexed vertex fetch, viewport/cull/setup,
  perspective interpolation, early-Z, double-buffered 320x180 RGB444 output
  with vblank-swap presentation, and frame/cycle/triangle/fragment counters.
- `rtl/gpu/shader_core.v`: shared programmable Pine core (16x4 S18Q12 regs,
  17 opcodes incl. TEX2D, 64-instruction programs, watchdog on missing END).
- `rtl/gpu/rasterizer.v`: pixel-center top-left edge walker with viewport
  clipping and backpressure-stable output.
- `rtl/gpu/reciprocal.v`: 32-cycle restoring divider for perspective divide.
- `rtl/memory/render_target.v`: dual-bank framebuffer with cross-clock
  vblank-only swap; `rtl/memory/texture_mem.v`: 48-bit 4-texel texture ROM.
- `rtl/host/demo_host.v`: per-frame PineBus program (uniforms, shaders,
  clear, draw, present); `rtl/host/camera_controller.v`: D-pad orbit/pitch,
  center-tap shader modes, center+up/down zoom chord.
- 50 MHz `gpu_clk` domain (`rtl/board/clock_reset.v`); DRAW validation uses a
  serial mod-3 check (state 42) after `%` was found to infer a 32 ns divider.
- `tb/` now covers camera, framebuffer CDC, reciprocal, DRAW-error, 96
  randomized shader programs vs reference, and 24 rasterizer triangles under
  randomized stalls. `make test` runs all 8 fast suites; new `make verify`
  checks every RTL frame pixel-for-pixel against the integer reference.
- `docs/validation/hardware-pineapple.jpg`: HDMI capture of the live render.

### Verified
- `make test`: 8/8 PASS. `make verify`: cube modes 0-5 and 1072-triangle
  pineapple all match the reference with zero mismatched pixels
  (e.g. pineapple CRC 63134D29 both sides).
- `make fpga`: PASS at 50 MHz post-route (`gpu_clk` 50.36 MHz, `pix_clk`
  151 MHz; 22% LUT, 42% RAMB18, 41% RAMB36). `-nodsp` works around a
  nextpnr DSP-carry routing limitation on this install.
- `make program`: PASS, DONE flag set. HDMI capture shows the lit textured
  pineapple on the dark-blue clear color, matching the reference pose.
  Remaining: physical D-pad checks (orbit/zoom/shader-mode) and a second
  asset on screen; the cube is proven in simulation with unchanged RTL.

## [0.1.0] - 2026-09-26

Milestone 1 board bring-up. There is no GPU pipeline or framebuffer yet.
This is the initial import; the repo had no prior git history, so everything
below counts as the "changes just made".

### Added
- Board harness `rtl/pineapple_top.v`: 640x480 test pattern only.
  Default red/green/blue/white bars; up/down/left select solid red/green/blue,
  right selects a gradient, center restores bars. `CPU_RESETN` resets the design.
- `rtl/board/clock_reset.v`: 100 MHz to 25 MHz pixel clock, reset asserted
  asynchronously and released synchronously with the pixel clock running.
- `rtl/board/gpu_scanout.v`: 800x525 timing, H/V sync, data-enable and
  `vblank_start`. Timing boundary only; framebuffer fetch arrives in M2.
- `rtl/board/dvi_out.v`: 12-bit TFP410 DVI output with registered payload and
  ODDR-forwarded pixel clock, reused from Tomato.
- `rtl/board/keypad.v`: five-button D-pad with debounce, center no-repeat and
  arrow autorepeat, plus debounced level output. Top uses `SAMPLE=15`
  (1.31 ms at 25 MHz).
- `constr/nexys.xdc`: Nexys A7-100T pins for clock, reset, five buttons and
  JC/JD video only.
- `tb/tb_board.v`: full-frame check over two 800x525 frames (active RGB,
  blanking, sync, coordinate wrap, vblank, reset behavior).
- `tb/tb_keypad.v`: bounce, no-repeat, autorepeat, chord and release checks.
- `Makefile`: `make test` (Icarus), `make fpga` / `make program` via the
  existing Tomato `hardware/fpga/common.mk` flow (`TOMATO_FPGA` override).
  `make program` loads volatile SRAM only, no flash image.
- Docs: frozen `docs/p1-specification.md`, `docs/architecture.md` contract,
  `docs/milestones.md` ten-stage order, `docs/provenance.md` Tomato reuse log,
  `docs/validation.md` plus `docs/validation/icarus.log` and `fpga-summary.log`.
- GPU toolchain scaffolding (ahead of RTL): `tools/pineasm.py` Pine assembler,
  `tools/pinepack.py` OBJ/texture packer, `tools/reference_renderer.py`
  integer-only golden model, `tools/generate_assets.py` procedural asset builder.
- Shaders: `shaders/basic.vert` plus `unlit`, `diffuse`, `toon`, `normal`,
  `depth`, `uv` fragment shaders (source only, no hardware stage yet).
- Assets: procedural `assets/pineapple.obj`, `pineapple.ppm`, `cube.obj`,
  `assets/cube/`, `assets/packed/` BRAM images, `camera.mem`, `program.mem`.

### Verified
- `make test`: PASS (Icarus, 2026-09-25).
- `make fpga`: PASS for `xc7a100tcsg324-1` (Yosys + nextpnr-xilinx + Project X-Ray).
- `make program`: bitstream rebuild passed; programming failed with
  `Error: no device found` (no board attached). No monitor output claimed yet.
  Remaining M1 gate: physical programming and on-screen confirmation of bars
  plus all five bring-up controls. See `docs/validation.md`.

### Changed
- License simplified to a single MIT `LICENSE` (personal project; copy freely
  with attribution). Removed `LICENSE-APACHE` and `assets/LICENSE`; all RTL
  headers, `tools/generate_assets.py` and `docs/provenance.md` now reference
  MIT-only. Added this `CHANGELOG.md`.
