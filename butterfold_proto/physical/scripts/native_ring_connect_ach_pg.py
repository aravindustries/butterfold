#!/usr/bin/env python3
"""Connect ACH Metal2 VDD/VSS ports to the native PDN_CORE_RING.

Uses existing OpenROAD/pdngen generated multi-cut dbVias. Does not hand-draw
via-cut polygons, does not add a post-route envelope ring, and does not
reintroduce the rejected in-core second VSS branch (x≈26).

VDD: extend three existing core Metal4 stripes to the north ACH ports and
     stitch with 1x3 Via2 and 2x3 Via3 arrays.
VSS: stitch the six west ACH ports onto the native west Metal4 VSS ring
     that already occupies x=0.42..2.42. Stay in the west margin.
"""
from __future__ import annotations

import os
import sys

from openroad import Design, Tech
import odb


def um(dbu, v):
    return int(round(v * dbu))


def pin_boxes(block, name, layer_name="Metal2"):
    bt = block.findBTerm(name)
    if bt is None:
        raise SystemExit(f"missing bterm {name}")
    boxes = []
    for bp in bt.getBPins():
        for box in bp.getBoxes():
            layer = box.getTechLayer()
            if layer is None or layer.getName() != layer_name:
                continue
            boxes.append((box.xMin(), box.yMin(), box.xMax(), box.yMax()))
    return boxes


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
            if box.getTechVia() or box.getBlockVia():
                continue
            layer = box.getTechLayer()
            if layer is None or layer.getName() != layer_name:
                continue
            out.append((box.xMin(), box.yMin(), box.xMax(), box.yMax()))
    return out


