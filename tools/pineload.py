#!/usr/bin/env python3
"""Upload a Pine shader to the FPGA over USB-UART, no resynthesis needed.

Assembles a .pine source with pineasm, wraps it in a PINE frame
(magic, LE16 base/count, LE words, checksum byte), and sends it at
115200 8N1. The on-chip loader stages the payload, then commits it to
instruction RAM atomically between frames.

Pick the destination with --mode N (fragment slot (N+1)*64, matching the
D-pad shader mode) or --base W (raw word address). Select the D-pad mode
on the board first, then upload to that mode's slot.
"""
import argparse
import glob
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pineasm import assemble

MAGIC = b"PINE"
BAUD = 115200


def build_frame(words, base):
    if not 0 <= base <= 511:
        raise ValueError("base out of range 0..511")
    if not 1 <= len(words) <= 512:
        raise ValueError("word count out of range 1..512")
    if base + len(words) > 512:
        raise ValueError(f"base {base} + {len(words)} words overflows 512-word program RAM")
    body = base.to_bytes(2, "little") + len(words).to_bytes(2, "little")
    for w in words:
        body += (w & 0xFFFFFFFF).to_bytes(4, "little")
    return MAGIC + body + bytes([sum(body) & 0xFF])


def find_port():
    for pat in ("/dev/cu.usbserial-*", "/dev/ttyUSB*", "/dev/tty.usbserial-*"):
        hits = sorted(glob.glob(pat))
        if hits:
            return hits[0]
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("source", help=".pine shader source")
    ap.add_argument("--mode", type=int, choices=range(6),
                    help="D-pad shader mode 0..5: uploads to that mode's fragment slot")
    ap.add_argument("--base", type=int, default=64,
                    help="raw program-RAM word address (default 64, mode 0 slot)")
    ap.add_argument("--port", help="serial port (default: first usbserial device)")
    ap.add_argument("--baud", type=int, default=BAUD)
    a = ap.parse_args()
    base = (a.mode + 1) * 64 if a.mode is not None else a.base
    try:
        words = assemble(Path(a.source).read_text())
    except ValueError as e:
        print(f"assemble error: {e}", file=sys.stderr)
        return 1
    try:
        frame = build_frame(words, base)
    except ValueError as e:
        print(f"frame error: {e}", file=sys.stderr)
        return 1
    port = a.port or find_port()
    if port is None:
        print("no USB serial port found; pass --port (pip install pyserial for sending)",
              file=sys.stderr)
        return 1
    try:
        import serial
    except ImportError:
        print("pyserial not installed; run: pip install pyserial", file=sys.stderr)
        return 1
    with serial.Serial(port, a.baud, timeout=2) as s:
        s.write(frame)
        s.flush()
    slot = f"mode {a.mode} slot" if a.mode is not None else "raw base"
    print(f"sent {len(words)} words ({len(frame)} bytes) to {slot} {base} via {port}")
    print("The new program takes effect on the next frame; no resynthesis needed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
