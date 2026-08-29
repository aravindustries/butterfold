#!/usr/bin/env python3
"""Build the 23-pin LibreLane FP_DEF_TEMPLATE from official D03/ACH collateral.

The organizer padring DEF (D03_ACH_padring.def) uses pad-slot pin names
(N01, W08, W08_Y, ...) at full-chip coordinates and has no DIEAREA.

The organizer translation (D03_ACH.def) is the user-slot DEF:
  DESIGN D03_ACH
  DIEAREA (0 0) (222000 335000)  # 1110 um x 1675 um at 200 dbu/um
  origin (350 um, 910 um) in the full chip
  135 pins = 23 participant pins plus pad PU/PD/CS/OE/IE/... extras

ButterFold top is core-only with exactly 23 terminals. This script copies
geometry from D03_ACH.def without inventing coordinates:

  input pads  (cell Y) : exact name match (clk, rst_n, din[], din_valid_i)
  output pads (cell A) : din_ready_o_OUT / dout_valid_o_OUT / dout_OUT[n]
  power/ground         : VDD, VSS (all Metal2 abutment rectangles)

Pad-control pins are omitted; the organizer padring ties them.
"""
from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
SRC_DEF = REPO / "D03.def/D03/project_defs/ACH/D03_ACH.def"
OUT_DEF = HERE / "d03_ach_user_template.def"

# Participant pin -> D03_ACH.def pin that carries the core-facing data/power
# terminal (Y for inputs, A/_OUT for bidirectional pads used as outputs).
PIN_MAP = {
    "VSS": "VSS",
    "clk": "clk",
    "rst_n": "rst_n",
    "din_valid_i": "din_valid_i",
    "din[7]": "din[7]",
    "din[6]": "din[6]",
    "din[5]": "din[5]",
    "din[4]": "din[4]",
    "din[3]": "din[3]",
    "din[2]": "din[2]",
    "din[1]": "din[1]",
    "din[0]": "din[0]",
    "din_ready_o": "din_ready_o_OUT",
    "dout_valid_o": "dout_valid_o_OUT",
    "dout[7]": "dout_OUT[7]",
    "dout[6]": "dout_OUT[6]",
    "dout[5]": "dout_OUT[5]",
    "dout[4]": "dout_OUT[4]",
    "dout[3]": "dout_OUT[3]",
    "dout[2]": "dout_OUT[2]",
    "dout[1]": "dout_OUT[1]",
    "dout[0]": "dout_OUT[0]",
    "VDD": "VDD",
}

DIRECTION = {
    "VSS": "INOUT",
    "clk": "INPUT",
    "rst_n": "INPUT",
    "din_valid_i": "INPUT",
    "din[7]": "INPUT",
    "din[6]": "INPUT",
    "din[5]": "INPUT",
    "din[4]": "INPUT",
    "din[3]": "INPUT",
    "din[2]": "INPUT",
    "din[1]": "INPUT",
    "din[0]": "INPUT",
    "din_ready_o": "OUTPUT",
    "dout_valid_o": "OUTPUT",
    "dout[7]": "OUTPUT",
    "dout[6]": "OUTPUT",
    "dout[5]": "OUTPUT",
    "dout[4]": "OUTPUT",
    "dout[3]": "OUTPUT",
    "dout[2]": "OUTPUT",
    "dout[1]": "OUTPUT",
    "dout[0]": "OUTPUT",
    "VDD": "INOUT",
}

USE = {
    "VSS": "GROUND",
    "VDD": "POWER",
}


def parse_pins(text: str) -> dict[str, str]:
    m = re.search(r"^PINS\s+\d+\s*;\n(.*)\nEND PINS", text, re.S | re.M)
    if not m:
        raise SystemExit("PINS section not found in source DEF")
    body = m.group(1)
    pins = {}
    for block in re.split(r"\n(?=- )", body):
        block = block.strip("\n")
        if not block.startswith("- "):
            continue
        name = block.split()[1]
        pins[name] = block
    return pins


def rewrite_block(user_name: str, src_block: str) -> str:
    lines = src_block.splitlines()
    header = lines[0]
    # "- src + NET src + DIRECTION X + USE Y"
    use = USE.get(user_name, "SIGNAL")
    direction = DIRECTION[user_name]
    new_header = (
        f"- {user_name} + NET {user_name} + DIRECTION {direction} + USE {use}"
    )
    # Keep remaining LAYER / FIXED lines verbatim (official geometry).
    rest = "\n".join(lines[1:])
    return new_header + "\n" + rest


def main() -> int:
    if not SRC_DEF.is_file():
        print(f"missing source DEF: {SRC_DEF}", file=sys.stderr)
        return 1
    text = SRC_DEF.read_text()
    src_sha = hashlib.sha256(text.encode()).hexdigest()
    units = re.search(r"^UNITS DISTANCE MICRONS \d+ ;", text, re.M).group(0)
    die = re.search(r"^DIEAREA .*", text, re.M).group(0)
    pins = parse_pins(text)
    missing = [src for src in PIN_MAP.values() if src not in pins]
    if missing:
        print(f"source pins missing: {missing}", file=sys.stderr)
        return 1

    out_pins = []
    for user, src in PIN_MAP.items():
        out_pins.append(rewrite_block(user, pins[src]))

    header = f"""VERSION 5.8 ;
DIVIDERCHAR "/" ;
BUSBITCHARS "[]" ;
DESIGN butterfold_top ;
{units}
{die}
PINS {len(out_pins)} ;
"""
    body = "\n".join(out_pins) + "\nEND PINS\nEND DESIGN\n"
    OUT_DEF.write_text(header + body)
    out_sha = hashlib.sha256(OUT_DEF.read_bytes()).hexdigest()
    print(f"wrote {OUT_DEF}")
    print(f"source SHA-256 {src_sha}")
    print(f"output SHA-256 {out_sha}")
    print(f"pins {len(out_pins)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
