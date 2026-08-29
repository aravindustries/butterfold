#!/usr/bin/env python3
"""Local pin-access ECO: pgfix aoi221_2 MX -> R180, patch only missed endpoints.

Does not invoke TritonRoute. Appends short M2+Via1 jogs onto existing net wires.
"""
from openroad import Tech, Design
import odb

PDK = "/foss/pdks/gf180mcuD"
CAND = "physical/results/d03_ach_candidate"
OUT = "physical/reports/signoff/evidence/d03_ach/drc"
INSTS = [
    "_11280_",
    "_11106_",
    "_11366_",
    "_11339_",
    "_11136_",
    "_11474_",
    "_11394_",
    "_11408_",
    "_11241_",
]
SKIP_PINS = {"VDD", "VSS", "VNW", "VPW"}

tech = Tech()
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef")
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef")
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef")
d = Design(tech)
d.readDb(CAND + "/butterfold_top_pgfix.odb")
db = tech.getDB()
block = db.getChip().getBlock()
ttech = db.getTech()
m1 = ttech.findLayer("Metal1")
m2 = ttech.findLayer("Metal2")
m3 = ttech.findLayer("Metal3")
via1 = ttech.findVia("Via1_VV") or ttech.findVia("Via1_VH") or ttech.findVia("Via1_HV")
via2 = ttech.findVia("Via2_VH") or ttech.findVia("Via2_HV") or ttech.findVia("Via2_VV")
if via1 is None:
    vias = [v.getName() for v in ttech.getVias() if "Via1" in v.getName()]
    raise SystemExit("no Via1, have " + str(vias[:20]))
if via2 is None:
    vias = [v.getName() for v in ttech.getVias() if "Via2" in v.getName()]
    raise SystemExit("no Via2, have " + str(vias[:20]))
print("VIA1", via1.getName(), "VIA2", via2.getName())
dbu = block.getDefUnits()
print("DBU", dbu)


def um(v):
    return v / float(dbu)


def pin_boxes(iterm):
    bb = iterm.getBBox()
    return [odb.Rect(bb.xMin(), bb.yMin(), bb.xMax(), bb.yMax())]


def boxes_str(boxes):
    return "; ".join(
        "%.3f,%.3f-%.3f,%.3f" % (um(b.xMin()), um(b.yMin()), um(b.xMax()), um(b.yMax()))
        for b in boxes
    )


def collect_shapes(net):
    w = net.getWire()
    out = []
    if w is None:
        return out
    pitr = odb.dbWirePathItr()
    path = odb.dbWirePath()
    shape = odb.dbWirePathShape()
    pitr.begin(w)
    while pitr.getNextPath(path):
        while pitr.getNextShape(shape):
            sh = shape.shape
            lyr = shape.layer
            if lyr is None:
                continue
            box = odb.Rect(sh.xMin(), sh.yMin(), sh.xMax(), sh.yMax())
            out.append((lyr.getName(), box))
    return out


def overlaps(a, b, slack=0):
    return not (
        a.xMax() < b.xMin() - slack
        or b.xMax() < a.xMin() - slack
        or a.yMax() < b.yMin() - slack
        or b.yMax() < a.yMin() - slack
    )


def pin_hit(pin_rects, shapes):
    for _ly, box in shapes:
        for p in pin_rects:
            if overlaps(p, box, slack=1):
                return True
    return False


def pin_center(rects):
    best = max(rects, key=lambda r: (r.xMax() - r.xMin()) * (r.yMax() - r.yMin()))
    return (best.xMin() + best.xMax()) // 2, (best.yMin() + best.yMax()) // 2


def snap(v, step):
    return int(round(v / float(step)) * step)


def nearest_m2_point(shapes, x, y):
    best = None
    bestd = None
    for ly, box in shapes:
        if ly != "Metal2":
            continue
        cx = min(max(x, box.xMin()), box.xMax())
        cy = min(max(y, box.yMin()), box.yMax())
        dist = abs(cx - x) + abs(cy - y)
        if bestd is None or dist < bestd:
            bestd = dist
            best = (cx, cy)
    return best, bestd


def nearest_m1_point(shapes, x, y):
    best = None
    bestd = None
    for ly, box in shapes:
        if ly != "Metal1":
            continue
        cx = min(max(x, box.xMin()), box.xMax())
        cy = min(max(y, box.yMin()), box.yMax())
        dist = abs(cx - x) + abs(cy - y)
        if bestd is None or dist < bestd:
            bestd = dist
            best = (cx, cy)
    return best, bestd


# Snapshot MX pin geometry before rotation.
mx_pins = {}
for name in INSTS:
    inst = block.findInst(name)
    if inst is None:
        raise SystemExit("missing " + name)
    print(
        "BEFORE",
        name,
        inst.getMaster().getName(),
        inst.getOrient(),
        inst.getLocation()[0],
        inst.getLocation()[1],
    )
    mx_pins[name] = {}
    for it in inst.getITerms():
        pn = it.getMTerm().getName()
        if pn in SKIP_PINS:
            continue
        mx_pins[name][pn] = pin_boxes(it)

# Rotate in place.
for name in INSTS:
    inst = block.findInst(name)
    x, y = inst.getLocation()
    inst.setPlacementStatus("PLACED")
    inst.setOrient("R180")
    inst.setLocation(x, y)
    inst.setPlacementStatus("FIRM")
    print("AFTER", name, inst.getMaster().getName(), inst.getOrient())

