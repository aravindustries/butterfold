#!/usr/bin/env python3
"""Insert a deterministic regional reset distribution tree before GRT."""
from __future__ import annotations
import os
from openroad import Design, Tech
import odb

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.environ.get("RESET_TREE_SRC", PROTO + "/physical/results/native_power_ring_ach/predrt/candidate37_clone.odb")
DST = os.environ.get("RESET_TREE_DST", PROTO + "/physical/results/native_power_ring_ach/predrt/candidate38_reset.odb")
NETS = ("net226", "net227", "net228")
NX = NY = 4

def main():
    tech = Tech(); design = Design(tech); design.readDb(SRC)
    db = tech.getDB(); block = db.getChip().getBlock()
    master = db.findMaster("gf180mcu_fd_sc_mcu9t5v0__clkbuf_20")
    if master is None: raise SystemExit("missing clkbuf_20")
    core = block.getCoreArea(); w = core.dx(); h = core.dy()
    vdd = block.findNet("VDD"); vss = block.findNet("VSS")
    lines = [f"SRC {SRC}", f"DST {DST}"]
    total = 0
    for net_name in NETS:
        net = block.findNet(net_name)
        loads = [it for it in net.getITerms()
                 if it.getMTerm().getIoType() == "INPUT"
                 and not it.getInst().getMaster().getName().endswith("__antenna")]
        buckets = [[] for _ in range(NX * NY)]
        for it in loads:
            x, y = map(int, it.getInst().getLocation())
            bx = max(0, min(NX - 1, (x - core.xMin()) * NX // max(1, w)))
            by = max(0, min(NY - 1, (y - core.yMin()) * NY // max(1, h)))
            buckets[by * NX + bx].append(it)
        made = 0
        for idx, bucket in enumerate(buckets):
            if not bucket: continue
            inst = odb.dbInst_create(block, master, f"rsttree_{net_name}_{idx}")
            inst.setOrient("R0")
            bx, by = idx % NX, idx // NX
            x = core.xMin() + (2 * bx + 1) * w // (2 * NX)
            y = core.yMin() + (2 * by + 1) * h // (2 * NY)
            inst.setLocation(x, y); inst.setPlacementStatus("PLACED")
            branch = odb.dbNet_create(block, f"rsttree_{net_name}_{idx}_n")
            branch.setSigType("SIGNAL")
            inst.findITerm("I").connect(net); inst.findITerm("Z").connect(branch)
            for pin in ("VDD", "VNW"):
                it = inst.findITerm(pin)
                if it: it.connect(vdd)
            for pin in ("VSS", "VPW"):
                it = inst.findITerm(pin)
                if it: it.connect(vss)
            for it in bucket:
                it.disconnect(); it.connect(branch)
            lines.append(f"BRANCH {net_name} {idx} LOADS {len(bucket)} XY {x} {y}")
            made += 1; total += 1
        lines.append(f"NET {net_name} LOADS {len(loads)} BRANCHES {made}")
    design.writeDb(DST)
    lines.append(f"TOTAL_BRANCHES {total}")
    with open(os.path.splitext(DST)[0] + ".log", "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))

if __name__ == "__main__": main()
