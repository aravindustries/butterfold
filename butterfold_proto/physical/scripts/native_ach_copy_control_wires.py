#!/usr/bin/env python3
"""Copy ACH 2-pin control/IN routes from ach_routed onto the native-wire M3-cut ODB.

Does not run DRT. Existing non-ACH wires are left untouched.
"""
from __future__ import annotations

import json
import os
from collections import defaultdict

from openroad import Design, Tech
import odb

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.environ.get(
    "COPY_SRC",
    PROTO + "/physical/results/native_power_ring_ach/predrt/applied_m3cut.odb",
)
DST = os.environ.get(
    "COPY_DST",
    PROTO + "/physical/results/native_power_ring_ach/predrt/applied_m3cut_ctrlwires.odb",
)
WIRES = os.environ.get(
    "COPY_JSON",
    PROTO + "/physical/results/native_power_ring_ach/predrt/ach_control_wires.json",
)
LOG = os.environ.get(
    "COPY_LOG",
    PROTO + "/physical/results/native_power_ring_ach/predrt/copy_control_wires.log",
)


def segs_of(wire):
    if wire is None:
        return []
    dec = odb.dbWireDecoder()
    dec.begin(wire)
    out = []
    layer = None
    last = None
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
            last = None
    return out


def overlap(a, b, slop=560):
    # axis-aligned segments; slop ~ 0.28 um at 2000 dbu
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b
    if ax1 > ax2:
        ax1, ax2 = ax2, ax1
    if ay1 > ay2:
        ay1, ay2 = ay2, ay1
    if bx1 > bx2:
        bx1, bx2 = bx2, bx1
    if by1 > by2:
        by1, by2 = by2, by1
    return not (ax2 + slop < bx1 or bx2 + slop < ax1 or ay2 + slop < by1 or by2 + slop < ay1)


def main() -> None:
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    data = json.load(open(WIRES))
    tech = Tech()
    design = Design(tech)
    design.readDb(SRC)
    db = tech.getDB()
    block = db.getChip().getBlock()
    dbtech = db.getTech()
    lines = [f"SRC {SRC}", f"JSON_NETS {data['n']}"]
    copied = 0
    missing = 0
    for rec in data["nets"]:
        net = block.findNet(rec["name"])
        if net is None:
            missing += 1
            lines.append(f"MISSING {rec['name']}")
            continue
        old = net.getWire()
        if old is not None:
            odb.dbWire_destroy(old)
        wire = odb.dbWire.create(net)
        enc = odb.dbWireEncoder()
        enc.begin(wire)
        for ev in rec["events"]:
            op = ev["op"]
            if op == "PATH":
                lyr = dbtech.findLayer(ev["layer"])
                if lyr is None:
                    lines.append(f"NOLAYER {rec['name']} {ev['layer']}")
                    continue
                enc.newPath(lyr, "ROUTED")
            elif op == "PT":
                enc.addPoint(int(ev["x"]), int(ev["y"]))
            elif op == "TVIA":
                v = dbtech.findVia(ev["via"])
                if v is None:
                    lines.append(f"NOVIA {rec['name']} {ev['via']}")
                    continue
                enc.addTechVia(v)
            elif op == "VIA":
                v = dbtech.findVia(ev["via"])
                if v is None:
                    lines.append(f"NOVIA {rec['name']} {ev['via']}")
                    continue
                enc.addVia(v)
        enc.end()
        copied += 1
    lines.append(f"COPIED {copied} MISSING {missing}")

    ach_names = {rec["name"] for rec in data["nets"]}
    native = defaultdict(list)
    ach = defaultdict(list)
    for net in block.getNets():
        if net.getSigType() in ("POWER", "GROUND"):
            continue
        s = segs_of(net.getWire())
        bucket = ach if net.getName() in ach_names else native
        for layer, x1, y1, x2, y2 in s:
            bucket[layer].append((net.getName(), x1, y1, x2, y2))

    hits = []
    for layer, asegs in ach.items():
        nsegs = native.get(layer, [])
        for an, ax1, ay1, ax2, ay2 in asegs:
            for nn, bx1, by1, bx2, by2 in nsegs:
                if overlap((ax1, ay1, ax2, ay2), (bx1, by1, bx2, by2)):
                    hits.append((layer, an, nn, ax1, ay1, ax2, ay2, bx1, by1, bx2, by2))
                    if len(hits) >= 200:
                        break
            if len(hits) >= 200:
                break
        if len(hits) >= 200:
            break
    lines.append(f"OVERLAP_HITS {len(hits)} (capped 200)")
    for h in hits[:40]:
        lines.append("HIT " + " ".join(str(x) for x in h))

    still = 0
    for net in block.getNets():
        if net.getSigType() in ("POWER", "GROUND"):
            continue
        if net.getWire() is None:
            still += 1
    lines.append(f"SIGNAL_UNROUTED {still}")
    design.writeDb(DST)
    lines.append(f"WROTE {DST}")
    text = "\n".join(lines) + "\n"
    open(LOG, "w").write(text)
    open("/tmp/copy_control_wires.txt", "w").write(text)
    os._exit(0)


if __name__ == "__main__":
    main()
