#!/usr/bin/env python3
"""Place ACH tie/load cells and stitch 2-pin nets in the padframe halo.

Escape the core on Metal2 (vertical) so last-row Metal3 is never used as a
shared trunk. Long runs stay on unique M2 tracks; M3 is used only for
short padframe jogs and antenna U-bridges. Does not run DRT.
"""
from __future__ import annotations

import os
from collections import defaultdict

from openroad import Design, Tech
import odb

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.environ.get(
    "STITCH_SRC",
    PROTO + "/physical/results/native_power_ring_ach/predrt/applied_m3cut.odb",
)
DST = os.environ.get(
    "STITCH_DST",
    PROTO + "/physical/results/native_power_ring_ach/predrt/applied_m3cut_stitched.odb",
)
LOG = os.environ.get(
    "STITCH_LOG",
    PROTO + "/physical/results/native_power_ring_ach/predrt/stitch_ties.log",
)

# 0.28 um half-pitch grid used by GF180 M2/M3.
TRACK0 = 560
PITCH = 1120
# 0.28 um: allows 0.73 um organizer pin pitch, forbids overlap of centerlines.
# M2.2a needs 0.56 um center-to-center; use PITCH slop for escape-vs-PIN/native.
SLOP = 560
ANT_LEN = 80 * 2000
JOG = 2 * PITCH
GAP = 2 * PITCH
HALO_Y = 1098 * 2000 + TRACK0  # just above core / last-row M3
NORTH_YVIA = int(1672.44 * 2000)  # 80ef-style short north PIN stub
WEST_PIN_VIA_X = int(0.84 * 2000)
MIN_M2 = PITCH  # 0.56 um: Via2 pad 0.28x0.38 fails M2.3 without extra M2


def bterm_box(bt, prefer="Metal2"):
    boxes = []
    for bp in bt.getBPins():
        for box in bp.getBoxes():
            lyr = box.getTechLayer()
            boxes.append((lyr.getName() if lyr else "?", box.xMin(), box.yMin(), box.xMax(), box.yMax()))
    pref = [b for b in boxes if b[0] == prefer]
    use = pref or boxes
    if not use:
        return None
    _, x1, y1, x2, y2 = use[0]
    return (x1, y1, x2, y2)


def inst_origin(inst):
    try:
        loc = inst.getLocation()
        return int(loc[0]), int(loc[1])
    except Exception:
        bb = inst.getBBox()
        return int(bb.xMin()), int(bb.yMin())


def iterm_xy(it):
    inst = it.getInst()
    ox, oy = inst_origin(inst)
    orient = str(inst.getOrient())
    mw = inst.getMaster().getWidth()
    mh = inst.getMaster().getHeight()
    mterm = it.getMTerm()
    xs, ys = [], []

    def xf(x, y):
        if orient in ("R0", "N"):
            return ox + x, oy + y
        if orient in ("MX", "FS"):
            return ox + x, oy + mh - y
        if orient in ("MY", "FN"):
            return ox + mw - x, oy + y
        if orient in ("R180", "S"):
            return ox + mw - x, oy + mh - y
        return ox + x, oy + y

    for mp in mterm.getMPins():
        for box in mp.getGeometry():
            x1, y1 = xf(box.xMin(), box.yMin())
            x2, y2 = xf(box.xMax(), box.yMax())
            xs += [x1, x2]
            ys += [y1, y2]
    if not xs:
        bb = inst.getBBox()
        return (bb.xMin() + bb.xMax()) // 2, (bb.yMin() + bb.yMax()) // 2
    return (min(xs) + max(xs)) // 2, (min(ys) + max(ys)) // 2


def snap(v, pitch, origin=0):
    return origin + int(round((v - origin) / pitch)) * pitch


def snap_track(v):
    return TRACK0 + int(round((v - TRACK0) / PITCH)) * PITCH


def segs_of(wire):
    if wire is None:
        return []
    dec = odb.dbWireDecoder()
    dec.begin(wire)
    out = []
    layer = None
    last = None
    while True:
        op = dec.next()
        if op == odb.dbWireDecoder.END_DECODE:
            break
        if op in (odb.dbWireDecoder.PATH, odb.dbWireDecoder.SHORT, odb.dbWireDecoder.VWIRE):
            lyr = dec.getLayer()
            layer = lyr.getName() if lyr else None
            last = None
            continue
        if op in (odb.dbWireDecoder.POINT, odb.dbWireDecoder.POINT_EXT):
            pt = dec.getPoint()
            xy = (int(pt[0]), int(pt[1]))
            if last is not None and layer is not None and xy != last:
                out.append((layer, last[0], last[1], xy[0], xy[1]))
            last = xy
            continue
        if op in (odb.dbWireDecoder.TECH_VIA, odb.dbWireDecoder.VIA):
            last = None
    return out


class Obst:
    def __init__(self):
        self.segs = defaultdict(list)

    def add(self, layer, x1, y1, x2, y2, name):
        self.segs[layer].append((int(x1), int(y1), int(x2), int(y2), name))

    def hits(self, layer, x1, y1, x2, y2, me, slop=SLOP, skip_prefix=None):
        if x1 > x2:
            x1, x2 = x2, x1
        if y1 > y2:
            y1, y2 = y2, y1
        x1 -= slop
        y1 -= slop
        x2 += slop
        y2 += slop
        for a, b, c, d, n in self.segs.get(layer, []):
            if n == me:
                continue
            if skip_prefix and n.startswith(skip_prefix):
                continue
            aa, cc = (a, c) if a <= c else (c, a)
            bb, dd = (b, d) if b <= d else (d, b)
            if not (x2 < aa or cc < x1 or y2 < bb or dd < y1):
                return n
        return None


