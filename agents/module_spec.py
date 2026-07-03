"""
module_spec.py — parse butterfold_module_io.md into structured module contracts.

This is the SINGLE SOURCE OF TRUTH loader. Everything downstream (planner, code
agent, verify) consumes the parsed contract, never a second spec file.

Pure stdlib, no API key: it parses the markdown into, per module,
  { name, title, functions[], ports[{name,dir,width,desc}] }
and can emit a compile-ready Verilog port skeleton for any module. The skeleton
gives the code agent a correct starting frame (and is the no-LLM fallback).
"""
from __future__ import annotations
import re, pathlib
from typing import Optional

ROOT      = pathlib.Path(__file__).parent.parent
SPEC_PATH = ROOT / "butterfold_module_io.md"

# Section title (as written in the spec)  ->  Verilog module name.
# These names match the existing tests/modules/tb_<name>.v testbenches.
TITLE_TO_NAME = {
    "FDIQ I/O ADAPTER":            "fdiq_io_adapter",
    "UNIFIED MIXED-RADIX CORE":    "unified_mixed_radix_core",
    "TWIDDLE SOURCE":              "twiddle_source",
    "SCHEDULER + ADDRESS CONTROL": "scheduler_addr_control",
    "SUBCARRIER MAP / EXTRACT":    "subcarrier_map_extract",
    "TDIQ I/O ADAPTER WITH CP":    "tdiq_io_adapter_cp",
    "TOP-LEVEL CHIP INTERFACE":    "butterfold_top",
}

# A build order that respects data dependencies (leaf datapath/rom first, then
# the controller, then the top that wires them together).
BUILD_ORDER = [
    "twiddle_source",
    "unified_mixed_radix_core",
    "subcarrier_map_extract",
    "fdiq_io_adapter",
    "tdiq_io_adapter_cp",
    "scheduler_addr_control",
    "butterfold_top",
]

# Ports whose direction the spec states with the "Input/Output" column. A port
# line looks like:   - name[7:0]        Input    description
#              or:   - name             Output   description
_PORT_RE = re.compile(
    r"^-\s+(?P<name>[a-zA-Z_]\w*)\s*(?P<bus>\[[^\]]+\])?\s+"
    r"(?P<dir>Input|Output)\b\s*(?P<desc>.*)$"
)


def _width_from_bus(bus: Optional[str]) -> int:
    """'[7:0]' -> 8 ; '[6:0]' -> 7 ; None -> 1."""
    if not bus:
        return 1
    m = re.match(r"\[(\d+):(\d+)\]", bus.strip())
    if not m:
        return 1
    hi, lo = int(m.group(1)), int(m.group(2))
    return abs(hi - lo) + 1


