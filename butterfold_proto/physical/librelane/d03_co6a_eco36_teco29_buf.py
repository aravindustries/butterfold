#!/usr/bin/env python3
"""Series-insert clkbuf on remaining weak ZN/Q nets. Tap existing sink-net wire."""
import math
from collections import defaultdict
from openroad import Tech, Design
import odb, os

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
PDK = "/foss/pdks/gf180mcuD"
SRC = PROTO + "/physical/results/d03_ach_candidate/co6a36/setup_eco32/butterfold_top_co6a36_teco28.odb"
OUT = PROTO + "/physical/results/d03_ach_candidate/co6a36/setup_eco33"
ODB = OUT + "/butterfold_top_co6a36_teco29.odb"
NINE = {"_11280_", "_11106_", "_11366_", "_11339_", "_11136_", "_11474_", "_11394_", "_11408_", "_11241_"}
DRIVERS = [
    ("_11198_", "ZN"),
    ("_11447_", "ZN"),
    ("_11183_", "ZN"),
    ("_12569_", "ZN"),
    ("_11527_", "ZN"),
    ("_11150_", "ZN"),
    ("_11164_", "ZN"),
    ("_12482_", "ZN"),
    ("_11225_", "ZN"),
    ("_20030_", "Q"),
]

tech = Tech()
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef")
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef")
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef")
design = Design(tech)
design.readDb(SRC)
db = tech.getDB()
block = db.getChip().getBlock()
ttech = db.getTech()
dbu = block.getDefUnits()
m1 = ttech.findLayer("Metal1")
m2 = ttech.findLayer("Metal2")
m3 = ttech.findLayer("Metal3")
via1 = ttech.findVia("Via1_VV") or ttech.findVia("Via1_VH") or ttech.findVia("Via1_HV")
via2 = ttech.findVia("Via2_VH") or ttech.findVia("Via2_HV") or ttech.findVia("Via2_VV")
clk4 = db.findMaster("gf180mcu_fd_sc_mcu9t5v0__clkbuf_4")
clk8 = db.findMaster("gf180mcu_fd_sc_mcu9t5v0__clkbuf_8")
core = block.getCoreArea()
core_x0, core_y0, core_x1 = core.xMin(), core.yMin(), core.xMax()
row_h = int(5.04 * dbu)


def um(v):
    return v / float(dbu)


def dbu_um(x):
    return int(round(x * dbu))


def pin_xy(iterm):
    ok, ax, ay = iterm.getAvgXY()
    if ok:
        return int(ax), int(ay)
    bb = iterm.getBBox()
    return (bb.xMin() + bb.xMax()) // 2, (bb.yMin() + bb.yMax()) // 2


def overlaps(inst):
    bb = inst.getBBox()
    hits = []
    for o in block.getInsts():
        if o.getName() == inst.getName():
            continue
        ob = o.getBBox()
        if ob.yMax() <= bb.yMin() or ob.yMin() >= bb.yMax():
            continue
        if ob.xMax() <= bb.xMin() or ob.xMin() >= bb.xMax():
            continue
        hits.append(o.getName())
    return hits


rows = defaultdict(list)
for inst in block.getInsts():
    bb = inst.getBBox()
    yk = int(round((bb.yMin() - core_y0) / float(row_h)))
    rows[yk].append((bb.xMin(), bb.xMax()))


def best_hole(cx, cy):
    """Prefer clkbuf_8 hole, else clkbuf_4, nearest."""
    found8, found4 = [], []
    for yk, items in rows.items():
        y = (core_y0 + yk * row_h) / dbu
        if abs(y - cy) > 80:
            continue
        items = sorted(items)
        prev = core_x0
        for x0, x1 in items:
            gap = (x0 - prev) / dbu
            gx0, gx1 = prev / dbu, x0 / dbu
            gcx = 0.5 * (gx0 + gx1)
            dist = math.hypot(gcx - cx, y - cy)
            if gap >= 14.56 - 0.01:
                found8.append((dist, y, gx0, 14.56, "8"))
            elif gap >= 7.84 - 0.01:
                found4.append((dist, y, gx0, 7.84, "4"))
            if x1 > prev:
                prev = x1
    found8.sort()
    found4.sort()
    if found8 and found8[0][0] <= 80:
        return found8[0]
    if found4:
        return found4[0]
    if found8:
        return found8[0]
    return None


