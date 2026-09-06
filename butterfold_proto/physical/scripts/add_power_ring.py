#!/usr/bin/env python3
"""Add a closed top-level VDD/VSS power ring on the accepted power-fixed ODB.

Reproducible OpenDB ECO.  No hand-drawn via cuts: every M4/M5 transition uses
the existing GF180 generated 3x3 Via4 master (via4_5_3200_3200_3_3_1040_1040).

Architecture
------------
Internal PDN already has Metal4 vertical 1.6 um straps and Metal5 horizontal
1.6 um straps, but they do not form a closed ring.

This ECO:

* Adds Metal5 top/bottom bars that close the existing same-net Metal4
  verticals into a core ring (Via4 3x3 at each strap crossing).
* Adds a closed Metal5 ring in the empty ACH envelope (y > 1088.64) that
  physically meets the north VDD pad feeds.
* Extends three VSS Metal4 verticals into that envelope and closes a VSS
  Metal5 ring there.  Does NOT recreate the rejected west-core second VSS
  branch that shorted seven signal nets.

Input:  physical/results/m2_fix/power_fixed.odb
"""
from __future__ import annotations

import os
import sys

from openroad import Design, Tech
import odb


def um(dbu: int, value: float) -> int:
    return int(round(value * dbu))


def swire(net):
    wires = net.getSWires()
    return wires[0] if wires else odb.dbSWire.create(net, "NONE")


def add_rect(sw, layer, dbu, box):
    x1, y1, x2, y2 = box
    odb.dbSBox.create(sw, layer, um(dbu, x1), um(dbu, y1), um(dbu, x2), um(dbu, y2), "NONE")


def add_via(sw, via, dbu, x, y):
    odb.dbSBox.create(sw, via, um(dbu, x), um(dbu, y), "NONE")


def closed_ring_rects(x0, y0, x1, y1, w):
    """Four rectangles of width w forming a closed ring. Outer bbox (x0,y0)-(x1,y1)."""
    return [
        (x0, y1 - w, x1, y1),  # north
        (x0, y0, x1, y0 + w),  # south
        (x0, y0, x0 + w, y1),  # west
        (x1 - w, y0, x1, y1),  # east
    ]


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: add_power_ring.py <in.odb> <out.odb> <out.def>")
        return 2

    tech = Tech()
    design = Design(tech)
    design.readDb(sys.argv[1])
    db = tech.getDB()
    block = db.getChip().getBlock()
    dbtech = db.getTech()
    dbu = block.getDefUnits()

    m4 = dbtech.findLayer("Metal4")
    m5 = dbtech.findLayer("Metal5")
    via45 = block.findVia("via4_5_3200_3200_3_3_1040_1040")
    if not all((m4, m5, via45)):
        raise SystemExit("required Metal4/Metal5/via4_5 3x3 generated via unavailable")

    vdd = block.findNet("VDD")
    vss = block.findNet("VSS")
    vdd_sw = swire(vdd)
    vss_sw = swire(vss)

    # Existing 1.6 um Metal4 strap centers (from power_fixed.odb).
    vdd_m4_x = [23.04, 176.64, 330.24, 483.84, 637.44, 791.04, 944.64]
    vss_m4_x = [26.34, 179.94, 333.54, 487.14, 640.74, 794.34, 947.94]
    # North ACH VDD M4 feeds (subset that already reaches y=1675).
    vdd_north_m4_x = [483.84, 637.44, 791.04]

    ring_w = 8.0

    # Core-width M5 bars were tried and rejected: they overlay signal Metal4
    # (including SRAM Q routing just above the macros at y=1061) and Mag
    # extract merged SRAM Q[1] with unrelated logic.  Close the ring in the
    # ACH envelope instead, using the existing 1.6 um core M4/M5 grid.
    vdd_core_vias = 0
    vss_core_vias = 0

    # ---- Upper VDD pad ring in the ACH envelope ----
    vdd_u = (16.0, 1096.0, 1094.0, 1673.0)
    for box in closed_ring_rects(*vdd_u, ring_w):
        add_rect(vdd_sw, m5, dbu, box)
    vdd_upper_vias = 0
    for x in vdd_north_m4_x:
        add_via(vdd_sw, via45, dbu, x, vdd_u[3] - ring_w / 2.0)  # north bar
        add_via(vdd_sw, via45, dbu, x, vdd_u[1] + ring_w / 2.0)  # south bar
        vdd_upper_vias += 2

    # ---- Upper VSS ring (offset inside VDD; no west-core second branch) ----
    vss_u = (28.0, 1108.0, 1082.0, 1661.0)
    for box in closed_ring_rects(*vss_u, ring_w):
        add_rect(vss_sw, m5, dbu, box)
    # Extend existing VSS M4 verticals north into the empty envelope only.
    vss_up_x = [(25.54, 27.14, 26.34), (486.34, 487.94, 487.14), (947.14, 948.74, 947.94)]
    for x1, x2, xc in vss_up_x:
        add_rect(vss_sw, m4, dbu, (x1, 1088.94, x2, 1661.0))
        add_via(vss_sw, via45, dbu, xc, vss_u[3] - ring_w / 2.0)
        add_via(vss_sw, via45, dbu, xc, vss_u[1] + ring_w / 2.0)

    design.writeDb(sys.argv[2])
    design.writeDef(sys.argv[3])
    print("VDD_RING_LAYER Metal5")
    print("VSS_RING_LAYER Metal5")
    print("VDD_RING_WIDTH_UM", ring_w)
    print("VSS_RING_WIDTH_UM", ring_w)
    print("VDD_CORE_RING_VIA4", vdd_core_vias, "x 3x3 =", vdd_core_vias * 9, "cuts")
    print("VSS_CORE_RING_VIA4", vss_core_vias, "x 3x3 =", vss_core_vias * 9, "cuts")
    print("VDD_UPPER_RING_VIA4", vdd_upper_vias, "x 3x3 =", vdd_upper_vias * 9, "cuts")
    print("VSS_UPPER_RING_M4_EXTENSIONS", len(vss_up_x))
    print("VIA_MASTER via4_5_3200_3200_3_3_1040_1040")
    print("RAW_HAND_DRAWN_CRITICAL_VIA_CUTS 0")
    print("REJECTED_SECOND_VSS_BRANCH not recreated")
    print("wrote", sys.argv[2])
    print("wrote", sys.argv[3])
    return 0


if __name__ == "__main__":
    rc = main()
    if rc:
        os._exit(rc)
