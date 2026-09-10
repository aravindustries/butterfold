#!/usr/bin/env python3
"""Offline sizing for the final native-ACH setup/slew closure candidate.

OpenROAD's in-session resizer trips a stale GRouteDb callback on this design.
Perform only deterministic, function-preserving master swaps here, then use the
normal native ACH GRT/DRT flow to legalize and route the resulting database.
"""
from __future__ import annotations

import os

from openroad import Design, Tech


PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.environ.get(
    "TIMING_SIZE_SRC",
    PROTO + "/physical/results/native_power_ring_ach/predrt/odb_buf3.odb",
)
DST = os.environ.get(
    "TIMING_SIZE_DST",
    PROTO + "/physical/results/native_power_ring_ach/predrt/candidate32_size.odb",
)
SIZE_CONE_BUFFERS = os.environ.get("SIZE_CONE_BUFFERS", "1") == "1"

# Weak cells common to the fresh-extraction violating paths.  Every replacement
# is the same Boolean cell family at the next characterized drive strength.
EXPLICIT = {
    "_09413_": "gf180mcu_fd_sc_mcu9t5v0__nand3_4",
    "_09417_": "gf180mcu_fd_sc_mcu9t5v0__clkinv_20",
    "_09419_": "gf180mcu_fd_sc_mcu9t5v0__nand2_4",
    "_15953_": "gf180mcu_fd_sc_mcu9t5v0__aoi211_4",
    "_15972_": "gf180mcu_fd_sc_mcu9t5v0__nor2_4",
    "_16297_": "gf180mcu_fd_sc_mcu9t5v0__oai32_4",
}
if os.environ.get("SIZE_LAUNCH_CLOCKS", "0") == "1":
    EXPLICIT.update({
        "clkbuf_leaf_13_clk_regs": "gf180mcu_fd_sc_mcu9t5v0__clkbuf_20",
        "clkbuf_leaf_23_clk_regs": "gf180mcu_fd_sc_mcu9t5v0__clkbuf_20",
    })
if os.environ.get("SIZE_SECOND_CONE", "0") == "1":
    EXPLICIT.update({
        "_20008_": "gf180mcu_fd_sc_mcu9t5v0__dffrnq_4",
        "_09398_": "gf180mcu_fd_sc_mcu9t5v0__nor2_4",
    })
if os.environ.get("SIZE_EXPLICIT_DATA", "1") != "1":
    EXPLICIT = {name: master for name, master in EXPLICIT.items()
                if name.startswith("clkbuf_leaf_") or
                (os.environ.get("SIZE_SECOND_CONE", "0") == "1" and
                 name in {"_20008_", "_09398_"})}


def main() -> None:
    tech = Tech()
    design = Design(tech)
    design.readDb(SRC)
    db = tech.getDB()
    block = db.getChip().getBlock()
    masters = {}
    for lib in db.getLibs():
        for master in lib.getMasters():
            masters[master.getName()] = master

    swaps = []
    for inst in block.getInsts():
        old = inst.getMaster().getName()
        new = EXPLICIT.get(inst.getName())
        if (
            new is None
            and SIZE_CONE_BUFFERS
            and (inst.getName().startswith("cone_buf_") or inst.getName().startswith("cone3_buf_"))
            and old == "gf180mcu_fd_sc_mcu9t5v0__clkbuf_8"
        ):
            new = "gf180mcu_fd_sc_mcu9t5v0__clkbuf_20"
        if new is None or new == old:
            continue
        master = masters.get(new)
        if master is None:
            raise SystemExit(f"missing replacement master {new}")
        if inst.getName().startswith("clkbuf_leaf_"):
            inst.setDoNotTouch(False)
        if not inst.swapMaster(master):
            raise SystemExit(f"swap failed {inst.getName()} {old} -> {new}")
        swaps.append((inst.getName(), old, new))

    os.makedirs(os.path.dirname(DST), exist_ok=True)
    design.writeDb(DST)
    log = os.path.splitext(DST)[0] + ".log"
    with open(log, "w", encoding="utf-8") as stream:
        stream.write(f"SRC {SRC}\nDST {DST}\nSWAPS {len(swaps)}\n")
        for name, old, new in swaps:
            stream.write(f"SWAP {name} {old} -> {new}\n")
    print(f"SRC {SRC}")
    print(f"DST {DST}")
    print(f"SWAPS {len(swaps)}")


if __name__ == "__main__":
    main()
