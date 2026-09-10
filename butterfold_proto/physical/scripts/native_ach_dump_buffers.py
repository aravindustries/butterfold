#!/usr/bin/env python3
"""Dump the proven 25-buffer ECO from setup_buf_pre_drt.odb."""
from __future__ import annotations

import os

from openroad import Design, Tech

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.path.join(PROTO, "physical/results/native_power_ring_ach/setup_buf_pre_drt.odb")
REF = os.path.join(
    PROTO, "physical/results/native_power_ring_ach/pre_timing_checkpoint/filled.odb"
)
OUT = os.path.join(PROTO, "physical/reports/native_power_ring/final_ach/setup_buf_topology.txt")


def main() -> None:
    ref_t = Tech()
    ref_d = Design(ref_t)
    ref_d.readDb(REF)
    ref_names = {i.getName() for i in ref_t.getDB().getChip().getBlock().getInsts()}

    tech = Tech()
    design = Design(tech)
    design.readDb(SRC)
    block = tech.getDB().getChip().getBlock()
    dbu = block.getDefUnits()
    lines = []
    for inst in block.getInsts():
        if inst.getName() in ref_names:
            continue
        bb = inst.getBBox()
        rec = [
            f"INST {inst.getName()} {inst.getMaster().getName()}",
            f"  XY {bb.xMin()/dbu:.3f} {bb.yMin()/dbu:.3f}",
        ]
        for it in inst.getITerms():
            net = it.getNet()
            rec.append(
                f"  PIN {it.getMTerm().getName()} NET {net.getName() if net else 'OPEN'}"
            )
        lines.append("\n".join(rec))
    text = f"NEW_INSTS {len(lines)}\n" + "\n".join(lines) + "\n"
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "w").write(text)
    open("/tmp/buf_topo.txt", "w").write(text)
    os._exit(0)


if __name__ == "__main__":
    main()
