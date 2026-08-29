#!/usr/bin/env python3
"""Regional rst_n tree on teco21. Local OpenDB wires only. No TritonRoute."""
from collections import defaultdict
from openroad import Tech, Design
import odb

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
PDK = "/foss/pdks/gf180mcuD"
SRC = PROTO + "/physical/results/d03_ach_candidate/co6a36/setup_eco25/butterfold_top_co6a36_teco21.odb"
OUT = PROTO + "/physical/results/d03_ach_candidate/co6a36/setup_eco27"
ODB = OUT + "/butterfold_top_co6a36_teco23.odb"
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
m4 = ttech.findLayer("Metal4")
m5 = ttech.findLayer("Metal5")
via1 = ttech.findVia("Via1_VV") or ttech.findVia("Via1_VH") or ttech.findVia("Via1_HV")
via2 = ttech.findVia("Via2_VH") or ttech.findVia("Via2_HV") or ttech.findVia("Via2_VV")
via3 = ttech.findVia("Via3_HV") or ttech.findVia("Via3_VH") or ttech.findVia("Via3_VV")
via4 = ttech.findVia("Via4_VH") or ttech.findVia("Via4_HV") or ttech.findVia("Via4_VV")
print("VIAS", via1.getName(), via2.getName(), via3.getName(), via4.getName())
VIAS_UP = [via1, via2, via3, via4]
VIAS_DOWN = [via4, via3, via2, via1]

clk8 = db.findMaster("gf180mcu_fd_sc_mcu9t5v0__clkbuf_8")
clk16 = db.findMaster("gf180mcu_fd_sc_mcu9t5v0__clkbuf_16")
print("MASTERS", clk8.getWidth()/dbu, clk16.getWidth()/dbu)

