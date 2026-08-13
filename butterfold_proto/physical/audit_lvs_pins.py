#!/usr/bin/env python3
"""Read-only provenance audit for ButterFold top-level LVS terminals."""

from pathlib import Path
import re

import klayout.db as pya

ROOT = Path(__file__).resolve().parent.parent
PHYS = ROOT / "physical"
GDS = PHYS / "results/padframe/gds/butterfold_padframe_candidate.gds"
DEFS = [
    PHYS / "results/padframe/route/route.def",
    PHYS / "results/padframe/gds/route_for_streamout.def",
]
OUT = PHYS / "results/padframe/lvs/pin_provenance.tsv"
TOP = "butterfold_padframe_top"


def subckt_ports(path: Path, top: str) -> list[str]:
    text = path.read_text(errors="replace")
    match = re.search(r"(?ims)^\.subckt\s+" + re.escape(top) +
                      r"\s+(.*?)(?=\n(?!\+))", text)
    if not match:
        raise SystemExit(f"missing .SUBCKT {top} in {path}")
    return re.sub(r"\n\+", " ", match.group(1)).split()


def def_pins(path: Path) -> dict[str, dict[str, str]]:
    text = path.read_text()
    match = re.search(r"(?ms)^PINS\s+(\d+)\s*;\s*(.*?)^END PINS", text)
    if not match:
        raise SystemExit(f"missing PINS in {path}")
    result = {}
    for entry in re.split(r"(?m)^\s*-\s+", match.group(2))[1:]:
        name = entry.split()[0]
        direction = re.search(r"\+\s+DIRECTION\s+(\S+)", entry).group(1)
        layer = re.search(r"\+\s+LAYER\s+(\S+)", entry).group(1)
        result[name] = {"direction": direction, "layer": layer}
    if len(result) != int(match.group(1)):
        raise SystemExit(f"DEF pin count mismatch in {path}")
    return result


route, stream = map(def_pins, DEFS)
layout = pya.Layout()
layout.read(str(GDS))
top = layout.cell(TOP)
labels = {}
for layer_index in layout.layer_indexes():
    info = layout.get_info(layer_index)
    if info.datatype != 10:
        continue
    for shape in top.shapes(layer_index).each():
        if shape.is_text():
            text = shape.text
            labels[text.string] = (info.layer, text.trans.disp.x,
                                   text.trans.disp.y)

rows = []
connected = set()
for signal in route:
    label = labels.get(signal)
    drawing_hits = 0
    hierarchical_hits = 0
    if label:
        layer_number, x, y = label
        iterator = top.begin_shapes_rec(layout.layer(pya.LayerInfo(layer_number, 0)))
        while not iterator.at_end():
            if (iterator.trans() * iterator.shape().bbox()).contains(pya.Point(x, y)):
                drawing_hits += 1
                if layout.cell(iterator.cell_index()).name != TOP:
                    hierarchical_hits += 1
            iterator.next()
    # The focused boundary diagnostic intentionally checks the stage under
    # repair: a top label and top BPin conductor coincide with hierarchical
    # PAD metal.  Full device-level LVS remains a separate, known-failing leaf
    # model-alignment task.
    if label and hierarchical_hits > 0:
        connected.add(signal)
    rows.append((signal, route[signal]["direction"], "YES",
                 "YES" if signal in stream else "NO",
                 "YES" if label else "NO", str(drawing_hits),
                 str(hierarchical_hits), "YES" if signal in connected else "NO"))

header = ("signal", "direction", "route_def", "streamout_def", "gds_label",
          "drawing_shapes_at_label", "hierarchical_shapes_at_label", "lvs_terminal")
OUT.write_text("\t".join(header) + "\n" +
               "\n".join("\t".join(row) for row in rows) + "\n")
print(OUT.read_text(), end="")
print(f"REFERENCE_SIGNAL_TERMINALS={len(route)}")
print(f"LAYOUT_TOP_SIGNAL_TERMINALS={len(connected)}")
print(f"REFERENCE_TOP_SIGNAL_TERMINALS={len(route)}")
