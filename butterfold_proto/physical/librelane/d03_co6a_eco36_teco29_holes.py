import math
from collections import defaultdict
from openroad import Tech, Design

PDK="/foss/pdks/gf180mcuD"
SRC="/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_candidate/co6a36/setup_eco32/butterfold_top_co6a36_teco28.odb"
tech=Tech(); 
tech.readLef(PDK+"/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef")
tech.readLef(PDK+"/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef")
tech.readLef(PDK+"/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef")
d=Design(tech); d.readDb(SRC)
db=tech.getDB(); block=db.getChip().getBlock(); dbu=block.getDefUnits()
core=block.getCoreArea()
core_x0,core_y0,core_x1=core.xMin(),core.yMin(),core.xMax()
row_h=int(5.04*dbu)
rows=defaultdict(list)
for inst in block.getInsts():
    bb=inst.getBBox()
    yk=int(round((bb.yMin()-core_y0)/float(row_h)))
    rows[yk].append((bb.xMin(),bb.xMax()))

def holes_near(cx,cy,need=7.84,radius=40,limit=4):
    found=[]
    for yk,items in rows.items():
        y=(core_y0+yk*row_h)/dbu
        if abs(y-cy)>radius: continue
        items=sorted(items); prev=core_x0
        for x0,x1 in items:
            gap=(x0-prev)/dbu
            if gap>=need-0.01:
                gx0,gx1=prev/dbu,x0/dbu
                gcx=0.5*(gx0+gx1)
                found.append((math.hypot(gcx-cx,y-cy),y,gx0,gx1,gap))
            if x1>prev: prev=x1
    found.sort(); return found[:limit]

for n in ["_11198_","_11447_","_11183_","_12569_","_11527_","_11150_","_11164_","_12482_","_11225_","_20030_"]:
    i=block.findInst(n)
    bb=i.getBBox()
    cx=0.5*(bb.xMin()+bb.xMax())/dbu
    cy=0.5*(bb.yMin()+bb.yMax())/dbu
    hs=holes_near(cx,cy,7.84,50,3)
    hs8=holes_near(cx,cy,14.56,50,2)
    print(f"{n} {i.getMaster().getName().split('__')[-1]} @{cx:.1f},{cy:.1f}")
    if hs:
        d,y,x0,x1,w=hs[0]
        print(f"  c4 dist={d:.1f} y={y:.2f} x={x0:.2f}..{x1:.2f} w={w:.2f}")
    else:
        print("  NO_C4")
    if hs8:
        d,y,x0,x1,w=hs8[0]
        print(f"  c8 dist={d:.1f} y={y:.2f} x={x0:.2f}..{x1:.2f} w={w:.2f}")
print("DONE")
