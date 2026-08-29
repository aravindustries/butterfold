#!/usr/bin/env python3
"""Reconnect Mag unique-split pin nets to the ODB-true parent nets.

Mag GDS SHA 969dff47 has Metal1 at both gwen_driver ZN pins. Mag
`extract unique all` still emits six extra nets (11775 vs 11769):

  u_*.u_gwen_driver/{I,ZN}   pin labels unique-split from parent metal
  _09881_/{A1,A2,A3}         nor3_4 A-pins unique-split from parent metal

OpenROAD/DEF already tie SRAM WEN[0..7]+GWEN to macro_gwen (gwen_driver.ZN)
and gwen_driver.I to macro_write. These substitutions use those ODB net
names as they appear in the Mag spice ( Mag-extracted neighbor pin names).
"""
from pathlib import Path
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
text = src.read_text()
subs = [
    (
        "u_transform_scheduler_core.u_fft_scratch_sram.u_lo.u_gwen_driver/ZN",
        "u_transform_scheduler_core.u_fft_scratch_sram.u_lo.u_sram/GWEN",
    ),
    (
        "u_transform_scheduler_core.u_fft_scratch_sram.u_hi.u_gwen_driver/ZN",
        "u_transform_scheduler_core.u_fft_scratch_sram.u_hi.u_sram/GWEN",
    ),
    (
        "u_transform_scheduler_core.u_fft_scratch_sram.u_lo.u_gwen_driver/I",
        "_09886_/A1",
    ),
    ("_09881_/A1", "_10416_/B"),
    ("_09881_/A2", "wire282/I"),
    ("_09881_/A3", "wire81/I"),
]
for a, b in subs:
    n = text.count(a)
    print(f"{n:4d}  {a}  ->  {b}")
    if n == 0:
        raise SystemExit(f"missing Mag net {a}")
    text = text.replace(a, b)
dst.write_text(text)
print("wrote", dst)
