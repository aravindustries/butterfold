#!/usr/bin/env python3
"""Scan legal 0.28 um M2 channels around the nine R180 cells."""
from openroad import Tech, Design
import odb
from collections import defaultdict

PDK = "/foss/pdks/gf180mcuD"
CAND = "physical/results/d03_ach_candidate"
INSTS = [
    "_11280_", "_11106_", "_11366_", "_11339_", "_11136_",
    "_11474_", "_11394_", "_11408_", "_11241_",
]
SKIP = {"VDD", "VSS", "VNW", "VPW"}

tech = Tech()
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef")
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef")
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef")
d = Design(tech)
d.readDb(CAND + "/butterfold_top_pgfix.odb")
block = tech.getDB().getChip().getBlock()
dbu = block.getDefUnits()
W = int(0.28 * dbu)
S = int(0.28 * dbu)
print("DBU", dbu)

for name in INSTS:
    inst = block.findInst(name)
    x, y = inst.getLocation()
    inst.setPlacementStatus("PLACED")
    inst.setOrient("R180")
    inst.setLocation(x, y)
    inst.setPlacementStatus("FIRM")

# Collect all M2
m2 = []
for net in block.getNets():
    nn = net.getName()
    w = net.getWire()
    if w is None:
        continue
    pitr = odb.dbWirePathItr()
    path = odb.dbWirePath()
    shape = odb.dbWirePathShape()
    pitr.begin(w)
    while pitr.getNextPath(path):
        while pitr.getNextShape(shape):
            lyr = shape.layer
            if lyr is None or lyr.getName() != "Metal2":
                continue
            sh = shape.shape
            m2.append((nn, sh.xMin(), sh.yMin(), sh.xMax(), sh.yMax()))
print("M2_SHAPES", len(m2))


def um(v):
    return v / float(dbu)


for name in INSTS:
    inst = block.findInst(name)
    bb = inst.getBBox()
    x0, y0, x1, y1 = bb.xMin() - 4 * dbu, bb.yMin() - 4 * dbu, bb.xMax() + 4 * dbu, bb.yMax() + 4 * dbu
    local = [r for r in m2 if not (r[3] < x0 or r[1] > x1 or r[4] < y0 or r[2] > y1)]
    # vertical-ish tracks: group by x-center of shapes with height>=width
    xs = []
    ys = []
    for nn, a, b, c, d2 in local:
        w, h = c - a, d2 - b
        if h >= w:
            xs.append(((a + c) / 2.0, w, nn, b, d2))
        if w >= h:
            ys.append(((b + d2) / 2.0, h, nn, a, c))
    xs.sort()
    ys.sort()
    print("CELL", name, "bbox", um(bb.xMin()), um(bb.yMin()), um(bb.xMax()), um(bb.yMax()),
          "nM2", len(local), "vtracks", len(xs), "htracks", len(ys))
    # unique x centers within 0.05 um
    ux = []
    for xc, w, nn, ylo, yhi in xs:
        if not ux or abs(xc - ux[-1][0]) > 0.05 * dbu:
            ux.append([xc, w, nn])
    gaps = []
    for i in range(1, len(ux)):
        gap = (ux[i][0] - ux[i][0] and (ux[i][0] - ux[i - 1][0] - ux[i][1] / 2 - ux[i - 1][1] / 2))
        edge_gap = (ux[i][0] - ux[i][1] / 2) - (ux[i - 1][0] + ux[i - 1][1] / 2)
        if edge_gap >= 0.28 * dbu - 1:
            gaps.append(edge_gap)
    print("  unique_x", len(ux), "edge_gaps_ge_0.28", len([g for g in [
        ((ux[i][0] - ux[i][1] / 2) - (ux[i - 1][0] + ux[i - 1][1] / 2))
        for i in range(1, len(ux))
    ] if g >= 0.28 * dbu - 1]))
    ge = []
    for i in range(1, len(ux)):
        edge_gap = (ux[i][0] - ux[i][1] / 2) - (ux[i - 1][0] + ux[i - 1][1] / 2)
        ge.append(edge_gap)
    if ge:
        print("  x_edge_gap_um min", um(min(ge)), "max", um(max(ge)),
              "n_ge_0.56", sum(1 for g in ge if g >= 0.56 * dbu - 1),
              "n_ge_0.84", sum(1 for g in ge if g >= 0.84 * dbu - 1))
        # show a few largest
        sg = sorted(ge, reverse=True)[:5]
        print("  largest_x_gaps_um", [round(um(g), 3) for g in sg])
    # same for y
    uy = []
    for yc, h, nn, xlo, xhi in ys:
        if not uy or abs(yc - uy[-1][0]) > 0.05 * dbu:
            uy.append([yc, h, nn])
    gy = []
    for i in range(1, len(uy)):
        edge_gap = (uy[i][0] - uy[i][1] / 2) - (uy[i - 1][0] + uy[i - 1][1] / 2)
        gy.append(edge_gap)
    if gy:
        print("  unique_y", len(uy), "y_edge_gap min", um(min(gy)), "max", um(max(gy)),
              "n_ge_0.56", sum(1 for g in gy if g >= 0.56 * dbu - 1),
              "n_ge_0.84", sum(1 for g in gy if g >= 0.84 * dbu - 1))
        print("  largest_y_gaps_um", [round(um(g), 3) for g in sorted(gy, reverse=True)[:5]])

    # nearest same-net M2 to each PATCH pin
    for it in inst.getITerms():
        pn = it.getMTerm().getName()
        if pn in SKIP:
            continue
        net = it.getNet()
        if net is None:
            continue
        pb = it.getBBox()
        # hit?
        hit = False
        best = None
        nn = net.getName()
        for ly, box in []:
            pass
        # from global m2 of this net
        bestd = None
        for n2, a, b, c, d2 in m2:
            if n2 != nn:
                continue
            # dist from pin bbox to rect
            dx = 0
            if c < pb.xMin():
                dx = pb.xMin() - c
            elif pb.xMax() < a:
                dx = a - pb.xMax()
            dy = 0
            if d2 < pb.yMin():
                dy = pb.yMin() - d2
            elif pb.yMax() < b:
                dy = b - pb.yMax()
            dist = (dx * dx + dy * dy) ** 0.5 if dx and dy else (dx or dy)
            if dist <= 1:
                hit = True
            if bestd is None or dist < bestd:
                bestd = dist
        print("  PIN", pn, nn, "hit" if hit else "miss", "nearest_m2_um", None if bestd is None else round(um(bestd), 3),
              "pin", round(um(pb.xMin()), 3), round(um(pb.yMin()), 3), round(um(pb.xMax()), 3), round(um(pb.yMax()), 3))
print("SCAN_DONE")
