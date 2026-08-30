#!/usr/bin/env python3
"""DEF→GDS streamout at DEF 0.5 nm DBU. Library GDS is 1 nm and must not hijack dbu."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path

import klayout.db as pya

PROTO = Path("/headless/aravindustries-repos/butterfold/butterfold_proto")
PDK = Path(os.environ.get("PDKPATH", "/foss/pdks/gf180mcuD"))
OUT = PROTO / "physical/results/pin22_signoff"
DEF_PATH = Path(os.environ.get("ROUTE_DEF", OUT / "filled.def"))
GDS_PATH = Path(os.environ.get("OUTPUT_GDS", OUT / "candidate/butterfold_top.gds"))
DESIGN = "butterfold_top"
TARGET_DBU = 0.0005

SC = PDK / "libs.ref/gf180mcu_fd_sc_mcu9t5v0"
SRAM = PDK / "libs.ref/gf180mcu_fd_ip_sram"
TECH_LEF = SC / "techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef"
CELL_LEF = SC / "lef/gf180mcu_fd_sc_mcu9t5v0.lef"
SRAM_LEF = SRAM / "lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef"
SC_GDS = SC / "gds/gf180mcu_fd_sc_mcu9t5v0.gds"
SRAM_GDS = SRAM / "gds/gf180mcu_fd_ip_sram__sram256x8m8wm1.gds"
LYT = PDK / "libs.tech/klayout/tech/gf180mcu.lyt"
LYM = PDK / "libs.tech/klayout/tech/gf180mcu.map"

for p in (DEF_PATH, TECH_LEF, CELL_LEF, SRAM_LEF, SC_GDS, SRAM_GDS, LYT, LYM):
    if not p.is_file():
        raise SystemExit(f"missing {p}")

tech = pya.Technology()
tech.load(str(LYT))
opts = tech.load_layout_options
opts.lefdef_config.read_lef_with_def = False
opts.lefdef_config.lef_files = [str(TECH_LEF), str(CELL_LEF), str(SRAM_LEF)]
opts.lefdef_config.map_file = str(LYM)
opts.lefdef_config.dbu = TARGET_DBU
opts.lefdef_config.net_property_name = None
opts.lefdef_config.instance_property_name = None
opts.lefdef_config.pin_property_name = None
opts.cell_conflict_resolution = pya.LoadLayoutOptions.CellConflictResolution.RenameCell

layout = pya.Layout()
print(f"[INFO] Reading DEF {DEF_PATH}")
layout.read(str(DEF_PATH), opts)
if abs(layout.dbu - TARGET_DBU) > 1e-12:
    raise SystemExit(f"DEF dbu {layout.dbu} != {TARGET_DBU}")
top = layout.cell(DESIGN)
print(f"[INFO] DEF dbu {layout.dbu} bbox {top.bbox()}")

print("[INFO] Clearing abstract cells")
for cell in layout.each_cell():
    if cell.cell_index() != top.cell_index() and not cell.name.startswith("VIA"):
        cell.clear()

lib = pya.Layout()
for gds in (SC_GDS, SRAM_GDS):
    print(f"[INFO] Reading library GDS {gds}")
    lib.read(str(gds), opts)
print(f"[INFO] Library dbu {lib.dbu}")

missing = []
for cell in layout.each_cell():
    if cell.cell_index() == top.cell_index() or cell.name.startswith("VIA"):
        continue
    src = lib.cell(cell.name)
    if src is None:
        missing.append(cell.name)
        continue
    cell.copy_tree(src)
if missing:
    raise SystemExit("missing GDS cells: " + ", ".join(missing))
if abs(layout.dbu - TARGET_DBU) > 1e-12:
    raise SystemExit(f"dbu hijacked to {layout.dbu}")
print("[INFO] All LEF cells have matching GDS cells.")

out_layout = pya.Layout()
out_layout.dbu = TARGET_DBU
out_top = out_layout.create_cell(DESIGN)
out_top.copy_tree(top)
ghosts = [c.name for c in out_layout.each_cell() if c.is_ghost_cell()]
if ghosts:
    raise SystemExit("ghost cells: " + ", ".join(ghosts))

GDS_PATH.parent.mkdir(parents=True, exist_ok=True)
out_layout.write(str(GDS_PATH))
bbox = out_top.bbox()
dbu = out_layout.dbu
w_um = bbox.width() * dbu
h_um = bbox.height() * dbu
if w_um > 1110.01 or h_um > 1110.01:
    raise SystemExit(f"GDS too large {w_um:.4f} x {h_um:.4f}")
sha = hashlib.sha256(GDS_PATH.read_bytes()).hexdigest()
print(f"[INFO] Wrote {GDS_PATH}")
print(f"GDS_DBU {dbu}")
print(f"GDS_BBOX_DBU {bbox.left} {bbox.bottom} {bbox.right} {bbox.top}")
print(f"GDS_BBOX_UM {w_um:.4f} {h_um:.4f}")
print(f"GDS_AREA_MM2 {w_um * h_um / 1e6:.6f}")
print(f"GDS_SHA256 {sha}")
GDS_PATH.with_suffix(".gds.sha256").write_text(sha + "  " + GDS_PATH.name + "\n")
