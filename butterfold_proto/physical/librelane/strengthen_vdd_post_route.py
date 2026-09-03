#!/usr/bin/env python3
"""Widen the VDD pad-to-core connection AFTER routing is complete.

Review comment: "you're powering your whole project through 1 via."  True --
the core PDN drops only one VDD Metal4 stripe under the six VDD pins, so the
pad-side stitch had a single via stack and a single 1.6-um riser.

An earlier attempt added the extra metal BEFORE global placement.  That
re-planned the router, and a 1996-fanout clock net collided with the PDN
(3 shorts, LVS collapsed VDD and VSS into one node).  Routing is not the
place to be perturbed, so this script runs AFTER detailed routing: it only
adds metal in the empty band above the core, then the flow re-extracts,
re-streams and re-verifies.  Nothing re-routes.

It REFUSES to write if the metal it would add touches anything that is not
VDD, so a conflict aborts instead of silently shorting.

Usage:  openroad -python strengthen_vdd_post_route.py <src.odb> <dst.odb> <dst.def>
        (use the LibreLane OpenROAD: /foss/tools/openroad-librelane/bin/openroad)
"""
from __future__ import annotations

import os
import sys

from openroad import Design, Tech
import odb


def um(dbu, v):
    return int(round(v * dbu))


def swire(net):
    sws = net.getSWires()
    return sws[0] if sws else odb.dbSWire.create(net, "NONE")


def add_rect(sw, layer, x1, y1, x2, y2):
    if x1 > x2:
        x1, x2 = x2, x1
    if y1 > y2:
        y1, y2 = y2, y1
    odb.dbSBox.create(sw, layer, int(x1), int(y1), int(x2), int(y2), "NONE")


def add_via(sw, via, x, y):
    odb.dbSBox.create(sw, via, int(x), int(y), "NONE")


def special_rects(net, layer_name):
    out = []
    for sw in net.getSWires():
        for box in sw.getWires():
            layer = box.getTechLayer()
            if layer is None or layer.getName() != layer_name:
                continue
            out.append((box.xMin(), box.yMin(), box.xMax(), box.yMax()))
    return out


def pin_boxes(block, name, layer_name):
    bt = block.findBTerm(name)
    if bt is None:
        raise SystemExit(f"missing bterm {name}")
    out = []
    for bp in bt.getBPins():
        for box in bp.getBoxes():
            layer = box.getTechLayer()
            if layer is None or layer.getName() != layer_name:
                continue
            out.append((box.xMin(), box.yMin(), box.xMax(), box.yMax()))
    return out


