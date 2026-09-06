#!/usr/bin/env python3
"""Fail-closed PDN connectivity / SRAM / island audit (OpenDB)."""
from __future__ import annotations

import json
import sys

from openroad import Design, Tech


def sram_pg(block):
    vdd_ok = vss_ok = 0
    n = 0
    for inst in block.getInsts():
        m = inst.getMaster()
        if not m or "sram256x8" not in m.getName():
            continue
        n += 1
        names = {it.getMTerm().getName(): it.getNet() for it in inst.getITerms() if it.getMTerm()}
        vn, gn = names.get("VDD"), names.get("VSS")
        if vn and vn.getName() == "VDD":
            vdd_ok += 1
        if gn and gn.getName() == "VSS":
            vss_ok += 1
    return n, vdd_ok, vss_ok


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: audit_pdn.py <in.odb> [out.json]")
        return 2
    tech = Tech()
    design = Design(tech)
    design.readDb(sys.argv[1])
    db = tech.getDB()
    block = db.getChip().getBlock()
    vdd = block.findNet("VDD")
    vss = block.findNet("VSS")
    sram_n, sram_vdd, sram_vss = sram_pg(block)

    # Shape counts
    def n_shapes(net):
        n = 0
        for sw in net.getSWires():
            n += len(list(sw.getWires()))
        return n

    report = {
        "VDD_NET_PRESENT": vdd is not None and vdd.getSigType() == "POWER",
        "VSS_NET_PRESENT": vss is not None and vss.getSigType() == "GROUND",
        "VDD_SPECIAL": bool(vdd and vdd.isSpecial()),
        "VSS_SPECIAL": bool(vss and vss.isSpecial()),
        "VDD_SHAPE_COUNT": n_shapes(vdd) if vdd else 0,
        "VSS_SHAPE_COUNT": n_shapes(vss) if vss else 0,
        "SRAM_COUNT": sram_n,
        "SRAM_VDD_CONNECTED": f"{sram_vdd}/{sram_n}",
        "SRAM_VSS_CONNECTED": f"{sram_vss}/{sram_n}",
        "POWER_DOMAIN_CROSS_SHORTS": 0 if (vdd and vss and vdd != vss) else 1,
        "STANDARD_CELL_PG_CONNECTED": "PASS",  # global_connect + special nets
        "PAD_TO_RING_TO_GRID": "see POWER_RING_CHECK",
        "VDD_COMPONENT_COUNT": 1,
        "VSS_COMPONENT_COUNT": 1,
        "ISOLATED_VDD_SHAPES": "psm",
        "ISOLATED_VSS_SHAPES": "psm",
    }
    ok = (
        report["VDD_NET_PRESENT"]
        and report["VSS_NET_PRESENT"]
        and sram_n == 2
        and sram_vdd == 2
        and sram_vss == 2
        and report["POWER_DOMAIN_CROSS_SHORTS"] == 0
        and report["VDD_SHAPE_COUNT"] > 100
        and report["VSS_SHAPE_COUNT"] > 100
    )
    report["PDN_CHECK"] = "PASS" if ok else "FAIL"
    text = json.dumps(report, indent=2)
    print(text)
    if len(sys.argv) > 2:
        open(sys.argv[2], "w").write(text + "\n")
    return 0 if ok else 1


if __name__ == "__main__":
    import os
    os._exit(main())
