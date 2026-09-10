#!/usr/bin/env python3
"""Add a Via2 on the remaining SRAM Q[4] Metal2 stub where it already
crosses Metal3. No rip-up, no GRT, no extra obstructions.
"""
from __future__ import annotations

import os

from openroad import Design, Tech
import odb

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.path.join(PROTO, "physical/results/native_power_ring_ach/ach_ant_routed_ant1.odb")
DST = os.path.join(PROTO, "physical/results/native_power_ring_ach/ach_ant_via.odb")
LOG = os.path.join(PROTO, "physical/results/native_power_ring_ach/logs/ant_via.log")


def main() -> None:
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    tech = Tech()
    design = Design(tech)
    design.readDb(SRC)
    db = tech.getDB()
    block = db.getChip().getBlock()
    dbtech = db.getTech()
    dbu = block.getDefUnits()
    inst = block.findInst("_17993_")
    net = inst.findITerm("I1").getNet()
    wire = net.getWire()
    m2 = dbtech.findLayer("Metal2")
    via = dbtech.findVia("Via2_VH")
    if m2 is None or via is None or wire is None:
        open(LOG, "w").write("missing m2/via/wire\n")
        os._exit(1)
    # Existing M2/M3 crossing nearest the violating mux pin.
    pts_um = [(37.24, 99.96), (37.80, 103.88)]
    enc = odb.dbWireEncoder()
    enc.append(wire)
    for x_um, y_um in pts_um:
        x = int(round(x_um * dbu))
        y = int(round(y_um * dbu))
        enc.newPath(m2, "ROUTED")
        enc.addPoint(x, y)
        enc.addTechVia(via)
    enc.end()
    design.writeDb(DST)
    open(LOG, "w").write(
        f"NET {net.getName()}\nVIA Via2_VH at {pts_um}\nWROTE {DST}\n"
    )
    os._exit(0)


if __name__ == "__main__":
    main()
