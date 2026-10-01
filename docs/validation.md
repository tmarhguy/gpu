# P1 validation

## 2026-09-26 — full GPU (v0.2.0)

Executed locally using Icarus and the installed Tomato toolchain
(`xc7a100tcsg324-1`, 50 MHz GPU target).

- `make test`: PASS — 8 suites: board frames, keypad, camera control,
  framebuffer CDC/vblank swap, reciprocal divider, DRAW-error path,
  96 randomized shader programs vs the integer reference, 24 rasterizer
  triangles under randomized backpressure.
- `make verify`: PASS — every RTL frame matches the integer golden model
  with zero mismatched pixels out of 57,600: cube shader modes 0-5
  (yaw 5) plus the 1072-triangle pineapple showcase
  (reference CRC = RTL CRC = 63134D29).
- `make fpga`: PASS. Post-route timing at 50 MHz: `gpu_clk` 50.36 MHz,
  `pix_clk` 151.10 MHz (pre-route estimate was 40.03 MHz; only the
  post-route number gates). Utilization: 22% LUT, 42% RAMB18, 41% RAMB36.
  Synthesis uses `-nodsp`: nextpnr-xilinx on this install cannot reliably
  route the mapped DSP carry ports, so multiplies stay in fabric.
  A `%3` DRAW check that inferred a ~32 ns divider was replaced with a
  serial mod-3 validator (state 42, 14 cycles per DRAW, exhaustive proof
  over all 16384 counts); DRAW-error behavior is covered by `tb_drawerr.v`.
- `make program`: PASS — SRAM load 100%, DONE flag set.
- Hardware: HDMI capture ([photo](hardware-pineapple.jpg)) shows the lit,
  textured pineapple on the dark-blue clear color, matching the reference
  pose and lighting. The USB capture crops/scales the 640x360 image area;
  geometry, texture, and shading match the golden frame exactly.

Remaining: physical D-pad checks (orbit/pitch/zoom/shader-mode cycling).
The second-asset check is closed in v0.3.0 below.

## 2026-09-26 — second asset on silicon (v0.3.0)

`rtl/gpu/` untouched; asset selection is parameters only
(`cube_top.v` into `pineapple_top` into GPU/host, `TOP=cube_top` build).

- Cube build `make fpga-cube`: PASS at 50 MHz post-route (`gpu_clk`
  60.88 MHz, `pix_clk` 120.32 MHz).
- `make program-cube`: PASS, DONE set. HDMI capture
  ([photo](hardware-cube.jpg)) shows the diffuse-shaded cube face on the
  dark-blue clear color, matching the mode-0 yaw-0 sim/reference frame
  (CRC 641A94BF, 0 mismatches).
- Pineapple build rebuilt after the parameter plumbing and re-timed clean
  (`gpu_clk` 55.43 MHz); board reprogrammed and the pineapple confirmed on
  screen again.
- Measured frame loop at 50 MHz (sim `frame_cycles`, incl. host overhead):
  cube ≈1.36M cycles ≈ 37 fps face-on (reproduced 2026-10-01 at yaw 0;
  yaw-5 diffuse runs 1.84M ≈ 27 fps — see the per-mode table in
  [architecture](architecture.md)), pineapple ≈2.0M cycles ≈ 25 fps; hardware
  PRESENT can add up to one 16.7 ms vblank wait on top.

## 2026-09-25 — milestone 1 bring-up (v0.1.0)

- `make test`: PASS. Two consecutive 800×525 frames; every active RGB pixel,
  blanking pixel, H/V sync sample, coordinate wrap and vblank pulse checked.
  Reset assertion and clock-running reset behavior checked. Keypad bounce,
  center no-repeat, arrow autorepeat, chord levels and release checked.
- `make fpga`: PASS. Yosys synthesis, nextpnr placement/routing and Project X-Ray
  bit generation completed for xc7a100tcsg324-1. The local artifact is
  `build/pineapple_top.bit` (ignored by Git).
- `make program`: bitstream rebuild passed; programming FAILED because
  openFPGALoader reported `Error: no device found`. No board programming or
  monitor output is claimed. Connect/power the Nexys A7 USB-JTAG port and rerun
  `make program`, then verify color bars and all five bring-up controls.
- `git diff --check`: PASS (new files were also inspected during creation).

Logs: [Icarus](icarus.log), [FPGA/program summary](fpga-summary.log).

The flow warns that nextpnr ignores `[current_design]` configuration properties
in the reused XDC. Project X-Ray also falls back to its slower Python FASM parser.
Neither prevented bitstream generation. Timing is nextpnr's internal analysis;
TFP410 board-level setup/hold and visible output still require physical validation.

## Sim re-verification (2026-10-01, Icarus 13.0, Apple Silicon)

- `make test`: PASS — all 9 binaries (board, keypad, camera, framebuffer,
  reciprocal, drawerr, 96-program shader, rasterizer, uart).
- `make verify`: PASS — pineapple showcase CRC `63134D29` (0 mismatches,
  1,998,853 cycles), cube modes 0-5 all CRC-matched with 0 mismatches.

## Hardware session A1/A2 — pending (fill in at the bench)

Builds: `make program` (pineapple), `make program-cube` (cube).
Photos land beside `hardware-pineapple.jpg` / `hardware-cube.jpg`.

### A1 — controls and modes

| # | Build | Input | Expected | Photo | Result |
|---|---|---|---|---|---|
| 1 | pineapple | power-on boot | lit textured pineapple on `0x013` | | |
| 2 | pineapple | RIGHT x3 | yaw steps, matches sim poses | | |
| 3 | pineapple | UP x2 | pitch steps, matches sim poses | | |
| 4 | pineapple | CENTER+UP / CENTER+DOWN | zoom in / out | | |
| 5 | pineapple | CENTER tap modes 0-5 | 0 diffuse, 1 normal, 2 toon, 3 unlit, 4 uv, 5 depth | | |
| 6 | cube | boot + RIGHT x2 + modes 0,1 | same behavior, cube asset | | |

Any photo diverging from the sim-predicted frame is a P1 defect: record the
mode/yaw and the reference CRC here.

### A2 — live shader upload

| # | Step | Expected | Result |
|---|---|---|---|
| 1 | mode 2 selected, `python3 tools/pineload.py shaders/flat.frag --mode 2` | flat-shaded frame, no resynthesis/reboot | |
| 2 | CENTER-tap away and back to mode 2 | upload persists in its slot | |
| 3 | `0x4C` PROG_LOADS before/after | +1, `error` flag clear | |