def net_m2_points(net):
    w = net.getWire()
    pts = []
    if w is None:
        return pts
    pitr = odb.dbWirePathItr()
    path = odb.dbWirePath()
    shape = odb.dbWirePathShape()
    pitr.begin(w)
    while pitr.getNextPath(path):
        while pitr.getNextShape(shape):
            if shape.layer and shape.layer.getName() in ("Metal2", "Metal3"):
                p = shape.point
                pts.append((p.getX(), p.getY(), shape.layer.getName()))
    return pts


def lroute(net, src_it, dst_it):
    sx, sy = pin_xy(src_it)
    dx, dy = pin_xy(dst_it)
    w = net.getWire()
    e = odb.dbWireEncoder()
    if w is None:
        e.begin(odb.dbWire_create(net))
    else:
        e.append(w)
    e.newPath(m1, "ROUTED")
    e.addPoint(sx, sy)
    e.addITerm(src_it)
    e.addTechVia(via1)
    e.addPoint(sx, sy)
    e.addTechVia(via2)
    e.addPoint(sx, sy)
    if sx != dx:
        e.addPoint(dx, sy)
    e.addTechVia(via2)
    e.addPoint(dx, sy)
    if sy != dy:
        e.addPoint(dx, dy)
    e.addTechVia(via1)
    e.addPoint(dx, dy)
    e.addITerm(dst_it)
    e.end()


def tap_existing(net, iterm):
    """Connect iterm to existing net wire via nearest M2/M3 point."""
    ix, iy = pin_xy(iterm)
    pts = net_m2_points(net)
    if not pts:
        print("  NO_M2", net.getName())
        return False
    ax, ay, layer = min(pts, key=lambda p: abs(p[0] - ix) + abs(p[1] - iy))
    w = net.getWire()
    e = odb.dbWireEncoder()
    e.append(w)
    lyr = m2 if layer == "Metal2" else m3
    e.newPath(lyr, "ROUTED")
    e.addPoint(ax, ay)
    if layer == "Metal3":
        e.addTechVia(via2)
        e.addPoint(ax, ay)
    if ax != ix:
        e.addPoint(ix, ay)
    if ay != iy:
        e.addPoint(ix, iy)
    e.addTechVia(via1)
    e.addPoint(ix, iy)
    e.addITerm(iterm)
    e.end()
    return True


nins = 0
for dname, pin in DRIVERS:
    inst = block.findInst(dname)
    zit = inst.findITerm(pin)
    old = zit.getNet()
    if old is None:
        print("NONET", dname); continue
    bb = inst.getBBox()
    cx = 0.5 * (bb.xMin() + bb.xMax()) / dbu
    cy = 0.5 * (bb.yMin() + bb.yMax()) / dbu
    hole = best_hole(cx, cy)
    if hole is None:
        print("NOHOLE", dname); continue
    dist, y, x0, need, kind = hole
    master = clk8 if kind == "8" else clk4
    bname = "teco29_buf_" + dname.strip("_")
    buf = odb.dbInst_create(block, master, bname)
    buf.setOrient("R0")
    buf.setLocation(dbu_um(x0), dbu_um(y))
    buf.setPlacementStatus("FIRM")
    ov = overlaps(buf)
    if ov:
        print("OVERLAP", bname, ov[:3], "- skip")
        # cannot easily destroy inst; leave FIRM unused? disconnect - skip connect
        continue
    mid = odb.dbNet_create(block, bname + "_i")
    zit.disconnect()
    zit.connect(mid)
    buf.findITerm("I").connect(mid)
    buf.findITerm("Z").connect(old)
    lroute(mid, zit, buf.findITerm("I"))
    ok = tap_existing(old, buf.findITerm("Z"))
    print("BUF", bname, kind, "dist", round(dist, 1), "at", x0, y, "tap", ok, "old", old.getName())
    nins += 1

print("INSERTED", nins)
for name in NINE:
    i = block.findInst(name)
    if i.getMaster().getName() != "gf180mcu_fd_sc_mcu9t5v0__aoi221_2" or str(i.getOrient()) != "R180":
        raise SystemExit("CELL_LOST " + name)

os.makedirs(OUT, exist_ok=True)
design.writeDb(ODB)
print("WROTE", ODB)
print("TECO29_GEOM_DONE")
