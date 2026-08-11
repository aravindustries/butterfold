#!/usr/bin/env python3
"""Build matched leaf-level SPICE views from Magic .ext and OpenDB CDL.

Foundry cells remain opaque.  Magic's extracted top-level interconnect supplies
the layout connectivity; OpenDB's post-route CDL supplies the reference.
"""

from collections import Counter
from pathlib import Path
import re
import sys

TOP = "butterfold_padframe_top"
POWER = {"VDD", "VNW", "DVDD"}
GROUND = {"VSS", "VPW", "DVSS"}


class DSU:
    def __init__(self):
        self.p = {}

    def find(self, x):
        self.p.setdefault(x, x)
        root = x
        while self.p[root] != root:
            root = self.p[root]
        while self.p[x] != x:
            parent = self.p[x]
            self.p[x] = root
            x = parent
        return root

    def union(self, a, b):
        a, b = self.find(a), self.find(b)
        if a != b:
            self.p[b] = a


def statements(text):
    out, cur = [], ""
    for line in text.splitlines():
        if line.startswith("+"):
            cur += " " + line[1:].strip()
        else:
            if cur:
                out.append(cur)
            cur = line.strip()
    if cur:
        out.append(cur)
    return out


def leaf_ports(work):
    allowed = pdk_ports()
    result = {}
    for path in work.glob("*.ext"):
        if path.stem == TOP:
            continue
        numbered = []
        for line in path.read_text(errors="replace").splitlines():
            m = re.match(r'^port "([^"]+)" (\d+) ', line)
            if m:
                numbered.append((int(m.group(2)), m.group(1)))
        seen, ordered = set(), []
        for _, name in sorted(numbered):
            if name in allowed.get(path.stem, []) and name not in seen:
                ordered.append(name)
                seen.add(name)
        result[path.stem] = ordered
    return result


def layout_netlist(work, output):
    ports_by_master = leaf_ports(work)
    lines = (work / f"{TOP}.ext").read_text(errors="replace").splitlines()
    uses, top_ports, dsu = [], [], DSU()
    for line in lines:
        m = re.match(r'^use (\S+) (\S+) ', line)
        if m:
            uses.append(m.groups())
            continue
        m = re.match(r'^port "([^"]+)" ', line)
        if m:
            top_ports.append(m.group(1))
            continue
        if line.startswith("merge "):
            names = re.findall(r'"([^"]+)"', line)
            if len(names) >= 2:
                dsu.union(names[0], names[1])

    # ButterFold's current single-supply padframe intentionally ties core and
    # digital-I/O rails together.  These are special/PDN nets rather than top
    # signal BTerms, so normalize their extracted leaf terminals explicitly.
    for master, inst in uses:
        for pin in ports_by_master.get(master, []):
            if pin in POWER:
                dsu.union(f"{inst}/{pin}", "u_core/one_")
            elif pin in GROUND:
                dsu.union(f"{inst}/{pin}", "u_core/zero_")

    # Prefer stable human-readable labels for each extracted connected component.
    members = {}
    for name in list(dsu.p):
        members.setdefault(dsu.find(name), []).append(name)
    canonical = {}
    top_set = set(top_ports)
    for root, names in members.items():
        tops = sorted(top_set.intersection(names))
        plain = sorted(n for n in names if "/" not in n and not n.endswith("#"))
        canonical[root] = (tops or plain or sorted(names))[0]

    def net(name):
        root = dsu.find(name)
        return canonical.get(root, name).replace("[", "_").replace("]", "_")

    top_ports = sorted(top_ports, key=lambda n: int(next(
        re.match(r'^port "[^"]+" (\d+) ', x).group(1)
        for x in lines if x.startswith(f'port "{n}" '))))
    out = ["* Hierarchical leaf LVS layout derived from candidate GDS by Magic",
           ".subckt " + TOP + " " + " ".join(net(p) for p in top_ports)]
    counts = Counter()
    for master, inst in uses:
        pins = ports_by_master.get(master, [])
        if not pins:
            continue
        nets = [("u_core/one_" if pin in POWER else
                 "u_core/zero_" if pin in GROUND else
                 net(f"{inst}/{pin}")) for pin in pins]
        out.append("X" + inst + " " + " ".join(nets) + " " + master)
        counts[master] += 1
    out.append(".ends " + TOP)
    for master in sorted(counts):
        out.append(".subckt " + master + " " + " ".join(ports_by_master[master]))
        out.append(".ends " + master)
    output.write_text("\n".join(out) + "\n")
    return ports_by_master, counts, top_ports


