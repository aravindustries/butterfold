#!/usr/bin/env python3
"""
dump_vectors.py — print the exact input/output values used by the end-to-end
functional checks, so the numbers are reproducible and quotable in the report.

All vectors come from the Python golden (golden/vectors.py); because both the
register-file and SRAM tops are bit-exact to the golden, these ARE the RTL I/O
values for both. Run (from repo root, after golden/vectors.py has emitted):
  python3 scripts/dump_vectors.py
"""
from __future__ import annotations
import pathlib
ROOT = pathlib.Path(__file__).parent.parent
VEC  = ROOT / "tests" / "vectors"


def _bytes(name):
    out = []
    for ln in (VEC / name).read_text().splitlines():
        ln = ln.split("//")[0].strip()
        for t in ln.split():
            if t and not t.lower().startswith("0x"):
                out.append(int(t, 16))
    return out


def _s8(b):
    return b - 256 if b >= 128 else b


def complex_table(name, title):
    b = _bytes(name)
    print(f"\n{title}  ({len(b)} bytes = {len(b)//2} complex Q1.7 samples)")
    print("  idx |  I hex  Q hex |  I dec  Q dec")
    print("  ----+---------------+--------------")
    for k in range(len(b) // 2):
        i, q = b[2*k], b[2*k+1]
        print(f"  {k:>3} |   {i:02x}     {q:02x}   |  {_s8(i):>4}   {_s8(q):>4}")


def hexgrid(name, title, per=16):
    b = _bytes(name)
    print(f"\n{title}  ({len(b)} bytes, interleaved I,Q,I,Q,...)")
    for off in range(0, len(b), per):
        row = " ".join(f"{v:02x}" for v in b[off:off+per])
        print(f"  {off:03d}: {row}")


if __name__ == "__main__":
    print("=" * 66)
    print("ButterFold end-to-end test vectors (golden == RTL, both tops)")
    print("=" * 66)
    complex_table("top_in.hex",  "TX INPUT  (din payload after cmd 0x03)")
    hexgrid("top_gold.hex",      "TX OUTPUT (dout, 137 complex incl. CP=9)")
    complex_table("rx_gold.hex", "RX OUTPUT (dout payload for cmd 0x04)")
