# Runtime shader upload

New Pine shaders run on the FPGA with no resynthesis. `tools/pineload.py`
assembles a `.pine` source and sends it over USB-UART (115200 8N1, `RsRx`
pin C4); `rtl/gpu/shader_loader.v` stages the payload and commits it to
instruction RAM atomically between frames.

## Wire frame

| field | bytes | notes |
|---|---|---|
| magic | `50 49 4E 45` (`PINE`) | exact match, driven from true-idle |
| base | LE16 | program-RAM word address, 0..511 |
| count | LE16 | payload words, 1..512, `base+count <= 512` |
| payload | 4×count | words little-endian |
| checksum | 1 | sum of every post-magic byte mod 256 |

The loader validates range before staging anything and checks the checksum
before committing: a bad frame leaves program RAM untouched and sticks the
`error` flag until the next good commit or reset. Any inter-byte gap past
~335 ms (24 M cycles at 50 MHz) aborts the frame. Staging runs while the GPU
keeps rendering the old program; only the `count`-cycle commit holds the
demo host, and only across a GPU-idle boundary, so no torn frame or shader
fault can wedge the pipeline. Successful commits increment a counter
readable on PineBus at `0x4C`.

## Slots

`assets/program.mem` lays out seven 64-word programs; the eighth slot is free:

| base | content | selected by |
|---|---|---|
| 0 | `basic.vert` (vertex) | fixed `vs_base` |
| 64 | `diffuse.frag` | D-pad mode 0 |
| 128 | `normal.frag` | mode 1 |
| 192 | `toon.frag` | mode 2 |
| 256 | `unlit.frag` | mode 3 |
| 320 | `uv.frag` | mode 4 |
| 384 | `depth.frag` | mode 5 |
| 448 | free | `--base 448` |

`demo_host` rewrites `fs_base` from the D-pad mode every frame, so upload to
the slot of the mode currently on screen. `pineload.py --mode N` computes
`(N+1)*64` for you; `--base W` takes a raw address instead.

## Usage

```
pip install pyserial                       # once
python3 tools/pineload.py shaders/mine.frag --mode 2
```

Select D-pad mode 2 first; the new fragment program takes effect on the next
frame. The upload survives mode switches only in its own slot — switching
away and back keeps it, reprogramming the bitstream restores the baked image.

## Limits

Straight-line ISA only (no branches; 64 instructions, 16 vec4 registers),
and the fixed vertex/fragment register ABI still applies. A serial port is
write-only: the screen is the acknowledgement.
