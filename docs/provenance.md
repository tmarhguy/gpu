# Tomato reuse

Source repository: https://github.com/tmarhguy/tomato
Inspected checkout HEAD: 4a7f8598944391f59e3c00cfdf796292679e2faa.
Files were copied from the local checkout; local modifications, if any, are not
represented by that commit identifier.

- `hardware/fpga/core/rtl/board/dvi_out.v`: payload registers and ODDR, unchanged
  apart from simulation macro and timescale.
- `hardware/fpga/core/rtl/board/keypad.v`: retained keycode/event/repeat contract;
  added debounced level output, synchronizer attribute and reset of edge history.
  The bring-up top used SAMPLE=15 (1.31 ms at 25 MHz); the GPU top runs the
  keypad on the 50 MHz GPU clock with SAMPLE=16 for the same debounce interval.
- `hardware/fpga/core/constr/nexys.xdc`: only clock/reset, five buttons and JC/JD
  video pins retained. Unused peripheral constraints excluded.
- `hardware/fpga/hdmi_test/rtl/main.sv`: timing and BUFG divide-by-four reference.
  New reset logic keeps the pixel clock running and synchronizes reset release.
- `hardware/fpga/common.mk` and `scripts/env.sh`: reused in place, not copied.
- `hardware/fpga/core/rtl/board/videoout.v`: timing reference only; no text, tile,
  wallpaper or font subsystem copied.

Original source headers retained. This project is MIT-only (see root LICENSE);
Tomato reuse above is by the same author and is released here under MIT.
The pasted brief's chat citation tokens are historical placeholders, not verified
external references; this document records the actual narrow source inspection.
