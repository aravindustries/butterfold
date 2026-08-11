#!/usr/bin/env python3
"""Normalize OpenDB-generated CDL and create an LVS negative control."""

from pathlib import Path
import re
import sys

TOP = "butterfold_padframe_top"
POWER = {"VDD", "VNW", "DVDD"}
GROUND = {"VSS", "VPW", "DVSS"}
PDK_PRIMITIVES = {
    "cap_nmos_06v0",
    "nfet_05v0",
    "nfet_06v0",
    "nfet_06v0_dss",
    "pfet_05v0",
    "pfet_06v0",
    "pfet_06v0_dss",
    "ppolyf_u",
}


def statements(text: str) -> list[str]:
    out, current = [], ""
    for line in text.splitlines():
        if line.startswith("+"):
            current += " " + line[1:].strip()
        else:
            if current:
                out.append(current)
            current = line.rstrip()
    if current:
        out.append(current)
    return out


def wrap(stmt: str) -> str:
    words = stmt.split()
    if not words:
        return ""
    lines, line = [], words.pop(0)
    for word in words:
        if len(line) + len(word) + 1 > 88:
            lines.append(line)
            line = "+ " + word
        else:
            line += " " + word
    lines.append(line)
    return "\n".join(lines)


def x_master(words: list[str]) -> str:
    """Return the subcircuit name preceding SPICE instance parameters."""
    for index, word in enumerate(words[1:], start=1):
        if "=" in word or word.startswith("$["):
            return words[index - 1]
    return words[-1]


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit("usage: prepare_lvs_reference.py RAW OUT BAD")
    raw_path, out_path, bad_path = map(Path, sys.argv[1:])
    raw_text = raw_path.read_text()
    stmts = statements(raw_text)
    pdk_root = Path("/foss/pdks/gf180mcuD/libs.ref")
    master_paths = [
        pdk_root / "gf180mcu_fd_sc_mcu9t5v0/spice/gf180mcu_fd_sc_mcu9t5v0.spice",
        pdk_root / "gf180mcu_fd_io/spice/gf180mcu_fd_io.spice",
        pdk_root / "gf180mcu_fd_ip_sram/spice/gf180mcu_fd_ip_sram__sram256x8m8wm1.spice",
    ]
    master_text = "\n".join(path.read_text() for path in master_paths)
    ports = {}
    for stmt in [*stmts, *statements(master_text)]:
        words = stmt.split()
        if len(words) >= 2 and words[0].upper() == ".SUBCKT":
            ports[words[1]] = words[2:]

    normalized, bad_stmts = [], []
    in_top = False
    supply_fixes = 0
    negative_done = False
    for stmt in stmts:
        words = stmt.split()
        if len(words) >= 2 and words[0].upper() == ".SUBCKT":
            in_top = words[1] == TOP
        elif words and words[0].upper() == ".ENDS":
            in_top = False
        new_stmt = stmt
        if in_top and words and words[0].startswith("X"):
            master = x_master(words)
            master_index = words.index(master, 1)
            nets = words[1:master_index]
            master_ports = ports.get(master)
            if master_ports and len(master_ports) == len(nets):
                for index, pin in enumerate(master_ports):
                    if not nets[index].startswith("_unconnected_"):
                        continue
                    if pin in POWER:
                        nets[index] = "u_core/one_"
                        supply_fixes += 1
                    elif pin in GROUND:
                        nets[index] = "u_core/zero_"
                        supply_fixes += 1
                new_stmt = " ".join([words[0], *nets, *words[master_index:]])
        normalized.append(new_stmt)
        bad_stmt = new_stmt
        if in_top and not negative_done and words and words[0] == "Xu_clk_iso":
            bad_stmt = re.sub(r"\bclk_iso\b", "lvs_negative_broken_clk", new_stmt, count=1)
            negative_done = bad_stmt != new_stmt
        bad_stmts.append(bad_stmt)

    if supply_fixes == 0 or not negative_done:
        raise SystemExit("reference normalization/negative-control construction failed")
    cleaned_master = []
    for statement in statements(master_text):
        words = statement.split()
        if words and words[0].startswith("X"):
            for index, word in enumerate(words):
                if word.startswith("$T="):
                    words = words[:index]
                    break
            statement = " ".join(words)
        cleaned_master.append(statement)

    blocks = {}
    current_name, current_block = None, []
    for statement in cleaned_master:
        words = statement.split()
        if len(words) >= 2 and words[0].upper() == ".SUBCKT":
            current_name, current_block = words[1], [statement]
        elif current_name is not None:
            current_block.append(statement)
            if words and words[0].upper() == ".ENDS":
                blocks[current_name] = current_block
                current_name, current_block = None, []

    required = set()
    for statement in normalized:
        words = statement.split()
        if words and words[0].startswith("X"):
            required.add(x_master(words))
    pending = list(required)
    while pending:
        name = pending.pop()
        for statement in blocks.get(name, []):
            words = statement.split()
            if words and words[0].startswith("X"):
                dependency = x_master(words)
                if dependency not in required and dependency not in PDK_PRIMITIVES:
                    required.add(dependency)
                    pending.append(dependency)
    missing = sorted(name for name in required
                     if name not in blocks and name not in PDK_PRIMITIVES)
    if missing:
        raise SystemExit(f"missing PDK subcircuit definitions: {missing}")
    selected = []
    for name in sorted(required):
        selected.extend(blocks.get(name, []))
    suffix = "\n" + "\n".join(wrap(s) for s in selected) + "\n"
    out_path.write_text("\n".join(wrap(s) for s in normalized) + suffix)
    bad_path.write_text("\n".join(wrap(s) for s in bad_stmts) + suffix)
    print(f"normalized_supply_terminals={supply_fixes}")
    print(f"reachable_pdk_subcircuits={len(required)}")
    print("negative_control=clock isolation input disconnected")


if __name__ == "__main__":
    main()
