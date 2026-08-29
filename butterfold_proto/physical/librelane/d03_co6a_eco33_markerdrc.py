#!/usr/bin/env python3
"""Marker-driven M2.1/M2.2a cleanup using actual 0.28 um channels.

Deck: M2.1 width 0.28 um, M2.2a space 0.28 um (euclidean).
0.56 um-pitch M2 cannot host a third 0.28 um wire.  Only gaps whose
edge-to-edge clearance is >= 0.84 um (0.28 wire + 0.28 + 0.28) are used.
Via1 is placed where a legal channel overlaps the R180 M1 pin.
No TritonRoute.  Nine R180 aoi221_2 unchanged.
"""
from __future__ import annotations

import math
import re
from collections import defaultdict

from openroad import Tech, Design
import odb

PDK = "/foss/pdks/gf180mcuD"
CAND = "physical/results/d03_ach_candidate"
OUT = "physical/reports/signoff/evidence/d03_ach/drc"
LYRDB = CAND + "/klayout_drc_co6a32/butterfold_top_metal2.lyrdb"
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
ttech = tech.getDB().getTech()
m2 = ttech.findLayer("Metal2")
via_vv = ttech.findVia("Via1_VV")
via_vh = ttech.findVia("Via1_VH")
dbu = block.getDefUnits()
W = int(round(0.28 * dbu)); HW = W // 2; S = int(round(0.28 * dbu))
WIDE = int(round(10.0 * dbu)); GRID = 10; STEP = 140
WIN = int(round(6.0 * dbu))
print("DBU", dbu, "W", W, "S", S, flush=True)


def um(v):
    return v / float(dbu)


def snap(v, g=GRID):
    return int(round(v / float(g)) * g)


def pin_boxes(iterm):
    bb = iterm.getBBox()
    return [odb.Rect(bb.xMin(), bb.yMin(), bb.xMax(), bb.yMax())]


def overlaps(a, b, slack=0):
    return not (a.xMax() < b.xMin() - slack or b.xMax() < a.xMin() - slack
                or a.yMax() < b.yMin() - slack or b.yMax() < a.yMin() - slack)


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


def pin_hit(pin_rects, shapes):
    for _ly, box in shapes:
        for p in pin_rects:
            if overlaps(p, box, slack=1):
                return True
    return False


def parse_markers(path):
    text = open(path).read()
    items = []
    for m in re.finditer(r"<category>'([^']+)'</category>.*?<value>([^<]+)</value>", text, re.S):
        cat, val = m.group(1), m.group(2)
        if cat not in ("M2.1", "M2.2a"):
            continue
        nums = [float(x) for x in re.findall(r"-?\d+\.\d+", val)]
        if len(nums) < 4:
            continue
        xs, ys = nums[0::2], nums[1::2]
        items.append((cat, sum(xs) / len(xs), sum(ys) / len(ys)))
    return items


markers = parse_markers(LYRDB)
print("MARKERS", len(markers), flush=True)

for name in INSTS:
    inst = block.findInst(name)
    print("BEFORE", name, inst.getOrient(), flush=True)
    x, y = inst.getLocation()
    inst.setPlacementStatus("PLACED")
    inst.setOrient("R180")
    inst.setLocation(x, y)
    inst.setPlacementStatus("FIRM")

inst_bb = {}
for name in INSTS:
    bb = block.findInst(name).getBBox()
    inst_bb[name] = odb.Rect(bb.xMin(), bb.yMin(), bb.xMax(), bb.yMax())

need, leave = [], 0
for name in INSTS:
    inst = block.findInst(name)
    for it in inst.getITerms():
        pn = it.getMTerm().getName()
        if pn in SKIP:
            continue
        net = it.getNet()
        r180 = pin_boxes(it)
        shapes = [] if net is None else collect_shapes(net)
        if pin_hit(r180, shapes):
            leave += 1
        else:
            need.append((name, pn, it, net, r180, shapes))
print("LEAVE", leave, "PATCH", len(need), flush=True)

dirty = set()
for cat, cx, cy in markers:
    best = bestd = None
    for name, pn, it, net, r180, _sh in need:
        bb = inst_bb[name]
        ix0, iy0, ix1, iy1 = um(bb.xMin()), um(bb.yMin()), um(bb.xMax()), um(bb.yMax())
        dx = 0.0 if ix0 <= cx <= ix1 else min(abs(cx - ix0), abs(cx - ix1))
        dy = 0.0 if iy0 <= cy <= iy1 else min(abs(cy - iy0), abs(cy - iy1))
        celld = math.hypot(dx, dy)
        if bestd is None or celld < bestd:
            bestd = celld
            best = (name, pn)
    if best and bestd <= 4.0:
        dirty.add(best)
print("DIRTY", len(dirty), flush=True)

