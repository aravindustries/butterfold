#!/usr/bin/env python3
"""
Generate padframe_pad_positions.generated.tcl from the official ACH pad map.

Source of truth for WHICH signal goes on WHICH side, in WHICH order:
    D03.def/D03/project_defs/ACH/D03_ACH_pad_map.yaml   (read-only, never modified)

Source of truth for the per-pad PLACEMENT COORDINATES:
    This script's own PITCH_UM / START_UM constants below.
    NOTE: the official D03_ACH_padring.def encodes absolute coordinates for
    the full ~2580-2935um multi-project ACH die. Our local team-side mock
    padframe (see padframe_config.tcl: die_w = die_h = 2235.0um) is a
    different, smaller die used only for our own timing/DRC/LVS signoff, so
    those absolute coordinates do NOT carry over. What DOES carry over from
    the real DEF is the real pad-to-pad pitch (measured at 100um between
    consecutive io cells on this IO library, vs. the 75um previously assumed
    in the hand-written version of this file) -- that reflects the physical
    width of the gf180mcu IO cell masters, not the die size, so it is kept.

Emits, for consumption by padframe_place_pads.tcl and
padframe_connect_static_controls.tcl:
    PAD_WEST_LIST / PAD_NORTH_LIST   -- {inst location} pairs for place_pad
    PAD_WEST_OCCUPIED / PAD_NORTH_OCCUPIED  -- fill-exclusion ranges
    PAD_TIE_INFO                     -- inst -> {side location}, so the
                                         static-controls tie cells can be
                                         placed near whichever row (west or
                                         north) the pad actually ended up on

Re-run this any time D03_ACH_pad_map.yaml changes. Do not hand-edit the
generated .tcl output.
"""
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
SRC_YAML = REPO / "D03.def/D03/project_defs/ACH/D03_ACH_pad_map.yaml"
OUT_TCL = HERE / "padframe_pad_positions.generated.tcl"

# Local floorplan parameters (ours to choose; die is 2235 x 2235um per
# padframe_config.tcl). Kept identical in spirit to the previous hand-written
# script's origin (500um) so existing corner/margin clearance assumptions
# still hold; pitch corrected to match the real IO cell footprint (100um).
START_UM = 500.0
PITCH_UM = 75.0      # pad cell width: pads abut, matching the original
                     # padframe_place_pads.tcl.  The IO rows on this 2235um
                     # die are only 355..1855um (1500um) long, so the 100um
                     # pitch of the full-size ACH die does not fit here.
PAD_WIDTH_UM = 75.0   # approx, measured from real DEF cell-to-fill spacing
MARGIN_UM = 0.0       # match original occupied-range convention exactly

# Row abstraction coordinates used elsewhere in the flow (manual_fill_side in
# padframe_place_pads.tcl): west row sits at x=350, north row at y=2235.
WEST_ROW_X = 350.0
NORTH_ROW_Y = 2235.0

NAME_OVERRIDES = {
    "VSS": "u_pad_dvss",
    "VDD": "u_pad_dvdd",
    "clk": "u_pad_clk",
    "rst_n": "u_pad_rst_n",
    "din_valid_i": "u_pad_din_valid",
    "din_ready_o": "u_pad_din_ready",
    "dout_valid_o": "u_pad_dout_valid",
}
BUS_RE = re.compile(r"^(din|dout)\[(\d+)\]$")


def pad_instance_name(pin_name):
    if pin_name in NAME_OVERRIDES:
        return NAME_OVERRIDES[pin_name]
    m = BUS_RE.match(pin_name)
    if m:
        return f"u_pad_{m.group(1)}{m.group(2)}"
    raise ValueError(f"no naming rule for pin {pin_name!r}")


def parse_pad_map(path):
    """Minimal parser for this file's specific YAML shape (list of flat
    dict entries under 'pads:', each entry ending at the next '- ' at the
    same indent). No external yaml dependency required."""
    entries = []
    cur = None
    in_pads = False
    for raw in path.read_text().splitlines():
        if raw.startswith("pads:"):
            in_pads = True
            continue
        if raw.startswith("breaks:"):
            break
        if not in_pads:
            continue
        m = re.match(r"^-\s+(\w+):\s*(\S.*)$", raw)
        if m:
            if cur is not None:
                entries.append(cur)
            cur = {m.group(1): m.group(2)}
            continue
        m = re.match(r"^\s+(\w+):\s*(\S.*)$", raw)
        if m and cur is not None:
            cur[m.group(1)] = m.group(2)
    if cur is not None:
        entries.append(cur)
    return entries


