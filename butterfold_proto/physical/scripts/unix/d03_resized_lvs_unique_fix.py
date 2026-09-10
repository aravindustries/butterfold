#!/usr/bin/env python3
"""Regenerate Magic unique-split corrections from THIS extraction + ODB.

Mag `extract unique all` names most nets as inst/pin. Most of those are the
canonical Mag name for an already-connected ODB net (a rename). A leftover
unique-split fragment is a second Mag net for the same ODB parent — join it.

Do not join DEF-distinct nets. Do not reuse old gwen/nor3 instance names.

This extraction's leftover (audited against Netgen 1-net mismatch):

  u_transform_scheduler_core.u_fft_scratch_sram.u_lo.u_sram/Q[3]
      -> u_transform_scheduler_core.u_fft_scratch_sram.u_lo.macro_q[3]

SRAM Q[3] pin label unique-split from parent metal; schematic is one net.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

from openroad import Design, Tech

LEFTOVER_JOINS = [
    (
        "u_transform_scheduler_core.u_fft_scratch_sram.u_lo.u_sram/Q[3]",
        "u_transform_scheduler_core.u_fft_scratch_sram.u_lo.macro_q[3]",
    )
]


def unescape(name: str) -> str:
    return name.replace("\\[", "[").replace("\\]", "]")


def token_replace(text: str, src: str, dst: str) -> tuple[str, int]:
    pat = re.compile(r"(?<![A-Za-z0-9_\\])" + re.escape(src) + r"(?![A-Za-z0-9_\\])")
    n = len(pat.findall(text))
    return pat.sub(dst, text), n


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: d03_resized_lvs_unique_fix.py <spice> <odb> <out.spice>")
        return 2
    spice_path, odb_path, out_path = map(Path, sys.argv[1:])
    text = spice_path.read_text()
    tech = Tech()
    design = Design(tech)
    design.readDb(str(odb_path))
    block = tech.getDB().getChip().getBlock()

    aliases = sorted(set(re.findall(r"\b([A-Za-z0-9_\\./\[\]]+/[A-Za-z0-9_\\[\]]+)\b", text)))
    print(f"candidate_aliases {len(aliases)}")
    subs = []
    for alias in aliases:
        if "/" not in alias:
            continue
        inst_name, pin = alias.rsplit("/", 1)
        inst = block.findInst(inst_name)
        if inst is None:
            inst = block.findInst(unescape(inst_name))
        if inst is None:
            continue
        iterm = inst.findITerm(pin) or inst.findITerm(unescape(pin))
        if iterm is None:
            continue
        net = iterm.getNet()
        if net is None:
            continue
        parent = unescape(net.getName())
        alias_u = unescape(alias)
        if parent == alias_u:
            continue
        subs.append((alias, parent))

    print(f"odb_parent_subs {len(subs)}")
    for alias, parent in sorted(subs, key=lambda t: -len(t[0])):
        text, n = token_replace(text, alias, parent)
        if n:
            print(f"{n:4d}  {alias}  ->  {parent}")

    text = unescape(text.replace("\\[", "[").replace("\\]", "]"))
    for a, b in LEFTOVER_JOINS:
        text, n = token_replace(text, a, b)
        print(f"leftover {n:4d}  {a}  ->  {b}")
        if n == 0:
            print("WARNING missing leftover unique-split net", a)

    out_path.write_text(text)
    print("wrote", out_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
