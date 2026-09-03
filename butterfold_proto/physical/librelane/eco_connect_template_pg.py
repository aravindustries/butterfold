#!/usr/bin/env python3
"""Connect official ACH Metal2 VDD/VSS pin shapes to the compact-core PDN.

LibreLane generates PDN before ApplyDEFTemplate, so the organizer M2 power
ports sit on the validation DIE envelope and are not via'd to the core grid.

This script discovers the actual PDN geometry in the current ODB. It does
not reuse stale D03 coordinates from the old 1675-um-tall core.

VDD (north envelope pins):
  stitch official M2 ports together, extend a VDD Metal4 stripe from the
  compact-core PDN up to the pin Y, then drop Via2/Via3 at the overlap.

VSS (west envelope pins):
  stay west of the leftmost VDD Metal4 stripe. M3 west-margin bus onto an
  M4 pad over an existing VSS Metal5 stripe, Via2 at each pin.
"""
from __future__ import annotations

import os
import sys

from openroad import Design, Tech
import odb


def um(dbu, v):
    return int(round(v * dbu))


def pin_boxes(block, name, layer_name=None):
    bt = block.findBTerm(name)
    if bt is None:
        raise SystemExit(f"missing bterm {name}")
    boxes = []
    for bp in bt.getBPins():
        for box in bp.getBoxes():
            layer = box.getTechLayer()
            if layer is None:
                continue
            if layer_name and layer.getName() != layer_name:
                continue
            boxes.append(
                (layer.getName(), box.xMin(), box.yMin(), box.xMax(), box.yMax())
            )
    return boxes


def swire(net):
    sws = net.getSWires()
    if sws:
        return sws[0]
    return odb.dbSWire.create(net, "NONE")


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


def pick_vdd_m4(vdd_m4, pin_xlo, pin_xhi, core_ymax):
    """Prefer a VDD M4 stripe overlapping the north pin X-range, inside core."""
    overlapping = []
    for x1, y1, x2, y2 in vdd_m4:
        if x2 < pin_xlo or x1 > pin_xhi:
            continue
        overlapping.append((x1, y1, x2, y2))
    if not overlapping:
        overlapping = list(vdd_m4)
    # Prefer stripes that already reach near the top of the compact core.
    overlapping.sort(key=lambda b: (-min(b[3], core_ymax), -(b[3] - b[1]), b[0]))
    return overlapping[0]


