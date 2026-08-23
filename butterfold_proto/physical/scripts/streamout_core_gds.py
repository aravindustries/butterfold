#!/usr/bin/env python3
"""Stream the 24-pin core DEF to GDS using KLayout + GF180 GDS masters."""
from __future__ import annotations
import hashlib
import os
from pathlib import Path
import klayout.db as pya

PHYS = Path(__file__).resolve().parent.parent
PDK = Path(os.environ.get("PDKPATH", "/foss/pdks/gf180mcuD"))
ROUTE_DEF = Path(os.environ.get("ROUTE_DEF", PHYS / "results/24pin_eco/hold_eco/routed.def"))
OUTPUT_GDS = Path(os.environ.get("OUTPUT_GDS", PHYS / "results/24pin_eco/gds/butterfold_top.gds"))
TOP = "butterfold_top"
SC = PDK / "libs.ref/gf180mcu_fd_sc_mcu9t5v0"
SRAM = PDK / "libs.ref/gf180mcu_fd_ip_sram"

layout = pya.Layout()
options = pya.LoadLayoutOptions()
config = options.lefdef_config
config.dbu = 0.0005
config.read_lef_with_def = False
config.lef_files = [
    str(SC / "techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef"),
    str(SC / "lef/gf180mcu_fd_sc_mcu9t5v0.lef"),
    str(SRAM / "lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef"),
]
config.map_file = str(PDK / "libs.tech/klayout/tech/gf180mcu.map")
config.macro_layout_files = [
    str(SC / "gds/gf180mcu_fd_sc_mcu9t5v0.gds"),
    str(SRAM / "gds/gf180mcu_fd_ip_sram__sram256x8m8wm1.gds"),
]
config.macro_resolution_mode = 2
layout.read(str(ROUTE_DEF), options)
top = layout.cell(TOP)
if top is None:
    raise SystemExit(f"missing top cell {TOP}: {[c.name for c in layout.top_cells()]}")

counts = {}
for inst in top.each_inst():
    n = inst.na * inst.nb if inst.is_regular_array() else 1
    counts[inst.cell.name] = counts.get(inst.cell.name, 0) + n
sram = "gf180mcu_fd_ip_sram__sram256x8m8wm1"
if counts.get(sram, 0) != 2:
    raise SystemExit(f"SRAM count {counts.get(sram, 0)}")
if any(n.startswith("gf180mcu_fd_io") for n in counts):
    raise SystemExit("unexpected IO pads in core GDS")
sc = sum(v for k, v in counts.items() if k.startswith("gf180mcu_fd_sc_mcu9t5v0__"))
ant = counts.get("gf180mcu_fd_sc_mcu9t5v0__antenna", 0)
OUTPUT_GDS.parent.mkdir(parents=True, exist_ok=True)
tmp = OUTPUT_GDS.with_name(OUTPUT_GDS.stem + ".tmp.gds")
layout.write(str(tmp))
tmp.replace(OUTPUT_GDS)
digest = hashlib.sha256(OUTPUT_GDS.read_bytes()).hexdigest()
bbox = top.dbbox()
print(f"GDS={OUTPUT_GDS}")
print(f"TOP={TOP}")
print(f"BBOX_UM={bbox}")
print(f"AREA_MM2={bbox.width()*bbox.height()/1e6:.6f}")
print(f"SRAM={counts.get(sram,0)}")
print(f"ANTENNA={ant}")
print(f"STDCELLS={sc}")
print(f"SHA256={digest}")
print(f"BYTES={OUTPUT_GDS.stat().st_size}")
