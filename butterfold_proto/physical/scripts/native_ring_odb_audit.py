#!/usr/bin/env python3
"""Audit native-ring ODB: ring geometry, ACH pins, generated vias, PG cuts."""
from __future__ import annotations

import json
import os
import sys

from openroad import Design, Tech
import odb


def um(dbu, v):
    return v / dbu


def pin_boxes(block, name):
    bt = block.findBTerm(name)
    if bt is None:
        return []
    out = []
    for bp in bt.getBPins():
        for box in bp.getBoxes():
            layer = box.getTechLayer()
            out.append(
                {
                    "layer": layer.getName() if layer else None,
                    "x1": box.xMin(),
                    "y1": box.yMin(),
                    "x2": box.xMax(),
                    "y2": box.yMax(),
                }
            )
    return out


def special_rects(net, layer_name=None):
    out = []
    for sw in net.getSWires():
        for box in sw.getWires():
            via = box.getTechVia() or box.getBlockVia()
            if via:
                continue
            layer = box.getTechLayer()
            if layer is None:
                continue
            if layer_name and layer.getName() != layer_name:
                continue
            out.append((layer.getName(), box.xMin(), box.yMin(), box.xMax(), box.yMax()))
    return out


def via_stats(net):
    tech = {}
    block = {}
    cuts = []
    for sw in net.getSWires():
        for box in sw.getWires():
            tv = box.getTechVia()
            bv = box.getBlockVia()
            via = tv or bv
            if via is None:
                continue
            name = via.getName()
            key = "tech" if tv else "block"
            d = tech if tv else block
            d[name] = d.get(name, 0) + 1
            cuts.append((key, name, box.xMin(), box.yMin(), box.xMax(), box.yMax()))
    return tech, block, cuts


def classify_ring(rects, dbu, core):
    """Pick long closed-loop candidates near the core boundary."""
    cx1, cy1, cx2, cy2 = core
    horiz = []
    vert = []
    for layer, x1, y1, x2, y2 in rects:
        w = um(dbu, x2 - x1)
        h = um(dbu, y2 - y1)
        if w >= 200 and 1.2 <= h <= 4.0:
            horiz.append((layer, um(dbu, x1), um(dbu, y1), um(dbu, x2), um(dbu, y2), w, h))
        if h >= 200 and 1.2 <= w <= 4.0:
            vert.append((layer, um(dbu, x1), um(dbu, y1), um(dbu, x2), um(dbu, y2), w, h))
    return {"horiz": sorted(horiz, key=lambda b: b[2]), "vert": sorted(vert, key=lambda b: b[1])}


def main() -> int:
    src = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("ECO_SRC")
    if not src:
        print("usage: native_ring_odb_audit.py <odb>")
        return 2
    tech = Tech()
    design = Design(tech)
    design.readDb(src)
    db = tech.getDB()
    block = db.getChip().getBlock()
    dbu = block.getDefUnits()
    core = block.getCoreArea()
    die = block.getDieArea()
    core_t = (core.xMin(), core.yMin(), core.xMax(), core.yMax())
    report = {
        "odb": src,
        "dbu": dbu,
        "die_um": [um(dbu, die.xMin()), um(dbu, die.yMin()), um(dbu, die.xMax()), um(dbu, die.yMax())],
        "core_um": [um(dbu, core.xMin()), um(dbu, core.yMin()), um(dbu, core.xMax()), um(dbu, core.yMax())],
        "bterms": sorted(bt.getName() for bt in block.getBTerms()),
        "bterm_count": len(list(block.getBTerms())),
    }
    vias_block = sorted(v.getName() for v in block.getVias())
    vias_tech = sorted(v.getName() for v in db.getTech().getVias())
    report["block_vias"] = vias_block
    report["tech_vias"] = vias_tech

    for net_name in ("VDD", "VSS"):
        net = block.findNet(net_name)
        rects = special_rects(net)
        tvia, bvia, cuts = via_stats(net)
        pins = pin_boxes(block, net_name)
        report[net_name] = {
            "pin_boxes": [
                {
                    "layer": p["layer"],
                    "um": [um(dbu, p["x1"]), um(dbu, p["y1"]), um(dbu, p["x2"]), um(dbu, p["y2"])],
                }
                for p in pins
            ],
            "special_rect_count": len(rects),
            "tech_via_counts": tvia,
            "block_via_counts": bvia,
            "via_instance_count": len(cuts),
            "ring": classify_ring(rects, dbu, core_t),
        }
        # min cut count among generated arrays
        min_cuts = None
        for name, n in {**tvia, **bvia}.items():
            # parse trailing _R_C if present
            parts = name.split("_")
            # via4_5_3200_3200_3_3_1040_1040 -> 3*3=9
            cuts_n = None
            if len(parts) >= 6 and parts[4].isdigit() and parts[5].isdigit():
                cuts_n = int(parts[4]) * int(parts[5])
            if cuts_n is not None:
                min_cuts = cuts_n if min_cuts is None else min(min_cuts, cuts_n)
        report[net_name]["min_parsed_array_cuts"] = min_cuts
        report[net_name]["single_cut_tech_vias"] = {
            k: v for k, v in tvia.items() if k.endswith("_VV") or "1_1" in k
        }

    out = sys.argv[2] if len(sys.argv) > 2 else None
    text = json.dumps(report, indent=2)
    print(text[:15000])
    if out:
        open(out, "w").write(text + "\n")
        print("WROTE", out)
    return 0


if __name__ == "__main__":
    rc = main()
    if rc:
        os._exit(rc)