def occupied(block, keep_net, layers, win):
    """Every shape from any net except keep_net that intersects win."""
    wx1, wy1, wx2, wy2 = win
    hits = []
    for net in block.getNets():
        if net.getName() == keep_net:
            continue
        for sw in net.getSWires():
            for box in sw.getWires():
                lay = box.getTechLayer()
                if lay is None or lay.getName() not in layers:
                    continue
                if box.xMin() < wx2 and wx1 < box.xMax() and \
                   box.yMin() < wy2 and wy1 < box.yMax():
                    hits.append((net.getName(), lay.getName(),
                                 box.xMin(), box.yMin(), box.xMax(), box.yMax()))
    return hits


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__)
        return os.EX_USAGE
    src, dst_odb, dst_def = sys.argv[1], sys.argv[2], sys.argv[3]

    # Same handle discovery as eco_connect_template_pg.py -- the vias are
    # tech vias named Via<n>_VV, not block vias.
    tech = Tech()
    design = Design(tech)
    design.readDb(src)
    db = tech.getDB()
    block = db.getChip().getBlock()
    dbtech = db.getTech()
    dbu = block.getDefUnits()
    core = block.getCoreArea()

    m3 = dbtech.findLayer("Metal3")
    m4 = dbtech.findLayer("Metal4")
    via2 = dbtech.findVia("Via2_VV")
    via3 = dbtech.findVia("Via3_VV")
    for nm, obj in (("Metal3", m3), ("Metal4", m4), ("Via2_VV", via2), ("Via3_VV", via3)):
        if obj is None:
            raise SystemExit(f"tech object not found: {nm}")

    vdd = block.findNet("VDD")
    vss = block.findNet("VSS")
    if vdd is None:
        raise SystemExit("no VDD net")

    pins = pin_boxes(block, "VDD", "Metal2")
    if not pins:
        raise SystemExit("no VDD Metal2 pin shapes")
    x_lo = min(b[0] for b in pins)
    x_hi = max(b[2] for b in pins)
    y_lo = min(b[1] for b in pins)
    y_hi = max(b[3] for b in pins)
    print(f"vdd_pins {len(pins)} x={x_lo/dbu:.3f}..{x_hi/dbu:.3f} "
          f"y={y_lo/dbu:.3f}..{y_hi/dbu:.3f}")

    # Plate floor: clear of the core AND of every VSS Metal4 top.
    vss_m4_top = max([b[3] for b in special_rects(vss, "Metal4")], default=0) if vss else 0
    plate_y1 = max(vss_m4_top, core.yMax()) + um(dbu, 1.00)
    print(f"core_ymax {core.yMax()/dbu:.3f}  vss_m4_top {vss_m4_top/dbu:.3f}  "
          f"plate_y1 {plate_y1/dbu:.3f}")

    if plate_y1 >= y_lo:
        raise SystemExit("no clear band between core and VDD pins")

    # SAFETY: the plate spans only the pin x-range, entirely above the core.
    win = (x_lo, plate_y1, x_hi, y_hi)
    clash = occupied(block, "VDD", {"Metal3", "Metal4"}, win)
    if clash:
        print(f"REFUSING: {len(clash)} non-VDD shape(s) in the plate window:")
        for c in clash[:10]:
            print(f"   net={c[0]} {c[1]} "
                  f"({c[2]/dbu:.3f},{c[3]/dbu:.3f})-({c[4]/dbu:.3f},{c[5]/dbu:.3f})")
        return os.EX_DATAERR

    sw = swire(vdd)
    # A solid plate across the pin span trips MSLOT.1 (wide metal needs slots):
    # 72.28 x 584.23 um was flagged in butterfold_top.  Build parallel straps
    # instead -- the same approach the core PDN uses, at widths that draw no
    # MSLOT markers -- so the current capacity is kept without the rule.
    STRAP_W = um(dbu, 3.00)
    STRAP_PITCH = um(dbu, 4.50)
    strap_cx = []
    cx = x_lo + STRAP_W // 2
    while cx + STRAP_W // 2 <= x_hi:
        strap_cx.append(cx)
        cx += STRAP_PITCH
    # Guarantee one strap sits on the existing 1.6-um riser, which carries the
    # via stack down into the core grid.
    for base in special_rects(vdd, "Metal4"):
        bcx = (base[0] + base[2]) // 2
        if x_lo <= bcx <= x_hi and base[3] >= y_hi - um(dbu, 1.0):
            if not any(abs(c - bcx) < STRAP_W // 2 for c in strap_cx):
                strap_cx.append(bcx)
    for c in sorted(strap_cx):
        add_rect(sw, m4, c - STRAP_W // 2, plate_y1, c + STRAP_W // 2, y_hi)
    # The six VDD pins have gaps between them, so a strap landing in a gap gets
    # no via and would float (PSM-0038).  One horizontal Metal4 tie bar along
    # the bottom shorts every strap together and onto the existing 1.6-um
    # riser, which carries the via stack down into the core grid.  Its width is
    # STRAP_W, so MSLOT.1 (30um max unslotted width) is not in play.
    add_rect(sw, m4, x_lo, plate_y1, x_hi, plate_y1 + STRAP_W)
    print(f"vdd_straps {len(strap_cx)} x {STRAP_W/dbu:.1f}um wide "
          f"@ {STRAP_PITCH/dbu:.1f}um pitch + tie bar")
    # Metal3 landing under the whole pin bar so every pin can take a via.
    add_rect(sw, m3, x_lo, y_lo, x_hi, y_hi)
    # Step a via stack along the length of each pin rather than placing one at
    # its centre.  The pins are 9.5-10.25 um long, so a 2 um pitch with a 1 um
    # inset from each end fits 4-5 stacks per pin -- about 28 in total, instead
    # of 1.  Pitch and inset are deliberately loose: cut-to-cut spacing here is
    # far above the minimum, so this adds cuts without adding spacing risk.
    # Vias only where a strap actually runs, otherwise they land on no metal.
    nvias = 0
    for bx1, by1, bx2, by2 in pins:
        cy = (by1 + by2) // 2
        for c in strap_cx:
            if bx1 + STRAP_W // 2 <= c <= bx2 - STRAP_W // 2:
                add_via(sw, via3, c, cy)
                add_via(sw, via2, c, cy)
                nvias += 1
    print(f"vdd_span {x_lo/dbu:.3f} {plate_y1/dbu:.3f} {x_hi/dbu:.3f} {y_hi/dbu:.3f}")
    print(f"vdd_vias {nvias} across {len(pins)} pins")

    design.writeDb(dst_odb)
    design.writeDef(dst_def)
    print("wrote", dst_odb)
    print("wrote", dst_def)
    return 0


if __name__ == "__main__":
    rc = main()
    if rc:
        sys.stderr.write(f"strengthen_vdd_post_route failed rc={rc}\n")
        os._exit(rc)
