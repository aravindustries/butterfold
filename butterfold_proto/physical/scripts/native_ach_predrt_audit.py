#!/usr/bin/env python3
"""Audit an ODB for ACH shell + PDN + pre-route suitability."""
from __future__ import annotations

import os
import sys

from openroad import Design, Tech


def main() -> None:
    path = sys.argv[1]
    outp = sys.argv[2] if len(sys.argv) > 2 else "/tmp/odb_audit.txt"
    tech = Tech()
    design = Design(tech)
    design.readDb(path)
    block = tech.getDB().getChip().getBlock()
    bterms = sorted(bt.getName() for bt in block.getBTerms())
    ties = [i for i in block.getInsts() if i.getName().startswith("ach_tie_")]
    loads = [i for i in block.getInsts() if i.getName().startswith("ach_rx_load_")]
    diodes = [
        i
        for i in block.getInsts()
        if i.getMaster() and i.getMaster().getName().endswith("__antenna")
    ]
    sig_wires = 0
    pg_wires = 0
    for net in block.getNets():
        st = net.getSigType()
        w = net.getWire()
        has = w is not None
        sw = list(net.getSWires())
        if st in ("POWER", "GROUND"):
            if sw or has:
                pg_wires += 1
        else:
            if has:
                sig_wires += 1
    inst = block.findInst("_20041_")
    lines = [
        f"ODB {path}",
        f"BTERMS {len(bterms)}",
        f"TIES {len(ties)}",
        f"RX_LOADS {len(loads)}",
        f"DIODES {len(diodes)}",
        f"INSTS {len(list(block.getInsts()))}",
        f"SIGNAL_WIRES {sig_wires}",
        f"PG_NETS_WITH_SPECIAL {pg_wires}",
        f"HAS_20041 {inst is not None}",
    ]
    if inst is not None:
        lines.append(f"MASTER_20041 {inst.getMaster().getName()}")
        q = inst.findITerm("Q")
        if q and q.getNet():
            lines.append(f"NET_20041_Q {q.getNet().getName()}")
    lines.append("BTERM_SAMPLE " + " ".join(bterms[:8] + ["..."] + bterms[-4:]))
    open(outp, "w").write("\n".join(lines) + "\n")
    os._exit(0)


if __name__ == "__main__":
    main()
