#!/usr/bin/env python3
"""Insert non-inverting clkbufs on the extracted high-slew fft128_active cone.

Uses odb only (no GRT callbacks). Boolean function is preserved.
"""
from __future__ import annotations

import os
import sys

from openroad import Design, Tech
import odb

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.environ.get(
    "ODB_BUF_SRC",
    os.path.join(PROTO, "physical/results/native_power_ring_ach/predrt/odb_buf3.odb"),
)
DST = os.environ.get(
    "ODB_BUF_DST",
    os.path.join(PROTO, "physical/results/native_power_ring_ach/predrt/odb_buf5.odb"),
)

# Driver instance / pin on the extracted worst path (buf25 OpenRCX).
DRIVERS = [
    ("_15985_", "ZN"),
    ("_15996_", "ZN"),
]
STRONG = set()


def iterm_xy(it):
    avg = it.getAvgXY()
    if isinstance(avg, tuple) and len(avg) >= 3 and avg[0]:
        return int(avg[1]), int(avg[2])
    if isinstance(avg, tuple) and len(avg) == 2:
        return int(avg[0]), int(avg[1])
    bb = it.getBBox()
    if bb:
        return int((bb.xMin() + bb.xMax()) / 2), int((bb.yMin() + bb.yMax()) / 2)
    inst = it.getInst()
    loc = inst.getLocation()
    return int(loc[0]), int(loc[1])


def load_pins(iterm):
    net = iterm.getNet()
    if net is None:
        return []
    out = []
    for it in net.getITerms():
        if it == iterm:
            continue
        inst = it.getInst()
        name = inst.getName()
        master = inst.getMaster().getName()
        if master.endswith("__antenna"):
            continue
        if name.startswith("ach_tie_") or name.startswith("ach_rx_load_"):
            continue
        if inst.isDoNotTouch():
            continue
        mterm = it.getMTerm()
        if mterm.getIoType() == "INPUT":
            out.append(it)
    return out


def insert_one(block, tech, driver, loads, name, master):
    dx, dy = iterm_xy(driver)
    lxs = []
    lys = []
    for ld in loads:
        x, y = iterm_xy(ld)
        lxs.append(x)
        lys.append(y)
    cx = int((dx + sum(lxs) / len(lxs)) / 2)
    cy = int((dy + sum(lys) / len(lys)) / 2)
    site_h = 5040  # 9T row ~2.52 um at 2000 dbu
    cy = int(round(cy / site_h) * site_h)
    inst = odb.dbInst_create(block, master, name)
    inst.setOrient("R0")
    inst.setLocation(cx, cy)
    inst.setPlacementStatus("PLACED")
    parent = driver.getNet()
    znet = odb.dbNet_create(block, name + "_n")
    znet.setSigType("SIGNAL")
    inst.findITerm("I").connect(parent)
    inst.findITerm("Z").connect(znet)
    for ld in loads:
        ld.disconnect()
        ld.connect(znet)
    return inst, (cx, cy, len(loads))


def main() -> None:
    tech = Tech()
    design = Design(tech)
    design.readDb(SRC)
    db = tech.getDB()
    block = db.getChip().getBlock()
    masters = {}
    for lib in db.getLibs():
        for tag, cell in (("8", "gf180mcu_fd_sc_mcu9t5v0__clkbuf_8"),
                          ("20", "gf180mcu_fd_sc_mcu9t5v0__clkbuf_20"),
                          ("12", "gf180mcu_fd_sc_mcu9t5v0__clkbuf_12")):
            m = lib.findMaster(cell)
            if m:
                masters[tag] = m
    if "8" not in masters:
        raise SystemExit("missing clkbuf_8")
    nbuf = 0
    lines = [f"SRC {SRC}"]
    for inst_name, pin in DRIVERS:
        inst = block.findInst(inst_name)
        if inst is None:
            lines.append(f"MISSING {inst_name}")
            continue
        drv = inst.findITerm(pin)
        if drv is None or drv.getNet() is None:
            lines.append(f"NO_NET {inst_name}/{pin}")
            continue
        loads = load_pins(drv)
        if len(loads) < 2:
            lines.append(f"SKIP {inst_name}/{pin} loads={len(loads)}")
            continue
        loads_xy = sorted(loads, key=lambda it: iterm_xy(it)[0] + iterm_xy(it)[1] * 3)
        groups = [loads_xy]
        use_strong = (inst_name, pin) in STRONG
        master = masters["20"] if use_strong and "20" in masters else masters.get("12", masters["8"]) if len(loads_xy) >= 6 else masters["8"]
        if use_strong:
            groups = [loads_xy]
        elif len(loads_xy) >= 8:
            q = max(1, len(loads_xy) // 4)
            groups = [loads_xy[i:i+q] if i < 3*q else loads_xy[i:] for i in range(0, 4*q, q)]
            groups = [g for g in groups if g]
        elif len(loads_xy) >= 4:
            mid = len(loads_xy) // 2
            groups = [loads_xy[:mid], loads_xy[mid:]]
        for gi, grp in enumerate(groups):
            if not grp:
                continue
            name = f"cone5_buf_{nbuf}"
            try:
                _, info = insert_one(block, tech, drv, grp, name, master)
            except Exception as e:
                lines.append(f"FAIL {inst_name}/{pin} g{gi} {e}")
                continue
            nbuf += 1
            lines.append(
                f"BUF {name} drv={inst_name}/{pin} loads={info[2]} xy={info[0]/2000:.3f},{info[1]/2000:.3f}"
            )
    lines.append(f"INSERTED {nbuf}")
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    design.writeDb(DST)
    log = os.path.join(os.path.dirname(DST), "odb_buf.log")
    open(log, "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))
    os._exit(0)


if __name__ == "__main__":
    main()
