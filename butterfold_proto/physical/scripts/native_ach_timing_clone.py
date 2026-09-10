#!/usr/bin/env python3
"""Offline critical-gate cloning for native ACH setup closure.

Clone only max-drive combinational gates identified by fresh extracted timing,
split their load sets, and leave their Boolean inputs identical.  This avoids
the serial delay of another buffer and avoids OpenROAD's stale GRT callback.
"""
from __future__ import annotations

import os

from openroad import Design, Tech
import odb


PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.environ.get(
    "TIMING_CLONE_SRC",
    PROTO + "/physical/results/native_power_ring_ach/predrt/odb_buf3.odb",
)
DST = os.environ.get(
    "TIMING_CLONE_DST",
    PROTO + "/physical/results/native_power_ring_ach/predrt/candidate33_clone.odb",
)
TARGETS = ("_09511_", "_15985_", "_15996_")
CRITICAL_LOAD = {
    "_09511_": "cone_buf_9",
    "_15985_": "_15992_",
    "_15996_": "clone218",
}


def xy(iterm):
    avg = iterm.getAvgXY()
    if isinstance(avg, tuple) and len(avg) >= 3 and avg[0]:
        return int(avg[1]), int(avg[2])
    box = iterm.getBBox()
    if box:
        return (box.xMin() + box.xMax()) // 2, (box.yMin() + box.yMax()) // 2
    return tuple(map(int, iterm.getInst().getLocation()))


def output_iterm(inst):
    outs = [it for it in inst.getITerms() if it.getMTerm().getIoType() == "OUTPUT"]
    if len(outs) != 1:
        raise RuntimeError(f"{inst.getName()} has {len(outs)} outputs")
    return outs[0]


def main() -> None:
    tech = Tech()
    design = Design(tech)
    design.readDb(SRC)
    block = tech.getDB().getChip().getBlock()
    lines = [f"SRC {SRC}", f"DST {DST}"]
    made = 0

    for target in TARGETS:
        inst = block.findInst(target)
        if inst is None:
            raise SystemExit(f"missing target {target}")
        out = output_iterm(inst)
        net = out.getNet()
        loads = [
            it for it in net.getITerms()
            if it != out and it.getMTerm().getIoType() == "INPUT"
            and not it.getInst().getMaster().getName().endswith("__antenna")
        ]
        critical = [it for it in loads if it.getInst().getName() == CRITICAL_LOAD[target]]
        if not critical:
            lines.append(f"SKIP {target} loads={len(loads)} missing={CRITICAL_LOAD[target]}")
            continue
        # Isolate the named load from the fresh worst path.  This is more
        # deterministic than a coordinate split and avoids burdening the
        # critical clone with unrelated fanout.
        moved = critical
        clone = odb.dbInst_create(block, inst.getMaster(), f"timing_clone_{target.strip('_')}")
        clone.setOrient(inst.getOrient())
        xs, ys = zip(*(xy(it) for it in moved))
        clone.setLocation(sum(xs) // len(xs), sum(ys) // len(ys))
        clone.setPlacementStatus("PLACED")
        for src_it in inst.getITerms():
            if src_it == out or src_it.getMTerm().getIoType() == "OUTPUT":
                continue
            dst_it = clone.findITerm(src_it.getMTerm().getName())
            if dst_it is not None and src_it.getNet() is not None:
                dst_it.connect(src_it.getNet())
        clone_out = output_iterm(clone)
        clone_net = odb.dbNet_create(block, f"timing_clone_{target.strip('_')}_n")
        clone_net.setSigType("SIGNAL")
        clone_out.connect(clone_net)
        for load in moved:
            load.disconnect()
            load.connect(clone_net)
        lines.append(
            f"CLONE {target} master={inst.getMaster().getName()} "
            f"loads_before={len(loads)} original={len(loads)-len(moved)} clone={len(moved)}"
        )
        made += 1

    os.makedirs(os.path.dirname(DST), exist_ok=True)
    design.writeDb(DST)
    lines.append(f"CLONES {made}")
    with open(os.path.splitext(DST)[0] + ".log", "w", encoding="utf-8") as stream:
        stream.write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
