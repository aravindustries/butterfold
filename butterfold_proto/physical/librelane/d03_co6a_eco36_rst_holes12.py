"""Find clkbuf_8 holes for 12 rst_n subregions (split 6 by median x, NE unsplit)."""
import math
from collections import defaultdict
from openroad import Tech, Design

PDK="/foss/pdks/gf180mcuD"
SRC="/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_candidate/co6a36/setup_eco25/butterfold_top_co6a36_teco21.odb"
tech=Tech()
tech.readLef(PDK+"/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef")
tech.readLef(PDK+"/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef")
tech.readLef(PDK+"/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef")
d=Design(tech); d.readDb(SRC)
db=tech.getDB(); block=db.getChip().getBlock(); dbu=block.getDefUnits()
core=block.getCoreArea()
core_x0, core_y0, core_x1, core_y1 = core.xMin(), core.yMin(), core.xMax(), core.yMax()
net=block.findNet("rst_n")
sinks=[]
for it in net.getITerms():
    pn=it.getMTerm().getName()
    if pn in ("VDD","VSS","VNW","VPW"): continue
    ok,ax,ay=it.getAvgXY()
    px,py=(ax/dbu,ay/dbu) if ok else (0,0)
    east=px>=460.0
    if py<402.4: key="SE" if east else "SW"
    elif py<776.2: key="ME" if east else "MW"
    else: key="NE" if east else "NW"
    sinks.append((key,px,py))

groups=defaultdict(list)
for k,px,py in sinks:
    groups[k].append((px,py))

# split each except NE by median x
regions={}
for k,pts in groups.items():
    if k=="NE" or len(pts)<180:
        cx=sum(p[0] for p in pts)/len(pts)
        cy=sum(p[1] for p in pts)/len(pts)
        regions[k]=(pts,cx,cy)
        continue
    xs=sorted(p[0] for p in pts)
    med=xs[len(xs)//2]
    a=[p for p in pts if p[0]<med]
    b=[p for p in pts if p[0]>=med]
    for tag,g in (("A",a),("B",b)):
        if not g: continue
        cx=sum(p[0] for p in g)/len(g)
        cy=sum(p[1] for p in g)/len(g)
        regions[k+tag]=(g,cx,cy)

row_h=int(5.04*dbu)
rows=defaultdict(list)
for inst in block.getInsts():
    bb=inst.getBBox()
    yk=int(round((bb.yMin()-core_y0)/float(row_h)))
    rows[yk].append((bb.xMin(), bb.xMax()))

def holes_near(cx,cy,need=14.56,radius=80,limit=5):
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
                found.append((math.hypot(gcx-cx,y-cy), y, gx0, gx1, gap))
            if x1>prev: prev=x1
    found.sort()
    return found[:limit]

print("NREG", len(regions))
for k,(g,cx,cy) in sorted(regions.items()):
    hs=holes_near(cx,cy)
    print(f"{k:4s} n={len(g):3d} cent=({cx:6.1f},{cy:6.1f})")
    if hs:
        d,y,x0,x1,w=hs[0]
        print(f"     hole dist={d:5.1f} y={y:.2f} x={x0:.2f}..{x1:.2f} w={w:.2f}")
    else:
        print("     NO_HOLE")
print("DONE")
