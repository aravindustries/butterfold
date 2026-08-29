#!/usr/bin/env python3
"""Same-row X displacement + legal 0.28 um pin access for 9 R180 aoi221_2.

Starts from pgfix. No TritonRoute. Fillers only are displaced.
"""
from __future__ import annotations

import math
from collections import defaultdict

from openroad import Tech, Design
import odb

PDK = "/foss/pdks/gf180mcuD"
CAND = "physical/results/d03_ach_candidate"
OUT = "physical/reports/signoff/evidence/d03_ach/drc"
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
db = tech.getDB()
block = db.getChip().getBlock()
ttech = db.getTech()
m2 = ttech.findLayer("Metal2")
via_vv = ttech.findVia("Via1_VV")
via_vh = ttech.findVia("Via1_VH")
dbu = block.getDefUnits()
site = block.getRows()[0].getSite()
SW, SH = site.getWidth(), site.getHeight()
W = int(round(0.28 * dbu))
HW = W // 2
S = int(round(0.28 * dbu))
WIDE = int(round(10.0 * dbu))
GRID = 10
STEP = 140
RAD = int(round(20.0 * dbu))
print("DBU", dbu, "SITE_UM", SW / float(dbu), SH / float(dbu), "W", W, "S", S, flush=True)


def um(v):
    return v / float(dbu)


def snap(v, g=GRID):
    return int(round(v / float(g)) * g)


def overlaps(a, b, slack=0):
    return not (
        a.xMax() < b.xMin() - slack
        or b.xMax() < a.xMin() - slack
        or a.yMax() < b.yMin() - slack
        or b.yMax() < a.yMin() - slack
    )


def gap_euclid(a, b):
    if a.xMax() < b.xMin():
        dx = b.xMin() - a.xMax()
    elif b.xMax() < a.xMin():
        dx = a.xMin() - b.xMax()
    else:
        dx = 0
    if a.yMax() < b.yMin():
        dy = b.yMin() - a.yMax()
    elif b.yMax() < a.yMin():
        dy = a.yMin() - b.yMax()
    else:
        dy = 0
    if dx == 0 and dy == 0:
        return 0
    if dx == 0:
        return dy
    if dy == 0:
        return dx
    return int(round(math.hypot(dx, dy)))


def is_fill(mn, strict=True):
    if strict:
        return ("__fill_" in mn) or ("__fillcap_" in mn)
    return ("__fill_" in mn) or ("__fillcap_" in mn) or ("__filltie" in mn) or ("__endcap" in mn)


def pin_box(iterm):
    bb = iterm.getBBox()
    return odb.Rect(bb.xMin(), bb.yMin(), bb.xMax(), bb.yMax())


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
            out.append((lyr.getName(), odb.Rect(sh.xMin(), sh.yMin(), sh.xMax(), sh.yMax())))
    return out


def pin_hit(pin, shapes):
    for _ly, box in shapes:
        if overlaps(pin, box, slack=1):
            return True
    return False


BIN = 2000
idx = defaultdict(list)
idx1 = defaultdict(list)
eco = []
eco1 = []
W1 = int(round(0.23 * dbu))
HW1 = W1 // 2
S1 = int(round(0.23 * dbu))


