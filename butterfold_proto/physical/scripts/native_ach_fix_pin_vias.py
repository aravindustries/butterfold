#!/usr/bin/env python3
"""Rewrite ACH PIN approaches to the Mag-clean 80ef style.

80ef north landing:
  Via2_VH at (pin_x, ~1672.44) with M2+M3 present
  M2 stub to the PIN (no via at y=1674.5)

Mag unique-merges Via2_VV sitting on the PIN into VSUBS, then into VSS.
"""
from __future__ import annotations

import os

from openroad import Design, Tech
import odb

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.environ.get(
    "FIX_SRC",
    PROTO + "/physical/results/native_power_ring_ach/predrt/applied_m3cut_stitched4.odb",
)
DST = os.environ.get(
    "FIX_DST",
    PROTO + "/physical/results/native_power_ring_ach/predrt/applied_m3cut_stitched8.odb",
)


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


def segs_vias(wire):
    if wire is None:
        return [], []
    dec = odb.dbWireDecoder()
    dec.begin(wire)
    out, vias = [], []
    layer, last = None, None
    while True:
        op = dec.next()
        if op == odb.dbWireDecoder.END_DECODE:
            break
        if op in (odb.dbWireDecoder.PATH, odb.dbWireDecoder.SHORT, odb.dbWireDecoder.VWIRE):
            lyr = dec.getLayer()
            layer = lyr.getName() if lyr else None
            last = None
            continue
        if op in (odb.dbWireDecoder.POINT, odb.dbWireDecoder.POINT_EXT):
            pt = dec.getPoint()
            xy = (int(pt[0]), int(pt[1]))
            if last is not None and layer is not None and xy != last:
                out.append((layer, last[0], last[1], xy[0], xy[1]))
            last = xy
            continue
        if op in (odb.dbWireDecoder.TECH_VIA, odb.dbWireDecoder.VIA):
            try:
                v = dec.getTechVia()
                vn = v.getName() if v else "?"
            except Exception:
                vn = "?"
            if last is not None:
                vias.append((vn, last[0], last[1]))
            last = None
    return out, vias


def encode_keep(enc, segs, vias, m2, m3, via1, via2, via2vh, sx, sy, drop_y, pin_via_y, dx, dy, dbu):
    """Keep M2 trunk on tiel x up to drop_y; 80ef-style Via2_VH jog; M2 stub to PIN."""
    enc.newPath(m2, "ROUTED")
    enc.addPoint(int(sx), int(sy))
    enc.addTechVia(via1)
    # replay M2 verticals on tiel x that stay below drop_y
    y = int(sy)
    x = int(sx)
    m2_verts = []
    for lyr, x1, y1, x2, y2 in segs:
        if lyr != "Metal2":
            continue
        if abs(x1 - x2) > dbu // 4:
            continue
        xa = x1
        ya, yb = sorted([y1, y2])
        if abs(xa - sx) > 2 * dbu:
            continue
        if ya >= drop_y:
            continue
        yb2 = min(yb, drop_y)
        if yb2 > ya:
            m2_verts.append((xa, ya, yb2))
    m2_verts.sort(key=lambda t: t[1])
    for xa, ya, yb in m2_verts:
        if ya > y + dbu // 4:
            enc.addPoint(x, ya)
        enc.addPoint(xa, yb)
        x, y = xa, yb
    if y < drop_y:
        enc.addPoint(x, drop_y)
        y = drop_y
    # Hop to M3 with Via2_VH at tiel x, drop_y (padframe but NOT on the PIN).
    enc.addTechVia(via2vh)
    enc.newPath(m3, "ROUTED")
    enc.addPoint(x, drop_y)
    enc.addPoint(int(dx), drop_y)
    enc.addTechVia(via2vh)
    # Fresh M2 path: via location, then stub to PIN. Do not add a via after the stub.
    enc.newPath(m2, "ROUTED")
    enc.addPoint(int(dx), drop_y)
    enc.addPoint(int(dx), int(dy))


def main() -> None:
    tech = Tech()
    design = Design(tech)
    design.readDb(SRC)
    db = tech.getDB()
    block = db.getChip().getBlock()
    dbtech = db.getTech()
    dbu = block.getDefUnits()
    m2 = dbtech.findLayer("Metal2")
    m3 = dbtech.findLayer("Metal3")
    via1 = dbtech.findVia("Via1_VV") or dbtech.findVia("Via1_HV")
    via2 = dbtech.findVia("Via2_VV")
    via2vh = dbtech.findVia("Via2_VH") or via2
    drop_y = int(1672.44 * dbu)
    pin_via_y = int(1673.0 * dbu)
    lines = [f"SRC {SRC} VIA2VH {via2vh.getName() if via2vh else None}"]
    nfix = 0
    nskip = 0
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
        # True north organizer pins sit at y=1674.5. West pins can also have
        # y>1600 (x=0.5) and must not be rewritten as north landings.
        if dy < 1670 * dbu or dx < 10 * dbu:
            nskip += 1
            continue
        segs, vias = segs_vias(net.getWire())
        pin_vias = [v for v in vias if v[2] >= pin_via_y]
        sx, sy = iterm_xy(its[0])
        old = net.getWire()
        if old is not None:
            odb.dbWire_destroy(old)
        wire = odb.dbWire.create(net)
        enc = odb.dbWireEncoder()
        enc.begin(wire)
        encode_keep(enc, segs, vias, m2, m3, via1, via2, via2vh, sx, sy, drop_y, pin_via_y, dx, dy, dbu)
        enc.end()
        nfix += 1
        if pin_vias or nfix <= 8:
            lines.append(
                f"FIX {net.getName()} tiel={sx/dbu:.3f},{sy/dbu:.3f} pin={dx/dbu:.3f},{dy/dbu:.3f} "
                f"pin_vias_was {len(pin_vias)}"
            )
    lines.append(f"FIXED {nfix} SKIP_WEST_OR_OTHER {nskip}")
    design.writeDb(DST)
    lines.append(f"WROTE {DST}")
    text = "\n".join(lines) + "\n"
    open("/tmp/fix_pin_vias.txt", "w").write(text)
    print(text)
    os._exit(0)


if __name__ == "__main__":
    main()
