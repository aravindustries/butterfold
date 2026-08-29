#!/usr/bin/env python3
"""Holes near 6 merged rst_n regions + port. clkbuf sizes from LEF via block."""
import math
from collections import defaultdict
from openroad import Tech, Design

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
core_x0, core_y0, core_x1, core_y1 = core.xMin(), core.yMin(), core.xMax(), core.yMax()

# clkbuf widths from any instance or from masters via insts... scan unique
seen = {}
for inst in block.getInsts():
    m = inst.getMaster()
    n = m.getName()
    if "clkbuf_" in n or n.endswith("__buf_16") or n.endswith("__buf_8") or n.endswith("__buf_4"):
        seen[n] = m.getWidth()/dbu
print("KNOWN_WIDTHS", seen)

net = block.findNet("rst_n")
sinks = []
for it in net.getITerms():
    pn = it.getMTerm().getName()
    if pn in ("VDD", "VSS", "VNW", "VPW"):
        continue
    ok, ax, ay = it.getAvgXY()
    bb = it.getInst().getBBox()
    if ok:
        px, py = ax/dbu, ay/dbu
    else:
        px = 0.5*(bb.xMin()+bb.xMax())/dbu
        py = 0.5*(bb.yMin()+bb.yMax())/dbu
    sinks.append((it, px, py, it.getInst().getName(), pn))

# 6 regions: merge upper-middle into N
# y splits: 402, 776, and merge y>776
# x split: 460
regions = {
    "SW": [], "SE": [], "MW": [], "ME": [], "NW": [], "NE": [],
}
for rec in sinks:
    it, px, py, name, pn = rec
    east = px >= 460.0
    if py < 402.4:
        key = "SE" if east else "SW"
    elif py < 776.2:
        key = "ME" if east else "MW"
    else:
        key = "NE" if east else "NW"
    regions[key].append(rec)

row_h = int(5.04 * dbu)
rows = defaultdict(list)
for inst in block.getInsts():
    bb = inst.getBBox()
    yk = int(round((bb.yMin() - core_y0) / float(row_h)))
    rows[yk].append((bb.xMin(), bb.xMax()))

def holes_near(cx, cy, need_um, radius_um=100, limit=10):
    found = []
    for yk, items in rows.items():
        y = (core_y0 + yk * row_h) / dbu
        if abs(y - cy) > radius_um:
            continue
        items = sorted(items)
        prev = core_x0
        for x0, x1 in items:
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

print("\n==== 6 REGIONS ====")
for k in ("SW", "SE", "MW", "ME", "NW", "NE"):
    g = regions[k]
    px = [r[1] for r in g]; py = [r[2] for r in g]
    cx, cy = sum(px)/len(px), sum(py)/len(py)
    print(f"{k} n={len(g):4d} bbox=({min(px):.1f},{min(py):.1f})-({max(px):.1f},{max(py):.1f}) "
          f"cent=({cx:.1f},{cy:.1f})")
    print(f"  clkbuf_8 holes:")
    for d, y, x0, x1, w in holes_near(cx, cy, 14.56, 90, 6):
        print(f"    dist={d:6.1f} y={y:7.2f} x={x0:7.2f}..{x1:7.2f} w={w:.2f}")
    print(f"  clkbuf_4 holes:")
    for d, y, x0, x1, w in holes_near(cx, cy, 7.84, 50, 4):
        print(f"    dist={d:6.1f} y={y:7.2f} x={x0:7.2f}..{x1:7.2f} w={w:.2f}")

print("\n==== PORT-ADJACENT HOLES ====")
print("clkbuf_8 near (20,274):")
for d, y, x0, x1, w in holes_near(20, 274, 14.56, 50, 10):
    print(f"  dist={d:6.1f} y={y:7.2f} x={x0:7.2f}..{x1:7.2f} w={w:.2f}")
print("clkbuf_16=28 near (20,274):")
for d, y, x0, x1, w in holes_near(20, 274, 28.0, 80, 8):
    print(f"  dist={d:6.1f} y={y:7.2f} x={x0:7.2f}..{x1:7.2f} w={w:.2f}")
print("clkbuf_8 near (20,25) bottom row:")
for d, y, x0, x1, w in holes_near(50, 25.2, 14.56, 20, 8):
    print(f"  dist={d:6.1f} y={y:7.2f} x={x0:7.2f}..{x1:7.2f} w={w:.2f}")

# count 14.56 holes globally
n8 = n4 = 0
for yk, items in rows.items():
    items = sorted(items)
    prev = core_x0
    for x0, x1 in items:
        gap = (x0 - prev) / dbu
        if gap >= 14.56 - 0.01:
            n8 += 1
        if gap >= 7.84 - 0.01:
            n4 += 1
        if x1 > prev:
            prev = x1
print("GLOBAL_HOLES clkbuf_8", n8, "clkbuf_4", n4)

# rst_n wire bbox
w = net.getWire()
print("WIRE length_um", w.getLength()/dbu if w else None)
print("DONE")