def pin_clear(x, pin_xs, gap=PITCH):
    return all(abs(int(x) - int(px)) >= gap for px in pin_xs)


def choose_escape_x(sx0, pin_xs, obst, name, y0, y1, last_row=False):
    """Snap to a track >= 0.56 um from every PIN x.

    Last-row native M2 sits ~0.56 um below the iterm. Prefer a track that
    also clears that, but never walk more than ~13 um (that used to throw
    the M3 jog across the whole padframe and starve the 1672 um band).
    """
    x = snap_track(sx0)
    fallback = None
    for k in range(0, 24):
        for sign in (0,) if k == 0 else (1, -1):
            xx = x + sign * k * PITCH
            if not pin_clear(xx, pin_xs, PITCH):
                continue
            if fallback is None:
                fallback = xx
            if last_row and obst.hits("Metal2", xx, y0, xx, y0, name, slop=PITCH):
                continue
            probe = y0 + (PITCH if y1 >= y0 else -PITCH)
            if obst.hits("Metal2", xx, y0, xx, probe, name, slop=SLOP):
                continue
            return xx
    return fallback if fallback is not None else x


def load_native(block, obst, skip_names):
    n = 0
    for net in block.getNets():
        nm = net.getName()
        if nm in skip_names:
            continue
        st = str(net.getSigType())
        if st in ("POWER", "GROUND"):
            continue
        w = net.getWire()
        if w is None:
            continue
        for lyr, x1, y1, x2, y2 in segs_of(w):
            obst.add(lyr, x1, y1, x2, y2, nm)
            n += 1
    return n


def encode(enc, ops, via1, via2, m2):
    """ops: ('pt', layer, x, y) | ('via', via) | ('via1',)."""
    cur = None
    # Always tap M1 pin with Via1 at the first point.
    first = next(op for op in ops if op[0] == "pt")
    enc.newPath(m2, "ROUTED")
    enc.addPoint(int(first[2]), int(first[3]))
    enc.addTechVia(via1)
    cur = None
    for op in ops:
        if op[0] == "via":
            enc.addTechVia(op[1])
            cur = None
        elif op[0] == "pt":
            lyr, x, y = op[1], int(op[2]), int(op[3])
            if cur is not lyr:
                enc.newPath(lyr, "ROUTED")
                cur = lyr
            enc.addPoint(x, y)


def try_add(obst, net, layer, x1, y1, x2, y2):
    hit = obst.hits(layer, x1, y1, x2, y2, net)
    if hit is not None:
        return hit
    obst.add(layer, x1, y1, x2, y2, net)
    return None


def m2_horiz(obst, net, m2, x0, y, x1):
    hit = obst.hits("Metal2", x0, y, x1, y, net)
    if hit:
        return None, hit
    obst.add("Metal2", x0, y, x1, y, net)
    return [("pt", m2, x1, y)], None