# placements: (name, master, x_um, y_um, region_or_root)
PLACES = [
    ("teco23_rst_root", clk16, 7.84, 277.20, None),
    ("teco23_rst_SW", clk8, 243.04, 226.80, "SW"),
    ("teco23_rst_SE", clk8, 595.84, 297.36, "SE"),
    ("teco23_rst_MW", clk8, 262.64, 544.32, "MW"),
    ("teco23_rst_ME", clk8, 640.64, 579.60, "ME"),
    ("teco23_rst_NW", clk8, 223.44, 1310.40, "NW"),
    ("teco23_rst_NE", clk8, 556.64, 1164.24, "NE"),
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


# Place buffers
created = {}
for name, master, x, y, region in PLACES:
    inst = odb.dbInst_create(block, master, name)
    inst.setOrient("R0")
    inst.setLocation(dbu_um(x), dbu_um(y))
    inst.setPlacementStatus("FIRM")
    ov = overlaps(inst)
    bb = inst.getBBox()
    print("PLACE", name, master.getName(), um(bb.xMin()), um(bb.yMin()), um(bb.xMax()), um(bb.yMax()),
          "OV", len(ov), ov[:4])
    if ov:
        raise SystemExit("OVERLAP " + name)
    created[name] = inst

# Classify sinks
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
    sinks.append((it, px, py, key, it.getInst().getName(), pn))

by = defaultdict(list)
for rec in sinks:
    by[rec[3]].append(rec)
for k, v in sorted(by.items()):
    print("REGION", k, "n", len(v))

# New nets
stem = odb.dbNet_create(block, "rst_n_stem")
reg_nets = {}
for k in ("SW", "SE", "MW", "ME", "NW", "NE"):
    reg_nets[k] = odb.dbNet_create(block, "rst_n_" + k)

# Disconnect sinks from rst_n, attach to regional nets
for it, px, py, key, iname, pn in sinks:
    it.disconnect()
    it.connect(reg_nets[key])

root = created["teco23_rst_root"]
root.findITerm("I").connect(rst)
root.findITerm("Z").connect(stem)
for k in ("SW", "SE", "MW", "ME", "NW", "NE"):
    b = created["teco23_rst_" + k]
    b.findITerm("I").connect(stem)
    b.findITerm("Z").connect(reg_nets[k])

print("RST_N terms", len(list(rst.getITerms())), "bterms", len(list(rst.getBTerms())))
print("STEM terms", len(list(stem.getITerms())))
for k, n in reg_nets.items():
    print("NET", n.getName(), "terms", len(list(n.getITerms())))

# Destroy original rst_n mesh only
w = rst.getWire()
if w:
    print("DESTROY rst_n wire len_um", um(w.getLength()))
    odb.dbWire_destroy(w)

# Nine R180 check
for name in NINE:
    i = block.findInst(name)
    if i.getMaster().getName() != "gf180mcu_fd_sc_mcu9t5v0__aoi221_2" or str(i.getOrient()) != "R180":
        raise SystemExit("CELL_LOST " + name)


def encode_path(net, src_it, dst_it, vias_up, vias_down):
    """Manhattan M1-M5-M4-M1 path from src pin to dst pin on net."""
    sx, sy = pin_xy(src_it)
    dx, dy = pin_xy(dst_it)
    w = net.getWire()
    e = odb.dbWireEncoder()
    if w is None:
        w = odb.dbWire_create(net)
        e.begin(w)
    else:
        e.append(w)
    e.newPath(m1, "ROUTED")
    e.addPoint(sx, sy)
    e.addITerm(src_it)
    for v in vias_up:
        e.addTechVia(v)
        e.addPoint(sx, sy)
    # now M5 (H): go to dst x
    if sx != dx:
        e.addPoint(dx, sy)
    # down Via4 to M4, vertical to dst y
    e.addTechVia(via4)
    e.addPoint(dx, sy)
    if sy != dy:
        e.addPoint(dx, dy)
    for v in (via3, via2, via1):
        e.addTechVia(v)
        e.addPoint(dx, dy)
    e.addITerm(dst_it)
    e.end()


def encode_bterm_to_iterm(net, bterm, iterm):
    bx = (bterm.getBBox().xMin() + bterm.getBBox().xMax()) // 2
    by = (bterm.getBBox().yMin() + bterm.getBBox().yMax()) // 2
    ix, iy = pin_xy(iterm)
    w = odb.dbWire_create(net)
    e = odb.dbWireEncoder()
    e.begin(w)
    e.newPath(m1, "ROUTED")
    e.addPoint(ix, iy)
    e.addITerm(iterm)
    for v in VIAS_UP:
        e.addTechVia(v)
        e.addPoint(ix, iy)
    # M5 H toward pad x, then we may need V - pad y is close
    if ix != bx:
        e.addPoint(bx, iy)
    if iy != by:
        # M5 is H; vertical should be M4. Drop via4, V, then maybe stay M4 to pad.
        e.addTechVia(via4)
        e.addPoint(bx, iy)
        e.addPoint(bx, by)
    e.addBTerm(bterm)
    e.end()


print("WIRE port->root")
bt = block.findBTerm("rst_n")
encode_bterm_to_iterm(rst, bt, root.findITerm("I"))

print("WIRE stem rootZ -> 6x I")
z = root.findITerm("Z")
for k in ("SW", "SE", "MW", "ME", "NW", "NE"):
    encode_path(stem, z, created["teco23_rst_" + k].findITerm("I"), VIAS_UP, VIAS_DOWN)

print("WIRE regional Z -> sinks")
npath = 0
for k, recs in by.items():
    zterm = created["teco23_rst_" + k].findITerm("Z")
    nnet = reg_nets[k]
    for it, px, py, key, iname, pn in recs:
        encode_path(nnet, zterm, it, VIAS_UP, VIAS_DOWN)
        npath += 1
        if npath % 200 == 0:
            print("  paths", npath)
print("PATHS", npath)

# wire length report
for n in [rst, stem] + list(reg_nets.values()):
    w = n.getWire()
    print("WIRELEN", n.getName(), "none" if w is None else um(w.getLength()),
          "terms", len(list(n.getITerms())))

import os
os.makedirs(OUT, exist_ok=True)
design.writeDb(ODB)
print("WROTE", ODB)
print("TECO23_GEOM_DONE")