BIN = 2000
idx = defaultdict(list)
eco = []


def add_idx(nn, rect):
    for bx in range(rect.xMin() // BIN, rect.xMax() // BIN + 1):
        for by in range(rect.yMin() // BIN, rect.yMax() // BIN + 1):
            idx[(bx, by)].append((nn, rect))


def query(win, slack=S):
    seen, out = set(), []
    x0, y0, x1, y1 = win.xMin() - slack, win.yMin() - slack, win.xMax() + slack, win.yMax() + slack
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
print("M2_INDEX", nsh, flush=True)


def is_wide(r):
    return (r.xMax() - r.xMin()) > WIDE and (r.yMax() - r.yMin()) > WIDE


def legal(rect, netname):
    win = odb.Rect(rect.xMin() - S - 20, rect.yMin() - S - 20, rect.xMax() + S + 20, rect.yMax() + S + 20)
    for onet, ob in query(win, S + 20) + [e for e in eco if overlaps(win, e[1], slack=S)]:
        g = gap_euclid(rect, ob)
        if onet == netname:
            if g == 0:
                continue
            if g < S:
                return False
        else:
            need_s = int(round(0.30 * dbu)) if is_wide(ob) else S
            if g < need_s:
                return False
    return True


def seg(x1, y1, x2, y2):
    if x1 == x2:
        return odb.Rect(x1 - HW, min(y1, y2) - HW, x1 + HW, max(y1, y2) + HW)
    return odb.Rect(min(x1, x2) - HW, y1 - HW, max(x1, x2) + HW, y1 + HW)


def via_box(vx, vy, vert):
    if vert:
        return odb.Rect(vx - 280, vy - 380, vx + 280, vy + 380)
    return odb.Rect(vx - 380, vy - 280, vx + 380, vy + 280)


def via_m1(vx, vy, vert):
    if vert:
        return odb.Rect(vx - 260, vy - 380, vx + 260, vy + 380)
    return odb.Rect(vx - 380, vy - 260, vx + 380, vy + 260)


def unique_pts(pts):
    out = []
    for p in pts:
        p = (snap(p[0]), snap(p[1]))
        if not out or out[-1] != p:
            out.append(p)
    return out


def legal_path(pts, netname, vert, vx, vy):
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
    vb = via_box(vx, vy, vert)
    if not legal(vb, netname):
        return False, []
    rects.append(vb)
    return True, rects


def channels(win):
    """Return legal 0.28 um vertical x-centers and horizontal y-centers in win."""
    obs = query(win, S)
    # vertical obstacles: x-intervals of M2 that occupy some y in the window
    xspans = []
    yspans = []
    for nn, r in obs:
        xspans.append((r.xMin(), r.xMax(), (r.xMin() + r.xMax()) // 2, r.xMax() - r.xMin()))
        yspans.append((r.yMin(), r.yMax(), (r.yMin() + r.yMax()) // 2, r.yMax() - r.yMin()))
    # cluster x-centers of primarily-vertical shapes
    verts = sorted((r.xMin(), r.xMax()) for _nn, r in obs if (r.yMax() - r.yMin()) >= (r.xMax() - r.xMin()))
    hors = sorted((r.yMin(), r.yMax()) for _nn, r in obs if (r.xMax() - r.xMin()) >= (r.yMax() - r.yMin()))

    def gap_centers(spans, lo, hi):
        # merge overlapping spans then find gaps >= 0.84 um
        if not spans:
            return [snap((lo + hi) // 2)]
        spans = sorted(spans)
        merged = [list(spans[0])]
        for a, b in spans[1:]:
            if a <= merged[-1][1] + 1:
                merged[-1][1] = max(merged[-1][1], b)
            else:
                merged.append([a, b])
        # also consider window edges as walls
        walls = [[lo - W, lo]] + merged + [[hi, hi + W]]
        out = []
        for i in range(1, len(walls)):
            gap = walls[i][0] - walls[i - 1][1]
            if gap >= 2 * S + W - 1:
                c = snap((walls[i - 1][1] + walls[i][0]) // 2)
                out.append(c)
        return out

    xs = gap_centers(verts, win.xMin(), win.xMax())
    ys = gap_centers(hors, win.yMin(), win.yMax())
    return xs, ys


def encode(net, pts, via_obj, iterm, width=W):
    e = odb.dbWireEncoder()
    e.append(net.getWire())
    try:
        e.newPath(m2, "ROUTED", width)
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


patched, failed = 0, []
mapf = open(OUT + "/co6a33_marker_map.rpt", "w")
mapf.write("RULES M2.1=0.28 M2.2a=0.28 channel_gap>=0.84\n")

for name, pn, it, net, r180, shapes in sorted(need, key=lambda r: (0 if (r[0], r[1]) in dirty else 1, r[0], r[1])):
    nn = "-" if net is None else net.getName()
    if net is None or net.getWire() is None:
        failed.append((name, pn, nn, "no wire"))
        continue
    inst = block.findInst(name)
    bb = inst.getBBox()
    pin = max(r180, key=lambda r: (r.xMax() - r.xMin()) * (r.yMax() - r.yMin()))
    win = odb.Rect(bb.xMin() - WIN, bb.yMin() - WIN, bb.xMax() + WIN, bb.yMax() + WIN)
    xs, ys = channels(win)
    # also allow same-net M2 centerlines as tracks
    for ly, box in shapes:
        if ly != "Metal2":
            continue
        if (box.yMax() - box.yMin()) >= (box.xMax() - box.xMin()):
            xs.append(snap((box.xMin() + box.xMax()) // 2))
        else:
            ys.append(snap((box.yMin() + box.yMax()) // 2))
    xs = sorted(set(xs))
    ys = sorted(set(ys))
    anchors = nearest_m2(shapes, (pin.xMin() + pin.xMax()) // 2, (pin.yMin() + pin.yMax()) // 2)
    # via positions: legal channel coords whose via M1 overlaps pin
    vias = []
    for vert, via_obj, tracks, other in (
        (True, via_vv, xs, ys),
        (False, via_vh, ys, xs),
    ):
        for t in tracks:
            if vert:
                vx = t
                # vy samples in/near pin
                vys = [snap((pin.yMin() + pin.yMax()) // 2)]
                y = snap(pin.yMin())
                while y <= pin.yMax():
                    vys.append(y)
                    y += STEP
                for o in other:
                    if pin.yMin() - 400 <= o <= pin.yMax() + 400:
                        vys.append(o)
                for vy in set(vys):
                    if overlaps(via_m1(vx, vy, True), pin, slack=0) and legal(via_box(vx, vy, True), nn):
                        vias.append((abs(vx - (pin.xMin() + pin.xMax()) // 2) + abs(vy - (pin.yMin() + pin.yMax()) // 2),
                                     vx, vy, True, via_obj))
            else:
                vy = t
                vxs = [snap((pin.xMin() + pin.xMax()) // 2)]
                x = snap(pin.xMin())
                while x <= pin.xMax():
                    vxs.append(x)
                    x += STEP
                for o in other:
                    if pin.xMin() - 400 <= o <= pin.xMax() + 400:
                        vxs.append(o)
                for vx in set(vxs):
                    if overlaps(via_m1(vx, vy, False), pin, slack=0) and legal(via_box(vx, vy, False), nn):
                        vias.append((abs(vx - (pin.xMin() + pin.xMax()) // 2) + abs(vy - (pin.yMin() + pin.yMax()) // 2),
                                     vx, vy, False, via_obj))
    vias.sort()

    def astar_tracks(ax, ay, vx, vy, vert):
        """A* on the legal x/y channel grid plus the two endpoints."""
        import heapq
        xset = sorted(set(xs + [ax, vx]))
        yset = sorted(set(ys + [ay, vy]))
        start, goal = (ax, ay), (vx, vy)
        def neigh(p):
            px, py = p
            for x in xset:
                if x != px:
                    yield (x, py)
            for y in yset:
                if y != py:
                    yield (px, y)
        def h(p):
            return abs(p[0] - vx) + abs(p[1] - vy)
        openh = [(h(start), 0, start)]
        came, gsc, seen = {}, {start: 0}, set()
        found = None
        n = 0
        while openh and n < 8000:
            _f, g, cur = heapq.heappop(openh)
            if cur in seen:
                continue
            seen.add(cur)
            n += 1
            if cur == goal:
                found = cur
                break
            for nxt in neigh(cur):
                if nxt in seen:
                    continue
                r = seg(cur[0], cur[1], nxt[0], nxt[1])
                if not legal(r, nn):
                    continue
                ng = g + abs(nxt[0] - cur[0]) + abs(nxt[1] - cur[1])
                if ng >= gsc.get(nxt, 10 ** 18):
                    continue
                gsc[nxt] = ng
                came[nxt] = cur
                heapq.heappush(openh, (ng + h(nxt), ng, nxt))
        if found is None:
            return None
        pts = [found]
        while pts[-1] in came:
            pts.append(came[pts[-1]])
            if pts[-1] == start:
                break
        pts.reverse()
        if pts[0] != start:
            pts = [start] + pts
        if pts[-1] != goal:
            pts.append(goal)
        return unique_pts(pts)

    best = None
    ntry = 0
    for _d, vx, vy, vert, via_obj in vias[:20]:
        for ax, ay, _ad in anchors[:4]:
            fam = []
            if ay == vy:
                fam.append([(ax, ay), (vx, vy)])
            if ax == vx:
                fam.append([(ax, ay), (vx, vy)])
            fam.append([(ax, ay), (vx, ay), (vx, vy)])
            fam.append([(ax, ay), (ax, vy), (vx, vy)])
            for ty in ys[:12]:
                fam.append([(ax, ay), (ax, ty), (vx, ty), (vx, vy)])
            for tx in xs[:12]:
                fam.append([(ax, ay), (tx, ay), (tx, vy), (vx, vy)])
            for pts in fam:
                ntry += 1
                pts = unique_pts(pts)
                if len(pts) < 2:
                    continue
                if pts[-1] != (vx, vy):
                    pts.append((vx, vy))
                    pts = unique_pts(pts)
                ok, rects = legal_path(pts, nn, vert, vx, vy)
                if not ok:
                    continue
                nb = max(0, len(pts) - 2)
                ln = sum(abs(b[0] - a[0]) + abs(b[1] - a[1]) for a, b in zip(pts, pts[1:]))
                cand = (nb, ln, pts, vert, vx, vy, via_obj, rects)
                if best is None or cand[0] < best[0] or (cand[0] == best[0] and cand[1] < best[1]):
                    best = cand
                if nb <= 1:
                    break
            if best is None:
                pts = astar_tracks(ax, ay, vx, vy, vert)
                ntry += 1
                if pts is not None:
                    ok, rects = legal_path(pts, nn, vert, vx, vy)
                    if ok:
                        nb = max(0, len(pts) - 2)
                        ln = sum(abs(b[0] - a[0]) + abs(b[1] - a[1]) for a, b in zip(pts, pts[1:]))
                        cand = (nb, ln, pts, vert, vx, vy, via_obj, rects)
                        if best is None or cand[0] < best[0] or (cand[0] == best[0] and cand[1] < best[1]):
                            best = cand
            if best is not None and best[0] <= 1:
                break
        if best is not None and best[0] <= 1:
            break

    if best is None:
        print("NO_LEGAL", name, pn, nn, "vias", len(vias), "xs", len(xs), "ys", len(ys),
              "pin", "%.3f,%.3f-%.3f,%.3f" % (um(pin.xMin()), um(pin.yMin()), um(pin.xMax()), um(pin.yMax())),
              flush=True)
        failed.append((name, pn, nn, "no legal M2 channel via"))
        mapf.write("FAIL %s %s %s vias=%d xs=%d ys=%d\n" % (name, pn, nn, len(vias), len(xs), len(ys)))
        continue

    nb, ln, pts, vert, vx, vy, via_obj, rects = best
    try:
        encode(net, pts, via_obj, it)
    except Exception as ex:
        print("ENCODE_FAIL", name, pn, ex, flush=True)
        failed.append((name, pn, nn, str(ex)))
        continue
    for r in rects:
        eco.append((nn, r))
        add_idx(nn, r)
    tag = "DIRTY" if (name, pn) in dirty else "CLEAN"
    print("PATCH", name, pn, tag, "bends", nb, "len_um", um(ln),
          "via", via_obj.getName(), um(vx), um(vy),
          "pts", " -> ".join("%.3f,%.3f" % (um(p[0]), um(p[1])) for p in pts),
          flush=True)
    patched += 1

print("PATCHED", patched, "FAILED", len(failed), flush=True)
miss = 0
for name in INSTS:
    inst = block.findInst(name)
    for it in inst.getITerms():
        pn = it.getMTerm().getName()
        if pn in SKIP:
            continue
        net = it.getNet()
        if not pin_hit(pin_boxes(it), [] if net is None else collect_shapes(net)):
            miss += 1
            print("STILL_MISS", name, pn, flush=True)
print("STILL_MISS", miss, flush=True)

n_mx = n_r180 = n_r0 = n_my = nsram = 0
for inst in block.getInsts():
    mn = inst.getMaster().getName()
    if "sram256x8m8wm1" in mn:
        nsram += 1
    if mn == "gf180mcu_fd_sc_mcu9t5v0__aoi221_2":
        o = str(inst.getOrient())
        n_mx += o == "MX"; n_r180 += o == "R180"; n_r0 += o == "R0"; n_my += o == "MY"
print("AOI221_2 MX", n_mx, "R180", n_r180, "R0", n_r0, "MY", n_my, "SRAM", nsram, flush=True)
if failed:
    mapf.write("FAILED_BEGIN\n")
    for rec in failed:
        mapf.write(" ".join(str(x) for x in rec) + "\n")
    mapf.write("FAILED_END\n")
mapf.close()
d.writeDb(CAND + "/butterfold_top_co6a33.odb")
d.writeDef(CAND + "/butterfold_top_co6a33.def")
print("WROTE_CO6A33", "OK" if not failed and miss == 0 else "INCOMPLETE", flush=True)
