# Pineapple GPU P1

<p align="center">
  <a href="docs/validation.md"><img alt="Status: silicon proven" src="https://img.shields.io/badge/status-silicon_proven-2ea043"></a>
  <a href="docs/architecture.md"><img alt="Target: Nexys A7-100T" src="https://img.shields.io/badge/target-Nexys_A7--100T-011F5B"></a>
  <a href="docs/shader_upload.md"><img alt="Shaders: 17-op programmable" src="https://img.shields.io/badge/shaders-17--op_programmable-DC2626"></a>
  <a href="#build-and-run"><img alt="Flow: FOSS Yosys/nextpnr" src="https://img.shields.io/badge/flow-FOSS_Yosys_nextpnr-6f42c1"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue"></a>
</p>

A standalone programmable 3D GPU for the Nexys A7-100T. The frozen
[P1 brief](docs/p1-specification.md) defines the target; the pineapple is an asset,
not special-purpose rendering logic.

<h3 align="center">Actual HDMI Render Output captured in <a href="https://open-vsx.org/extension/tmarhguy/frameport">Frameport v0.2.4</a></h3>

<div align="center">
  <img src="media/videos/pineapple-demo.gif" width="50%" alt="Pineapple demo on the Nexys A7-100T">
</div>

**Current implementation: full P1 GPU (v0.3.0).** Programmable vertex/fragment
shaders, rasterizer, depth, texture, double-buffered presentation and demo host
are implemented and verified — see [validation](docs/validation.md). Both the
pineapple (`make program`) and the cube (`make program-cube`, unchanged GPU RTL)
have rendered on silicon. The bring-up test pattern is preserved as
`rtl/board/bringup_top.v` for diagnostics.

## Architecture

```mermaid
flowchart TD
    subgraph NEXYS["NEXYS A7-100T · xc7a100tcsg324-1"]
        BTNS["Five buttons<br/>N17 C · M18 U · P18 D · P17 L · M17 R"]
        subgraph GPUCLK["gpu_clk · 50 MHz"]
            HOST["Demo / Host Controller<br/>rtl/host"]
            CMD["COMMAND PROCESSOR<br/>CLEAR · DRAW_INDEXED · PRESENT"]
            MEMV[("Vertex RAM · Index RAM")]
            VCORE{{"PROGRAMMABLE VERTEX CORE"}}
            PRIM["PRIMITIVE / CLIP / CULL"]
            SETUP["TRIANGLE SETUP"]
            RAST["RASTERIZER"]
            INTERP["INTERPOLATOR"]
            TEX[("Texture RAM")]
            FCORE{{"PROGRAMMABLE FRAGMENT CORE"}}
            DEPTH{"DEPTH TEST"}
            FB[("Double Framebuffer")]
        end
        subgraph PIXCLK["pix_clk · 25 MHz"]
            SCAN["SCANOUT<br/>640x360 centered in 640x480"]
            DVI["Tomato DVI output<br/>TFP410 · JC / JD"]
        end
    end
    MON[("MONITOR")]
    BTNS --> HOST
    HOST -- "PineBus commands" --> CMD
    CMD -- "DRAW_INDEXED / CLEAR" --> MEMV
    MEMV --> VCORE
    VCORE --> PRIM
    PRIM --> SETUP
    SETUP --> RAST
    RAST -- "fragments" --> INTERP
    INTERP --> FCORE
    TEX --> FCORE
    FCORE --> DEPTH
    DEPTH --> FB
    FB -- "vblank swap · CDC" --> SCAN
    SCAN --> DVI
    DVI --> MON
    classDef prog fill:#b71c1c,color:#fff,stroke:#7f0000;
    class VCORE,FCORE prog;
```

Five D-pad buttons drive a demo host (`rtl/host/`) that submits
`CLEAR` / `DRAW_INDEXED` / `PRESENT` over PineBus. The GPU (`rtl/gpu/`)
fetches indexed vertices, runs them through the programmable vertex core,
culls, sets up triangles, rasterizes with a top-left edge walker,
interpolates perspective-correct attributes, runs the programmable fragment
core against texture RAM, depth-tests, and presents a double-buffered
320×180 RGB444 frame scanned out as 640×360 centered in 640×480 DVI.
Every node maps to exact files, clocks, pins and BRAM budgets in the
[NEXYS A7-100T contract](docs/architecture.md); PineBus registers,
the 17-op shader ISA and the fixed-point rules are specified in
[registers](docs/registers.md), [shader ISA](docs/shader_isa.md) and
[fixed point](docs/fixed_point.md).

Before the GPU first rendered, the DVI path was validated with a
red/green/blue/white band test pattern:

<div align="center">
  <img src="media/screenshots/bringup-test-pattern.png" width="50%" alt="DVI bring-up test pattern">
  <br>
  <em>Bring-up test pattern (<code>rtl/board/bringup_top.v</code>)</em>
</div>

## Build and run

```
make test     # fast unit suites (Icarus)
make verify   # pixel-exact RTL-vs-reference frames (minutes)
make fpga
make program
```

Icarus Verilog is required for tests. FPGA targets include the existing Tomato
flow at `../tomato/hardware/fpga/common.mk`; override `TOMATO_FPGA=/absolute/path`
if needed. Its `scripts/env.sh` selects the installed Yosys, nextpnr-xilinx,
Project X-Ray and openFPGALoader environment. Target: `xc7a100tcsg324-1`.
No Vivado or CPU firmware is required. `make program` loads volatile FPGA SRAM;
it does not install a power-on flash image.

Connect the existing 12-bit TFP410 PMOD across JC/JD. Output is 640×480 at
25 MHz / (800×525) = 59.524 Hz. The GPU renders 320×180 centered between
60-line black bars. D-pad orbits/pitches, center+up/down zooms, center taps
cycle the six shader modes. CPU_RESETN resets the design.

## Layout and next steps

`rtl/board/` contains clock/reset, keypad, timing and DVI output.
`rtl/gpu/`, `rtl/host/` and `rtl/memory/` hold the graphics processor, demo
host and framebuffer/texture memories. `rtl/cube_top.v` re-targets the same
GPU at the cube asset (`make fpga-cube` / `make program-cube`). `tb/` checks
units, full frames and button behavior. Remaining: physical D-pad confirmation.
Measured frame loop at 50 MHz: ≈37 fps cube, ≈25 fps pineapple.

See [milestones](docs/milestones.md) and [reuse provenance](docs/provenance.md).
Every milestone requires Icarus checks;
hardware changes also require synthesis. Bit-accurate Python reference behavior
must precede the rasterizer and shader RTL. The ten-stage implementation order
in the brief is preserved.

## Changelog and license

See [CHANGELOG.md](CHANGELOG.md). MIT only, see [LICENSE](LICENSE) — personal
project, you may copy with attribution.
