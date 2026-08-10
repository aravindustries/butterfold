#!/usr/bin/env python3
"""Merge routed DEF geometry with installed GF180 GDS library views."""

from __future__ import annotations

import hashlib
import os
from pathlib import Path
import sys

import klayout.db as pya


def fail(message: str) -> None:
    raise SystemExit(f"CANDIDATE_GDS_ERROR: {message}")


PHYS_DIR = Path(__file__).resolve().parent
PDK_ROOT = Path(os.environ.get("PDKPATH", "/foss/pdks/gf180mcuD")).resolve()
ROUTE_DEF = Path(
    os.environ.get(
        "ROUTE_DEF",
        PHYS_DIR / "results/padframe/gds/route_for_streamout.def",
    )
).resolve()
OUTPUT_GDS = Path(
    os.environ.get(
        "OUTPUT_GDS",
        PHYS_DIR / "results/padframe/gds/butterfold_padframe_candidate.gds",
    )
).resolve()

SC_ROOT = PDK_ROOT / "libs.ref/gf180mcu_fd_sc_mcu9t5v0"
SRAM_ROOT = PDK_ROOT / "libs.ref/gf180mcu_fd_ip_sram"
IO_ROOT = PDK_ROOT / "libs.ref/gf180mcu_fd_io"
TECH_LEF = SC_ROOT / "techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef"
CELL_LEF = SC_ROOT / "lef/gf180mcu_fd_sc_mcu9t5v0.lef"
SRAM_LEF = SRAM_ROOT / "lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef"
LAYER_MAP = PDK_ROOT / "libs.tech/klayout/tech/gf180mcu.map"
TECH_FILE = PDK_ROOT / "libs.tech/klayout/tech/gf180mcu.lyt"
SC_GDS = SC_ROOT / "gds/gf180mcu_fd_sc_mcu9t5v0.gds"
SRAM_GDS = SRAM_ROOT / "gds/gf180mcu_fd_ip_sram__sram256x8m8wm1.gds"
IO_GDS = IO_ROOT / "gds/gf180mcu_fd_io.gds"
IO_MASTERS = [
    "in_c",
    "bi_t",
    "dvdd",
    "dvss",
    "cor",
    "fill10",
    "fill5",
    "fill1",
    "fillnc",
    "brk2",
    "brk5",
]
IO_LEFS = [IO_ROOT / f"lef/gf180mcu_fd_io__{name}.lef" for name in IO_MASTERS]

required_files = [
    ROUTE_DEF,
    TECH_LEF,
    CELL_LEF,
    SRAM_LEF,
    LAYER_MAP,
    TECH_FILE,
    SC_GDS,
    SRAM_GDS,
    IO_GDS,
    *IO_LEFS,
]
missing = [str(path) for path in required_files if not path.is_file()]
if missing:
    fail("missing required physical collateral:\n  " + "\n  ".join(missing))

layout = pya.Layout()
options = pya.LoadLayoutOptions()
config = options.lefdef_config
# The routed DEF declares 2000 database units per micron. Preserve its 0.5 nm
# grid; KLayout rescales the 1 nm library GDS views exactly during substitution.
config.dbu = 0.0005
config.read_lef_with_def = False
config.lef_files = [str(TECH_LEF), str(CELL_LEF), str(SRAM_LEF), *map(str, IO_LEFS)]
config.map_file = str(LAYER_MAP)
config.macro_layout_files = [str(SC_GDS), str(SRAM_GDS), str(IO_GDS)]
# Always resolve placed masters from actual GDS, never from abstract LEF shapes.
config.macro_resolution_mode = 2
layout.read(str(ROUTE_DEF), options)

top_name = "butterfold_padframe_top"
top = layout.cell(top_name)
if top is None or [cell.name for cell in layout.top_cells()] != [top_name]:
    fail(f"expected sole top cell {top_name}")

counts: dict[str, int] = {}
for instance in top.each_inst():
    multiplicity = instance.na * instance.nb if instance.is_regular_array() else 1
    counts[instance.cell.name] = counts.get(instance.cell.name, 0) + multiplicity

