#!/usr/bin/env python3
"""Map 9 CO.6a KLayout markers to Mag GDS instances and local cell geometry."""
import pya

GDS = "/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_candidate/butterfold_top.gds"
PDK_GDS = "/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/gds/gf180mcu_fd_sc_mcu9t5v0.gds"

# KLayout lyrdb edge-pairs (µm). First edge is typically the contact; second is metal1.
MARKERS = [
    ((771.07, 1154.97, 771.07, 1155.03), (771.065, 1154.97, 771.065, 1155.03)),
    ((265.95, 1175.13, 265.95, 1175.19), (265.945, 1175.13, 265.945, 1175.19)),
    ((254.19, 1185.21, 254.19, 1185.27), (254.185, 1185.21, 254.185, 1185.27)),
    ((268.75, 1195.29, 268.75, 1195.35), (268.745, 1195.29, 268.745, 1195.35)),
    ((270.99, 1286.01, 270.99, 1286.07), (270.985, 1286.01, 270.985, 1286.07)),
    ((648.43, 1296.09, 648.43, 1296.15), (648.425, 1296.09, 648.425, 1296.15)),
    ((374.59, 1346.49, 374.59, 1346.55), (374.585, 1346.49, 374.585, 1346.55)),
    ((408.75, 1376.73, 408.75, 1376.79), (408.745, 1376.73, 408.745, 1376.79)),
    ((770.51, 1487.61, 770.51, 1487.67), (770.505, 1487.61, 770.505, 1487.67)),
]

ly = pya.Layout()
ly.read(GDS)
top = ly.top_cell()
dbu = ly.dbu
m1 = ly.layer(34, 0)
co = ly.layer(33, 0)
print(f"dbu={dbu} top={top.name}")


def um_box(b):
    return (b.left * dbu, b.bottom * dbu, b.right * dbu, b.top * dbu)


def find_inst(x_um, y_um):
    p = pya.Point(int(round(x_um / dbu)), int(round(y_um / dbu)))
    hits = []
    it = top.begin_instances_rec()
    while not it.at_end():
        c = it.inst_cell()
        tr = it.trans()
        bb = c.bbox().transformed(tr)
        if bb.contains(p):
            name = c.name if c else "?"
            w = (bb.right - bb.left) * dbu
            h = (bb.top - bb.bottom) * dbu
            if w < 50 and h < 20:
                hits.append((name, str(tr), um_box(bb), w, h))
        it.next()
    hits.sort(key=lambda t: t[3] * t[4])
    return hits


def local_shapes(inst_trans, layer, p_um, rad_um=0.2):
    p = pya.DPoint(p_um[0], p_um[1])
    r = pya.DBox(p.x - rad_um, p.y - rad_um, p.x + rad_um, p.y + rad_um)
    rdbu = pya.Box(
        int(r.left / dbu), int(r.bottom / dbu), int(r.right / dbu), int(r.top / dbu)
    )
    out = []
    it = top.begin_shapes_rec_touching(layer, rdbu)
    while not it.at_end():
        sh = it.shape()
        bb = sh.bbox().transformed(it.trans())
        out.append(um_box(bb))
        it.next()
    return out


for i, (e1, e2) in enumerate(MARKERS, 1):
    cx = 0.5 * (e1[0] + e2[0])
    cy = 0.5 * (e1[1] + e1[3])
    dx = abs(e1[0] - e2[0])
    print(f"\n=== M{i} center=({cx:.5f},{cy:.5f}) dx={dx*1000:.1f}nm ===")
    print(f"  contact_edge x={e1[0]} y={e1[1]}..{e1[3]}")
    print(f"  metal1_edge  x={e2[0]} y={e2[1]}..{e2[3]}")
    hits = find_inst(cx, cy)
    if not hits:
        print("  NO instance")
        continue
    name, trans, bb, w, h = hits[0]
    print(f"  inst {name} {trans}")
    print(f"  bbox_um {bb[0]:.5f} {bb[1]:.5f} {bb[2]:.5f} {bb[3]:.5f}  size {w:.3f}x{h:.3f}")
    if len(hits) > 1:
        print(f"  other hits: {[(h[0], h[1]) for h in hits[1:4]]}")
    m1s = local_shapes(None, m1, (cx, cy), 0.15)
    cos = local_shapes(None, co, (cx, cy), 0.15)
    print(f"  nearby M1 ({len(m1s)}): {m1s[:4]}")
    print(f"  nearby CO ({len(cos)}): {cos[:4]}")
