#!/usr/bin/env python3
"""Compare applied BTERM geometry against the ACH_VALIDATION_ONLY template.

Usage:
  verify_d03_ach_template_pins.py <applied.def> [template.def]
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_TEMPLATE = HERE / "d03_ach_user_template.def"

FUNCTIONAL = [
    "clk",
    "rst_n",
    "din_valid_i",
    *[f"din[{i}]" for i in range(8)],
    "din_ready_o",
    "dout_valid_o",
    *[f"dout[{i}]" for i in range(8)],
]
PG = ["VDD", "VSS"]
EXPECTED = FUNCTIONAL + PG


def parse_pins(text: str) -> dict[str, dict]:
    m = re.search(r"^PINS\s+\d+\s*;\n(.*)\nEND PINS", text, re.S | re.M)
    if not m:
        raise SystemExit("PINS section not found")
    pins = {}
    for block in re.split(r"\n(?=- )", m.group(1)):
        block = block.strip("\n")
        if not block.startswith("- "):
            continue
        name = block.split()[1]
        direction = None
        use = None
        dm = re.search(r"\+ DIRECTION (\S+)", block)
        um = re.search(r"\+ USE (\S+)", block)
        if dm:
            direction = dm.group(1)
        if um:
            use = um.group(1)
        boxes = []
        for line in block.splitlines():
            lm = re.search(
                r"\+ LAYER (\S+) \( ([-\d]+) ([-\d]+) \) \( ([-\d]+) ([-\d]+) \)",
                line,
            )
            if lm:
                boxes.append(
                    (
                        lm.group(1),
                        int(lm.group(2)),
                        int(lm.group(3)),
                        int(lm.group(4)),
                        int(lm.group(5)),
                    )
                )
        pins[name] = {
            "direction": direction,
            "use": use,
            "boxes": tuple(boxes),
        }
    return pins


def diearea(text: str):
    m = re.search(
        r"^DIEAREA \( ([-\d]+) ([-\d]+) \) \( ([-\d]+) ([-\d]+) \)", text, re.M
    )
    if not m:
        return None
    return tuple(int(x) for x in m.groups())


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: verify_d03_ach_template_pins.py <applied.def> [template.def]")
        return 2
    applied_path = Path(sys.argv[1])
    template_path = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_TEMPLATE
    applied = applied_path.read_text()
    template = template_path.read_text()
    ap = parse_pins(applied)
    tp = parse_pins(template)
    print(f"applied {applied_path}")
    print(f"template {template_path}")
    print(f"applied_die {diearea(applied)}")
    print(f"template_die {diearea(template)}")
    print(f"applied_bterms {len(ap)}")
    print(f"template_bterms {len(tp)}")

    missing = [n for n in EXPECTED if n not in ap]
    extra_expected = [n for n in ap if n in EXPECTED]
    print(f"expected_present {len(extra_expected)}/{len(EXPECTED)}")
    if missing:
        print("MISSING", missing)

    func_ok = 0
    for name in FUNCTIONAL:
        if name not in ap or name not in tp:
            print(f"FAIL {name} missing")
            continue
        if ap[name]["boxes"] == tp[name]["boxes"]:
            func_ok += 1
            print(
                f"MATCH {name} dir={ap[name]['direction']} layer={ap[name]['boxes'][0][0]} boxes={ap[name]['boxes']}"
            )
        else:
            print(f"MISMATCH {name}")
            print(f"  applied  {ap[name]['boxes']}")
            print(f"  template {tp[name]['boxes']}")

    pg_ok = True
    for name in PG:
        if name not in ap or name not in tp:
            print(f"FAIL {name} missing")
            pg_ok = False
            continue
        if ap[name]["boxes"] == tp[name]["boxes"]:
            print(f"MATCH {name} boxes={ap[name]['boxes']}")
        else:
            print(f"MISMATCH {name}")
            print(f"  applied  {ap[name]['boxes']}")
            print(f"  template {tp[name]['boxes']}")
            pg_ok = False

    print(f"FUNCTIONAL_MATCH {func_ok}/{len(FUNCTIONAL)}")
    print(f"PG_MATCH {pg_ok}")
    print(f"BTERM_EXPECTED {len(EXPECTED)}")
    return 0 if func_ok == len(FUNCTIONAL) and pg_ok and not missing else 1


if __name__ == "__main__":
    raise SystemExit(main())
