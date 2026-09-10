#!/usr/bin/env python3
"""Dump ACH north/west via+wire geometry and last-row tiel vs pin alignment."""
from __future__ import annotations

import os
from collections import defaultdict

from openroad import Design, Tech
import odb

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.environ.get(
    "DUMP_ODB",
    PROTO + "/physical/results/native_power_ring_ach/predrt/filled4.odb",
)


def segs_vias(wire):
    if wire is None:
        return [], []
    dec = odb.dbWireDecoder()
    dec.begin(wire)
    out, vias = [], []
    layer, last = None, None
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
            try:
                v = dec.getTechVia()
                vn = v.getName() if v else "?"
            except Exception:
                vn = "?"
            if last is not None:
                vias.append((vn, last[0], last[1]))
            last = None
    return out, vias


def main() -> None:
    tech = Tech()
    design = Design(tech)
    design.readDb(SRC)
    db = tech.getDB()
    block = db.getChip().getBlock()
    dbu = block.getDefUnits()
    core = block.getCoreArea()
    names = [
        "ach_dout_PDRV0_4_tie0",
        "ach_dout_CS_3_tie0",
        "ach_dout_SL_2_tie0",
        "dout_IN[2]",
        "dout_OUT[5]",
    ]
    lines = [f"ODB {SRC} dbu {dbu} core_ymax {core.yMax()/dbu:.3f}"]
    for name in names:
        net = block.findNet(name)
        if net is None:
            # try bterm name as net
            bt = block.findBTerm(name)
            net = bt.getNet() if bt else None
        if net is None:
            lines.append(f"MISSING {name}")
            continue
        segs, vias = segs_vias(net.getWire())
        lines.append(f"NET {net.getName()} segs {len(segs)} vias {len(vias)}")
        pad_vias = [v for v in vias if v[2] > int(core.yMax()) or v[1] < int(6 * dbu)]
        lines.append(f"  PAD_VIAS {len(pad_vias)}")
        for v in vias:
            if v[2] > 1600 * dbu or v[1] < 10 * dbu:
                lines.append(f"  VIA {v[0]} {v[1]/dbu:.3f} {v[2]/dbu:.3f}")
        for s in segs:
            if max(s[2], s[4]) > 1600 * dbu or min(s[1], s[3]) < 10 * dbu:
                lines.append(
                    f"  SEG {s[0]} {s[1]/dbu:.3f},{s[2]/dbu:.3f} -> {s[3]/dbu:.3f},{s[4]/dbu:.3f}"
                )

    # north tiel vs pin
    lines.append("NORTH_ALIGN")
    mis = []
    for net in block.getNets():
        bts = list(net.getBTerms())
        its = [
            it
            for it in net.getITerms()
            if it.getInst().getName().startswith(("ach_tie_", "ach_rx_load_"))
        ]
        if len(bts) != 1 or not its:
            continue
        inst = its[0].getInst()
        loc = inst.getLocation()
        bb = None
        for bp in bts[0].getBPins():
            for box in bp.getBoxes():
                if box.getTechLayer() and box.getTechLayer().getName() == "Metal2":
                    bb = box
                    break
        if bb is None:
            continue
        px = (bb.xMin() + bb.xMax()) / 2
        py = (bb.yMin() + bb.yMax()) / 2
        if py < 1600 * dbu:
            continue
        dx = abs(loc[0] + inst.getMaster().getWidth() / 2 - px) / dbu
        lines.append(
            f"  {net.getName()} tiel {loc[0]/dbu:.3f},{loc[1]/dbu:.3f} pin {px/dbu:.3f},{py/dbu:.3f} dx {dx:.3f}"
        )
        mis.append(dx)
    if mis:
        lines.append(f"NORTH_DX_MAX {max(mis):.3f} MEAN {sum(mis)/len(mis):.3f} N {len(mis)}")

    # cell displacement vs native filled near M1.1
    lines.append("DONE")
    text = "\n".join(lines) + "\n"
    open("/tmp/dump_pdrv.txt", "w").write(text)
    print(text)
    os._exit(0)


if __name__ == "__main__":
    main()