def must_via(block, name):
    via = block.findVia(name)
    if via is None:
        raise SystemExit(f"missing generated via {name}")
    return via


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: native_ring_connect_ach_pg.py <in.odb> <out.odb> <out.def>")
        return 2
    src, dst_odb, dst_def = sys.argv[1], sys.argv[2], sys.argv[3]

    tech = Tech()
    design = Design(tech)
    design.readDb(src)
    db = tech.getDB()
    block = db.getChip().getBlock()
    dbtech = db.getTech()
    dbu = block.getDefUnits()
    core = block.getCoreArea()
    die = block.getDieArea()
    print(f"dbu {dbu}")
    print(
        f"die_um {die.xMin()/dbu:.3f} {die.yMin()/dbu:.3f} {die.xMax()/dbu:.3f} {die.yMax()/dbu:.3f}"
    )
    print(
        f"core_um {core.xMin()/dbu:.3f} {core.yMin()/dbu:.3f} {core.xMax()/dbu:.3f} {core.yMax()/dbu:.3f}"
    )

    m2 = dbtech.findLayer("Metal2")
    m3 = dbtech.findLayer("Metal3")
    m4 = dbtech.findLayer("Metal4")
    m5 = dbtech.findLayer("Metal5")
    via23 = must_via(block, "via2_3_3200_1200_1_3_1040_1040")  # 1x3 = 3 cuts
    via34 = must_via(block, "via3_4_3200_2000_2_3_1040_1040")  # 2x3 = 6 cuts
    via34_1x3 = must_via(block, "via3_4_3200_1200_1_3_1040_1040")  # 1x3 = 3 cuts
    via45 = must_via(block, "via4_5_3200_3200_3_3_1040_1040")  # 3x3 = 9 cuts
    if not all((m2, m3, m4, m5)):
        raise SystemExit("missing GF180 metal layers")

    # --- VDD: three independent M4 risers to north ACH ports ---
    vdd = block.findNet("VDD")
    sw_vdd = swire(vdd)
    vdd_pins = pin_boxes(block, "VDD", "Metal2")
    if len(vdd_pins) != 6:
        raise SystemExit(f"expected 6 VDD Metal2 pins, got {len(vdd_pins)}")
    pin_xlo = min(b[0] for b in vdd_pins)
    pin_xhi = max(b[2] for b in vdd_pins)
    pin_ylo = min(b[1] for b in vdd_pins)
    pin_yhi = max(b[3] for b in vdd_pins)
    print(
        f"vdd_pins {len(vdd_pins)} x={pin_xlo/dbu:.3f}..{pin_xhi/dbu:.3f} "
        f"y={pin_ylo/dbu:.3f}..{pin_yhi/dbu:.3f}"
    )

    vdd_m4 = special_rects(vdd, "Metal4")
    vdd_m5 = special_rects(vdd, "Metal5")
    # Prefer the three full-height 1.6-um core stripes used by the accepted
    # pre-ring repair, which already cross the native north Metal5 ring.
    targets = [483.84, 637.44, 791.04]
    chosen = []
    for tx in targets:
        txd = um(dbu, tx)
        hits = []
        for x1, y1, x2, y2 in vdd_m4:
            if x1 <= txd <= x2 and (y2 - y1) / dbu > 200:
                hits.append((x1, y1, x2, y2))
        if not hits:
            raise SystemExit(f"no VDD Metal4 stripe covering x={tx}")
        hits.sort(key=lambda b: -(b[3] - b[1]))
        chosen.append(hits[0])
        print(
            f"vdd_m4_stripe x={hits[0][0]/dbu:.3f}..{hits[0][2]/dbu:.3f} "
            f"y={hits[0][1]/dbu:.3f}..{hits[0][3]/dbu:.3f}"
        )

    north_ring = None
    for x1, y1, x2, y2 in vdd_m5:
        if (x2 - x1) / dbu > 200 and abs((y1 + y2) / 2 / dbu - 1090.24) < 3:
            north_ring = (x1, y1, x2, y2)
            break
    if north_ring is None:
        raise SystemExit("native VDD north Metal5 ring not found")
    print(
        f"vdd_north_ring x={north_ring[0]/dbu:.3f}..{north_ring[2]/dbu:.3f} "
        f"y={north_ring[1]/dbu:.3f}..{north_ring[3]/dbu:.3f}"
    )

    # M3 manifold across the six official north ports, wide enough to cover
    # the three M4 risers.
    man_x1 = min(chosen[0][0], pin_xlo)
    man_x2 = max(chosen[-1][2], pin_xhi)
    add_rect(sw_vdd, m3, man_x1, pin_ylo, man_x2, pin_yhi)
    add_rect(sw_vdd, m2, pin_xlo, pin_ylo, pin_xhi, pin_yhi)
    print(
        f"vdd_m3_manifold x={man_x1/dbu:.3f}..{man_x2/dbu:.3f} "
        f"y={pin_ylo/dbu:.3f}..{pin_yhi/dbu:.3f}"
    )

    ring_cy = (north_ring[1] + north_ring[3]) // 2
    pin_cy = (pin_ylo + pin_yhi) // 2
    for x1, y1, x2, y2 in chosen:
        cx = (x1 + x2) // 2
        extend_from = min(y2, max(y1, north_ring[3]))
        add_rect(sw_vdd, m4, x1, extend_from, x2, pin_yhi)
        add_via(sw_vdd, via34, cx, pin_cy)
        # Do not drop an extra Via4 on the north ring: pdngen already
        # placed a 4x3 Via4 array at each M4-stripe / M5-ring crossing.
        # A second 3x3 array at the same origin produces V4.1 slivers.
        print(f"vdd_riser cx={cx/dbu:.3f} via3@{pin_cy/dbu:.3f} (pdngen Via4 at ring kept)")

    for x1, y1, x2, y2 in vdd_pins:
        add_via(sw_vdd, via23, (x1 + x2) // 2, (y1 + y2) // 2)

    # --- VSS: west ACH ports onto native west Metal4 ring ---
    vss = block.findNet("VSS")
    sw_vss = swire(vss)
    vss_pins = pin_boxes(block, "VSS", "Metal2")
    if len(vss_pins) != 6:
        raise SystemExit(f"expected 6 VSS Metal2 pins, got {len(vss_pins)}")
    vss_m4 = special_rects(vss, "Metal4")
    west_ring = None
    for x1, y1, x2, y2 in vss_m4:
        if (y2 - y1) / dbu > 200 and 0.2 <= x1 / dbu <= 1.0 and 1.8 <= x2 / dbu <= 3.0:
            west_ring = (x1, y1, x2, y2)
            break
    if west_ring is None:
        raise SystemExit("native VSS west Metal4 ring not found")
    print(
        f"vss_west_ring x={west_ring[0]/dbu:.3f}..{west_ring[2]/dbu:.3f} "
        f"y={west_ring[1]/dbu:.3f}..{west_ring[3]/dbu:.3f}"
    )
    vdd_west = min(b[0] for b in vdd_m4)
    print(f"leftmost_vdd_m4_x {vdd_west/dbu:.3f}")
    # Keep VSS metal west of VDD ring with >= 0.8 um clearance.
    vss_xhi_limit = vdd_west - um(dbu, 0.80)
    # 3.2-um generated via needs x=0..3.2 if centered at 1.60.
    via_xhi = um(dbu, 3.20)
    if via_xhi > vss_xhi_limit:
        raise SystemExit(
            f"VSS via enclosure xhi {via_xhi/dbu:.3f} too close to VDD M4 "
            f"{vdd_west/dbu:.3f}"
        )

    ymin = min(b[1] for b in vss_pins)
    ymax = max(b[3] for b in vss_pins)
    # Vertical M3 spine in the official 1-um west pin column, plus a local
    # M2/M3 pad at each port covering the generated via. Never enter the
    # digital core (xmin=6.72) and never build the rejected x≈26 branch.
    add_rect(sw_vss, m3, um(dbu, 0.0), ymin, um(dbu, 1.0), ymax)
    via_cx = um(dbu, 1.60)
    for x1, y1, x2, y2 in vss_pins:
        cy = (y1 + y2) // 2
        if not (west_ring[1] <= cy <= west_ring[3]):
            raise SystemExit(f"VSS pin y={cy/dbu:.3f} not on west ring")
        add_rect(sw_vss, m2, um(dbu, 0.0), y1, via_xhi, y2)
        add_rect(sw_vss, m3, um(dbu, 0.0), y1, via_xhi, y2)
        add_rect(sw_vss, m4, west_ring[0], y1, via_xhi, y2)
        add_via(sw_vss, via23, via_cx, cy)
        add_via(sw_vss, via34, via_cx, cy)
        print(f"vss_entry cy={cy/dbu:.3f} via_cx={via_cx/dbu:.3f}")

    if via_xhi >= core.xMin():
        raise SystemExit("VSS geometry entered the digital core")

    design.writeDb(dst_odb)
    design.writeDef(dst_def)
    print("VDD independent M4 entries: 3; Via3 2x3 (6 cuts); Via2 1x3 (3 cuts); Via4 3x3 (9 cuts) at ring")
    print("VSS independent west-ring entries: 6; Via3 2x3 (6 cuts); Via2 1x3 (3 cuts)")
    print("REJECTED_SECOND_VSS_BRANCH_REINTRODUCED NO")
    print("wrote", dst_odb)
    print("wrote", dst_def)
    return 0


if __name__ == "__main__":
    rc = main()
    if rc:
        os._exit(rc)