rpt = open(OUT + "/co6a32_pinaccess.rpt", "w")
rpt.write("inst pin net hit_after_r180 mx_boxes r180_boxes action\n")
need = []
leave = 0
for name in INSTS:
    inst = block.findInst(name)
    for it in inst.getITerms():
        pn = it.getMTerm().getName()
        if pn in SKIP_PINS:
            continue
        net = it.getNet()
        nn = "-" if net is None else net.getName()
        r180 = pin_boxes(it)
        shapes = [] if net is None else collect_shapes(net)
        hit = pin_hit(r180, shapes)
        action = "LEAVE" if hit else "PATCH"
        if hit:
            leave += 1
        else:
            need.append((name, pn, it, net, r180, shapes))
        line = "%s %s %s %s mx=[%s] r180=[%s] %s\n" % (
            name,
            pn,
            nn,
            "YES" if hit else "NO",
            boxes_str(mx_pins[name].get(pn, [])),
            boxes_str(r180),
            action,
        )
        rpt.write(line)
        print(line.strip())
rpt.close()
print("LEAVE", leave, "PATCH", len(need))

patched = 0
hw = int(round(0.14 * dbu))  # 0.28 um M2 width
pitch = int(round(0.84 * dbu))  # keep neighbor jogs 0.56 um apart edge-to-edge


def add_bar(enc, x1, y1, x2, y2):
    xa, xb = sorted([int(x1), int(x2)])
    ya, yb = sorted([int(y1), int(y2)])
    enc.addRect(xa - hw, ya - hw, xb + hw, yb + hw)


by_inst = {}
for rec in need:
    by_inst.setdefault(rec[0], []).append(rec)

for name, recs in by_inst.items():
    inst = block.findInst(name)
    bb = inst.getBBox()
    y0 = bb.yMin() + pitch
    tracks = [y0 + i * pitch for i in range(len(recs))]
    tracks = [min(max(y, bb.yMin() + hw), bb.yMax() - hw) for y in tracks]
    for track_y, (name, pn, it, net, r180, shapes) in zip(tracks, recs):
        if net is None or net.getWire() is None:
            print("SKIP", name, pn)
            continue
        best = max(r180, key=lambda r: (r.xMax() - r.xMin()) * (r.yMax() - r.yMin()))
        inset = int(round(0.06 * dbu))
        px = (best.xMin() + best.xMax()) // 2
        py = (best.yMin() + best.yMax()) // 2
        px = min(max(px, best.xMin() + inset), best.xMax() - inset)
        py = min(max(py, best.yMin() + inset), best.yMax() - inset)
        m2pt, m2d = nearest_m2_point(shapes, px, track_y)
        if m2pt is None:
            m1pt, _m1d = nearest_m1_point(shapes, px, track_y)
            if m1pt is None:
                print("NO_ANCHOR", name, pn)
                continue
            x1, y1 = m1pt
        else:
            x1, y1 = m2pt
        e = odb.dbWireEncoder()
        try:
            e.append(net.getWire())
        except Exception as ex:
            print("APPEND_FAIL", name, pn, ex)
            continue
        e.newPath(m2, "ROUTED")
        e.addPoint(int(x1), int(y1))
        if int(y1) != int(track_y):
            e.addPoint(int(x1), int(track_y))
        if int(x1) != int(px):
            e.addPoint(int(px), int(track_y))
        if int(track_y) != int(py):
            e.addPoint(int(px), int(py))
        e.addTechVia(via1)
        e.addITerm(it)
        e.end()
        print(
            "PATCH_M2",
            name,
            pn,
            "track",
            um(track_y),
            "from",
            um(x1),
            um(y1),
            "to",
            um(px),
            um(py),
        )
        patched += 1

# Re-check hits after patch.
miss = 0
for name in INSTS:
    inst = block.findInst(name)
    for it in inst.getITerms():
        pn = it.getMTerm().getName()
        if pn in SKIP_PINS:
            continue
        net = it.getNet()
        r180 = pin_boxes(it)
        shapes = [] if net is None else collect_shapes(net)
        if not pin_hit(r180, shapes):
            miss += 1
            print("STILL_MISS", name, pn, "-" if net is None else net.getName())
print("STILL_MISS_COUNT", miss)
print("ROUTE_ENDPOINTS_PATCHED", patched)

# Counts
n_mx = n_r180 = n_r0 = n_my = 0
nsram = 0
for inst in block.getInsts():
    mn = inst.getMaster().getName()
    if "sram256x8m8wm1" in mn:
        nsram += 1
    if mn == "gf180mcu_fd_sc_mcu9t5v0__aoi221_2":
        o = str(inst.getOrient())
        if o == "MX":
            n_mx += 1
        elif o == "R180":
            n_r180 += 1
        elif o == "R0":
            n_r0 += 1
        elif o == "MY":
            n_my += 1
print("AOI221_2 MX", n_mx, "R180", n_r180, "R0" , n_r0, "MY", n_my, "SRAM", nsram)

d.writeDb(CAND + "/butterfold_top_co6a32.odb")
d.writeDef(CAND + "/butterfold_top_co6a32.def")
print("WROTE_CO6A32")
