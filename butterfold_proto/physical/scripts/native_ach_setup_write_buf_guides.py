#!/usr/bin/env python3
"""Guides only for nets attached to the 25 setup-buffer instances."""
from __future__ import annotations

import os

from openroad import Design, Tech

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.path.join(PROTO, "physical/results/native_power_ring_ach/setup_buf_pre_drt.odb")
REF = os.path.join(PROTO, "physical/results/native_power_ring_ach/pre_timing_checkpoint/filled.odb")
GUIDE = os.path.join(PROTO, "physical/results/native_power_ring_ach/setup_buf_only.guide")


def main() -> None:
    ref_tech = Tech()
    ref_design = Design(ref_tech)
    ref_design.readDb(REF)
    ref_names = {i.getName() for i in ref_tech.getDB().getChip().getBlock().getInsts()}

    tech = Tech()
    design = Design(tech)
    design.readDb(SRC)
    block = tech.getDB().getChip().getBlock()
    new_insts = [i for i in block.getInsts() if i.getName() not in ref_names]
    nets = {}
    for inst in new_insts:
        for it in inst.getITerms():
            n = it.getNet()
            if n is None or n.getSigType() in ("POWER", "GROUND"):
                continue
            nets[n.getName()] = n
    pad = 20000
    with open(GUIDE, "w") as f:
        for name, net in sorted(nets.items()):
            xs, ys = [], []
            for it in net.getITerms():
                bb = it.getInst().getBBox()
                xs += [bb.xMin(), bb.xMax()]
                ys += [bb.yMin(), bb.yMax()]
            if not xs:
                continue
            x1, x2 = min(xs) - pad, max(xs) + pad
            y1, y2 = min(ys) - pad, max(ys) + pad
            f.write(f"{name}\n(\n")
            for layer in ("Metal1", "Metal2", "Metal3", "Metal4", "Metal5"):
                f.write(f"{int(x1)} {int(y1)} {int(x2)} {int(y2)} {layer}\n")
            f.write(")\n")
    open("/tmp/buf_only_guides.txt", "w").write(f"NETS {len(nets)} FILE {GUIDE}\n")
    os._exit(0)


if __name__ == "__main__":
    main()
