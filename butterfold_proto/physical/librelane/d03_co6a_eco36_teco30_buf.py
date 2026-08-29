#!/usr/bin/env python3
"""teco30: buffer leftover _11164_ ZN and _19230_ Q; destroy orphan buf."""
import math
from collections import defaultdict
from openroad import Tech, Design
import odb, os

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
PDK = "/foss/pdks/gf180mcuD"
SRC = PROTO + "/physical/results/d03_ach_candidate/co6a36/setup_eco33/butterfold_top_co6a36_teco29.odb"
OUT = PROTO + "/physical/results/d03_ach_candidate/co6a36/setup_eco34"
ODB = OUT + "/butterfold_top_co6a36_teco30.odb"
NINE = {"_11280_", "_11106_", "_11366_", "_11339_", "_11136_", "_11474_", "_11394_", "_11408_", "_11241_"}

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
core_x0, core_y0 = core.xMin(), core.yMin()
row_h = int(5.04 * dbu)

# destroy orphan
orph = block.findInst("teco29_buf_11164")
if orph:
    print("DESTROY_ORPHAN teco29_buf_11164")
    odb.dbInst.destroy(orph)


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


def holes(cx, cy, need, radius=80):
    found = []
    for yk, items in rows.items():
        y = (core_y0 + yk * row_h) / dbu
        if abs(y - cy) > radius:
            continue
        items = sorted(items)
        prev = core_x0
        for x0, x1 in items:
            gap = (x0 - prev) / dbu
            if gap >= need - 0.01:
                gcx = 0.5 * ((prev + x0) / dbu)
                found.append((math.hypot(gcx - cx, y - cy), y, prev / dbu, gap))
            if x1 > prev:
                prev = x1
    found.sort()
    return found


def net_pts(net):
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


def tap(net, iterm):
    ix, iy = pin_xy(iterm)
    pts = net_pts(net)
    if not pts:
        return False
    ax, ay, layer = min(pts, key=lambda p: abs(p[0] - ix) + abs(p[1] - iy))
    e = odb.dbWireEncoder()
    e.append(net.getWire())
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


def insert(dname, pin, x0, y, master, bname):
    inst = block.findInst(dname)
    zit = inst.findITerm(pin)
    old = zit.getNet()
    buf = odb.dbInst_create(block, master, bname)
    buf.setOrient("R0")
    buf.setLocation(dbu_um(x0), dbu_um(y))
    buf.setPlacementStatus("FIRM")
    ov = overlaps(buf)
    if ov:
        print("OVERLAP", bname, ov[:4])
        odb.dbInst.destroy(buf)
        return False
    mid = odb.dbNet_create(block, bname + "_i")
    zit.disconnect()
    zit.connect(mid)
    buf.findITerm("I").connect(mid)
    buf.findITerm("Z").connect(old)
    lroute(mid, zit, buf.findITerm("I"))
    ok = tap(old, buf.findITerm("Z"))
    print("BUF", bname, "at", x0, y, "tap", ok)
    # refresh occupancy
    bb = buf.getBBox()
    yk = int(round((bb.yMin() - core_y0) / float(row_h)))
    rows[yk].append((bb.xMin(), bb.xMax()))
    return True


# _11164_ at ~472, 1318. Use c4 hole 576.24, 1335.60
insert("_11164_", "ZN", 576.24, 1335.60, clk4, "teco30_buf_11164")

# _19230_
i = block.findInst("_19230_")
bb = i.getBBox()
cx = 0.5 * (bb.xMin() + bb.xMax()) / dbu
cy = 0.5 * (bb.yMin() + bb.yMax()) / dbu
hs8 = holes(cx, cy, 14.56)
hs4 = holes(cx, cy, 7.84)
print("_19230_ holes8", hs8[:2], "holes4", hs4[:2])
if hs8:
    d, y, x0, w = hs8[0]
    insert("_19230_", "Q", x0, y, clk8, "teco30_buf_19230")
elif hs4:
    d, y, x0, w = hs4[0]
    insert("_19230_", "Q", x0, y, clk4, "teco30_buf_19230")

for name in NINE:
    i = block.findInst(name)
    if i.getMaster().getName() != "gf180mcu_fd_sc_mcu9t5v0__aoi221_2" or str(i.getOrient()) != "R180":
        raise SystemExit("CELL_LOST " + name)

os.makedirs(OUT, exist_ok=True)
design.writeDb(ODB)
print("WROTE", ODB)
print("TECO30_GEOM_DONE")
