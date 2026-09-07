#!/usr/bin/env python3
"""Measure free space for a core-boundary power ring.

Read-only. Writes nothing to the database. Reports, for each margin band
outside the core, every Metal4/Metal5 shape that does NOT belong to VDD/VSS,
so we know exactly where a ring leg may and may not be placed.

usage:
  openroad -no_splash -python audit_core_ring_space.py <in.odb>
"""
from __future__ import annotations
import sys
from openroad import Design, Tech
import odb

CLEAR = 0.60          # required clearance (um) between ring metal and any signal shape
LAYERS = ("Metal4", "Metal5")


def shapes_of_net(net):
    """Yield (layer_name, x1, y1, x2, y2) for every routed shape on a signal net."""
    wire = net.getWire()
    if wire is None:
        return
    itr = odb.dbWirePathItr()
    path = odb.dbWirePath()
    pshape = odb.dbWirePathShape()
    itr.begin(wire)
    while itr.getNextPath(path):
        while itr.getNextShape(pshape):
            shape = pshape.shape
            if shape.isVia():
                try:
                    lay = shape.getTechVia().getBottomLayer()
                except Exception:
                    continue
            else:
                lay = shape.getTechLayer()
            if lay is None:
                continue
            yield lay.getName(), shape.xMin(), shape.yMin(), shape.xMax(), shape.yMax()


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: audit_core_ring_space.py <in.odb>")
        return 2

    tech = Tech()
    design = Design(tech)
    design.readDb(sys.argv[1])
    block = tech.getDB().getChip().getBlock()
    dbu = block.getDefUnits()
    u = lambda v: v / dbu

    core, die = block.getCoreArea(), block.getDieArea()
    print("DBU %d" % dbu)
    print("DIE  %.2f %.2f %.2f %.2f" % (u(die.xMin()), u(die.yMin()), u(die.xMax()), u(die.yMax())))
    print("CORE %.2f %.2f %.2f %.2f" % (u(core.xMin()), u(core.yMin()), u(core.xMax()), u(core.yMax())))

    bands = {
        "SOUTH": (u(die.xMin()), u(die.yMin()), u(die.xMax()), u(core.yMin())),
        "NORTH": (u(die.xMin()), u(core.yMax()), u(die.xMax()), u(core.yMax()) + 12.0),
        "WEST":  (u(die.xMin()), u(die.yMin()), u(core.xMin()), u(core.yMax())),
        "EAST":  (u(core.xMax()), u(die.yMin()), u(die.xMax()), u(core.yMax())),
    }

    pg = {"VDD", "VSS"}
    found = {b: {l: [] for l in LAYERS} for b in bands}

    for net in block.getNets():
        if net.getName() in pg:
            continue
        for lname, x1, y1, x2, y2 in shapes_of_net(net):
            if lname not in LAYERS:
                continue
            a, b_, c, d = u(x1), u(y1), u(x2), u(y2)
            for bn, (bx1, by1, bx2, by2) in bands.items():
                if a < bx2 and c > bx1 and b_ < by2 and d > by1:
                    found[bn][lname].append((net.getName(), a, b_, c, d))

    for bn, (bx1, by1, bx2, by2) in bands.items():
        print("\n=== %s band  x %.2f..%.2f  y %.2f..%.2f" % (bn, bx1, bx2, by1, by2))
        for lname in LAYERS:
            hits = found[bn][lname]
            if not hits:
                print("   %-7s CLEAR" % lname)
                continue
            if bn in ("WEST", "EAST"):
                lo = min(h[1] for h in hits); hi = max(h[3] for h in hits)
                axis = "x"
            else:
                lo = min(h[2] for h in hits); hi = max(h[4] for h in hits)
                axis = "y"
            nets = sorted({h[0] for h in hits})
            print("   %-7s %4d shapes, %s %.2f .. %.2f, %d nets" % (lname, len(hits), axis, lo, hi, len(nets)))
            print("           e.g. %s" % ", ".join(nets[:4]))
            # widest free strip along the band's narrow axis
            iv = sorted(((h[1], h[3]) if axis == "x" else (h[2], h[4])) for h in hits)
            merged = []
            for s, e in iv:
                if merged and s <= merged[-1][1] + CLEAR:
                    merged[-1][1] = max(merged[-1][1], e)
                else:
                    merged.append([s, e])
            span = (bx1, bx2) if axis == "x" else (by1, by2)
            free, cur = [], span[0]
            for s, e in merged:
                if s - CLEAR > cur:
                    free.append((cur, s - CLEAR))
                cur = max(cur, e + CLEAR)
            if cur < span[1]:
                free.append((cur, span[1]))
            free = [f for f in free if f[1] - f[0] > 0.4]
            print("           free strips (>0.4um, %.2fum clearance): %s"
                  % (CLEAR, ", ".join("%.2f..%.2f (%.2f)" % (a, b, b - a) for a, b in free) or "NONE"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