def parse(path: pathlib.Path = SPEC_PATH) -> dict:
    """Return {'modules': {name: {...}}, 'order': [...], 'raw': {name: sectiontext}}."""
    if not path.exists():
        raise FileNotFoundError(f"spec not found: {path}")
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()

    # Split into sections keyed by their heading title. A heading is a line whose
    # NEXT line is all '=' underline (the spec's section style).
    sections: dict[str, list[str]] = {}
    current: Optional[str] = None
    for i, ln in enumerate(lines):
        underline = i + 1 < len(lines) and set(lines[i + 1].strip()) == {"="} and lines[i + 1].strip()
        if underline:
            # strip a leading "N. " enumerator
            title = re.sub(r"^\d+\.\s*", "", ln.strip()).upper()
            current = title
            sections.setdefault(current, [])
            continue
        if current is not None and set(ln.strip()) == {"="}:
            continue  # the underline line itself
        if current is not None:
            sections[current].append(ln)

    modules: dict[str, dict] = {}
    raw: dict[str, str] = {}
    for title, body in sections.items():
        name = TITLE_TO_NAME.get(title)
        if not name:
            continue
        ports, functions, in_func = [], [], False
        for ln in body:
            s = ln.strip()
            if s.lower().startswith("function"):
                in_func = True
                continue
            m = _PORT_RE.match(s)
            if m:
                in_func = False
                ports.append({
                    "name":  m.group("name"),
                    "dir":   "input" if m.group("dir") == "Input" else "output",
                    "width": _width_from_bus(m.group("bus")),
                    "desc":  m.group("desc").strip(),
                })
            elif in_func and s.startswith("-"):
                functions.append(s.lstrip("- ").strip())
        # de-dup ports by name (spec sometimes lists clk/rst per-section)
        seen, uports = set(), []
        for p in ports:
            if p["name"] in seen:
                continue
            seen.add(p["name"]); uports.append(p)
        modules[name] = {"name": name, "title": title,
                         "functions": functions, "ports": uports}
        raw[title] = "\n".join(body).strip()

    # clk/rst are common to every module but only spelled out once at the top.
    common = [{"name": "clk", "dir": "input", "width": 1, "desc": "clock"},
              {"name": "rst_n", "dir": "input", "width": 1, "desc": "active-low reset"}]
    for name, mod in modules.items():
        if name == "butterfold_top":
            continue
        have = {p["name"] for p in mod["ports"]}
        for c in common:
            if c["name"] not in have:
                mod["ports"].insert(0, dict(c))

    order = [n for n in BUILD_ORDER if n in modules]
    return {"modules": modules, "order": order, "raw": raw}


def port_decl(mod: dict) -> str:
    """Verilog-2012 ANSI port list for a module contract."""
    rows = []
    for p in mod["ports"]:
        w = "" if p["width"] == 1 else f"[{p['width']-1}:0] "
        rows.append(f"    {p['dir']:<6} wire {w}{p['name']}")
    return ",\n".join(rows)


def skeleton(mod: dict) -> str:
    """A compile-clean starting module: correct ports, outputs tied to 0.

    This is the code agent's starting frame AND the no-API-key fallback (it
    elaborates cleanly, so the pipeline still runs end-to-end without an LLM).
    """
    outs = [p for p in mod["ports"] if p["dir"] == "output"]
    tie = "\n".join(
        f"    assign {p['name']} = {'1' if p['width']==1 else p['width']}'b0;"
        for p in outs
    )
    return (f"// {mod['name']} - ports from butterfold_module_io.md ({mod['title']})\n"
            f"// AUTO-GENERATED SKELETON: ports are authoritative; body is a stub.\n"
            f"`default_nettype none\n"
            f"module {mod['name']} (\n{port_decl(mod)}\n);\n\n"
            f"{tie}\n\n"
            f"endmodule\n"
            f"`default_nettype wire\n")


def contract_text(mod: dict) -> str:
    """Human/LLM-readable contract: function + exact port table."""
    lines = [f"MODULE: {mod['name']}   (spec section: {mod['title']})", "", "Function:"]
    lines += [f"  - {f}" for f in mod["functions"]] or ["  (see spec)"]
    lines += ["", "Ports (name : dir : width : description):"]
    for p in mod["ports"]:
        lines.append(f"  - {p['name']} : {p['dir']} : {p['width']}b : {p['desc']}")
    return "\n".join(lines)


if __name__ == "__main__":
    doc = parse()
    print(f"[module_spec] parsed {len(doc['modules'])} modules from {SPEC_PATH.name}")
    for name in doc["order"]:
        m = doc["modules"][name]
        ni = sum(1 for p in m["ports"] if p["dir"] == "input")
        no = sum(1 for p in m["ports"] if p["dir"] == "output")
        print(f"  - {name:<28} {len(m['ports']):>2} ports ({ni} in / {no} out), "
              f"{len(m['functions'])} function bullets")
    print("\n[module_spec] sample skeleton (twiddle_source):\n")
    print(skeleton(doc["modules"]["twiddle_source"]))
