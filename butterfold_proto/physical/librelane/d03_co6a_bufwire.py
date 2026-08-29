#!/usr/bin/env python3
"""Insert buf_3 in leftover sites on co6a27 (DRT_OK) without TritonRoute.

Keep existing ZN routes. Add manhattan M2 + Via1 for:
  aoi ZN -> buf I  (new net)
  buf Z  -> aoi ZN avg XY (tap onto kept ZN route)
"""
from openroad import Tech, Design
import odb

pdk = "/foss/pdks/gf180mcuD"
tech = Tech()
tech.readLef(pdk + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef")
tech.readLef(pdk + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef")
tech.readLef(pdk + "/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef")
d = Design(tech)
d.readDb("physical/results/d03_ach_candidate/butterfold_top_co6a27.odb")
db = tech.getDB()
block = db.getChip().getBlock()
ttech = db.getTech()
m1 = ttech.findLayer("Metal1")
m2 = ttech.findLayer("Metal2")
via1 = ttech.findVia("Via1_VV")
assert m1 and m2 and via1
dbu = block.getDefUnits()
bufm = db.findMaster("gf180mcu_fd_sc_mcu9t5v0__buf_3")
insts = [
    "_11280_",
    "_11106_",
    "_11366_",
    "_11339_",
    "_11136_",
    "_11474_",
    "_11394_",
    "_11408_",
    "_11241_",
]


def manhattan_m2(net, x1, y1, x2, y2):
    w = odb.dbWire.create(net)
    e = odb.dbWireEncoder()
    e.begin(w)
    e.newPath(m1, "ROUTED")
    e.addPoint(int(x1), int(y1))
    e.addTechVia(via1)
    e.newPath(m2, "ROUTED")
    e.addPoint(int(x1), int(y1))
    if x1 != x2 and y1 != y2:
        e.addPoint(int(x2), int(y1))
    e.addPoint(int(x2), int(y2))
    e.addTechVia(via1)
    e.end()


gap = int(round(5.60 * dbu))
for name in insts:
    aoi = block.findInst(name)
    bb = aoi.getBBox()
    gx1, gy1, gx2, gy2 = bb.xMax(), bb.yMin(), bb.xMax() + gap, bb.yMax()
    kill = []
    for inst in block.getInsts():
        ib = inst.getBBox()
        if inst.getName() == name:
            continue
        if ib.xMin() >= gx1 and ib.xMax() <= gx2 and ib.yMin() >= gy1 and ib.yMax() <= gy2:
            kill.append(inst)
    for inst in kill:
        print("KILL", inst.getName(), inst.getMaster().getName())
        odb.dbInst.destroy(inst)
    bname = "co6a_buf_" + name
    ni = odb.dbInst.create(block, bufm, bname)
    ni.setOrient(aoi.getOrient())
    ni.setLocation(gx1, gy1)
    ni.setPlacementStatus("FIRM")
    zt = aoi.findITerm("ZN")
    old = zt.getNet()
    tap = zt.getAvgXY()
    mid = odb.dbNet.create(block, "co6a_mid_" + name)
    zt.disconnect()
    zt.connect(mid)
    ni.findITerm("I").connect(mid)
    ni.findITerm("Z").connect(old)
    xy_zn = aoi.findITerm("ZN").getAvgXY()
    xy_i = ni.findITerm("I").getAvgXY()
    xy_z = ni.findITerm("Z").getAvgXY()
    # getAvgXY returns [ok, x, y]
    manhattan_m2(mid, xy_zn[1], xy_zn[2], xy_i[1], xy_i[2])
    manhattan_m2(old, xy_z[1], xy_z[2], tap[1], tap[2])
    print("WIRED", name, "mid", xy_zn[1], xy_zn[2], "->", xy_i[1], xy_i[2], "tap", xy_z[1], xy_z[2], "->", tap[1], tap[2])

d.writeDb("physical/results/d03_ach_candidate/butterfold_top_co6a27g.odb")
print("wrote co6a27g.odb")
