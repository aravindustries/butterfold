#!/usr/bin/env python3
"""Create routing guides for nets of new setup-buffer instances.

Keeps existing signal wires. Writes an ODB DRT can load.
"""
from __future__ import annotations

import os

from openroad import Design, Tech
import odb

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.path.join(PROTO, "physical/results/native_power_ring_ach/setup_buf_pre_drt.odb")
REF = os.path.join(PROTO, "physical/results/native_power_ring_ach/pre_timing_checkpoint/filled.odb")
DST = os.path.join(PROTO, "physical/results/native_power_ring_ach/setup_buf_guided.odb")
LOG = os.path.join(PROTO, "physical/results/native_power_ring_ach/logs/add_guides.log")


def main() -> None:
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    ref_tech = Tech()
    ref_design = Design(ref_tech)
    ref_design.readDb(REF)
    ref_names = {i.getName() for i in ref_tech.getDB().getChip().getBlock().getInsts()}

    tech = Tech()
    design = Design(tech)
    design.readDb(SRC)
    db = tech.getDB()
    block = db.getChip().getBlock()
    dbtech = db.getTech()
    layers = [dbtech.findLayer(n) for n in ("Metal2", "Metal3", "Metal4", "Metal5")]
    layers = [l for l in layers if l is not None]

    new_insts = [i for i in block.getInsts() if i.getName() not in ref_names]
    nets = []
    for inst in new_insts:
        for it in inst.getITerms():
            n = it.getNet()
            if n is not None:
                nets.append(n)
    # unique
    seen = set()
    uniq = []
    for n in nets:
        if n.getName() in seen:
            continue
        seen.add(n.getName())
        uniq.append(n)

    created = 0
    lines = [f"NEW_INSTS {len(new_insts)} NETS {len(uniq)}"]
    for inst in new_insts:
        lines.append(f"INST {inst.getName()} {inst.getMaster().getName()}")
    pad = 4000  # 2 um at 2000 dbu
    for net in uniq:
        xs, ys = [], []
        for it in net.getITerms():
            inst = it.getInst()
            bb = inst.getBBox()
            xs += [bb.xMin(), bb.xMax()]
            ys += [bb.yMin(), bb.yMax()]
        if not xs:
            continue
        if net.getSigType() in ("POWER", "GROUND"):
            continue
        x1, x2 = min(xs) - pad, max(xs) + pad
        y1, y2 = min(ys) - pad, max(ys) + pad
        rect = odb.Rect(int(x1), int(y1), int(x2), int(y2))
        for layer in layers:
            try:
                odb.dbGuide.create(net, layer, rect, False)
                created += 1
            except Exception as e:
                lines.append(f"GUIDE_FAIL {net.getName()} {layer.getName()} {e}")
                break
        lines.append(f"GUIDE {net.getName()} {x1} {y1} {x2} {y2}")
    lines.append(f"GUIDES_CREATED {created}")
    design.writeDb(DST)
    lines.append(f"WROTE {DST}")
    open(LOG, "w").write("\n".join(lines) + "\n")
    open("/tmp/add_guides.txt", "w").write("\n".join(lines) + "\n")
    os._exit(0)


if __name__ == "__main__":
    main()