def m2_vertical(obst, net, m2, m3, via2, x, y0, y1, hop_sign, no_nudge=False,
                hop_ymin=None, hop_ymax=None, avoid_xs=None):
    """M2 vertical with M3 U-hops every ANT_LEN.

    Returns (ops, x_end) or an error string. x_end may differ from x if the
    run had to jog around a native vertical.
    hop_ymin/hop_ymax: do not insert padframe Via2 hops outside this y band
    (core). Tiel nets do not need hops; buf_1 padframe hops Mag-merge to VSS.
    Never hop onto y1: a hop landing at the destination leaves only a Via2
    pad (M2.3).
    """
    ops = [("pt", m2, x, y0)]
    y = y0
    direction = 1 if y1 > y0 else -1
    last_hop = y0
    guard = 0
    # First pitch is always pure M2 so Via1 at the iterm is not stacked on Via2.
    first_need = min(abs(y1 - y0), MIN_M2)
    if first_need > 0:
        yfirst = y0 + direction * first_need
        hit = obst.hits("Metal2", x, y0, x, yfirst, net)
        if hit is None:
            obst.add("Metal2", x, y0, x, yfirst, net)
            ops.append(("pt", m2, x, yfirst))
            y = yfirst
        # else fall through and let the main loop layer-hop/nudge
    while y != y1:
        guard += 1
        if guard > 20000:
            return f"LOOP {net}"
        remaining = abs(y1 - y)
        # Always chunk M2 to <= ANT_LEN so the first piece is not the full run.
        in_hop_zone = True
        if hop_ymax is not None and direction > 0 and y >= hop_ymax:
            in_hop_zone = False
        if hop_ymin is not None and direction < 0 and y <= hop_ymin:
            in_hop_zone = False
        # Leave MIN_M2 of M2 after a hop so the dest via is not an island.
        do_hop = remaining > (ANT_LEN + GAP + MIN_M2) and in_hop_zone
        step = remaining if not do_hop else ANT_LEN
        yn = y + direction * step
        if not do_hop:
            hit = obst.hits("Metal2", x, y, x, yn, net)
            if hit is None:
                obst.add("Metal2", x, y, x, yn, net)
                ops.append(("pt", m2, x, yn))
                y = yn
                continue
            # Layer-hop the blocked slice on M3.
            hit3 = obst.hits("Metal3", x, y, x, yn, net)
            if hit3 is None:
                obst.add("Metal3", x, y, x, yn, net)
                ops.append(("via", via2))
                ops.append(("pt", m3, x, y))
                ops.append(("pt", m3, x, yn))
                ops.append(("via", via2))
                ops.append(("pt", m2, x, yn))
                y = yn
                last_hop = yn
                continue
            # Jog x by a pitch only on long interior runs, never onto a PIN x.
            if no_nudge:
                return f"BLOCK_M2 {net} x={x} y={y}->{yn} hit={hit}/{hit3}"
            nudged = False
            for s in (1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 8, -8, 10, -10):
                xx = x + s * PITCH
                if abs(xx - x) < PITCH:
                    continue
                if avoid_xs is not None and not pin_clear(xx, avoid_xs, PITCH):
                    continue
                if obst.hits("Metal2", xx, y, xx, y + direction * min(abs(yn - y), 8 * PITCH), net) is None:
                    if obst.hits("Metal3", x, y, xx, y, net) is None:
                        ystep = y + direction * min(abs(yn - y), 8 * PITCH)
                        obst.add("Metal3", x, y, xx, y, net)
                        obst.add("Metal2", xx, y, xx, ystep, net)
                        ops.append(("via", via2))
                        ops.append(("pt", m3, x, y))
                        ops.append(("pt", m3, xx, y))
                        ops.append(("via", via2))
                        ops.append(("pt", m2, xx, y))
                        ops.append(("pt", m2, xx, ystep))
                        x = xx
                        y = ystep
                        nudged = True
                        break
            if not nudged:
                return f"BLOCK_M2 {net} x={x} y={y}->{yn} hit={hit}/{hit3}"
            continue
        # Antenna U-bridge on M3, 2 um gap so islands do not re-touch.
        ycut = y + direction * ANT_LEN
        if (direction > 0 and ycut > y1) or (direction < 0 and ycut < y1):
            ycut = y1
        ycut2 = ycut + direction * GAP
        if (direction > 0 and ycut2 > y1) or (direction < 0 and ycut2 < y1):
            # Not enough room for a gap; just finish.
            hit = obst.hits("Metal2", x, y, x, y1, net)
            if hit:
                return f"BLOCK_TAIL {net} {hit}"
            obst.add("Metal2", x, y, x, y1, net)
            ops.append(("pt", m2, x, y1))
            y = y1
            continue
        jog = JOG * hop_sign
        ok = (
            obst.hits("Metal2", x, y, x, ycut, net) is None
            and obst.hits("Metal3", x, ycut, x + jog, ycut, net) is None
            and obst.hits("Metal3", x + jog, ycut, x + jog, ycut2, net) is None
            and obst.hits("Metal3", x + jog, ycut2, x, ycut2, net) is None
            and obst.hits("Metal2", x, ycut2, x, ycut2, net) is None
        )
        if not ok:
            # Try opposite jog, then skip hop this step.
            jog = -jog
            ok = (
                obst.hits("Metal2", x, y, x, ycut, net) is None
                and obst.hits("Metal3", x, ycut, x + jog, ycut, net) is None
                and obst.hits("Metal3", x + jog, ycut, x + jog, ycut2, net) is None
                and obst.hits("Metal3", x + jog, ycut2, x, ycut2, net) is None
            )
        if not ok:
            # Fall back to a shorter M2 step without hop.
            ys = y + direction * (PITCH * 8)
            if (direction > 0 and ys > y1) or (direction < 0 and ys < y1):
                ys = y1
            hit = obst.hits("Metal2", x, y, x, ys, net)
            if hit:
                hit3 = obst.hits("Metal3", x, y, x, ys, net)
                if hit3 is None:
                    obst.add("Metal3", x, y, x, ys, net)
                    ops.append(("via", via2))
                    ops.append(("pt", m3, x, y))
                    ops.append(("pt", m3, x, ys))
                    ops.append(("via", via2))
                    ops.append(("pt", m2, x, ys))
                    y = ys
                    last_hop = y
                    continue
                return f"BLOCK_ANT {net} {hit}/{hit3}"
            obst.add("Metal2", x, y, x, ys, net)
            ops.append(("pt", m2, x, ys))
            y = ys
            last_hop = y  # postpone
            continue
        obst.add("Metal2", x, y, x, ycut, net)
        obst.add("Metal3", x, ycut, x + jog, ycut, net)
        obst.add("Metal3", x + jog, ycut, x + jog, ycut2, net)
        obst.add("Metal3", x + jog, ycut2, x, ycut2, net)
        ops.append(("pt", m2, x, ycut))
        ops.append(("via", via2))
        ops.append(("pt", m3, x, ycut))
        ops.append(("pt", m3, x + jog, ycut))
        ops.append(("pt", m3, x + jog, ycut2))
        ops.append(("pt", m3, x, ycut2))
        ops.append(("via", via2))
        ops.append(("pt", m2, x, ycut2))
        y = ycut2
        last_hop = y
    return ops, x


def m2_tick(obst, net, m2, x, y):
    """0.56 um M2 out-and-back so a Via2 pad meets M2.3 (0.1444 um^2)."""
    for dx, dy in ((0, MIN_M2), (0, -MIN_M2), (MIN_M2, 0), (-MIN_M2, 0)):
        x2, y2 = x + dx, y + dy
        if obst.hits("Metal2", x, y, x2, y2, net, slop=PITCH) is None:
            obst.add("Metal2", x, y, x2, y2, net)
            return [("pt", m2, x2, y2), ("pt", m2, x, y)]
    return []


