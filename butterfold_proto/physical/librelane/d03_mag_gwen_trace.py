#!/usr/bin/env python3
"""Trace Mag GDS metal from gwen_driver ZN toward SRAM GWEN.

Instance origins from pgfix DEF (dbu 2000):
  lo: (460.88, 685.44) N  clkinv_8
  hi: (432.32, 700.56) FS clkinv_8
ZN Metal1 local box used for the seed: 4.630 1.745 5.130 3.090
"""
import pya

GDS = "/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_candidate/butterfold_top.gds"
ly = pya.Layout()
ly.read(GDS)
top = ly.top_cell()
dbu = ly.dbu
print("dbu", dbu, "top", top.name)

m1 = ly.layer(34, 0)
m2 = ly.layer(36, 0)
m3 = ly.layer(42, 0)
m4 = ly.layer(46, 0)
m5 = ly.layer(81, 0)
co = ly.layer(33, 0)
v1 = ly.layer(35, 0)
v2 = ly.layer(38, 0)
v3 = ly.layer(40, 0)
v4 = ly.layer(41, 0)

conn = pya.NetTracerConnectivity()
conn.connection(m1, co, m1)
conn.connection(m1, v1, m2)
conn.connection(m2, v2, m3)
conn.connection(m3, v3, m4)
conn.connection(m4, v4, m5)

# N: x' = ox+x, y' = oy+y
# FS (MY then MX? DEF FS = flipped south = MX then R180?):
# OpenROAD FS = MY+R0? In LEF/DEF: N, S, W, E, FN, FS, FW, FE.
# FS = flipped south = mirror X then rotate 180? Standard:
#   FS: x' = ox + w - x, y' = oy - y  ? 
# DEF orient FS: 'S' + flip. OpenROAD: FS is MY (mirror about Y) of S?
# Practical: transform via instance in GDS.

seeds = {
    "lo_N": (460.88, 685.44, "N", 10.080, 5.040),
    "hi_FS": (432.32, 700.56, "FS", 10.080, 5.040),
}

# Find GDS instances of clkinv_8 near those origins.
want = []
for c in ly.each_cell():
    if "clkinv_8" in c.name:
        want.append(c.cell_index())
print("clkinv_8 cells", [ly.cell(i).name for i in want])

hits = []
for inst in top.each_inst():
    if inst.cell.cell_index() not in want:
        continue
    bb = inst.bbox()
    x = bb.left * dbu
    y = bb.bottom * dbu
    for tag, (ox, oy, ori, w, h) in seeds.items():
        if abs(x - ox) < 0.05 and abs(y - (oy if ori == "N" else oy - h)) < 0.2:
            hits.append((tag, inst, ox, oy, ori))
        elif abs(x - ox) < 2 and abs(y - oy) < 2:
            hits.append((tag + "_near", inst, ox, oy, ori))

print("hits", len(hits))
for tag, inst, ox, oy, ori in hits:
    tr = inst.cplx_trans
    print(tag, "trans", tr, "bbox_um", inst.bbox().left * dbu, inst.bbox().bottom * dbu,
          inst.bbox().right * dbu, inst.bbox().top * dbu)

# Seed at local ZN center transformed by instance (dbu).
zn_local_dbu = pya.Point(int(round(4.88 / dbu)), int(round(2.4175 / dbu)))
tracer = pya.NetTracer()
for tag, inst, ox, oy, ori in hits:
    ip = inst.cplx_trans * zn_local_dbu
    print("SEED", tag, ip, "um", ip.x * dbu, ip.y * dbu)
    tracer.trace(conn, ly, top, ip, m1)
    print("  shapes", tracer.num_elements(), "incomplete", tracer.incomplete(), "name", tracer.name())
    layers = {}
    sram_touch = 0
    for sh in tracer.each_element():
        lid = sh.layer
        layers[lid] = layers.get(lid, 0) + 1
        b = sh.shape.bbox.transformed(sh.trans)
        cx = 0.5 * (b.left + b.right) * dbu
        cy = 0.5 * (b.bottom + b.top) * dbu
        if (40 < cx < 220 or 500 < cx < 700) and 700 < cy < 900:
            sram_touch += 1
    print("  layers", layers, "sram_region_shapes", sram_touch)
