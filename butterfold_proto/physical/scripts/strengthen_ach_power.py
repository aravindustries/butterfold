#!/usr/bin/env python3
"""Strengthen the final ACH-to-core VDD/VSS interface with redundant via arrays.

This is a deterministic post-route PG ECO.  It preserves the organizer DEF/YAML
and adds only ButterFold-side special-wire geometry.  The input database is the
closed final-ACH checkpoint produced by the normal m2-fix flow.
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
    odb.dbSBox.create(sw, layer, *(um(dbu, v) for v in box), "NONE")


def add_via(sw, via, dbu, x, y):
    odb.dbSBox.create(sw, via, um(dbu, x), um(dbu, y), "NONE")


def remove_legacy_via(net, dbu, via_name, x, y):
    """Remove the superseded single-cut technology via at an exact location."""
    tx, ty = um(dbu, x), um(dbu, y)
    removed = 0
    for sw in net.getSWires():
        for box in list(sw.getWires()):
            via = box.getTechVia()
            if via and via.getName() == via_name and box.xMin() <= tx <= box.xMax() and box.yMin() <= ty <= box.yMax():
                odb.dbSBox.destroy(box)
                removed += 1
    if removed != 1:
        raise SystemExit(f"expected one {via_name} at {x},{y}; removed {removed}")


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: strengthen_ach_power.py <in.odb> <out.odb> <out.def>")
        return 2

    tech = Tech()
    design = Design(tech)
    design.readDb(sys.argv[1])
    db = tech.getDB()
    block = db.getChip().getBlock()
    dbtech = db.getTech()
    dbu = block.getDefUnits()

    m2 = dbtech.findLayer("Metal2")
    m3 = dbtech.findLayer("Metal3")
    m4 = dbtech.findLayer("Metal4")
    via23 = block.findVia("via2_3_3200_1200_1_3_1040_1040")
    via34 = block.findVia("via3_4_3200_2000_2_3_1040_1040")
    via45 = block.findVia("via4_5_3200_3200_3_3_1040_1040")
    if not all((m2, m3, m4, via23, via34, via45)):
        raise SystemExit("required GF180 layers/generated multi-cut vias unavailable")

    # VDD: retain the official six north M2 PORT shapes.  Stitch each PORT to a
    # 1x3 Via2 array, use a 1-um M3 manifold, and enter three existing core VDD
    # M4 stripes independently through 2x3 Via3 arrays (six cuts each).
    vdd = block.findNet("VDD")
    vdd_sw = swire(vdd)
    remove_legacy_via(vdd, dbu, "Via2_VV", 637.44, 1674.50)
    remove_legacy_via(vdd, dbu, "Via3_VV", 637.44, 1674.50)
    add_rect(vdd_sw, m3, dbu, (483.04, 1674.00, 791.84, 1675.00))
    for x in (483.84, 636.64 + 0.80, 790.24 + 0.80):
        add_rect(vdd_sw, m4, dbu, (x - 0.80, 1088.64, x + 0.80, 1675.00))
        add_via(vdd_sw, via34, dbu, x, 1674.50)
    for x in (636.11, 648.885, 660.735, 674.265, 686.115, 698.89):
        add_via(vdd_sw, via23, dbu, x, 1674.50)

    # VSS: widen the west M3 manifold to a second existing VSS M4 stripe.
    # Each core entry uses 2x3 Via3 plus 3x3 Via4 arrays.  The six west source
    # PORTs retain separate source-local cuts; none carries the aggregate load.
    vss = block.findNet("VSS")
    vss_sw = swire(vss)
    remove_legacy_via(vss, dbu, "Via3_VV", 8.80, 40.11)
    remove_legacy_via(vss, dbu, "Via4_VV", 8.80, 40.11)
    # The west landing is signal-constrained.  Preserve its proven 1.6-um M3
    # and M4 overlap and replace the two critical single cuts with one robust
    # generated array per layer transition.  A trial extension to x=26.34 was
    # rejected by LVS because it crossed seven existing interface nets.
    add_via(vss_sw, via34, dbu, 8.80, 40.11)
    add_via(vss_sw, via45, dbu, 8.80, 40.11)
    design.writeDb(sys.argv[2])
    design.writeDef(sys.argv[3])
    print("VDD independent entries: 3; each critical Via3 array: 2x3 (6 cuts)")
    print("VSS independent entries: 1; Via3 2x3 (6 cuts), Via4 3x3 (9 cuts)")
    print("wrote", sys.argv[2])
    print("wrote", sys.argv[3])
    return 0


if __name__ == "__main__":
    rc = main()
    if rc:
        os._exit(rc)
