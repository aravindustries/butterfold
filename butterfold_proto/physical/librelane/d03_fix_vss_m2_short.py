#!/usr/bin/env python3
"""Connect ACH VSS M2 pins without crossing the VDD Metal4 stripe.

Original stitch drew VSS Metal2/Metal3 from x=0 to x=27.14, covering the
VDD M4 stripe at x=22.24..23.84. Mag GDS vias on that stripe shorted VDD
to VSS.

New path stays west of x=22.24:
  pin M2 -> Via2 -> M3 west-margin bus -> M4 pad @ (8.0, 39.31) -> Via4
  -> existing VSS Metal5 stripe (y=39.31..40.91).
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


def um(v):
    return int(round(v * dbu))


m3 = dbtech.findLayer("Metal3")
m4 = dbtech.findLayer("Metal4")
via2 = dbtech.findVia("Via2_VV")
via3 = dbtech.findVia("Via3_VV")
via4 = dbtech.findVia("Via4_VV")
assert m3 and m4 and via2 and via3 and via4

vss = block.findNet("VSS")
sw = vss.getSWires()[0]

removed_m2 = 0
removed_via2 = 0
removed_m3 = 0
for box in list(sw.getWires()):
    layer = box.getTechLayer()
    via = box.getTechVia()
    if layer is not None and layer.getName() == "Metal2" and box.xMax() > um(2.0):
        odb.dbSBox.destroy(box)
        removed_m2 += 1
        continue
    if layer is not None and layer.getName() == "Metal3":
        # drop pin-Y M3 jumpers that cross VDD M4 (xMax > 10 µm and xMin < 20)
        if box.xMin() < um(5.0) and box.xMax() > um(10.0):
            odb.dbSBox.destroy(box)
            removed_m3 += 1
            continue
    if via is not None and via.getName() == "Via2_VV":
        cx = 0.5 * (box.xMin() + box.xMax()) / dbu
        if 24.0 < cx < 28.0:
            odb.dbSBox.destroy(box)
            removed_via2 += 1
print("removed_m2", removed_m2, "removed_m3_cross", removed_m3, "removed_via2_m4", removed_via2)

pins = []
bt = block.findBTerm("VSS")
for bp in bt.getBPins():
    for box in bp.getBoxes():
        if box.getTechLayer().getName() == "Metal2":
            pins.append((box.xMin(), box.yMin(), box.xMax(), box.yMax()))
ymin = min(p[1] for p in pins)
ymax = max(p[3] for p in pins)
print("vss_pins", len(pins), "y", ymin / dbu, ymax / dbu)

# VSS Metal5 stripe nearest the south: y=39.31..40.91
m5_y1, m5_y2 = um(39.31), um(40.91)
# M4 landing west of VDD M4 (22.24) and inside core (6.72)
pad_x1, pad_x2 = um(8.00), um(9.60)
pad_y1, pad_y2 = m5_y1, m5_y2

# M3 vertical bus in the west pin column
odb.dbSBox.create(sw, m3, um(0.0), min(ymin, m5_y1), um(1.0), ymax, "NONE")
# M3 east to the M4 pad (stops at 9.60, well west of VDD M4)
odb.dbSBox.create(sw, m3, um(0.0), m5_y1, pad_x2, m5_y2, "NONE")
# M4 pad on VSS M5
odb.dbSBox.create(sw, m4, pad_x1, pad_y1, pad_x2, pad_y2, "NONE")
cx = (pad_x1 + pad_x2) // 2
cy = (pad_y1 + pad_y2) // 2
odb.dbSBox.create(sw, via3, int(cx), int(cy), "NONE")
odb.dbSBox.create(sw, via4, int(cx), int(cy), "NONE")
print("pad", pad_x1 / dbu, pad_y1 / dbu, pad_x2 / dbu, pad_y2 / dbu)

for x1, y1, x2, y2 in pins:
    cx_pin = (x1 + x2) // 2
    cy_pin = (y1 + y2) // 2
    odb.dbSBox.create(sw, via2, int(cx_pin), int(cy_pin), "NONE")
    print("via2_pin", cx_pin / dbu, cy_pin / dbu)

design.writeDb(dst_odb)
design.writeDef(dst_def)
print("wrote", dst_odb)
print("wrote", dst_def)
