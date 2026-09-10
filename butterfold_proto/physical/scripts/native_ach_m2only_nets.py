#!/usr/bin/env python3
"""Rebuild selected ACH nets as padframe-M2-only (no padframe Via2).

Mag unique-merges padframe Via2_VH VSUBS into the signal, then into VSS.
Tiel ZN is not a MOSFET gate, so antenna hops are unnecessary.
"""
from __future__ import annotations

import os

from openroad import Design, Tech
import odb

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.environ.get(
    "FIX_SRC",
    PROTO + "/physical/results/native_power_ring_ach/predrt/applied_nodpl_stitched.odb",
)
DST = os.environ.get(
    "FIX_DST",
    PROTO + "/physical/results/native_power_ring_ach/predrt/applied_nodpl_stitched_m2.odb",
)
NETS = os.environ.get("FIX_NETS", "WEST")


def iterm_xy(it):
    inst = it.getInst()
    loc = inst.getLocation()
    ox, oy = int(loc[0]), int(loc[1])
    mterm = it.getMTerm()
    xs, ys = [], []
    for mp in mterm.getMPins():
        for box in mp.getGeometry():
            xs += [ox + box.xMin(), ox + box.xMax()]
            ys += [oy + box.yMin(), oy + box.yMax()]
    return (min(xs) + max(xs)) // 2, (min(ys) + max(ys)) // 2


def bterm_xy(bt):
    for bp in bt.getBPins():
        for box in bp.getBoxes():
            if box.getTechLayer() and box.getTechLayer().getName() == "Metal2":
                return (box.xMin() + box.xMax()) // 2, (box.yMin() + box.yMax()) // 2
    return None


def main() -> None:
    tech = Tech()
    design = Design(tech)
    design.readDb(SRC)
    db = tech.getDB()
    block = db.getChip().getBlock()
    dbtech = db.getTech()
    dbu = block.getDefUnits()
    m2 = dbtech.findLayer("Metal2")
    via1 = dbtech.findVia("Via1_VV") or dbtech.findVia("Via1_HV")
    y_clip = int(1672.44 * dbu)
    x_land = int(4.20 * dbu)
    lines = [f"SRC {SRC} SEL {NETS}"]
    wanted = None if NETS.strip() in ("WEST", "ALL") else {n.strip() for n in NETS.split(",")}
    targets = []
    for net in block.getNets():
        if net.getSigType() in ("POWER", "GROUND"):
            continue
        its = [
            it
            for it in net.getITerms()
            if it.getInst().getName().startswith(("ach_tie_", "ach_rx_load_"))
        ]
        bts = list(net.getBTerms())
        if len(its) != 1 or len(bts) != 1:
            continue
        xy = bterm_xy(bts[0])
        if xy is None:
            continue
        dx, dy = xy
        if wanted is None:
            if NETS.strip() == "WEST" and dx >= 10 * dbu:
                continue
        elif net.getName() not in wanted:
            continue
        targets.append((net, its[0], dx, dy))
    for net, it, dx, dy in targets:
        name = net.getName()
        sx, sy = iterm_xy(it)
        old = net.getWire()
        if old is not None:
            odb.dbWire_destroy(old)
        wire = odb.dbWire.create(net)
        enc = odb.dbWireEncoder()
        enc.begin(wire)
        enc.newPath(m2, "ROUTED")
        enc.addPoint(int(sx), int(sy))
        enc.addTechVia(via1)
        if dx < 10 * dbu:
            # WEST: M2 to pin y, halo x, then stub into PIN. No Via2.
            enc.addPoint(int(sx), int(dy))
            enc.addPoint(int(x_land), int(dy))
            enc.addPoint(int(dx), int(dy))
            kind = "WEST"
        else:
            # NORTH: M2 to y_clip, jog to pin x, stub into PIN. No Via2.
            enc.addPoint(int(sx), int(y_clip))
            enc.addPoint(int(dx), int(y_clip))
            enc.addPoint(int(dx), int(dy))
            kind = "NORTH"
        enc.end()
        lines.append(
            f"FIX {kind} {name} tiel={sx/dbu:.3f},{sy/dbu:.3f} pin={dx/dbu:.3f},{dy/dbu:.3f}"
        )
    design.writeDb(DST)
    lines.append(f"WROTE {DST}")
    text = "\n".join(lines) + "\n"
    open("/tmp/m2only_nets.txt", "w").write(text)
    print(text)
    os._exit(0)


if __name__ == "__main__":
    main()
