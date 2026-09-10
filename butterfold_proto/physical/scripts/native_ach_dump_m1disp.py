#!/usr/bin/env python3
"""Compare cell origins near M1.1 sites between two ODBs."""
from __future__ import annotations

import os

from openroad import Design, Tech

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
A = os.environ.get("DISP_A", PROTO + "/physical/results/native_power_ring/filled.odb")
B = os.environ.get("DISP_B", PROTO + "/physical/results/native_power_ring_ach/ach_applied.odb")
SITES = [(616.81, 656.41), (659.59, 676.74), (641.635, 677.75), (634.015, 677.75)]


def load(path):
    tech = Tech()
    design = Design(tech)
    design.readDb(path)
    block = tech.getDB().getChip().getBlock()
    dbu = block.getDefUnits()
    insts = {}
    for inst in block.getInsts():
        loc = inst.getLocation()
        insts[inst.getName()] = (
            inst.getMaster().getName(),
            int(loc[0]),
            int(loc[1]),
            str(inst.getOrient()),
        )
    return insts, dbu


def near(insts, dbu, xum, yum, r=8.0):
    x, y = int(xum * dbu), int(yum * dbu)
    rad = int(r * dbu)
    out = []
    for n, (m, ix, iy, o) in insts.items():
        if abs(ix - x) <= rad and abs(iy - y) <= rad:
            out.append((n, m, ix / dbu, iy / dbu, o))
    out.sort(key=lambda t: (t[2], t[3], t[0]))
    return out


def main():
    a, dbu = load(A)
    b, _ = load(B)
    lines = [f"A {A}", f"B {B}", f"NA {len(a)} NB {len(b)}"]
    moved = 0
    only_a = 0
    only_b = 0
    for n, (m, x, y, o) in a.items():
        if n.startswith(("FILLER", "TAP_", "PHY_EDGE", "ach_tie_", "ach_rx_load_")):
            continue
        if n not in b:
            only_a += 1
            continue
        m2, x2, y2, o2 = b[n]
        if (x, y, o, m) != (x2, y2, o2, m2):
            moved += 1
            if moved <= 15:
                lines.append(
                    f"MOVED {n} {m} {x/dbu:.3f},{y/dbu:.3f} {o} -> {m2} {x2/dbu:.3f},{y2/dbu:.3f} {o2}"
                )
    for n in b:
        if n not in a and not n.startswith(("FILLER", "TAP_", "PHY_EDGE", "ach_tie_", "ach_rx_load_")):
            only_b += 1
    lines.append(f"MOVED {moved} ONLY_A {only_a} ONLY_B {only_b}")
    for xum, yum in SITES:
        lines.append(f"SITE {xum} {yum}")
        la = near(a, dbu, xum, yum)
        lb = near(b, dbu, xum, yum)
        sa, sb = {(t[0], t[1], t[2], t[3], t[4]) for t in la}, {(t[0], t[1], t[2], t[3], t[4]) for t in lb}
        lines.append(f"  A {len(la)} B {len(lb)} common {len(sa & sb)}")
        for t in la:
            tag = "SAME" if (t[0], t[1], t[2], t[3], t[4]) in sb else "A_ONLY"
            lines.append(f"  {tag} A {t[0]} {t[1]} {t[2]:.3f} {t[3]:.3f} {t[4]}")
        for t in lb:
            if (t[0], t[1], t[2], t[3], t[4]) not in sa:
                lines.append(f"  B_ONLY {t[0]} {t[1]} {t[2]:.3f} {t[3]:.3f} {t[4]}")
    text = "\n".join(lines) + "\n"
    open("/tmp/m1disp.txt", "w").write(text)
    print(text)
    os._exit(0)


if __name__ == "__main__":
    main()