def pdk_ports():
    paths = [
        Path("/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/cdl/gf180mcu_fd_sc_mcu9t5v0.cdl"),
        Path("/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_io/cdl/gf180mcu_fd_io.cdl"),
        Path("/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/cdl/gf180mcu_fd_ip_sram__sram256x8m8wm1.cdl"),
    ]
    result = {}
    for path in paths:
        for stmt in statements(path.read_text(errors="replace")):
            words = stmt.split()
            if len(words) > 2 and words[0].upper() == ".SUBCKT":
                result[words[1]] = words[2:]
    return result


def reference_netlist(raw, output, bad, layout_ports, wanted_counts):
    pdk = pdk_ports()
    stmts = statements(raw.read_text(errors="replace"))
    top_stmt = next(s for s in stmts if s.upper().startswith(".SUBCKT " + TOP.upper()))
    top_ports = top_stmt.split()[2:]
    instances, counts = [], Counter()
    in_top = False
    for stmt in stmts:
        words = stmt.split()
        if len(words) >= 2 and words[0].upper() == ".SUBCKT":
            in_top = words[1] == TOP
            continue
        if words and words[0].upper() == ".ENDS":
            in_top = False
            continue
        if not in_top or not words or not words[0].startswith("X"):
            continue
        master = words[-1]
        if master not in wanted_counts:
            continue
        source_pins = pdk.get(master)
        if not source_pins:
            raise SystemExit(f"missing PDK pin list: {master}")
        source_nets = words[1:-1]
        if len(source_nets) != len(source_pins):
            raise SystemExit(f"pin-count mismatch in raw CDL for {master}")
        by_pin = dict(zip(source_pins, source_nets))
        selected = []
        for pin in layout_ports[master]:
            value = by_pin[pin]
            if value.startswith("_unconnected_") and pin in POWER:
                value = "u_core/one_"
            elif value.startswith("_unconnected_") and pin in GROUND:
                value = "u_core/zero_"
            selected.append(value.replace("[", "_").replace("]", "_"))
        # The routed Verilog contains both wrapper and flow-created corner
        # instances at the same four physical placements.  GDS/Magic collapses
        # each coincident pair into one geometric leaf.  Keep only the number
        # of electrically identical corner leaves observable in layout.
        if master == "gf180mcu_fd_io__cor" and counts[master] >= wanted_counts[master]:
            continue
        instances.append((words[0], selected, master))
        counts[master] += 1
    if counts != wanted_counts:
        delta = {k: (wanted_counts[k], counts[k]) for k in wanted_counts if wanted_counts[k] != counts[k]}
        raise SystemExit(f"layout/reference leaf instance counts differ: {delta}")

    top_ports = [p.replace("[", "_").replace("]", "_") for p in top_ports]
    out = ["* Hierarchical leaf LVS reference derived from current post-route CDL",
           ".subckt " + TOP + " " + " ".join(top_ports)]
    for inst, nets, master in instances:
        out.append(inst + " " + " ".join(nets) + " " + master)
    out.append(".ends " + TOP)
    for master in sorted(wanted_counts):
        out.append(".subckt " + master + " " + " ".join(layout_ports[master]))
        out.append(".ends " + master)
    output.write_text("\n".join(out) + "\n")

    bad_lines = out.copy()
    for i, line in enumerate(bad_lines):
        if line.startswith("Xu_clk_iso "):
            words = line.split()
            words[1] = "negative_control_open"
            bad_lines[i] = " ".join(words)
            break
    else:
        raise SystemExit("could not construct negative control")
    bad.write_text("\n".join(bad_lines) + "\n")
    return counts, top_ports


def main():
    if len(sys.argv) != 6:
        raise SystemExit("usage: prepare_hierarchical_lvs.py WORK RAW_CDL LAYOUT REF BAD")
    work, raw, layout, ref, bad = map(Path, sys.argv[1:])
    ports, layout_counts, layout_top = layout_netlist(work, layout)
    ref_counts, ref_top = reference_netlist(raw, ref, bad, ports, layout_counts)
    print(f"layout_top_terminals={len(layout_top)}")
    print(f"reference_top_terminals={len(ref_top)}")
    print(f"leaf_instances={sum(layout_counts.values())}")
    print(f"leaf_masters={len(layout_counts)}")
    print(f"sram256_instances={layout_counts['gf180mcu_fd_ip_sram__sram256x8m8wm1']}")
    print(f"sram512_instances={sum(v for k, v in layout_counts.items() if 'sram512x8' in k)}")


if __name__ == "__main__":
    main()
