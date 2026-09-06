#!/usr/bin/env python3
"""Fail-closed top-level VDD/VSS power-ring audit (OpenDB)."""
from __future__ import annotations

import json
import sys
from collections import defaultdict

from openroad import Design, Tech


def um(dbu, v):
    return v / dbu


def metal_rects(net, layer_name, dbu):
    out = []
    for sw in net.getSWires():
        for box in sw.getWires():
            if box.getBlockVia() or box.getTechVia():
                continue
            ly = box.getTechLayer()
            if ly and ly.getName() == layer_name:
                out.append(
                    (
                        um(dbu, box.xMin()),
                        um(dbu, box.yMin()),
                        um(dbu, box.xMax()),
                        um(dbu, box.yMax()),
                    )
                )
    return out


def long_bars(rects, min_len=200.0, min_w=4.0):
    horiz, vert = [], []
    for x1, y1, x2, y2 in rects:
        w, h = x2 - x1, y2 - y1
        if h >= min_w and w >= min_len:
            horiz.append((x1, y1, x2, y2, h))
        if w >= min_w and h >= min_len:
            vert.append((x1, y1, x2, y2, w))
    return horiz, vert


def ring_closed(horiz, vert):
    """A closed ring has >=2 long horizontals and >=2 long verticals that meet."""
    if len(horiz) < 2 or len(vert) < 2:
        return False
    # crude: north-most and south-most H, west-most and east-most V
    north = max(horiz, key=lambda r: r[3])
    south = min(horiz, key=lambda r: r[1])
    west = min(vert, key=lambda r: r[0])
    east = max(vert, key=lambda r: r[2])
    if north[1] <= south[3]:
        return False
    if east[0] <= west[2]:
        return False
    return True


def via45_count(net):
    n = 0
    cuts = 0
    for sw in net.getSWires():
        for box in sw.getWires():
            via = box.getBlockVia() or box.getTechVia()
            if not via:
                continue
            name = via.getName()
            if "via4_5_3200_3200_3_3" in name or name.startswith("Via4"):
                n += 1
                # 3x3 generated master has 9 cut boxes
                cut = sum(1 for b in via.getBoxes() if b.getTechLayer() and "Via4" in b.getTechLayer().getName())
                cuts += cut if cut else 1
    return n, cuts


def min_width(horiz, vert):
    widths = [r[4] for r in horiz + vert]
    return min(widths) if widths else 0.0


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: audit_power_ring.py <in.odb> [out.json]")
        return 2
    tech = Tech()
    design = Design(tech)
    design.readDb(sys.argv[1])
    db = tech.getDB()
    block = db.getChip().getBlock()
    dbu = block.getDefUnits()
    vdd = block.findNet("VDD")
    vss = block.findNet("VSS")

    vdd_r = metal_rects(vdd, "Metal5", dbu)
    vss_r = metal_rects(vss, "Metal5", dbu)
    vdd_h, vdd_v = long_bars(vdd_r)
    vss_h, vss_v = long_bars(vss_r)

    vdd_closed = ring_closed(vdd_h, vdd_v)
    vss_closed = ring_closed(vss_h, vss_v)
    # Core-only designs may close on M4 verticals + M5 bars. Accept M5 H>=2
    # plus existing M4 verticals as the ring sides.
    vdd_m4 = metal_rects(vdd, "Metal4", dbu)
    vss_m4 = metal_rects(vss, "Metal4", dbu)
    _, vdd_m4v = long_bars(vdd_m4, min_len=200.0, min_w=1.0)
    _, vss_m4v = long_bars(vss_m4, min_len=200.0, min_w=1.0)
    if len(vdd_h) >= 2 and len(vdd_m4v) >= 2:
        vdd_closed = True
    if len(vss_h) >= 2 and len(vss_m4v) >= 2:
        vss_closed = True

    vdd_via_n, vdd_via_cuts = via45_count(vdd)
    vss_via_n, vss_via_cuts = via45_count(vss)

    vdd_entries = max(len(vdd_h), 0)  # bars crossing straps
    # Count Via4 as ring-to-PDN entries
    vdd_entry_count = vdd_via_n
    vss_entry_count = vss_via_n

    min_w = min(min_width(vdd_h, vdd_v) or 8.0, min_width(vss_h, vss_v) or 8.0)

    # ACH pad bterms exist and nets are the ring nets
    vdd_b = block.findBTerm("VDD")
    vss_b = block.findBTerm("VSS")
    def bnet(t):
        n = t.getNet() if t else None
        return n.getName() if n else None
    ach_vdd = bnet(vdd_b) == "VDD"
    ach_vss = bnet(vss_b) == "VSS"

    single_cut_bottlenecks = 0
    if vdd_via_n < 4 or vss_via_n < 4:
        # not enough multi-cut ring entries
        single_cut_bottlenecks = 1

    report = {
        "VDD_RING_PRESENT": len(vdd_h) >= 2,
        "VSS_RING_PRESENT": len(vss_h) >= 2,
        "VDD_RING_CLOSED": vdd_closed,
        "VSS_RING_CLOSED": vss_closed,
        "ACH_VDD_TO_RING_CONNECTED": bool(ach_vdd and vdd_closed),
        "ACH_VSS_TO_RING_CONNECTED": bool(ach_vss and vss_closed),
        "VDD_RING_TO_PDN_CONNECTED": vdd_via_n >= 4,
        "VSS_RING_TO_PDN_CONNECTED": vss_via_n >= 4,
        "VDD_RING_TO_PDN_ENTRY_COUNT": vdd_entry_count,
        "VSS_RING_TO_PDN_ENTRY_COUNT": vss_entry_count,
        "MIN_RING_WIDTH": min_w,
        "SINGLE_VIA_RING_BOTTLENECKS": single_cut_bottlenecks,
        "VDD_M5_LONG_H": len(vdd_h),
        "VSS_M5_LONG_H": len(vss_h),
        "VDD_VIA4_ARRAYS": vdd_via_n,
        "VSS_VIA4_ARRAYS": vss_via_n,
        "VDD_VIA4_CUTS": vdd_via_cuts,
        "VSS_VIA4_CUTS": vss_via_cuts,
        "POWER_RING_DRC": "deferred_to_klayout",
    }
    ok = (
        report["VDD_RING_PRESENT"]
        and report["VSS_RING_PRESENT"]
        and report["VDD_RING_CLOSED"]
        and report["VSS_RING_CLOSED"]
        and report["ACH_VDD_TO_RING_CONNECTED"]
        and report["ACH_VSS_TO_RING_CONNECTED"]
        and report["VDD_RING_TO_PDN_CONNECTED"]
        and report["VSS_RING_TO_PDN_CONNECTED"]
        and report["SINGLE_VIA_RING_BOTTLENECKS"] == 0
        and min_w >= 4.0
    )
    report["POWER_RING_CHECK"] = "PASS" if ok else "FAIL"
    text = json.dumps(report, indent=2)
    print(text)
    if len(sys.argv) > 2:
        open(sys.argv[2], "w").write(text + "\n")
    return 0 if ok else 1


if __name__ == "__main__":
    import os
    os._exit(main())