def pick_vss_m5(vss_m5, core_xmin, vdd_m4_xmin, clearance):
    """VSS Metal5 landing west of VDD M4, inside compact core."""
    west_limit = vdd_m4_xmin - clearance
    candidates = []
    for x1, y1, x2, y2 in vss_m5:
        if x2 <= west_limit and x2 > core_xmin:
            candidates.append((x1, y1, x2, y2))
    if not candidates:
        # Fall back to any M5 whose xMin is still west of VDD M4.
        for x1, y1, x2, y2 in vss_m5:
            if x1 < vdd_m4_xmin:
                candidates.append((x1, y1, x2, y2))
    if not candidates:
        raise SystemExit("no VSS Metal5 west of VDD Metal4")
    # Nearest the south-west corner of the core, matching the proven landing.
    candidates.sort(key=lambda b: (b[1], b[0]))
    return candidates[0]


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: eco_connect_template_pg.py <in.odb> <out.odb> <out.def>")
        return 2
    src, dst_odb, dst_def = sys.argv[1], sys.argv[2], sys.argv[3]

    tech = Tech()
    design = Design(tech)
    design.readDb(src)
    db = tech.getDB()
    block = db.getChip().getBlock()
    dbtech = db.getTech()
    dbu = block.getDefUnits()

    m2 = dbtech.findLayer("Metal2")
    m3 = dbtech.findLayer("Metal3")
    m4 = dbtech.findLayer("Metal4")
    m5 = dbtech.findLayer("Metal5")
    via2 = dbtech.findVia("Via2_VV")
    via3 = dbtech.findVia("Via3_VV")
    via4 = dbtech.findVia("Via4_VV")
    assert m2 and m3 and m4 and m5 and via2 and via3 and via4

    core = block.getCoreArea()
    die = block.getDieArea()
    print(
        f"die_um {die.xMin()/dbu:.3f} {die.yMin()/dbu:.3f} {die.xMax()/dbu:.3f} {die.yMax()/dbu:.3f}"
    )
    print(
        f"core_um {core.xMin()/dbu:.3f} {core.yMin()/dbu:.3f} {core.xMax()/dbu:.3f} {core.yMax()/dbu:.3f}"
    )

    # --- VDD ---
    vdd = block.findNet("VDD")
    sw_vdd = swire(vdd)
    vdd_boxes = pin_boxes(block, "VDD", "Metal2")
    if not vdd_boxes:
        raise SystemExit("no VDD Metal2 pin boxes")
    x_lo = min(b[1] for b in vdd_boxes)
    x_hi = max(b[3] for b in vdd_boxes)
    y_lo = min(b[2] for b in vdd_boxes)
    y_hi = max(b[4] for b in vdd_boxes)
    print(
        f"vdd_pins {len(vdd_boxes)} x={x_lo/dbu:.3f}..{x_hi/dbu:.3f} y={y_lo/dbu:.3f}..{y_hi/dbu:.3f}"
    )

    vdd_m4 = special_rects(vdd, "Metal4")
    if not vdd_m4:
        raise SystemExit("no VDD Metal4 special wires")
    stripe = pick_vdd_m4(vdd_m4, x_lo, x_hi, core.yMax())
    m4_x1, m4_y1, m4_x2, m4_y2 = stripe
    print(
        f"vdd_m4_stripe {m4_x1/dbu:.3f} {m4_y1/dbu:.3f} {m4_x2/dbu:.3f} {m4_y2/dbu:.3f}"
    )

    # The core PDN drops only ONE VDD Metal4 stripe under the pin span, so the
    # original single via + 1.6-um riser carried the entire chip supply
    # ("you're powering your whole project through 1 via" -- review comment).
    # The band above the core is free: every VSS Metal4 stripe stops at the
    # core top and there is no signal M4/M5 routing there.  Build a wide plate
    # in that band, tab several core stripes into it, and via EVERY pin.
    add_rect(sw_vdd, m2, x_lo, y_lo, x_hi, y_hi)

    vss_probe = block.findNet("VSS")
    vss_m4_top = 0
    if vss_probe is not None:
        for b in special_rects(vss_probe, "Metal4"):
            vss_m4_top = max(vss_m4_top, b[3])
    # Clear every VSS Metal4 top by 1 um -- never overlap the other supply.
    plate_y1 = max(vss_m4_top, core.yMax()) + um(dbu, 1.00)
    plate_y2 = y_lo - um(dbu, 2.00)        # stop short of the pin row

    # Full-height core stripes within reach of the pin span.
    reach = um(dbu, 160.0)
    feeders = [
        b for b in vdd_m4
        if b[0] >= x_lo - reach and b[2] <= x_hi + reach
        and b[3] >= core.yMax() - um(dbu, 5.0)
    ]
    if not feeders:
        feeders = [stripe]

    if plate_y2 > plate_y1:
        plate_x1 = min(b[0] for b in feeders)
        plate_x2 = max(b[2] for b in feeders)
        add_rect(sw_vdd, m4, plate_x1, plate_y1, plate_x2, plate_y2)
        for b in feeders:
            add_rect(sw_vdd, m4, b[0], min(b[3], plate_y1), b[2], plate_y1)
        # Riser spans ONLY the pin x-range, so no metal reaches the die edge
        # at an x where the organizer defined no pin.
        add_rect(sw_vdd, m4, x_lo, plate_y2, x_hi, y_hi)
        print(
            f"vdd_plate {plate_x1/dbu:.3f} {plate_y1/dbu:.3f} "
            f"{plate_x2/dbu:.3f} {plate_y2/dbu:.3f} feeders={len(feeders)}"
        )
    else:
        extend_from = max(m4_y1, min(m4_y2, core.yMax()))
        add_rect(sw_vdd, m4, m4_x1, extend_from, m4_x2, y_hi)
        print("vdd_plate skipped: no clear band, single stripe retained")

    add_rect(sw_vdd, m3, x_lo, y_lo, x_hi, y_hi)
    for _, bx1, by1, bx2, by2 in vdd_boxes:
        add_via(sw_vdd, via3, (bx1 + bx2) // 2, (by1 + by2) // 2)
        add_via(sw_vdd, via2, (bx1 + bx2) // 2, (by1 + by2) // 2)
    print(f"vdd_vias {len(vdd_boxes)}")

    # --- VSS ---
    vss = block.findNet("VSS")
    sw_vss = swire(vss)
    vss_pins = pin_boxes(block, "VSS", "Metal2")
    if not vss_pins:
        raise SystemExit("no VSS Metal2 pin boxes")
    ymin = min(b[2] for b in vss_pins)
    ymax = max(b[4] for b in vss_pins)
    print(
        f"vss_pins {len(vss_pins)} y={ymin/dbu:.3f}..{ymax/dbu:.3f}"
    )

    vdd_m4_xmin = min(b[0] for b in vdd_m4)
    print(f"leftmost_vdd_m4_x {vdd_m4_xmin/dbu:.3f}")
    vss_m5 = special_rects(vss, "Metal5")
    if not vss_m5:
        raise SystemExit("no VSS Metal5 special wires")
    m5_box = pick_vss_m5(vss_m5, core.xMin(), vdd_m4_xmin, um(dbu, 1.00))
    print(
        f"vss_m5_land {m5_box[0]/dbu:.3f} {m5_box[1]/dbu:.3f} {m5_box[2]/dbu:.3f} {m5_box[3]/dbu:.3f}"
    )

    # Proven west-margin M4 pad: 8.00..9.60, well west of VDD M4 at ~22.24.
    # Do not snug against the VDD M4 stripe; that historically shorted VSS/VDD.
    pad_x1 = um(dbu, 8.00)
    pad_x2 = um(dbu, 9.60)
    if pad_x2 >= vdd_m4_xmin - um(dbu, 2.00):
        raise SystemExit("VSS M4 pad would be too close to VDD Metal4")
    if pad_x1 < core.xMin() or pad_x2 > m5_box[2]:
        raise SystemExit("VSS M4 pad not over VSS Metal5 / inside core")
    pad_y1, pad_y2 = m5_box[1], m5_box[3]
    # Metal in the x=0..1 um pin column must exist ONLY where the organizer
    # actually placed a pin.  Metal that reaches the block boundary at a y with
    # no pin sits a fraction of a micron from padring metal once the block is
    # integrated, and trips minimum spacing (reported by LuighiV on the
    # previous submission: "a long metal strip close to a pad violating a
    # minimum distance").  So: keep the edge column to the pin span, and run
    # inward from x >= 1 um to reach the M4 landing pad.
    EDGE_KEEPOUT = um(dbu, 1.0)
    # A: edge-column bus, pin span only -- Via2 lands at each pin centre x=0.5
    add_rect(sw_vss, m3, um(dbu, 0.0), ymin, um(dbu, 1.5), ymax)
    # B: vertical drop to pad level, inboard of the boundary, overlapping A
    add_rect(sw_vss, m3, EDGE_KEEPOUT, pad_y1, um(dbu, 2.0), ymax)
    # C: horizontal run to the M4 pad, no longer touching x=0
    add_rect(sw_vss, m3, EDGE_KEEPOUT, pad_y1, pad_x2, pad_y2)
    add_rect(sw_vss, m4, pad_x1, pad_y1, pad_x2, pad_y2)
    cx_pad = (pad_x1 + pad_x2) // 2
    cy_pad = (pad_y1 + pad_y2) // 2
    add_via(sw_vss, via3, cx_pad, cy_pad)
    add_via(sw_vss, via4, cx_pad, cy_pad)
    print(f"vss_pad {pad_x1/dbu:.3f} {pad_y1/dbu:.3f} {pad_x2/dbu:.3f} {pad_y2/dbu:.3f}")
    for _, x1, y1, x2, y2 in vss_pins:
        add_via(sw_vss, via2, (x1 + x2) // 2, (y1 + y2) // 2)

    design.writeDb(dst_odb)
    design.writeDef(dst_def)
    print("wrote", dst_odb)
    print("wrote", dst_def)
    return 0


if __name__ == "__main__":
    # OpenROAD -python treats SystemExit as a crash; end cleanly.
    rc = main()
    if rc:
        sys.stderr.write(f"eco_connect_template_pg failed rc={rc}\n")
        os._exit(rc)
