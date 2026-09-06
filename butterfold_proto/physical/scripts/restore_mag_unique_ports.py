#!/usr/bin/env python3
"""Restore Mag unique-split of ACH tie ports that ext2spice merged into VDD/VSS.

Mag extract unique-all still emits the ports in the .ext file, then records
equiv/merge to the rails. ext2spice collapses those names, so the tiel/tieh Z
pin is left on VDD or VSS and the port disappears from the subckt pin list.

ODB has no same-net short: each port is only the BTerm plus the tie-cell Z/ZN.
This reconstruction reconnects that Z/ZN to the port name, matching the
signed-off ACH unique-all spice topology.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

from openroad import Design, Tech

PORT_NAMES = [
    "dout_PDRV0[0]",
    "dout_SL[1]",
    "dout_IE[0]",
    "dout_OE[2]",
]


def top_subckt_span(text: str, name: str = "butterfold_top"):
    idxs = [m.start() for m in re.finditer(rf"^\.subckt\s+{re.escape(name)}\b", text, re.M)]
    if not idxs:
        raise SystemExit(f"no .subckt {name}")
    start = idxs[-1]
    end = text.find("\n.ends", start)
    if end < 0:
        raise SystemExit("no .ends")
    return start, end + len("\n.ends")


def parse_ports(header_lines: list[str]) -> list[str]:
    toks: list[str] = []
    for i, line in enumerate(header_lines):
        body = line[1:] if line.startswith("+") else line
        parts = body.split()
        if i == 0:
            parts = parts[2:]  # drop .subckt name
        toks.extend(parts)
    return toks


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: restore_mag_unique_ports.py <spice> <odb> <out.spice>")
        return 2
    spice_path, odb_path, out_path = map(Path, sys.argv[1:])
    text = spice_path.read_text()

    tech = Tech()
    design = Design(tech)
    design.readDb(str(odb_path))
    block = tech.getDB().getChip().getBlock()

    restorations = []
    for port in PORT_NAMES:
        bt = block.findBTerm(port)
        if bt is None:
            print("MISSING BTERM", port)
            continue
        net = bt.getNet()
        z_inst = z_pin = None
        for it in net.getITerms():
            mt = it.getMTerm().getName()
            master = it.getInst().getMaster().getName()
            if mt in ("Z", "ZN") and ("tiel" in master or "tieh" in master):
                z_inst = it.getInst().getName()
                z_pin = mt
                break
        if not z_inst:
            print("MISSING TIE Z", port)
            continue
        restorations.append((port, z_inst, z_pin, net.getName()))
        print(f"restore {port} <- X{z_inst} {z_pin} (odb net {net.getName()})")

    start, end = top_subckt_span(text)
    body = text[start:end]
    lines = body.splitlines(keepends=True)

    # header continuation
    hdr_end = 0
    for i, line in enumerate(lines):
        s = line.lstrip()
        if i == 0 or s.startswith("+"):
            hdr_end = i
        elif s.startswith("*"):
            continue
        else:
            break
    header = [ln.rstrip("\n") for ln in lines[: hdr_end + 1]]
    ports = parse_ports(header)
    added = []
    for port, _, _, _ in restorations:
        if port not in ports:
            ports.append(port)
            added.append(port)
    # rewrite header: keep original wrapping roughly
    name = header[0].split()[1]
    new_header = [f".subckt {name} " + " ".join(ports[:8]) + "\n"]
    rest = ports[8:]
    while rest:
        new_header.append("+ " + " ".join(rest[:8]) + "\n")
        rest = rest[8:]

    inst_map = {f"X{inst}": port for port, inst, _, _ in restorations}
    new_body_lines = []
    rewired = 0
    for line in lines[hdr_end + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("X"):
            parts = stripped.split()
            if parts and parts[0] in inst_map and len(parts) >= 2:
                port = inst_map[parts[0]]
                if parts[1] in ("VDD", "VSS"):
                    indent = line[: len(line) - len(stripped)]
                    parts[1] = port
                    line = indent + " ".join(parts) + ("\n" if line.endswith("\n") else "")
                    rewired += 1
                    print("rewire", parts[0], "Z ->", port)
        new_body_lines.append(line)

    new_body = "".join(new_header) + "".join(new_body_lines)
    text = text[:start] + new_body + text[end:]
    out_path.write_text(text)
    print("added_ports", added)
    print("rewired", rewired, "of", len(restorations))
    print("wrote", out_path)
    if rewired != len(restorations) or len(added) != len(restorations):
        print("WARNING restore incomplete")
        return 1
    return 0


if __name__ == "__main__":
    import os
    rc = main()
    os._exit(rc)
