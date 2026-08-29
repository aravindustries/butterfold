#!/usr/bin/env python3
"""Spatially classify rst_n sinks on teco21 and find legal clkbuf_8 holes."""
import math
from collections import defaultdict

from openroad import Tech, Design
import odb

proto = "/headless/aravindustries-repos/butterfold/butterfold_proto"
pdk = "/foss/pdks/gf180mcuD"
src = proto + "/physical/results/d03_ach_candidate/co6a36/setup_eco25/butterfold_top_co6a36_teco21.odb"

tech = Tech()
tech.readLef(pdk + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef")
tech.readLef(pdk + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef")
tech.readLef(pdk + "/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef")
design = Design(tech)
design.readDb(src)
block = design.getBlock()
dbu = block.getDbUnitsPerMicron()
core = block.getCoreArea()
core_x0, core_y0 = core.xMin(), core.yMin()
core_x1, core_y1 = core.xMax(), core.yMax()
print("CORE um", core_x0/dbu, core_y0/dbu, core_x1/dbu, core_y1/dbu)
print("DIE", block.getDieArea().xMin()/dbu, block.getDieArea().yMin()/dbu,
      block.getDieArea().xMax()/dbu, block.getDieArea().yMax()/dbu)

net = block.findNet("rst_n")
print("RST_N terms", len(list(net.getITerms())), "bterms", len(list(net.getBTerms())))
w = net.getWire()
print("WIRE length_um", (w.getLength() if w else 0)/dbu)

# sink locations
sinks = []
pin_kinds = defaultdict(int)
for it in net.getITerms():
    mterm = it.getMTerm()
    pn = mterm.getName()
    if pn in ("VDD", "VSS", "VNW", "VPW"):
        continue
    inst = it.getInst()
    bb = inst.getBBox()
    cx = 0.5 * (bb.xMin() + bb.xMax()) / dbu
    cy = 0.5 * (bb.yMin() + bb.yMax()) / dbu
    io = mterm.getIoType()
    pin_kinds[pn] += 1
    ok, ax, ay = it.getAvgXY()
    if ok:
        px, py = ax/dbu, ay/dbu
    else:
        px, py = cx, cy
    sinks.append({
        "inst": inst.getName(),
        "pin": pn,
        "master": inst.getMaster().getName(),
        "orient": inst.getOrient(),
        "cx": cx, "cy": cy,
        "px": px, "py": py,
        "xmin": bb.xMin()/dbu, "xmax": bb.xMax()/dbu,
        "ymin": bb.yMin()/dbu, "ymax": bb.yMax()/dbu,
        "iterm": it,
    })
print("PIN_KINDS", dict(pin_kinds))
print("SINKS", len(sinks))
xs = [s["px"] for s in sinks]
ys = [s["py"] for s in sinks]
print("SINK_BBOX um", min(xs), min(ys), max(xs), max(ys))

# 4x4 grid histogram
nx, ny = 4, 4
xmin, xmax, ymin, ymax = min(xs), max(xs), min(ys), max(ys)
print("\n==== 4x4 GRID ====")
grid = [[ [] for _ in range(nx)] for _ in range(ny)]
for s in sinks:
    ix = min(nx-1, int((s["px"]-xmin) / (xmax-xmin+1e-9) * nx))
    iy = min(ny-1, int((s["py"]-ymin) / (ymax-ymin+1e-9) * ny))
    grid[iy][ix].append(s)
for iy in range(ny-1, -1, -1):
    y0 = ymin + iy*(ymax-ymin)/ny
    y1 = ymin + (iy+1)*(ymax-ymin)/ny
    row = []
    for ix in range(nx):
        x0 = xmin + ix*(xmax-xmin)/nx
        x1 = xmin + (ix+1)*(xmax-xmin)/nx
        n = len(grid[iy][ix])
        row.append(f"{n:4d}")
    print(f"y {y0:7.1f}-{y1:7.1f} | " + " ".join(row))
print("x bins:", " ".join(f"{xmin+i*(xmax-xmin)/nx:7.1f}" for i in range(nx+1)))

# 2x4 (8 regions) as candidate tree
print("\n==== 2x4 REGIONS (x=2 y=4) ====")
nx, ny = 2, 4
grid2 = [[ [] for _ in range(nx)] for _ in range(ny)]
for s in sinks:
    ix = min(nx-1, int((s["px"]-xmin) / (xmax-xmin+1e-9) * nx))
    iy = min(ny-1, int((s["py"]-ymin) / (ymax-ymin+1e-9) * ny))
    grid2[iy][ix].append(s)
regions = []
for iy in range(ny):
    for ix in range(nx):
        g = grid2[iy][ix]
        if not g:
            continue
        bx0, bx1 = min(s["px"] for s in g), max(s["px"] for s in g)
        by0, by1 = min(s["py"] for s in g), max(s["py"] for s in g)
        cx = sum(s["px"] for s in g)/len(g)
        cy = sum(s["py"] for s in g)/len(g)
        regions.append({
            "name": f"R{iy}{ix}",
            "n": len(g),
            "bbox": (bx0, by0, bx1, by1),
            "cent": (cx, cy),
            "sinks": g,
        })
        print(f"R{iy}{ix} n={len(g):4d} bbox=({bx0:.1f},{by0:.1f})-({bx1:.1f},{by1:.1f}) "
              f"cent=({cx:.1f},{cy:.1f}) span=({bx1-bx0:.1f}x{by1-by0:.1f})")

# clkbuf sizes
db = odb.dbDatabase.get()
for sz in (1, 2, 3, 4, 8, 12, 16, 20):
    m = db.findMaster(f"gf180mcu_fd_sc_mcu9t5v0__clkbuf_{sz}")
    if m:
        print(f"MASTER clkbuf_{sz} w={m.getWidth()/dbu:.2f} h={m.getHeight()/dbu:.2f}")

# occupancy by row for hole search
row_h = int(5.04 * dbu)
need8 = 14.56  # clkbuf_8
need4 = 7.84   # clkbuf_4
rows = defaultdict(list)
for inst in block.getInsts():
    bb = inst.getBBox()
    yk = int(round((bb.yMin() - core_y0) / row_h))
    rows[yk].append((bb.xMin(), bb.xMax(), inst.getName(), inst.getMaster().getName()))

def holes_near(cx, cy, need_um, radius_um=80, limit=8):
    """Find gaps of width>=need_um whose row y is within radius of cy and x near cx."""
    found = []
    for yk, items in rows.items():
        y = (core_y0 + yk * row_h) / dbu
        if abs(y - cy) > radius_um:
            continue
        items = sorted(items)
        prev = core_x0
        for x0, x1, name, master in items:
            gap = (x0 - prev) / dbu
            if gap >= need_um - 0.01:
                gx0, gx1 = prev/dbu, x0/dbu
                gcx = 0.5*(gx0+gx1)
                dist = math.hypot(gcx - cx, y - cy)
                found.append((dist, y, gx0, gx1, gap))
            if x1 > prev:
                prev = x1
        gap = (core_x1 - prev) / dbu
        if gap >= need_um - 0.01:
            gx0, gx1 = prev/dbu, core_x1/dbu
            gcx = 0.5*(gx0+gx1)
            dist = math.hypot(gcx - cx, y - cy)
            found.append((dist, y, gx0, gx1, gap))
    found.sort()
    return found[:limit]

print("\n==== HOLES NEAR REGION CENTROIDS (clkbuf_8=14.56) ====")
for r in regions:
    hs = holes_near(r["cent"][0], r["cent"][1], 14.56, 80, 5)
    print(f"{r['name']} n={r['n']} cent={r['cent'][0]:.1f},{r['cent'][1]:.1f} holes={len(hs)}")
    for d, y, x0, x1, w in hs:
        print(f"  dist={d:6.1f} y={y:7.2f} x={x0:7.2f}..{x1:7.2f} w={w:.2f}")

print("\n==== HOLES NEAR REGION CENTROIDS (clkbuf_4=7.84) ====")
for r in regions:
    hs = holes_near(r["cent"][0], r["cent"][1], 7.84, 60, 4)
    print(f"{r['name']} n={r['n']} holes4={len(hs)}")
    for d, y, x0, x1, w in hs[:3]:
        print(f"  dist={d:6.1f} y={y:7.2f} x={x0:7.2f}..{x1:7.2f} w={w:.2f}")

# rst_n port
bt = block.findBTerm("rst_n")
bb = bt.getBBox()
print("\nPORT rst_n", bb.xMin()/dbu, bb.yMin()/dbu, bb.xMax()/dbu, bb.yMax()/dbu)

# hole near port
print("HOLES NEAR PORT (clkbuf_8)")
for d, y, x0, x1, w in holes_near(20, 274, 14.56, 40, 8):
    print(f"  dist={d:6.1f} y={y:7.2f} x={x0:7.2f}..{x1:7.2f} w={w:.2f}")
print("HOLES NEAR PORT (clkbuf_4)")
for d, y, x0, x1, w in holes_near(20, 274, 7.84, 40, 8):
    print(f"  dist={d:6.1f} y={y:7.2f} x={x0:7.2f}..{x1:7.2f} w={w:.2f}")

# also 3x3
print("\n==== 3x3 REGIONS ====")
nx, ny = 3, 3
grid3 = [[ [] for _ in range(nx)] for _ in range(ny)]
for s in sinks:
    ix = min(nx-1, int((s["px"]-xmin) / (xmax-xmin+1e-9) * nx))
    iy = min(ny-1, int((s["py"]-ymin) / (ymax-ymin+1e-9) * ny))
    grid3[iy][ix].append(s)
for iy in range(ny):
    for ix in range(nx):
        g = grid3[iy][ix]
        if not g:
            print(f"Q{iy}{ix} n=0")
            continue
        cx = sum(s["px"] for s in g)/len(g)
        cy = sum(s["py"] for s in g)/len(g)
        print(f"Q{iy}{ix} n={len(g):4d} cent=({cx:.1f},{cy:.1f})")
print("DONE")
