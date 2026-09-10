#!/usr/bin/env python3
"""Rebuild Mag-bad west ACH nets with 80ef-style M4 trunk into the core.

80ef PDRV1_6: Via2_VH at x=0.84, M3 to x~55, Via3_HV + M4 running down into
the core. Mag then extracts a real via stack instead of Via2/VSUBS=VSS.
"""
from __future__ import annotations

import os

from openroad import Design, Tech
import odb

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.environ.get(
    "FIX_SRC",
    PROTO + "/physical/results/native_power_ring_ach/predrt/applied_nodpl_stitched10m.odb",
)
DST = os.environ.get(
    "FIX_DST",
    PROTO + "/physical/results/native_power_ring_ach/predrt/applied_nodpl_stitched10m4.odb",
)
NETS = os.environ.get(
    "FIX_NETS",
    "ach_dout_PDRV1_6_tie0,ach_din_PD_5_tie0,ach_din_PD_7_tie0,ach_din_valid_i_PD_tie0,dout_IN[6]",
)


def iterm_xy(it):
    inst = it.getInst()
    loc = inst.getLocation()
    ox, oy = int(loc[0]), int(loc[1])
    mterm = it.getMTerm()
    xs, ys = [], []
    for mp in mterm.getMPins():
        for box in mp.getGeometry():
            xs += [ox + box.xMin(), ox + box.xMax()]
            ys += [oy + box.yMin(), oy + box.yMax()]
    return (min(xs) + max(xs)) // 2, (min(ys) + max(ys)) // 2


def bterm_xy(bt):
    for bp in bt.getBPins():
        for box in bp.getBoxes():
            if box.getTechLayer() and box.getTechLayer().getName() == "Metal2":
                return (box.xMin() + box.xMax()) // 2, (box.yMin() + box.yMax()) // 2
    return None


def main() -> None:
    tech = Tech()
    design = Design(tech)
    design.readDb(SRC)
    db = tech.getDB()
    block = db.getChip().getBlock()
    dbtech = db.getTech()
    dbu = block.getDefUnits()
    m2 = dbtech.findLayer("Metal2")
    m3 = dbtech.findLayer("Metal3")
    m4 = dbtech.findLayer("Metal4")
    via1 = dbtech.findVia("Via1_VV") or dbtech.findVia("Via1_HV")
    via2 = dbtech.findVia("Via2_VH") or dbtech.findVia("Via2_VV")
    via3 = dbtech.findVia("Via3_HV") or dbtech.findVia("Via3_VH")
    if not all([m2, m3, m4, via1, via2, via3]):
        raise SystemExit("missing layers/vias")
    pin_via_x = int(0.84 * dbu)
    y_off = int(1.12 * dbu)
    lines = [f"SRC {SRC} VIA3 {via3.getName()}"]
    for name in NETS.split(","):
        name = name.strip()
        net = block.findNet(name)
        if net is None:
            lines.append(f"MISSING {name}")
            continue
        its = [
            it
            for it in net.getITerms()
            if it.getInst().getName().startswith(("ach_tie_", "ach_rx_load_"))
        ]
        bts = list(net.getBTerms())
        if not its or not bts:
            lines.append(f"SKIP {name}")
            continue
        sx, sy = iterm_xy(its[0])
        dx, dy = bterm_xy(bts[0])
        # 80ef PDRV1_6 uses M4 at x=55.16 running into the core. Tiel x can
        # land on a PDN M4 stripe (Mag-merges to VSS).
        if dy > 1500 * dbu:
            m4x = int(55.16 * dbu)
        elif "PD_7" in name:
            m4x = int(9.52 * dbu)
        else:
            m4x = int(8.40 * dbu)
        y_via = int(dy) - y_off
        old = net.getWire()
        if old is not None:
            odb.dbWire_destroy(old)
        wire = odb.dbWire.create(net)
        enc = odb.dbWireEncoder()
        enc.begin(wire)
        # Core stack over the tiel: M1-M2-M3-M4, one via per path.
        enc.newPath(m2, "ROUTED")
        enc.addPoint(int(sx), int(sy))
        enc.addTechVia(via1)
        enc.newPath(m2, "ROUTED")
        enc.addPoint(int(sx), int(sy))
        enc.addTechVia(via2)
        enc.newPath(m3, "ROUTED")
        enc.addPoint(int(sx), int(sy))
        enc.addPoint(int(m4x), int(sy))
        enc.addTechVia(via3)
        enc.newPath(m4, "ROUTED")
        enc.addPoint(int(m4x), int(sy))
        enc.addPoint(int(m4x), int(y_via))
        enc.addTechVia(via3)
        enc.newPath(m3, "ROUTED")
        enc.addPoint(int(m4x), int(y_via))
        enc.addPoint(int(pin_via_x), int(y_via))
        enc.addTechVia(via2)
        enc.newPath(m2, "ROUTED")
        enc.addPoint(int(pin_via_x), int(y_via))
        enc.addPoint(int(pin_via_x), int(dy))
        enc.addPoint(int(dx), int(dy))
        enc.end()
        lines.append(
            f"FIX {name} tiel={sx/dbu:.3f},{sy/dbu:.3f} pin={dx/dbu:.3f},{dy/dbu:.3f} m4x={m4x/dbu:.3f}"
        )
    design.writeDb(DST)
    lines.append(f"WROTE {DST}")
    text = "\n".join(lines) + "\n"
    open("/tmp/west_m4.txt", "w").write(text)
    print(text)
    os._exit(0)


if __name__ == "__main__":
    main()
