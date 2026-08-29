#!/usr/bin/env python3
"""teco24: regional rst_n tree with M3 spine + M2 drops, junction branching.
No M4 (clock). No full DRT. Source teco21.
"""
from collections import defaultdict
from openroad import Tech, Design
import odb, os

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
PDK = "/foss/pdks/gf180mcuD"
SRC = PROTO + "/physical/results/d03_ach_candidate/co6a36/setup_eco25/butterfold_top_co6a36_teco21.odb"
OUT = PROTO + "/physical/results/d03_ach_candidate/co6a36/setup_eco28"
ODB = OUT + "/butterfold_top_co6a36_teco24.odb"
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
print("VIA", via1.getName(), via2.getName())
clk8 = db.findMaster("gf180mcu_fd_sc_mcu9t5v0__clkbuf_8")
clk16 = db.findMaster("gf180mcu_fd_sc_mcu9t5v0__clkbuf_16")

PLACES = [
    ("teco24_rst_root", clk16, 7.84, 277.20, None),
    ("teco24_rst_SW", clk8, 243.04, 226.80, "SW"),
    ("teco24_rst_SE", clk8, 595.84, 297.36, "SE"),
    ("teco24_rst_MW", clk8, 262.64, 544.32, "MW"),
    ("teco24_rst_ME", clk8, 640.64, 579.60, "ME"),
    ("teco24_rst_NW", clk8, 223.44, 1310.40, "NW"),
    ("teco24_rst_NE", clk8, 556.64, 1164.24, "NE"),
]


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


created = {}
for name, master, x, y, region in PLACES:
    inst = odb.dbInst_create(block, master, name)
    inst.setOrient("R0")
    inst.setLocation(dbu_um(x), dbu_um(y))
    inst.setPlacementStatus("FIRM")
    ov = overlaps(inst)
    bb = inst.getBBox()
    print("PLACE", name, um(bb.xMin()), um(bb.yMin()), um(bb.xMax()), um(bb.yMax()), "OV", len(ov))
    if ov:
        raise SystemExit("OVERLAP " + name)
    created[name] = inst

rst = block.findNet("rst_n")
sinks = []
for it in list(rst.getITerms()):
    pn = it.getMTerm().getName()
    if pn in ("VDD", "VSS", "VNW", "VPW"):
        continue
    px, py = pin_xy(it)
    pxu, pyu = um(px), um(py)
    east = pxu >= 460.0
    if pyu < 402.4:
        key = "SE" if east else "SW"
    elif pyu < 776.2:
        key = "ME" if east else "MW"
    else:
        key = "NE" if east else "NW"
    sinks.append((it, px, py, key))

by = defaultdict(list)
for rec in sinks:
    by[rec[3]].append(rec)
for k in ("SW", "SE", "MW", "ME", "NW", "NE"):
    print("REGION", k, len(by[k]))

stem = odb.dbNet_create(block, "rst_n_stem")
reg_nets = {k: odb.dbNet_create(block, "rst_n_" + k) for k in by}

for it, px, py, key in sinks:
    it.disconnect()
    it.connect(reg_nets[key])

root = created["teco24_rst_root"]
root.findITerm("I").connect(rst)
root.findITerm("Z").connect(stem)
for k in by:
    b = created["teco24_rst_" + k]
    b.findITerm("I").connect(stem)
    b.findITerm("Z").connect(reg_nets[k])

w = rst.getWire()
if w:
    print("DESTROY rst_n wire um", um(w.getLength()))
    odb.dbWire_destroy(w)

for name in NINE:
    i = block.findInst(name)
    if i.getMaster().getName() != "gf180mcu_fd_sc_mcu9t5v0__aoi221_2" or str(i.getOrient()) != "R180":
        raise SystemExit("CELL_LOST " + name)


def lroute_m3m2(net, src_it, dst_it):
    """Single L: src M1-up to M3, H to dst x, via to M2, V to dst y, via to M1."""
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
    e.addPoint(sx, sy)  # M3
    if sx != dx:
        e.addPoint(dx, sy)
    e.addTechVia(via2)
    e.addPoint(dx, sy)  # M2
    if sy != dy:
        e.addPoint(dx, dy)
    e.addTechVia(via1)
    e.addPoint(dx, dy)
    e.addITerm(dst_it)
    e.end()


def encode_region_spine(net, zterm, recs):
    """One M3 horizontal trunk at Z-row through all sink x, M2 vertical drops."""
    zx, zy = pin_xy(zterm)
    xs = sorted(set([zx] + [r[1] for r in recs]))
    w = odb.dbWire_create(net)
    e = odb.dbWireEncoder()
    e.begin(w)
    # Z up to M3
    e.newPath(m1, "ROUTED")
    e.addPoint(zx, zy)
    e.addITerm(zterm)
    e.addTechVia(via1)
    e.addPoint(zx, zy)
    e.addTechVia(via2)
    e.addPoint(zx, zy)
    jids = {}
    for x in xs:
        jids[x] = e.addPoint(x, zy)
    # drops
    for it, sx, sy, key in recs:
        e.newPath(jids[sx], "ROUTED")
        e.addTechVia(via2)
        e.addPoint(sx, zy)
        if sy != zy:
            e.addPoint(sx, sy)
        e.addTechVia(via1)
        e.addPoint(sx, sy)
        e.addITerm(it)
    e.end()
    return um(w.getLength())


# port -> root I (6 L-routes for stem are small)
bt = block.findBTerm("rst_n")
# treat bterm as coordinates
bx = (bt.getBBox().xMin() + bt.getBBox().xMax()) // 2
pady = (bt.getBBox().yMin() + bt.getBBox().yMax()) // 2
ix, iy = pin_xy(root.findITerm("I"))
w = odb.dbWire_create(rst)
e = odb.dbWireEncoder()
e.begin(w)
e.newPath(m1, "ROUTED")
e.addPoint(ix, iy)
e.addITerm(root.findITerm("I"))
e.addTechVia(via1)
e.addPoint(ix, iy)
e.addTechVia(via2)
e.addPoint(ix, iy)
if ix != bx:
    e.addPoint(bx, iy)
e.addTechVia(via2)
e.addPoint(bx, iy)
if iy != pady:
    e.addPoint(bx, pady)
e.addBTerm(bt)
e.end()
print("PORT_WIRE_UM", um(w.getLength()))

print("STEM 6 L-routes")
z = root.findITerm("Z")
for k in ("SW", "SE", "MW", "ME", "NW", "NE"):
    lroute_m3m2(stem, z, created["teco24_rst_" + k].findITerm("I"))
print("STEM_LEN", um(stem.getWire().getLength()) if stem.getWire() else None)

print("REGIONAL SPINES")
for k, recs in by.items():
    nnet = reg_nets[k]
    zterm = created["teco24_rst_" + k].findITerm("Z")
    ln = encode_region_spine(nnet, zterm, recs)
    print("  ", k, "sinks", len(recs), "wire_um", ln)

os.makedirs(OUT, exist_ok=True)
design.writeDb(ODB)
print("WROTE", ODB)
print("TECO24_GEOM_DONE")