def main():
    entries = parse_pad_map(SRC_YAML)
    west, north = [], []
    for e in entries:
        slot = e.get("slot", "")
        pin_name = e.get("pin_name")
        if pin_name is None:
            continue  # generated filler slot (N08-N11), not a real signal
        inst = pad_instance_name(pin_name)
        if slot.startswith("W"):
            west.append((slot, pin_name, inst))
        elif slot.startswith("N"):
            north.append((slot, pin_name, inst))
        else:
            raise ValueError(f"unexpected slot side for {pin_name!r}: {slot!r}")

    west.sort(key=lambda r: int(r[0][1:]))
    north.sort(key=lambda r: int(r[0][1:]))

    def loc(i):
        return START_UM + i * PITCH_UM

    lines = []
    lines.append("# AUTO-GENERATED by gen_pad_positions.py -- do not hand-edit.")
    lines.append(f"# Source: {SRC_YAML.relative_to(REPO)}")
    lines.append("# Re-run gen_pad_positions.py if that file changes.")
    lines.append("")
    # NOTE: emit via lappend, not a braced literal.  Inside {...} Tcl does not
    # honour ;# as a comment, so annotations would become list elements and
    # place_pad -location would receive garbage.
    lines.append("set PAD_WEST_LIST {}")
    for i, (slot, pin_name, inst) in enumerate(west):
        lines.append(f"lappend PAD_WEST_LIST {{{inst} {loc(i):.1f}}}  ;# {slot} = {pin_name}")
    lines.append("")
    lines.append("set PAD_NORTH_LIST {}")
    for i, (slot, pin_name, inst) in enumerate(north):
        lines.append(f"lappend PAD_NORTH_LIST {{{inst} {loc(i):.1f}}}  ;# {slot} = {pin_name}")
    lines.append("")

    # The IO rows created by make_io_sites on this die run 355..1855um.  Any
    # pad whose extent leaves that window is rejected by place_pad (PAD-0119),
    # so fail loudly here instead of producing a file that dies mid-flow.
    ROW_LO, ROW_HI = 355.0, 1855.0
    for label, pads in (("WEST", west), ("NORTH", north)):
        if not pads:
            continue
        lo = loc(0)
        hi = loc(len(pads) - 1) + PAD_WIDTH_UM
        if lo < ROW_LO or hi > ROW_HI:
            raise SystemExit(
                f"{label} row overflow: {len(pads)} pads at pitch {PITCH_UM}um "
                f"from {START_UM}um span {lo}..{hi}um, "
                f"but the IO row is only {ROW_LO}..{ROW_HI}um. "
                f"Max pitch for {len(pads)} pads is "
                f"{(ROW_HI - ROW_LO - PAD_WIDTH_UM) / (len(pads) - 1):.1f}um.")

    w_lo = loc(0) - MARGIN_UM
    w_hi = loc(len(west) - 1) + PAD_WIDTH_UM + MARGIN_UM
    n_lo = loc(0) - MARGIN_UM
    n_hi = loc(len(north) - 1) + PAD_WIDTH_UM + MARGIN_UM
    lines.append(f"set PAD_WEST_OCCUPIED  {{{{{w_lo:.1f} {w_hi:.1f}}}}}")
    lines.append(f"set PAD_NORTH_OCCUPIED {{{{{n_lo:.1f} {n_hi:.1f}}}}}")
    lines.append("")

    # Per-pad side + row-location lookup, so any downstream script that
    # needs to place something near a pad's row (e.g. a static-control tie
    # cell) can compute a correct nearby x/y regardless of which edge that
    # pad ended up on.
    lines.append("array set PAD_TIE_INFO {")
    for i, (slot, pin_name, inst) in enumerate(west):
        lines.append(f"  {inst} {{W {loc(i):.1f}}}")
    for i, (slot, pin_name, inst) in enumerate(north):
        lines.append(f"  {inst} {{N {loc(i):.1f}}}")
    lines.append("}")
    lines.append(f"set PAD_WEST_ROW_X {WEST_ROW_X}")
    lines.append(f"set PAD_NORTH_ROW_Y {NORTH_ROW_Y}")
    lines.append("")

    OUT_TCL.write_text("\n".join(lines) + "\n")
    print(f"wrote {OUT_TCL} ({len(west)} west, {len(north)} north)")


if __name__ == "__main__":
    main()
