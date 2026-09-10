#!/usr/bin/env python3
"""Replace the long Metal2 spine on SRAM Q[4] with a Metal3 jumper.

The remaining antenna is Metal2 side-area on mux _17993_/I1. A via on a
still-continuous Metal2 run does not reset that ratio; the Metal2 segment
itself has to be removed and the net hopped to Metal3.
"""
from __future__ import annotations

import os

from openroad import Design, Tech
import odb

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.path.join(PROTO, "physical/results/native_power_ring_ach/ach_ant_routed_ant1.odb")
DST = os.path.join(PROTO, "physical/results/native_power_ring_ach/ach_ant_via.odb")
LOG = os.path.join(PROTO, "physical/results/native_power_ring_ach/logs/ant_cut.log")

# First long M2 run out of the violating pin.
CUT = (37.800, 100.800, 37.800, 159.600)


def close(a, b, eps=0.02):
    return abs(a - b) <= eps


def same_seg(x1, y1, x2, y2, tgt):
    ax, ay, bx, by = tgt
    return (
        close(x1, ax) and close(y1, ay) and close(x2, bx) and close(y2, by)
    ) or (
        close(x1, bx) and close(y1, by) and close(x2, ax) and close(y2, ay)
    )


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
    d = odb.dbWireDecoder()
    d.begin(wire)

    ops = []
    cur_layer = None
    cur_pts = []

    def flush_path():
        nonlocal cur_layer, cur_pts
        if cur_layer and cur_pts:
            ops.append(("PATH", cur_layer, list(cur_pts)))
        cur_pts = []

    while True:
        op = d.next()
        if op == odb.dbWireDecoder.END_DECODE:
            flush_path()
            break
        if op in (odb.dbWireDecoder.PATH, odb.dbWireDecoder.SHORT, odb.dbWireDecoder.VWIRE):
            flush_path()
            lyr = d.getLayer()
            cur_layer = lyr.getName() if lyr else None
            continue
        if op in (odb.dbWireDecoder.POINT, odb.dbWireDecoder.POINT_EXT):
            x, y = d.getPoint()
            cur_pts.append((x / dbu, y / dbu))
            continue
        if op in (odb.dbWireDecoder.VIA, odb.dbWireDecoder.TECH_VIA):
            via = d.getTechVia() or d.getVia()
            last = cur_pts[-1] if cur_pts else None
            last_layer = cur_layer
            flush_path()
            if via is not None and last is not None and last_layer:
                ops.append(("VIA_AT", via.getName(), last, last_layer))
            cur_layer = None
            continue
        if op == odb.dbWireDecoder.ITERM:
            flush_path()
            ops.append(("ITERM", d.getITerm(), None, None))
            continue
        if op == odb.dbWireDecoder.BTERM:
            flush_path()
            ops.append(("BTERM", d.getBTerm(), None, None))
            continue
        # Skip RECT/RULE/JUNCTION; vias recreate their own enclosure.

    dropped = 0
    kept = []
    for item in ops:
        kind = item[0]
        if kind == "PATH":
            _, layer, pts = item
            if layer == "Metal2" and len(pts) == 2 and same_seg(pts[0][0], pts[0][1], pts[1][0], pts[1][1], CUT):
                dropped += 1
                continue
        kept.append(item)
    if dropped != 1:
        open(LOG, "w").write(f"DROP_COUNT {dropped} expected 1 ops={len(ops)}\n")
        os._exit(1)

    m2 = dbtech.findLayer("Metal2")
    m3 = dbtech.findLayer("Metal3")
    via2 = dbtech.findVia("Via2_VH")
    routed = "ROUTED"
    odb.dbWire.destroy(wire)
    new = odb.dbWire.create(net)
    enc = odb.dbWireEncoder()
    enc.begin(new)

    def path(layer, pts):
        enc.newPath(layer, routed)
        for x, y in pts:
            enc.addPoint(int(round(x * dbu)), int(round(y * dbu)))

    for item in kept:
        kind = item[0]
        if kind == "PATH":
            _, layer_name, pts = item
            layer = dbtech.findLayer(layer_name)
            if layer is None or not pts:
                continue
            path(layer, pts)
        elif kind == "VIA_AT":
            _, vname, pt, layer_name = item
            layer = dbtech.findLayer(layer_name)
            via = dbtech.findVia(vname)
            if layer is None or via is None:
                continue
            path(layer, [pt])
            enc.addTechVia(via)
        elif kind == "ITERM":
            enc.addITerm(item[1])
        elif kind == "BTERM":
            enc.addBTerm(item[1])

    # Metal3 jumper on the same centerline, with Via2 at both ends.
    x1, y1, x2, y2 = CUT
    path(m2, [(x1, y1)])
    enc.addTechVia(via2)
    path(m3, [(x1, y1), (x2, y2)])
    path(m2, [(x2, y2)])
    enc.addTechVia(via2)
    enc.end()

    design.writeDb(DST)
    open(LOG, "w").write(
        f"NET {net.getName()}\nDROPPED_M2 {CUT}\nADDED_M3_JUMPER {CUT}\n"
        f"VIA2_ENDS ({x1},{y1}) ({x2},{y2})\nWROTE {DST}\n"
    )
    os._exit(0)


if __name__ == "__main__":
    main()
