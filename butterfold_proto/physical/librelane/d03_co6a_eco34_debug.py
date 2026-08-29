#!/usr/bin/env python3
"""Debug one remaining miss: _11366_ A2 after eco34 move."""
from openroad import Tech, Design
import odb

PDK = "/foss/pdks/gf180mcuD"
CAND = "physical/results/d03_ach_candidate"
tech = Tech()
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef")
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef")
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef")
d = Design(tech)
d.readDb(CAND + "/butterfold_top_co6a34.odb")
block = tech.getDB().getChip().getBlock()
dbu = block.getDefUnits()
inst = block.findInst("_11366_")
print("inst", inst.getOrient(), inst.getLocation()[0]/dbu, inst.getLocation()[1]/dbu)
it = inst.findITerm("A2")
net = it.getNet()
bb = it.getBBox()
print("pin", bb.xMin()/dbu, bb.yMin()/dbu, bb.xMax()/dbu, bb.yMax()/dbu, "net", net.getName())
# nearest same-net M2
pitr = odb.dbWirePathItr(); path=odb.dbWirePath(); shape=odb.dbWirePathShape()
pitr.begin(net.getWire())
best=None
n=0
while pitr.getNextPath(path):
    while pitr.getNextShape(shape):
        lyr=shape.layer
        if lyr is None or lyr.getName()!="Metal2":
            continue
        sh=shape.shape
        n+=1
        cx=min(max((bb.xMin()+bb.xMax())//2, sh.xMin()), sh.xMax())
        cy=min(max((bb.yMin()+bb.yMax())//2, sh.yMin()), sh.yMax())
        dist=abs(cx-(bb.xMin()+bb.xMax())//2)+abs(cy-(bb.yMin()+bb.yMax())//2)
        if best is None or dist<best[0]:
            best=(dist, sh.xMin()/dbu, sh.yMin()/dbu, sh.xMax()/dbu, sh.yMax()/dbu)
print("n_m2", n, "nearest", None if best is None else (best[0]/dbu, best[1:]))
# foreign M2 overlapping inflated pin
inf=odb.Rect(bb.xMin()-800, bb.yMin()-800, bb.xMax()+800, bb.yMax()+800)
cnt=0
for net2 in block.getNets():
    w=net2.getWire()
    if w is None: continue
    pitr=odb.dbWirePathItr(); path=odb.dbWirePath(); shape=odb.dbWirePathShape()
    pitr.begin(w)
    while pitr.getNextPath(path):
        while pitr.getNextShape(shape):
            lyr=shape.layer
            if lyr is None or lyr.getName()!="Metal2":
                continue
            sh=shape.shape
            if sh.xMax()<inf.xMin() or inf.xMax()<sh.xMin() or sh.yMax()<inf.yMin() or inf.yMax()<sh.yMin():
                continue
            if net2.getName()==net.getName():
                tag="SAME"
            else:
                tag="FORN"
            if cnt<20:
                print(tag, net2.getName(), sh.xMin()/dbu, sh.yMin()/dbu, sh.xMax()/dbu, sh.yMax()/dbu)
            cnt+=1
print("nearby_m2_boxes", cnt)
print("DEBUG_DONE")