def m3_horiz(obst, net, m2, m3, via2, x0, y, x1, from_m2=True, to_m2=True, tick=False):
    hit = obst.hits("Metal3", x0, y, x1, y, net)
    if hit:
        return None, hit
    ops = []
    if from_m2:
        ops.append(("via", via2))
        ops.append(("pt", m3, x0, y))
    else:
        ops.append(("pt", m3, x0, y))
    ops.append(("pt", m3, x1, y))
    obst.add("Metal3", x0, y, x1, y, net)
    if abs(int(x1) - int(x0)) < MIN_M2:
        for dx in (MIN_M2, -MIN_M2):
            if obst.hits("Metal3", x1, y, x1 + dx, y, net, slop=PITCH) is None:
                ops.append(("pt", m3, x1 + dx, y))
                ops.append(("pt", m3, x1, y))
                obst.add("Metal3", x1, y, x1 + dx, y, net)
                break
    if to_m2:
        ops.append(("via", via2))
        ops.append(("pt", m2, x1, y))
        # Do not tick inside the west PIN column, or at a PIN via that already
        # gets a 2 um M2 stub (tick +x collides with the neighboring organizer pin).
        if tick and x1 > 4 * 2000:
            ops.extend(m2_tick(obst, net, m2, x1, y))
    return ops, None


