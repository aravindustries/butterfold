#!/usr/bin/env python3
"""Extract hierarchical metal connectivity from the authoritative GDS.

This is the layout side of the hierarchical-cell LVS flow.  Foundry leaf
cells remain hierarchy boundaries; all routed metal/vias and every connected
leaf pin are extracted from the real GDS using the layer connectivity from
the installed GF180 KLayout deck.
"""

from pathlib import Path
import argparse
import klayout.db as db


METALS = [(34, "metal1"), (36, "metal2"), (42, "metal3"),
          (46, "metal4"), (81, "metal5")]
VIAS = [(35, "via1"), (38, "via2"), (40, "via3"), (41, "via4")]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("gds", type=Path)
    ap.add_argument("output", type=Path)
    ap.add_argument("--top", default="butterfold_padframe_top")
    ap.add_argument("--database", type=Path)
    args = ap.parse_args()

    layout = db.Layout()
    layout.read(str(args.gds))
    top = layout.cell(args.top)
    if top is None:
        raise SystemExit(f"missing GDS top cell: {args.top}")

    iterator = top.begin_shapes_rec(layout.layer(34, 0))
    l2n = db.LayoutToNetlist(iterator)
    l2n.name = "ButterFold GF180 hierarchical interconnect extraction"
    l2n.include_floating_subcircuits = True

    metal_regions = []
    metal_labels = []
    for layer_num, name in METALS:
        draw = l2n.make_polygon_layer(layout.layer(layer_num, 0), name)
        dummy = l2n.make_polygon_layer(layout.layer(layer_num, 4), name + "_dummy")
        combined = draw + dummy
        l2n.register(combined, name + "_conductor")
        labels = l2n.make_text_layer(layout.layer(layer_num, 10), name + "_labels")
        l2n.connect(combined)
        l2n.connect(combined, labels)
        metal_regions.append(combined)
        metal_labels.append(labels)

    via_regions = []
    for layer_num, name in VIAS:
        via = l2n.make_polygon_layer(layout.layer(layer_num, 0), name)
        l2n.connect(via)
        via_regions.append(via)

    for lower, via, upper in zip(metal_regions, via_regions, metal_regions[1:]):
        l2n.connect(lower, via)
        l2n.connect(via, upper)

    l2n.extract_netlist()
    netlist = l2n.netlist()
    netlist.write(str(args.output), db.NetlistSpiceWriter(),
                  "ButterFold GDS hierarchical metal-connectivity netlist")
    if args.database:
        l2n.write(str(args.database))

    circuits = list(netlist.each_circuit())
    top_circuit = netlist.circuit_by_name(args.top)
    if top_circuit is None:
        raise SystemExit("extraction did not produce the requested top circuit")
    print(f"circuits={len(circuits)}")
    print(f"top_pins={top_circuit.pin_count()}")
    print(f"top_nets={top_circuit.net_count()}")
    print(f"top_subcircuits={top_circuit.subcircuit_count()}")


if __name__ == "__main__":
    main()
