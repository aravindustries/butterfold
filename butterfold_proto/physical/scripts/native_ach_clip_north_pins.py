#!/usr/bin/env python3
"""Clip long M2-on-PIN-x north approaches; land with M3 + Via2 at the PIN only."""
from __future__ import annotations

import os
from openroad import Design, Tech
import odb

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.environ.get(
    "CLIP_SRC",
    PROTO + "/physical/results/native_power_ring_ach/predrt/applied_m3cut_stitched3.odb",
)
DST = os.environ.get(
    "CLIP_DST",
    PROTO + "/physical/results/native_power_ring_ach/predrt/applied_m3cut_stitched4.odb",
)
NETS = os.environ.get(
    "CLIP_NETS",
    "ach_dout_PDRV0_4_tie0,ach_dout_CS_3_tie0,ach_dout_SL_2_tie0,dout_IN[2]",
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


def segs_of(wire):
    dec = odb.dbWireDecoder()
    dec.begin(wire)
    out = []
    layer = None
    last = None
    vias = []
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
            if last is not None:
                try:
                    v = dec.getTechVia()
                    vias.append((v.getName() if v else "?", last[0], last[1]))
                except Exception:
                    pass
            last = None
    return out, vias


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
    via1 = dbtech.findVia("Via1_VV")
    via2 = dbtech.findVia("Via2_VV")
    y_clip = int(1672.0 * dbu)
    lines = [f"SRC {SRC}"]
    for name in NETS.split(","):
        name = name.strip()
        net = block.findNet(name)
        if net is None:
            lines.append(f"MISSING {name}")
            continue
        its = [it for it in net.getITerms() if it.getInst().getName().startswith(("ach_tie_", "ach_rx_load_"))]
        bts = list(net.getBTerms())
        if not its or not bts:
            lines.append(f"SKIP {name}")
            continue
        sx, sy = iterm_xy(its[0])
        dx, dy = bterm_xy(bts[0])
        old = net.getWire()
        segs, vias = segs_of(old) if old is not None else ([], [])
        # Keep M2 verticals on the tiel x up to y_clip; drop PIN-x M2 above y_clip.
        keep_m2 = []
        for lyr, x1, y1, x2, y2 in segs:
            if lyr != "Metal2":
                continue
            if abs(x1 - x2) > dbu // 4:
                continue
            x = x1
            ya, yb = sorted([y1, y2])
            # drop segments on PIN x that enter the pin keepout
            if abs(x - dx) < int(1.2 * dbu) and yb > y_clip:
                if ya < y_clip:
                    keep_m2.append((x, ya, x, y_clip))
                continue
            keep_m2.append((x1, y1, x2, y2))
        if old is not None:
            odb.dbWire_destroy(old)
        wire = odb.dbWire.create(net)
        enc = odb.dbWireEncoder()
        enc.begin(wire)
        cx = int(sx)
        enc.newPath(m2, "ROUTED")
        enc.addPoint(cx, int(sy))
        enc.addTechVia(via1)
        enc.newPath(m2, "ROUTED")
        enc.addPoint(cx, int(sy))
        hop = int(80 * dbu)
        gap = int(1.12 * dbu)
        jog = int(1.12 * dbu)
        y = int(sy)
        y1 = y_clip
        direction = 1
        while y1 - y > hop + gap:
            ycut = y + hop
            enc.addPoint(cx, ycut)
            enc.addTechVia(via2)
            enc.newPath(m3, "ROUTED")
            enc.addPoint(cx, ycut)
            enc.addPoint(cx + jog, ycut)
            enc.addPoint(cx + jog, ycut + gap)
            enc.addPoint(cx, ycut + gap)
            enc.addTechVia(via2)
            enc.newPath(m2, "ROUTED")
            enc.addPoint(cx, ycut + gap)
            y = ycut + gap
        enc.addPoint(cx, y_clip)
        enc.addTechVia(via2)
        enc.newPath(m3, "ROUTED")
        enc.addPoint(cx, y_clip)
        enc.addPoint(int(dx), y_clip)
        enc.addTechVia(via2)
        enc.newPath(m2, "ROUTED")
        enc.addPoint(int(dx), y_clip)
        enc.addPoint(int(dx), int(dy))
        enc.end()
        lines.append(f"CLIP {name} tiel_x={cx/dbu:.3f} pin={dx/dbu:.3f},{dy/dbu:.3f} yclip={y_clip/dbu:.3f}")
    design.writeDb(DST)
    lines.append(f"WROTE {DST}")
    text = "\n".join(lines) + "\n"
    open("/tmp/clip_north.txt", "w").write(text)
    print(text)
    os._exit(0)


if __name__ == "__main__":
    main()