def main() -> None:
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    repair_west = os.environ.get("REPAIR_WEST", "") == "1"
    no_pad_via2 = os.environ.get("NO_PAD_VIA2", "0") == "1"
    tech = Tech()
    design = Design(tech)
    design.readDb(SRC)
    db = tech.getDB()
    block = db.getChip().getBlock()
    dbtech = db.getTech()
    dbu = block.getDefUnits()
    core = block.getCoreArea()
    rows = list(block.getRows())
    site = rows[0].getSite()
    sw, sh = site.getWidth(), site.getHeight()
    row_y = sorted({r.getOrigin()[1] for r in rows})
    row_x0 = min(r.getBBox().xMin() for r in rows)
    row_x1 = max(r.getBBox().xMax() for r in rows)

    m2 = dbtech.findLayer("Metal2")
    m3 = dbtech.findLayer("Metal3")
    via1 = dbtech.findVia("Via1_VV") or dbtech.findVia("Via1_HV")
    via2 = dbtech.findVia("Via2_VV") or dbtech.findVia("Via2_VH")
    via2vh = dbtech.findVia("Via2_VH") or via2
    via2h = dbtech.findVia("Via2_HV") or via2vh
    if not all([m2, m3, via1, via2]):
        raise SystemExit("missing layers/vias")

    def row_at(x, y):
        for r in rows:
            if r.getOrigin()[1] != y:
                continue
            bb = r.getBBox()
            if bb.xMin() <= x <= bb.xMax():
                return r
        for r in rows:
            if r.getOrigin()[1] == y:
                return r
        return None

    occupied = set()
    for inst in block.getInsts():
        if inst.getName().startswith("ach_tie_") or inst.getName().startswith("ach_rx_load_"):
            continue
        bb = inst.getBBox()
        x = snap(bb.xMin(), sw, row_x0)
        y = min(row_y, key=lambda yy: abs(yy - bb.yMin()))
        w = inst.getMaster().getWidth()
        nsite = max(1, int((w + sw - 1) // sw))
        for i in range(nsite):
            occupied.add((x + i * sw, y))

    targets = []
    skip = set()
    for net in block.getNets():
        if net.getSigType() in ("POWER", "GROUND"):
            continue
        if net.getWire() is not None and not repair_west:
            continue
        bts = list(net.getBTerms())
        its = list(net.getITerms())
        if len(bts) != 1 or len(its) != 1:
            continue
        inst = its[0].getInst()
        if not (inst.getName().startswith("ach_tie_") or inst.getName().startswith("ach_rx_load_")):
            continue
        box = bterm_box(bts[0])
        if box is None:
            continue
        px = (box[0] + box[2]) // 2
        py = (box[1] + box[3]) // 2
        edge = "W" if px < 10 * dbu else ("N" if py > 1600 * dbu else "?")
        targets.append((net, inst, its[0], bts[0], box, edge, px, py))
        skip.add(net.getName())

    obst = Obst()
    native_segs = load_native(block, obst, skip)

    lines = [
        f"SRC {SRC}",
        f"TARGETS {len(targets)} NATIVE_SEGS {native_segs} REPAIR_WEST {repair_west} NO_PAD_VIA2 {no_pad_via2}",
    ]
    placed = 0
    # Place west-in-core first (west edge), then last-row cells for N and W-above.
    west_core = [t for t in targets if t[5] == "W" and t[7] <= core.yMax() + 2 * dbu]
    last_row = [t for t in targets if t not in west_core]

    def place_one(net, inst, it, bt, box, edge, px, py, prefer_last):
        mw = inst.getMaster().getWidth()
        nsite = max(1, int((mw + sw - 1) // sw))
        pad_sites = 0 if prefer_last else 2
        found = None
        if prefer_last:
            ty = row_y[-1]
            tx = snap(min(max(px, row_x0), row_x1 - mw), sw, row_x0)
            for dx in range(0, int((row_x1 - row_x0) / sw)):
                for sign in (0, 1, -1):
                    cx = tx if sign == 0 else tx + sign * dx * sw
                    if cx < row_x0 or cx + mw > row_x1:
                        continue
                    rr = row_at(cx, ty)
                    if rr is None:
                        continue
                    rbb = rr.getBBox()
                    if cx < rbb.xMin() or cx + mw > rbb.xMax():
                        continue
                    keys = [(cx + i * sw, ty) for i in range(-pad_sites, nsite + pad_sites)]
                    if not any(k in occupied for k in keys):
                        found = (cx, ty, rr)
                        break
                if found:
                    break
        else:
            ty = min(row_y, key=lambda yy: abs(yy - py))
            yi = row_y.index(ty)
            for dy in range(0, len(row_y)):
                for sign in (0, 1, -1):
                    if sign == 0:
                        cy = ty
                    else:
                        j = yi + sign * dy
                        if j < 0 or j >= len(row_y):
                            continue
                        cy = row_y[j]
                    for dx in range(0, 160):
                        cx = row_x0 + dx * sw
                        if cx < row_x0 or cx + mw > row_x1:
                            continue
                        rr = row_at(cx, cy)
                        if rr is None:
                            continue
                        rbb = rr.getBBox()
                        if cx < rbb.xMin() or cx + mw > rbb.xMax():
                            continue
                        keys = [(cx + i * sw, cy) for i in range(-pad_sites, nsite + pad_sites)]
                        if not any(k in occupied for k in keys):
                            found = (cx, cy, rr)
                            break
                    if found:
                        break
                if found:
                    break
        return found

    place_map = {}
    if repair_west:
        for rec in west_core + last_row:
            net, inst, it, bt, box, edge, px, py = rec
            place_map[net.getName()] = inst_origin(inst)
            if edge == "W":
                old = net.getWire()
                if old is not None:
                    odb.dbWire_destroy(old)
        placed = len(place_map)
        lines.append(f"REPAIR_WEST_DESTROYED {sum(1 for t in west_core+last_row if t[5]=='W')}")
        lines.append(f"PLACED {placed}")
    else:
        for rec in west_core + last_row:
            net, inst, it, bt, box, edge, px, py = rec
            prefer_last = rec in last_row
            found = place_one(*rec, prefer_last)
            if found is None:
                lines.append(f"PLACE_FAIL {inst.getName()} pin={px/dbu:.3f},{py/dbu:.3f}")
                continue
            fx, fy, row = found
            inst.setOrient(row.getOrient())
            inst.setLocation(int(fx), int(fy))
            inst.setPlacementStatus("PLACED")
            mw = inst.getMaster().getWidth()
            nsite = max(1, int((mw + sw - 1) // sw))
            for i in range(-2, nsite + 2):
                occupied.add((fx + i * sw, fy))
            placed += 1
            place_map[net.getName()] = (fx, fy)
            lines.append(
                f"PLACE {inst.getName()} {fx/dbu:.3f} {fy/dbu:.3f} {edge} pin {px/dbu:.3f} {py/dbu:.3f}"
            )
        lines.append(f"PLACED {placed}")

    routed = 0
    failed = 0
    used_yjog = set()  # unused; kept so older logs stay greppable
    used_ywest = set()
    north_pin_xs = [t[6] for t in last_row if t[5] != "W"]
    west_pin_ys = [t[7] for t in last_row + west_core if t[5] == "W"]

    def alloc_yjog(x0, x1, me, start, direction=-1, ymin=None, layer="Metal3"):
        """Pick a padframe y whose full [x0,x1] span is clear on layer.

        Same-y jogs are allowed when their x-spans do not overlap (obst.hits).
        Do not globally unique-reserve y: that burned the 1672 um band and
        forced 20 um PIN stubs that fail M2.2a against nearby tracks.
        """
        y = snap_track(start)
        xa, xb = (x0, x1) if x0 <= x1 else (x1, x0)
        if ymin is None:
            ymin = core.yMax() + 4 * dbu
        ymax = NORTH_YVIA
        for _ in range(2500):
            if ymin <= y <= ymax:
                if obst.hits(layer, xa, y, xb, y, me) is None:
                    return y
            y += direction * PITCH
            if y < ymin or y > ymax:
                direction = -direction
                y = snap_track(start) + direction * PITCH
        return y

    # Route west-above before north so north M3 jogs can dodge west M3.
    west_above = [t for t in last_row if t[5] == "W"]
    norths = [t for t in last_row if t[5] != "W"]
    route_order = west_core + west_above + norths

    for rec in route_order:
        net, inst, it, bt, box, edge, px, py = rec
        if net.getName() not in place_map:
            continue
        sx, sy = iterm_xy(it)
        sx = snap_track(sx)
        sy = int(sy)
        dx = int(px)
        dy = int(py)
        name = net.getName()
        hop_sign = 1 if (sum(map(ord, name)) % 2 == 0) else -1
        if repair_west and edge != "W":
            continue
        old = net.getWire()
        if old is not None:
            odb.dbWire_destroy(old)

        ops = [("pt", m2, sx, sy)]
        err = None
        is_tie = inst.getName().startswith("ach_tie_")
        if is_tie:
            hop_kw = dict(hop_ymax=sy, hop_ymin=sy, avoid_xs=north_pin_xs if edge == "N" else None)
        else:
            hop_kw = dict(
                hop_ymax=int(core.yMax()),
                hop_ymin=int(core.yMin()),
                avoid_xs=north_pin_xs if edge == "N" else None,
            )
        if edge == "N":
            last_row_start = sy > core.yMax() - 10 * dbu
            sx = choose_escape_x(
                sx, north_pin_xs, obst, name, sy, NORTH_YVIA, last_row=last_row_start
            )
            ops = [("pt", m2, sx, sy)]
            jog_layer = "Metal2" if no_pad_via2 else "Metal3"
            # Trial land near the PIN, then pick yjog, then freeze an x_land
            # whose M2 vertical to 1672.44 is clear so the Via2 is never isolated.
            x_trial = choose_escape_x(
                dx, north_pin_xs, obst, name, NORTH_YVIA, dy, last_row=False
            )
            yjog = alloc_yjog(
                sx, x_trial, name, 1668 * dbu, direction=-1, ymin=1600 * dbu, layer=jog_layer
            )
            x_land = None
            x0 = snap_track(dx)
            for k in range(0, 24):
                found = False
                for sign in (0,) if k == 0 else (1, -1):
                    xx = x0 + sign * k * PITCH
                    if not pin_clear(xx, north_pin_xs, PITCH):
                        continue
                    if obst.hits("Metal2", xx, yjog, xx, NORTH_YVIA, name, slop=PITCH):
                        continue
                    if obst.hits("Metal3", sx, yjog, xx, yjog, name):
                        continue
                    x_land = xx
                    found = True
                    break
                if found:
                    break
            if x_land is None:
                x_land = x_trial
            part = m2_vertical(
                obst, name, m2, m3, via2vh, sx, sy, yjog, hop_sign, **hop_kw
            )
            if isinstance(part, str):
                err = part
            else:
                vops, sx = part
                ops.extend(vops[1:])
                if no_pad_via2:
                    hop, hit = m2_horiz(obst, name, m2, sx, yjog, x_land)
                    if hit:
                        err = f"N_JOG {name} {hit}"
                    else:
                        ops.extend(hop)
                else:
                    hop, hit = m3_horiz(
                        obst, name, m2, m3, via2vh, sx, yjog, x_land,
                        from_m2=True, to_m2=(yjog != NORTH_YVIA), tick=True,
                    )
                    if hit:
                        err = f"N_JOG {name} {hit}"
                    else:
                        ops.extend(hop)
                if err is None and yjog != NORTH_YVIA:
                    part2 = m2_vertical(
                        obst,
                        name,
                        m2,
                        m3,
                        via2vh,
                        x_land,
                        yjog,
                        NORTH_YVIA,
                        hop_sign,
                        no_nudge=True,
                        hop_ymin=NORTH_YVIA,
                        hop_ymax=yjog,
                        avoid_xs=north_pin_xs,
                    )
                    if isinstance(part2, str):
                        err = f"N_UP {name} {part2}"
                        for alt in range(1, 16):
                            found = False
                            for sign in (1, -1):
                                xx = snap_track(x_land + sign * alt * PITCH)
                                if not pin_clear(xx, north_pin_xs, PITCH):
                                    continue
                                if obst.hits("Metal3", sx, yjog, xx, yjog, name):
                                    continue
                                part2 = m2_vertical(
                                    obst, name, m2, m3, via2vh, xx, yjog, NORTH_YVIA,
                                    hop_sign, no_nudge=True,
                                    hop_ymin=NORTH_YVIA, hop_ymax=yjog,
                                    avoid_xs=north_pin_xs,
                                )
                                if not isinstance(part2, str):
                                    hopx, hitx = m3_horiz(
                                        obst, name, m2, m3, via2vh, x_land, yjog, xx,
                                        from_m2=True, to_m2=True, tick=True,
                                    )
                                    if hitx:
                                        continue
                                    ops.extend(hopx or [])
                                    ops.extend(part2[0][1:])
                                    x_land = part2[1]
                                    err = None
                                    found = True
                                    break
                            if found:
                                break
                if err is None:
                    y_via = NORTH_YVIA
                    hop, hit = m3_horiz(
                        obst, name, m2, m3, via2vh, x_land, y_via, dx,
                        from_m2=(yjog != NORTH_YVIA), to_m2=True, tick=False,
                    )
                    if hit:
                        err2 = hit
                        for k in range(1, 12):
                            yy = NORTH_YVIA - k * PITCH
                            if yy < 1668 * dbu:
                                break
                            if obst.hits("Metal2", x_land, y_via, x_land, yy, name):
                                continue
                            hop, hit = m3_horiz(
                                obst, name, m2, m3, via2vh, x_land, yy, dx,
                                from_m2=(yjog != NORTH_YVIA), to_m2=True, tick=False,
                            )
                            if hit is None:
                                obst.add("Metal2", x_land, y_via, x_land, yy, name)
                                ops.append(("pt", m2, x_land, yy))
                                y_via = yy
                                err2 = None
                                break
                        if err2 is None:
                            ops.extend(hop)
                        else:
                            err = f"N_PINJOG {name} {err2}"
                    else:
                        ops.extend(hop)
                    if err is None and y_via != dy:
                        nat = obst.hits(
                            "Metal2", dx, y_via, dx, dy, name, slop=PITCH, skip_prefix="ach_"
                        )
                        if nat:
                            err = f"N_PIN {name} native {nat}"
                        else:
                            obst.add("Metal2", dx, y_via, dx, dy, name)
                            ops.append(("pt", m2, dx, dy))
        else:
            # WEST: never run a vertical on PIN x=0.5 (that shorts the pad
            # stack). 80ef lands Via2_VH at x=0.84 *below* PIN y so Mag does
            # not unique-merge the via into VSUBS/VSS, then an M2 stub to
            # the PIN. x_land sits on-core so halo vias are over cells.
            x_land = snap_track(int(8.40 * dbu))
            pin_via_x = WEST_PIN_VIA_X
            if sy > core.yMax() - 10 * dbu:
                sx = choose_escape_x(sx, (0,), obst, name, sy, dy, last_row=True)
                ops = [("pt", m2, sx, sy)]
            y_via = None
            for k in range(2, 16):
                yy = snap_track(dy - k * PITCH)
                if yy <= 0:
                    continue
                if yy in used_ywest:
                    continue
                if any(abs(yy - wy) < PITCH for wy in west_pin_ys if wy != dy):
                    continue
                if obst.hits("Metal3", sx, yy, pin_via_x, yy, name, slop=PITCH) is not None:
                    continue
                if obst.hits("Metal3", x_land, yy, pin_via_x, yy, name, slop=PITCH) is not None:
                    continue
                if obst.hits("Metal2", pin_via_x, yy, pin_via_x, dy, name, slop=PITCH) is not None:
                    continue
                if obst.hits("Metal2", pin_via_x, dy, dx, dy, name, slop=PITCH) is not None:
                    continue
                y_via = yy
                break
            if y_via is None:
                y_via = snap_track(dy - 2 * PITCH)
            used_ywest.add(y_via)
            y_run = y_via
            if sy != y_run:
                part = m2_vertical(
                    obst, name, m2, m3, via2vh, sx, sy, y_run, hop_sign, **hop_kw
                )
                if isinstance(part, str):
                    err = part
                    for alt in range(1, 16):
                        found = False
                        for sign in (1, -1):
                            xx = snap_track(sx + sign * alt * PITCH)
                            if xx < 2 * dbu:
                                continue
                            part = m2_vertical(
                                obst, name, m2, m3, via2vh, xx, sy, y_run, hop_sign, **hop_kw
                            )
                            if not isinstance(part, str):
                                sx = xx
                                ops = [("pt", m2, sx, sy)]
                                vops, sx = part
                                ops.extend(vops[1:])
                                err = None
                                found = True
                                break
                        if found:
                            break
                else:
                    vops, sx = part
                    ops.extend(vops[1:])
            if err is None:
                if no_pad_via2:
                    hop, hit = m2_horiz(obst, name, m2, sx, y_run, x_land)
                    if hit:
                        err2 = hit
                        for k in range(1, 48):
                            for sgn in (1, -1):
                                yy = snap_track(y_run + sgn * k * PITCH)
                                if yy < 0 or yy > 1675 * dbu:
                                    continue
                                if obst.hits("Metal2", sx, y_run, sx, yy, name):
                                    continue
                                if obst.hits("Metal2", sx, yy, x_land, yy, name):
                                    continue
                                obst.add("Metal2", sx, y_run, sx, yy, name)
                                ops.append(("pt", m2, sx, yy))
                                hop, hit = m2_horiz(obst, name, m2, sx, yy, x_land)
                                if hit is None:
                                    y_run = yy
                                    err2 = None
                                    break
                            if err2 is None:
                                break
                        if err2 is None:
                            ops.extend(hop)
                        else:
                            err = f"W_JOG {name} {err2}"
                    else:
                        ops.extend(hop)
                else:
                    hop, hit = m3_horiz(
                        obst, name, m2, m3, via2vh, sx, y_run, x_land, from_m2=True, to_m2=False
                    )
                    if hit:
                        err2 = hit
                        for k in range(1, 48):
                            for sgn in (1, -1):
                                yy = snap_track(y_run + sgn * k * PITCH)
                                if yy < 0 or yy > 1675 * dbu:
                                    continue
                                if obst.hits("Metal2", sx, y_run, sx, yy, name):
                                    continue
                                if obst.hits("Metal3", sx, yy, x_land, yy, name):
                                    continue
                                obst.add("Metal2", sx, y_run, sx, yy, name)
                                ops.append(("pt", m2, sx, yy))
                                hop, hit = m3_horiz(
                                    obst, name, m2, m3, via2vh, sx, yy, x_land, from_m2=True, to_m2=False
                                )
                                if hit is None:
                                    y_run = yy
                                    err2 = None
                                    break
                            if err2 is None:
                                break
                        if err2 is None:
                            ops.extend(hop)
                        else:
                            err = f"W_JOG {name} {err2}"
                    else:
                        ops.extend(hop)
            # Never run a vertical on the shared west x_land=8.12 trunk.
            # PIN approach y must stay *below* the PIN (pad-spacing).
            if err is None and y_run != y_via:
                if y_run < dy:
                    y_via = y_run
                # else keep the original below-PIN y_via; M3 jog y may differ
            if err is None:
                if no_pad_via2:
                    hop, hit = m2_horiz(obst, name, m2, x_land, y_via, dx)
                    if hit:
                        err = f"W_PIN {name} {hit}"
                    else:
                        ops.extend(hop)
                        if y_via != dy:
                            obst.add("Metal2", dx, y_via, dx, dy, name)
                            ops.append(("pt", m2, dx, dy))
                else:
                    hop, hit = m3_horiz(
                        obst, name, m2, m3, via2vh, x_land, y_via, pin_via_x, from_m2=False, to_m2=True
                    )
                    if hit:
                        err2 = hit
                        for k in range(1, 20):
                            yy = snap_track(y_via - k * PITCH)
                            if yy <= 0 or yy in used_ywest:
                                continue
                            if obst.hits("Metal2", x_land, y_via, x_land, yy, name):
                                continue
                            hop, hit = m3_horiz(
                                obst, name, m2, m3, via2vh, x_land, yy, pin_via_x,
                                from_m2=True, to_m2=True,
                            )
                            if hit is None:
                                obst.add("Metal2", x_land, y_via, x_land, yy, name)
                                ops.append(("pt", m2, x_land, yy))
                                ops.extend(hop)
                                y_via = yy
                                used_ywest.add(y_via)
                                err2 = None
                                obst.add("Metal2", pin_via_x, y_via, pin_via_x, dy, name)
                                ops.append(("pt", m2, pin_via_x, dy))
                                if pin_via_x != dx:
                                    obst.add("Metal2", pin_via_x, dy, dx, dy, name)
                                    ops.append(("pt", m2, dx, dy))
                                break
                        if err2 is not None:
                            err = f"W_PIN {name} {err2}"
                    else:
                        ops.extend(hop)
                        obst.add("Metal2", pin_via_x, y_via, pin_via_x, dy, name)
                        ops.append(("pt", m2, pin_via_x, dy))
                        if pin_via_x != dx:
                            obst.add("Metal2", pin_via_x, dy, dx, dy, name)
                            ops.append(("pt", m2, dx, dy))

        if err is not None:
            failed += 1
            lines.append(f"ROUTE_FAIL {err}")
            continue
        wire = odb.dbWire.create(net)
        enc = odb.dbWireEncoder()
        enc.begin(wire)
        encode(enc, ops, via1, via2, m2)
        enc.end()
        routed += 1

    # Native Via1+Via2 stack at 975.800,955.640 is a 0.28x0.38 M2 pad (M2.3).
    # Inject 0.56 um of regular M2 so DEF streamout keeps it (SBoxes drop).
    nfix = block.findNet("_07203_")
    if nfix is not None and nfix.getWire() is not None:
        vx, vy = int(975.800 * dbu), int(955.640 * dbu)
        recs = []
        dec = odb.dbWireDecoder()
        dec.begin(nfix.getWire())
        while True:
            op = dec.next()
            if op == odb.dbWireDecoder.END_DECODE:
                break
            if op in (odb.dbWireDecoder.PATH, odb.dbWireDecoder.SHORT, odb.dbWireDecoder.VWIRE):
                lyr = dec.getLayer()
                recs.append(("path", lyr))
            elif op in (odb.dbWireDecoder.POINT, odb.dbWireDecoder.POINT_EXT):
                pt = dec.getPoint()
                recs.append(("pt", int(pt[0]), int(pt[1])))
            elif op in (odb.dbWireDecoder.TECH_VIA, odb.dbWireDecoder.VIA):
                via = dec.getTechVia() if op == odb.dbWireDecoder.TECH_VIA else dec.getVia()
                recs.append(("via", via))
        injected = False
        newrecs = []
        ticks = {
            (int(975.800 * dbu), int(955.640 * dbu)),
            (int(980.840 * dbu), int(955.640 * dbu)),
            (int(201.880 * dbu), int(411.880 * dbu)),
        }
        seen = set()
        for r in recs:
            newrecs.append(r)
            if r[0] == "pt" and (r[1], r[2]) in ticks and (r[1], r[2]) not in seen:
                seen.add((r[1], r[2]))
                newrecs.append(("path", m2))
                newrecs.append(("pt", r[1], r[2]))
                newrecs.append(("pt", r[1] + MIN_M2, r[2]))
                newrecs.append(("path", m3))
                newrecs.append(("pt", r[1], r[2]))
                newrecs.append(("pt", r[1] + MIN_M2, r[2]))
                injected = True
        if injected:
            odb.dbWire_destroy(nfix.getWire())
            wire = odb.dbWire.create(nfix)
            enc = odb.dbWireEncoder()
            enc.begin(wire)
            cur = None
            for r in newrecs:
                if r[0] == "path":
                    enc.newPath(r[1], "ROUTED")
                    cur = r[1]
                elif r[0] == "pt":
                    if cur is None:
                        enc.newPath(m2, "ROUTED")
                        cur = m2
                    enc.addPoint(r[1], r[2])
                elif r[0] == "via":
                    enc.addTechVia(r[1])
                    cur = None
            enc.end()
        lines.append(f"NATIVE_M2_TICK _07203_ injected={injected}")

    still = sum(
        1
        for n in block.getNets()
        if n.getSigType() not in ("POWER", "GROUND") and n.getWire() is None
    )
    # ACH vs ACH / native overlap recount on produced wires
    ach_short = 0
    nat_short = 0
    produced = {}
    for rec in targets:
        net = rec[0]
        w = net.getWire()
        if w is None:
            continue
        produced[net.getName()] = segs_of(w)

    def seg_hit(a, b, slop=SLOP):
        ax1, ay1, ax2, ay2 = a
        bx1, by1, bx2, by2 = b
        if ax1 > ax2:
            ax1, ax2 = ax2, ax1
        if ay1 > ay2:
            ay1, ay2 = ay2, ay1
        if bx1 > bx2:
            bx1, bx2 = bx2, bx1
        if by1 > by2:
            by1, by2 = by2, by1
        return not (ax2 + slop < bx1 or bx2 + slop < ax1 or ay2 + slop < by1 or by2 + slop < ay1)

    names = list(produced)
    for i, n1 in enumerate(names):
        for n2 in names[i + 1 :]:
            for s1 in produced[n1]:
                for s2 in produced[n2]:
                    if s1[0] != s2[0]:
                        continue
                    if seg_hit(s1[1:], s2[1:]):
                        ach_short += 1
                        if ach_short <= 20:
                            lines.append(f"ACH_SHORT {n1} {n2} {s1[0]}")
    # native: use obst but obst now includes ACH. Re-scan native only.
    native = defaultdict(list)
    for net in block.getNets():
        nm = net.getName()
        if nm in skip or str(net.getSigType()) in ("POWER", "GROUND"):
            continue
        w = net.getWire()
        if w is None:
            continue
        for s in segs_of(w):
            native[s[0]].append((nm, s[1:]))
    for n1, segs in produced.items():
        for s in segs:
            for nm, box in native.get(s[0], []):
                if seg_hit(s[1:], box):
                    nat_short += 1
                    if nat_short <= 20:
                        lines.append(f"NAT_SHORT {n1} {nm} {s[0]}")

    lines.append(f"ROUTED {routed} FAIL {failed} SIGNAL_UNROUTED {still}")
    lines.append(f"ACH_SHORTS {ach_short} NAT_SHORTS {nat_short}")
    design.writeDb(DST)
    lines.append(f"WROTE {DST}")
    text = "\n".join(lines) + "\n"
    open(LOG, "w").write(text)
    open("/tmp/stitch_ties.txt", "w").write(text)
    os._exit(0)


if __name__ == "__main__":
    main()