sram256 = "gf180mcu_fd_ip_sram__sram256x8m8wm1"
sram512 = "gf180mcu_fd_ip_sram__sram512x8m8wm1"
if counts.get(sram256, 0) != 2:
    fail(f"expected two {sram256} references, found {counts.get(sram256, 0)}")
if counts.get(sram512, 0) != 0:
    fail(f"obsolete 512x8 SRAM references found: {counts[sram512]}")
for master, expected in {
    "gf180mcu_fd_io__in_c": 11,
    "gf180mcu_fd_io__bi_t": 10,
    "gf180mcu_fd_io__dvdd": 1,
    "gf180mcu_fd_io__dvss": 1,
}.items():
    if counts.get(master, 0) != expected:
        fail(f"expected {expected} references to {master}, found {counts.get(master, 0)}")

standard_cell_instances = sum(
    count for master, count in counts.items()
    if master.startswith("gf180mcu_fd_sc_mcu9t5v0__")
)
if standard_cell_instances == 0:
    fail("no GF180 standard-cell references found")

metal_shape_counts: dict[int, int] = {}
for layer_number in (34, 36, 42, 46, 81):
    layer_index = layout.layer(pya.LayerInfo(layer_number, 0))
    metal_shape_counts[layer_number] = top.shapes(layer_index).size()
if sum(metal_shape_counts.values()) == 0:
    fail("top cell contains no routed Metal1-Metal5 geometry")

for required_cell in (sram256, "gf180mcu_fd_io__in_c", "gf180mcu_fd_io__bi_t"):
    cell = layout.cell(required_cell)
    if cell is None or cell.bbox().empty():
        fail(f"actual GDS layout missing or empty for {required_cell}")

OUTPUT_GDS.parent.mkdir(parents=True, exist_ok=True)
temporary = OUTPUT_GDS.with_name(OUTPUT_GDS.stem + ".tmp.gds")
layout.write(str(temporary))
temporary.replace(OUTPUT_GDS)

# Reopen the serialized file rather than trusting the in-memory merge.
check = pya.Layout()
check.read(str(OUTPUT_GDS))
check_top = check.cell(top_name)
if check_top is None:
    fail("serialized GDS cannot be reopened with the expected top cell")
check_counts: dict[str, int] = {}
for instance in check_top.each_inst():
    multiplicity = instance.na * instance.nb if instance.is_regular_array() else 1
    check_counts[instance.cell.name] = check_counts.get(instance.cell.name, 0) + multiplicity
if check_counts.get(sram256, 0) != 2 or check_counts.get(sram512, 0) != 0:
    fail("serialized GDS SRAM hierarchy check failed")

digest = hashlib.sha256(OUTPUT_GDS.read_bytes()).hexdigest()
bbox = check_top.dbbox()
print(f"CANDIDATE_GDS={OUTPUT_GDS}")
print(f"TOP={top_name}")
print(f"DBU_UM={check.dbu}")
print(f"BBOX_UM={bbox}")
print(f"WIDTH_UM={bbox.width()}")
print(f"HEIGHT_UM={bbox.height()}")
print(f"SRAM256_INSTANCES={check_counts.get(sram256, 0)}")
print(f"SRAM512_INSTANCES={check_counts.get(sram512, 0)}")
print(f"STANDARD_CELL_INSTANCES={standard_cell_instances}")
print(f"INPUT_PAD_INSTANCES={check_counts.get('gf180mcu_fd_io__in_c', 0)}")
print(f"OUTPUT_PAD_INSTANCES={check_counts.get('gf180mcu_fd_io__bi_t', 0)}")
print("METAL_SHAPES=" + ",".join(f"{key}:{value}" for key, value in metal_shape_counts.items()))
print(f"SIZE_BYTES={OUTPUT_GDS.stat().st_size}")
print(f"SHA256={digest}")
print("GDS_REOPEN_PARSE=PASS")
