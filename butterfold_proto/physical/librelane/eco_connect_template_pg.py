#!/usr/bin/env python3
"""Connect official ACH Metal2 VDD/VSS pin shapes to the core PDN.

PDN is generated before ApplyDEFTemplate, so template M2 power ports sit
in the die margin and are not via'd to Metal4. Extend Metal4 to the VDD
north ports and Metal2 to the VSS west ports, then drop Via2/Via3.
"""
from openroad import Tech, Design
import odb
import sys

src = sys.argv[1]
dst_odb = sys.argv[2]
dst_def = sys.argv[3]

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
via2 = dbtech.findVia("Via2_VV")
via3 = dbtech.findVia("Via3_VV")
assert m2 and m3 and m4 and via2 and via3


def um(v):
    return int(round(v * dbu))


def pin_boxes(name):
    bt = block.findBTerm(name)
    boxes = []
    for bp in bt.getBPins():
        for box in bp.getBoxes():
            boxes.append(
                (box.getTechLayer().getName(), box.xMin(), box.yMin(), box.xMax(), box.yMax())
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


# --- VDD: stitch official M2 ports, extend M4 stripe up, via at overlap ---
vdd = block.findNet("VDD")
sw_vdd = swire(vdd)
m4_x1, m4_x2 = um(636.64), um(638.24)
vdd_boxes = [b for b in pin_boxes("VDD") if b[0] == "Metal2"]
x_lo = min(b[1] for b in vdd_boxes)
x_hi = max(b[3] for b in vdd_boxes)
y_lo = min(b[2] for b in vdd_boxes)
y_hi = max(b[4] for b in vdd_boxes)
add_rect(sw_vdd, m2, x_lo, y_lo, x_hi, y_hi)
add_rect(sw_vdd, m4, m4_x1, um(1653.12), m4_x2, um(1675.0))
add_rect(sw_vdd, m3, m4_x1, y_lo, m4_x2, y_hi)
cx = (m4_x1 + m4_x2) // 2
cy = (y_lo + y_hi) // 2
add_via(sw_vdd, via3, cx, cy)
add_via(sw_vdd, via2, cx, cy)

# --- VSS: west-margin M3 bus to a VSS M5 landing, never crossing VDD M4 ---
# VDD Metal4 sits at x=22.24..23.84. Any VSS M2/M3 across that X shorts
# through Mag GDS PDN vias. Drop onto existing VSS Metal5 at y=39.31
# using an M4 pad at x=8.00 (core, west of VDD M4).
vss = block.findNet("VSS")
sw_vss = swire(vss)
via4 = dbtech.findVia("Via4_VV")
assert via4
vss_pins = [b for b in pin_boxes("VSS") if b[0] == "Metal2"]
ymin = min(b[2] for b in vss_pins)
ymax = max(b[4] for b in vss_pins)
m5_y1, m5_y2 = um(39.31), um(40.91)
pad_x1, pad_x2 = um(8.00), um(9.60)
add_rect(sw_vss, m3, um(0.0), min(ymin, m5_y1), um(1.0), ymax)
add_rect(sw_vss, m3, um(0.0), m5_y1, pad_x2, m5_y2)
add_rect(sw_vss, m4, pad_x1, m5_y1, pad_x2, m5_y2)
cx_pad = (pad_x1 + pad_x2) // 2
cy_pad = (m5_y1 + m5_y2) // 2
add_via(sw_vss, via3, cx_pad, cy_pad)
add_via(sw_vss, via4, cx_pad, cy_pad)
for layer, x1, y1, x2, y2 in vss_pins:
    add_via(sw_vss, via2, (x1 + x2) // 2, (y1 + y2) // 2)

design.writeDb(dst_odb)
design.writeDef(dst_def)
print("wrote", dst_odb)
print("wrote", dst_def)