def add_idx(nn, rect):
    for bx in range(rect.xMin() // BIN, rect.xMax() // BIN + 1):
        for by in range(rect.yMin() // BIN, rect.yMax() // BIN + 1):
            idx[(bx, by)].append((nn, rect))


def query(win, slack=S):
    seen, out = set(), []
    x0 = win.xMin() - slack
    y0 = win.yMin() - slack
    x1 = win.xMax() + slack
    y1 = win.yMax() + slack
    for bx in range(x0 // BIN, x1 // BIN + 1):
        for by in range(y0 // BIN, y1 // BIN + 1):
            for rec in idx.get((bx, by), ()):
                k = id(rec[1])
                if k in seen:
                    continue
                seen.add(k)
                if overlaps(win, rec[1], slack=slack):
                    out.append(rec)
    return out


print("INDEX_M2", flush=True)
nsh = 0
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
            add_idx(nn, odb.Rect(sh.xMin(), sh.yMin(), sh.xMax(), sh.yMax()))
            nsh += 1
print("M2_SHAPES", nsh, flush=True)

def add_idx1(nn, rect):
    for bx in range(rect.xMin() // BIN, rect.xMax() // BIN + 1):
        for by in range(rect.yMin() // BIN, rect.yMax() // BIN + 1):
            idx1[(bx, by)].append((nn, rect))


def query1(win, slack=S1):
    seen, out = set(), []
    x0, y0, x1, y1 = win.xMin() - slack, win.yMin() - slack, win.xMax() + slack, win.yMax() + slack
    for bx in range(x0 // BIN, x1 // BIN + 1):
        for by in range(y0 // BIN, y1 // BIN + 1):
            for rec in idx1.get((bx, by), ()):
                k = id(rec[1])
                if k in seen:
                    continue
                seen.add(k)
                if overlaps(win, rec[1], slack=slack):
                    out.append(rec)
    return out


def xform_box(tr, x0, y0, x1, y1):
    pts = []
    for x, y in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        p = odb.Point(int(x), int(y))
        tr.apply(p)
        pts.append((p.getX(), p.getY()))
    xs = [a for a, b in pts]
    ys = [b for a, b in pts]
    return odb.Rect(min(xs), min(ys), max(xs), max(ys))


print("INDEX_M1", flush=True)
n1 = nobs = npin = 0
for net in block.getNets():
    nn = net.getName()
    try:
        swires = net.getSWires()
    except Exception:
        swires = []
    for sw in swires:
        boxes = []
        for meth in ("getWires", "getBoxes"):
            if hasattr(sw, meth):
                try:
                    boxes = list(getattr(sw, meth)())
                    break
                except Exception:
                    pass
        for box in boxes:
            try:
                ly = box.getTechLayer()
            except Exception:
                continue
            if ly is None or ly.getName() != "Metal1":
                continue
            add_idx1(nn, odb.Rect(box.xMin(), box.yMin(), box.xMax(), box.yMax()))
            n1 += 1

# Pins/OBS around the nine rows only.
eco_wins = []
for name in INSTS:
    inst = block.findInst(name)
    bb = inst.getBBox()
    eco_wins.append(odb.Rect(bb.xMin() - RAD, bb.yMin() - RAD, bb.xMax() + RAD, bb.yMax() + RAD))


def near_eco(rect):
    for w in eco_wins:
        if overlaps(rect, w, slack=0):
            return True
    return False

for inst in block.getInsts():
    bb = inst.getBBox()
    ibr = odb.Rect(bb.xMin(), bb.yMin(), bb.xMax(), bb.yMax())
    if not near_eco(ibr):
        continue
    if inst.getName() in INSTS:
        continue
    tr = inst.getTransform()
    for it in inst.getITerms():
        pn = it.getMTerm().getName()
        if pn in SKIP:
            continue
        net = it.getNet()
        nn = "__PIN__" if net is None else net.getName()
        pbb = it.getBBox()
        add_idx1(nn, odb.Rect(pbb.xMin(), pbb.yMin(), pbb.xMax(), pbb.yMax()))
        npin += 1
    for obs in inst.getMaster().getObstructions():
        ly = obs.getTechLayer()
        if ly is None or ly.getName() != "Metal1":
            continue
        add_idx1("__OBS__" + inst.getName(), xform_box(tr, obs.xMin(), obs.yMin(), obs.xMax(), obs.yMax()))
        nobs += 1
print("M1_SPECIAL", n1, "OBS", nobs, "PINS", npin, flush=True)


def is_wide(r):
    return (r.xMax() - r.xMin()) > WIDE and (r.yMax() - r.yMin()) > WIDE


def legal1(rect, netname):
    win = odb.Rect(rect.xMin() - S1 - 20, rect.yMin() - S1 - 20, rect.xMax() + S1 + 20, rect.yMax() + S1 + 20)
    for onet, ob in query1(win, S1 + 20) + [e for e in eco1 if overlaps(win, e[1], slack=S1)]:
        g = gap_euclid(rect, ob)
        if onet == netname:
            if g == 0:
                continue
            if g < S1:
                return False
        elif g < S1:
            return False
    return True


def seg1(x1, y1, x2, y2):
    if int(x1) == int(x2):
        return odb.Rect(int(x1) - HW1, min(int(y1), int(y2)) - HW1, int(x1) + HW1, max(int(y1), int(y2)) + HW1)
    return odb.Rect(min(int(x1), int(x2)) - HW1, int(y1) - HW1, max(int(x1), int(x2)) + HW1, int(y1) + HW1)


def via_m1(vx, vy, vert):
    if vert:
        return odb.Rect(vx - 260, vy - 380, vx + 260, vy + 380)
    return odb.Rect(vx - 380, vy - 260, vx + 380, vy + 260)


def legal(rect, netname):
    win = odb.Rect(rect.xMin() - S - 20, rect.yMin() - S - 20, rect.xMax() + S + 20, rect.yMax() + S + 20)
    for onet, ob in query(win, S + 20):
        g = gap_euclid(rect, ob)
        if onet == netname:
            if g == 0:
                continue
            if g < S:
                return False
        else:
            need = int(round(0.30 * dbu)) if is_wide(ob) else S
            if g < need:
                return False
    for onet, ob in eco:
        if not overlaps(win, ob, slack=S):
            continue
        g = gap_euclid(rect, ob)
        if onet == netname:
            if g == 0:
                continue
            if g < S:
                return False
        elif g < S:
            return False
    return True


def seg(x1, y1, x2, y2):
    if int(x1) == int(x2):
        return odb.Rect(int(x1) - HW, min(int(y1), int(y2)) - HW, int(x1) + HW, max(int(y1), int(y2)) + HW)
    return odb.Rect(min(int(x1), int(x2)) - HW, int(y1) - HW, max(int(x1), int(x2)) + HW, int(y1) + HW)


def via_m2(vx, vy, vert):
    if vert:
        return odb.Rect(vx - 280, vy - 380, vx + 280, vy + 380)
    return odb.Rect(vx - 380, vy - 280, vx + 380, vy + 280)


def unique_pts(pts):
    out = []
    for p in pts:
        p = (snap(p[0]), snap(p[1]))
        if not out or out[-1] != p:
            out.append(p)
    return out


def nearest_m2(shapes, x, y, k=6):
    cands = []
    for ly, box in shapes:
        if ly != "Metal2":
            continue
        cx = min(max(x, box.xMin()), box.xMax())
        cy = min(max(y, box.yMin()), box.yMax())
        cands.append((abs(cx - x) + abs(cy - y), snap(cx), snap(cy)))
    cands.sort()
    out, seen = [], set()
    for dist, cx, cy in cands:
        if (cx, cy) in seen:
            continue
        seen.add((cx, cy))
        out.append((cx, cy, dist))
        if len(out) >= k:
            break
    return out


def via_candidates(pin, netname):
    """Legal Via1 centers whose M2 is DRC-clean and via M1 overlaps the pin.

    Center may sit slightly outside the pin so the landing can sit in a
    neighboring 0.84 um M2 channel.
    """
    out = []
    pad = 400  # 0.20 um, about Via1 M1 half-extent
    x = snap(pin.xMin() - pad)
    xmax = pin.xMax() + pad
    while x <= xmax:
        y = snap(pin.yMin() - pad)
        ymax = pin.yMax() + pad
        while y <= ymax:
            for vert in (True, False):
                if not overlaps(via_m1(x, y, vert), pin, slack=0):
                    continue
                if legal(via_m2(x, y, vert), netname):
                    out.append((x, y, vert))
            y += STEP
            if len(out) > 48:
                break
        x += STEP
        if len(out) > 48:
            break
    seen, uniq = set(), []
    for rec in out:
        if rec in seen:
            continue
        seen.add(rec)
        uniq.append(rec)
    return uniq


def path_ok(pts, netname, vert, vx, vy):
    rects = []
    for a, b in zip(pts, pts[1:]):
        if a == b:
            continue
        if a[0] != b[0] and a[1] != b[1]:
            return False, []
        r = seg(a[0], a[1], b[0], b[1])
        if r.xMax() - r.xMin() < W and r.yMax() - r.yMin() < W:
            return False, []
        if not legal(r, netname):
            return False, []
        rects.append(r)
    vb = via_m2(vx, vy, vert)
    if not legal(vb, netname):
        return False, []
    rects.append(vb)
    return True, rects


def cell_m1_obs(inst, skip_pin):
    out = []
    tr = inst.getTransform()
    for it in inst.getITerms():
        pn = it.getMTerm().getName()
        if pn in SKIP or pn == skip_pin:
            continue
        net = it.getNet()
        nn = "__PIN__" if net is None else net.getName()
        bb = it.getBBox()
        out.append((nn, odb.Rect(bb.xMin(), bb.yMin(), bb.xMax(), bb.yMax())))
    for o in inst.getMaster().getObstructions():
        ly = o.getTechLayer()
        if ly is None or ly.getName() != "Metal1":
            continue
        out.append(("__OBS__" + inst.getName(), xform_box(tr, o.xMin(), o.yMin(), o.xMax(), o.yMax())))
    return out


def legal1_extra(rect, netname, extra):
    if not legal1(rect, netname):
        return False
    for onet, ob in extra:
        g = gap_euclid(rect, ob)
        if onet == netname:
            if g == 0:
                continue
            if g < S1:
                return False
        elif g < S1:
            return False
    return True


def m1_path(pin, vx, vy, vert, netname, extra):
    """Short M1 from pin center/edge to via M1. 0/1 bend."""
    vm1 = via_m1(vx, vy, vert)
    if overlaps(vm1, pin, slack=0):
        cx = snap((pin.xMin() + pin.xMax()) // 2)
        cy = snap((pin.yMin() + pin.yMax()) // 2)
        pts = unique_pts([(cx, cy), (vx, vy)])
        if len(pts) == 1:
            pts.append(pts[0])
        return [(0, pts, [], vert)]
    px = snap((pin.xMin() + pin.xMax()) // 2)
    py = snap((pin.yMin() + pin.yMax()) // 2)
    # clamp start onto pin
    px = min(max(px, pin.xMin() + HW1), pin.xMax() - HW1)
    py = min(max(py, pin.yMin() + HW1), pin.yMax() - HW1)
    fam = [[(px, py), (vx, vy)]] if (px == vx or py == vy) else []
    fam.append([(px, py), (vx, py), (vx, vy)])
    fam.append([(px, py), (px, vy), (vx, vy)])
    best = None
    for pts in fam:
        pts = unique_pts(pts)
        if len(pts) < 2:
            continue
        ok = True
        rects = []
        for a, b in zip(pts, pts[1:]):
            if a == b:
                continue
            if a[0] != b[0] and a[1] != b[1]:
                ok = False
                break
            r = seg1(a[0], a[1], b[0], b[1])
            if not legal1_extra(r, netname, extra):
                ok = False
                break
            rects.append(r)
        if not ok:
            continue
        if not legal1_extra(vm1, netname, extra):
            continue
        ln = sum(abs(b[0] - a[0]) + abs(b[1] - a[1]) for a, b in zip(pts, pts[1:]))
        if ln > int(6.0 * dbu):
            continue
        if best is None or ln < best[0]:
            best = (ln, pts, rects, vert)
    return [best] if best else []


def find_patch(pin, net, shapes):
    """Return (kind, payload). kind HIT / PATCH / FAIL."""
    nn = net.getName()
    if pin_hit(pin, shapes):
        return "HIT", None
    vias = via_candidates(pin, nn)
    if not vias:
        return "FAIL", "no_via"
    anchors = nearest_m2(shapes, (pin.xMin() + pin.xMax()) // 2, (pin.yMin() + pin.yMax()) // 2)
    if not anchors:
        return "FAIL", "no_anchor"
    best = None
    for vx, vy, vert in vias[:16]:
        for ax, ay, _d in anchors[:4]:
            fam = []
            if ay == vy:
                fam.append([(ax, ay), (vx, vy)])
            if ax == vx:
                fam.append([(ax, ay), (vx, vy)])
            fam.append([(ax, ay), (vx, ay), (vx, vy)])
            fam.append([(ax, ay), (ax, vy), (vx, vy)])
            for dy in (-1680, -1120, -560, 560, 1120, 1680):
                fam.append([(ax, ay), (ax, ay + dy), (vx, ay + dy), (vx, vy)])
            for dx in (-1680, -1120, -560, 560, 1120, 1680):
                fam.append([(ax, ay), (ax + dx, ay), (ax + dx, vy), (vx, vy)])
            for pts in fam:
                pts = unique_pts(pts)
                if len(pts) < 2:
                    continue
                if pts[-1] != (vx, vy):
                    pts.append((vx, vy))
                    pts = unique_pts(pts)
                ok, rects = path_ok(pts, nn, vert, vx, vy)
                if not ok:
                    continue
                nb = max(0, len(pts) - 2)
                ln = sum(abs(b[0] - a[0]) + abs(b[1] - a[1]) for a, b in zip(pts, pts[1:]))
                cand = (nb, ln, pts, vert, vx, vy, rects)
                if best is None or cand[0] < best[0] or (cand[0] == best[0] and cand[1] < best[1]):
                    best = cand
                if nb <= 1:
                    break
            if best is not None and best[0] <= 1:
                break
    if best is None:
        return "FAIL", "no_path"
    return "PATCH", best


def encode(net, pts, via_obj, iterm):
    e = odb.dbWireEncoder()
    e.append(net.getWire())
    try:
        e.newPath(m2, "ROUTED", W)
    except TypeError:
        e.newPath(m2, "ROUTED")
    prev = None
    for p in pts:
        if prev is not None and p == prev:
            continue
        e.addPoint(int(p[0]), int(p[1]))
        prev = p
    for a, b in zip(pts, pts[1:]):
        if a == b:
            continue
        r = seg(a[0], a[1], b[0], b[1])
        e.addRect(r.xMin(), r.yMin(), r.xMax(), r.yMax())
    e.addTechVia(via_obj)
    e.addITerm(iterm)
    e.end()


def encode_m1(net, pts, via_obj, iterm):
    e = odb.dbWireEncoder()
    e.append(net.getWire())
    try:
        e.newPath(ttech.findLayer("Metal1"), "ROUTED", W1)
    except TypeError:
        e.newPath(ttech.findLayer("Metal1"), "ROUTED")
    prev = None
    for p in pts:
        if prev is not None and p == prev:
            continue
        e.addPoint(int(p[0]), int(p[1]))
        prev = p
    for a, b in zip(pts, pts[1:]):
        if a == b:
            continue
        r = seg1(a[0], a[1], b[0], b[1])
        e.addRect(r.xMin(), r.yMin(), r.xMax(), r.yMax())
    e.addTechVia(via_obj)
    e.addITerm(iterm)
    e.end()


def find_patch_strong(inst, pin, pn, net, shapes):
    """HIT, M2 PATCH, or M1-to-existing-M2 PATCH."""
    kind, payload = find_patch(pin, net, shapes)
    if kind != "FAIL":
        return kind, payload, "M2"
    nn = net.getName()
    extra = cell_m1_obs(inst, pn)
    anchors = nearest_m2(shapes, (pin.xMin() + pin.xMax()) // 2, (pin.yMin() + pin.yMax()) // 2, k=12)
    best = None
    for ax, ay, dist in anchors:
        if dist > int(8.0 * dbu):
            continue
        for vert in (True, False):
            if not legal(via_m2(ax, ay, vert), nn):
                continue
            hits = m1_path(pin, ax, ay, vert, nn, extra)
            if not hits or hits[0] is None:
                continue
            ln, pts, rects, vert2 = hits[0]
            cand = (0 if ln == 0 else 1, ln + dist // 8, pts, vert2, ax, ay, rects, "M1")
            if best is None or cand[1] < best[1]:
                best = cand
    if best is None:
        return "FAIL", "no_m1_via", "M1"
    return "PATCH", best[:7], "M1"


# Row occupancy
by_y = defaultdict(list)
for inst in block.getInsts():
    bb = inst.getBBox()
    by_y[bb.yMin()].append(inst)


def fill_only_xs(inst, allow_tie=False):
    x, y = inst.getLocation()
    cw = inst.getMaster().getWidth()
    ch = inst.getMaster().getHeight()
    row = by_y[inst.getBBox().yMin()]
    n_sites = int(RAD // SW)
    out = []
    for k in range(-n_sites, n_sites + 1):
        nx = x + k * SW
        dest = odb.Rect(nx, y, nx + cw, y + ch)
        ok = True
        for o in row:
            if o.getName() == inst.getName():
                continue
            ob = o.getBBox()
            if ob.xMax() <= dest.xMin() or dest.xMax() <= ob.xMin():
                continue
            mn = o.getMaster().getName()
            if is_fill(mn, strict=True):
                continue
            if (not allow_tie) and (("__filltie" in mn) or ("__endcap" in mn)):
                ok = False
                break
            if ("__filltie" in mn) or ("__endcap" in mn):
                continue
            ok = False
            break
        if ok:
            out.append((abs(k), k, nx))
    out.sort()
    return out


def eval_at(inst, nx):
    x0, y = inst.getLocation()
    inst.setPlacementStatus("PLACED")
    inst.setLocation(int(nx), int(y))
    hits = patches = fails = 0
    wire = 0
    details = []
    for it in inst.getITerms():
        pn = it.getMTerm().getName()
        if pn in SKIP:
            continue
        net = it.getNet()
        pin = pin_box(it)
        if net is None or net.getWire() is None:
            fails += 1
            details.append((pn, "FAIL", "no_net"))
            continue
        shapes = collect_shapes(net)
        kind, payload, _ly = find_patch_strong(inst, pin, pn, net, shapes)
        details.append((pn, kind, payload))
        if kind == "HIT":
            hits += 1
        elif kind == "PATCH":
            patches += 1
            wire += payload[1]
        else:
            fails += 1
    inst.setLocation(int(x0), int(y))
    return fails, patches, wire, details


rpt = open(OUT + "/co6a34_moves.rpt", "w")
rpt.write("inst old_x new_x delta row k hits patches fails\n")
moves = []

# Rotate all nine to R180 at original XY first.
for name in INSTS:
    inst = block.findInst(name)
    x, y = inst.getLocation()
    print("BEFORE", name, inst.getOrient(), um(x), um(y), flush=True)
    inst.setPlacementStatus("PLACED")
    inst.setOrient("R180")
    inst.setLocation(x, y)
    print("AFTER_R180", name, inst.getOrient(), flush=True)

# Search and commit one cell at a time so later cells see committed eco metal.
for name in INSTS:
    inst = block.findInst(name)
    x0, y0 = inst.getLocation()
    cands = fill_only_xs(inst, allow_tie=True)
    print(name, "N_CAND_X", len(cands), "old_x", um(x0), flush=True)
    best = None
    bestk = None
    bestdet = None
    bestnx = None
    # Try small |k| first (cands already sorted by abs k).
    for abs_k, k, nx in cands:
        fails, patches, wire, details = eval_at(inst, nx)
        print("  TRY k=%d x=%.3f fails=%d patches=%d hits=%d wire_um=%.3f" % (
            k, um(nx), fails, patches, 6 - fails - patches, um(wire)), flush=True)
        rec = (fails, patches, wire, abs_k)
        if best is None or rec < best:
            best = rec
            bestk = k
            bestdet = details
            bestnx = nx
        if fails == 0 and patches == 0:
            break
        if best[0] == 0 and abs_k > 8:
            break
    if best is None:
        print("NO_CAND_X", name, flush=True)
        rpt.write("%s %.3f FAIL\n" % (name, um(x0)))
        moves.append((name, x0, x0, 0, y0, 0, 0, "FAIL"))
        continue
    print("PICK", name, "k", bestk, "fails", best[0], "patches", best[1], "x", um(bestnx), flush=True)

    # Commit best X even if eval still had fails; strong patch tries M1-to-M2.
    cw = inst.getMaster().getWidth()
    ch = inst.getMaster().getHeight()
    dest = odb.Rect(bestnx, y0, bestnx + cw, y0 + ch)
    row = list(by_y[inst.getBBox().yMin()])
    killed = 0
    for o in row:
        if o.getName() == name:
            continue
        ob = o.getBBox()
        if ob.xMax() <= dest.xMin() or dest.xMax() <= ob.xMin():
            continue
        mn = o.getMaster().getName()
        if not is_fill(mn, strict=False):
            continue
        odb.dbInst.destroy(o)
        killed += 1
    inst.setPlacementStatus("PLACED")
    inst.setLocation(int(bestnx), int(y0))
    inst.setPlacementStatus("FIRM")
    # Re-eval details at committed X and encode patches.
    npatch = 0
    for it in inst.getITerms():
        pn = it.getMTerm().getName()
        if pn in SKIP:
            continue
        net = it.getNet()
        pin = pin_box(it)
        shapes = [] if net is None else collect_shapes(net)
        if net is None:
            print("FAIL", name, pn, "no_net", flush=True)
            continue
        kind, payload, layer = find_patch_strong(inst, pin, pn, net, shapes)
        if kind == "PATCH":
            nb, ln, pts, vert, vx, vy, rects = payload[:7]
            via_obj = via_vv if vert else via_vh
            try:
                if layer == "M1":
                    encode_m1(net, pts, via_obj, it)
                    for r in rects:
                        eco1.append((net.getName(), r))
                        add_idx1(net.getName(), r)
                    add_idx(net.getName(), via_m2(vx, vy, vert))
                else:
                    encode(net, pts, via_obj, it)
                    for r in rects:
                        eco.append((net.getName(), r))
                        add_idx(net.getName(), r)
            except Exception as ex:
                print("ENCODE_FAIL", name, pn, ex, flush=True)
                continue
            npatch += 1
            print("PATCH", layer, name, pn, "bends", nb, "len_um", um(ln),
                  "via", via_obj.getName(), um(vx), um(vy),
                  "pts", " -> ".join("%.3f,%.3f" % (um(p[0]), um(p[1])) for p in pts),
                  flush=True)
        else:
            print(kind, name, pn, payload if kind != "HIT" else "", flush=True)
    print("COMMIT", name, "old", um(x0), "new", um(bestnx), "delta", um(bestnx - x0),
          "k", bestk, "killed_fill", killed, "patches", npatch, flush=True)
    rpt.write("%s %.3f %.3f %.3f %.3f %d hits_fail=%s patches=%d\n" % (
        name, um(x0), um(bestnx), um(bestnx - x0), um(y0), bestk, str(best[0]), npatch))
    moves.append((name, x0, bestnx, bestnx - x0, y0, bestk, npatch, "OK"))
    # rebuild by_y for this row after destroy/move
    ykey = y0  # origin y unchanged
    by_y[ykey] = [i for i in block.getInsts() if i.getBBox().yMin() == inst.getBBox().yMin() or i.getLocation()[1] == y0]

rpt.close()

# Recount access
miss = 0
for name in INSTS:
    inst = block.findInst(name)
    for it in inst.getITerms():
        pn = it.getMTerm().getName()
        if pn in SKIP:
            continue
        net = it.getNet()
        pin = pin_box(it)
        shapes = [] if net is None else collect_shapes(net)
        if not pin_hit(pin, shapes):
            miss += 1
            print("STILL_MISS", name, pn, "-" if net is None else net.getName(), flush=True)
print("STILL_MISS_COUNT", miss, flush=True)

nshort = 0
for nn, r in eco:
    for onet, ob in query(r, 0):
        if onet != nn and gap_euclid(r, ob) == 0 and id(ob) != id(r):
            nshort += 1
            print("SHORT", nn, "vs", onet, flush=True)
for nn, r in eco1:
    for onet, ob in query1(r, 0):
        if onet != nn and gap_euclid(r, ob) == 0 and id(ob) != id(r):
            nshort += 1
            print("SHORT_M1", nn, "vs", onet, flush=True)
print("PRESCREEN_SHORTS", nshort, "NEW_M2", len(eco), "NEW_M1", len(eco1), flush=True)

n_mx = n_r180 = n_r0 = n_my = nsram = 0
for inst in block.getInsts():
    mn = inst.getMaster().getName()
    if "sram256x8m8wm1" in mn:
        nsram += 1
        print("SRAM", inst.getName(), um(inst.getLocation()[0]), um(inst.getLocation()[1]), inst.getOrient(), flush=True)
    if mn == "gf180mcu_fd_sc_mcu9t5v0__aoi221_2":
        o = str(inst.getOrient())
        n_mx += o == "MX"
        n_r180 += o == "R180"
        n_r0 += o == "R0"
        n_my += o == "MY"
print("AOI221_2 MX", n_mx, "R180", n_r180, "R0", n_r0, "MY", n_my, "SRAM", nsram,
      "BTERMS", len(list(block.getBTerms())), flush=True)

d.writeDb(CAND + "/butterfold_top_co6a34.odb")
d.writeDef(CAND + "/butterfold_top_co6a34.def")
print("WROTE_CO6A34", "MISS", miss, "SHORTS", nshort, flush=True)
