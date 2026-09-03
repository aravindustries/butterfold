#!/usr/bin/env python3
"""KLayout DEF→GDS streamout for the shrink-area closed ECO, preserving DEF 0.5 nm DBU."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path

import klayout.db as pya

PROTO = Path("/headless/aravindustries-repos/butterfold/butterfold_proto")
PDK = Path(os.environ.get("PDKPATH", "/foss/pdks/gf180mcuD"))
OUT = PROTO / "physical/results/shrink_signoff"
DEF_PATH = Path(os.environ.get("ROUTE_DEF", OUT / "butterfold_top_closed.def"))
GDS_PATH = Path(os.environ.get("OUTPUT_GDS", OUT / "candidate/butterfold_top.gds"))
DESIGN = "butterfold_top"

SC = PDK / "libs.ref/gf180mcu_fd_sc_mcu9t5v0"
SRAM = PDK / "libs.ref/gf180mcu_fd_ip_sram"
TECH_LEF = SC / "techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef"
CELL_LEF = SC / "lef/gf180mcu_fd_sc_mcu9t5v0.lef"
SRAM_LEF = SRAM / "lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef"
SC_GDS = SC / "gds/gf180mcu_fd_sc_mcu9t5v0.gds"
SRAM_GDS = SRAM / "gds/gf180mcu_fd_ip_sram__sram256x8m8wm1.gds"
LYT = PDK / "libs.tech/klayout/tech/gf180mcu.lyt"
LYP = PDK / "libs.tech/klayout/tech/gf180mcu.lyp"
LYM = PDK / "libs.tech/klayout/tech/gf180mcu.map"

for p in (DEF_PATH, TECH_LEF, CELL_LEF, SRAM_LEF, SC_GDS, SRAM_GDS, LYT, LYP, LYM):
    if not p.is_file():
        raise SystemExit(f"missing {p}")

opts = pya.LoadLayoutOptions()
opts.lefdef_config.read_lef_with_def = False
opts.lefdef_config.lef_files = [str(TECH_LEF), str(CELL_LEF), str(SRAM_LEF)]
opts.lefdef_config.map_file = str(LYM)
opts.lefdef_config.dbu = 0.0005
opts.lefdef_config.macro_layout_files = [str(SC_GDS), str(SRAM_GDS)]
opts.lefdef_config.macro_resolution_mode = 2

layout = pya.Layout()
print(f"[INFO] Reading DEF {DEF_PATH}")
layout.read(str(DEF_PATH), opts)
top_index = layout.cell(DESIGN).cell_index()
top = layout.cell(DESIGN)
missing = [c.name for c in layout.each_cell() if c.is_ghost_cell()]
if missing:
    raise SystemExit("missing GDS cells: " + ", ".join(missing))
print("[INFO] All LEF cells have matching GDS cells.")

GDS_PATH.parent.mkdir(parents=True, exist_ok=True)
layout.write(str(GDS_PATH))
bbox = top.bbox()
dbu = layout.dbu
w_um = bbox.width() * dbu
h_um = bbox.height() * dbu
sha = hashlib.sha256(GDS_PATH.read_bytes()).hexdigest()
print(f"[INFO] Wrote {GDS_PATH}")
print(f"GDS_DBU {dbu}")
print(f"GDS_BBOX_DBU {bbox.left} {bbox.bottom} {bbox.right} {bbox.top}")
print(f"GDS_BBOX_UM {w_um:.4f} {h_um:.4f}")
print(f"GDS_AREA_MM2 {w_um * h_um / 1e6:.6f}")
print(f"GDS_SHA256 {sha}")
(GDS_PATH.with_suffix(".gds.sha256")).write_text(sha + "  " + GDS_PATH.name + "\n")
