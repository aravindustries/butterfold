#!/usr/bin/env python3
"""Add GRT-style bbox guides for unrouted ACH tie nets. Keep existing wires."""
from __future__ import annotations

import os

from openroad import Design, Tech
import odb

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.environ.get(
    "GUIDE_SRC",
    PROTO + "/physical/results/native_power_ring_ach/predrt/applied_m3cut.odb",
)
DST = os.environ.get(
    "GUIDE_DST",
    PROTO + "/physical/results/native_power_ring_ach/predrt/applied_m3cut_guided.odb",
)
LOG = os.environ.get(
    "GUIDE_LOG",
    PROTO + "/physical/results/native_power_ring_ach/predrt/add_ach_guides.log",
)


def collect_xy(net):
    xs, ys = [], []
    for it in net.getITerms():
        bb = it.getInst().getBBox()
        xs += [bb.xMin(), bb.xMax()]
        ys += [bb.yMin(), bb.yMax()]
        try:
            avg = it.getAvgXY()
            if avg is not None:
                xs.append(int(avg[0]))
                ys.append(int(avg[1]))
        except Exception:
            pass
    for bt in net.getBTerms():
        for pin in bt.getBPins():
            boxes = []
            try:
                boxes = list(pin.getBoxes())
            except Exception:
                try:
                    boxes = [pin.getBBox()]
                except Exception:
                    boxes = []
            for box in boxes:
                xs += [box.xMin(), box.xMax()]
                ys += [box.yMin(), box.yMax()]
    return xs, ys


def main() -> None:
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    tech = Tech()
    design = Design(tech)
    design.readDb(SRC)
    db = tech.getDB()
    block = db.getChip().getBlock()
    dbtech = db.getTech()
    layers = [dbtech.findLayer(n) for n in ("Metal2", "Metal3", "Metal4", "Metal5")]
    layers = [l for l in layers if l is not None]
    via_for = {
        "Metal2": dbtech.findLayer("Via2"),
        "Metal3": dbtech.findLayer("Via3"),
        "Metal4": dbtech.findLayer("Via4"),
        "Metal5": dbtech.findLayer("Via4"),
    }
    dbu = block.getDefUnits()
    pad = int(8.0 * dbu)
    die = block.getDieArea()

    targets = []
    for net in block.getNets():
        name = net.getName()
        if net.getSigType() in ("POWER", "GROUND"):
            continue
        if net.getWire() is not None:
            continue
        if not (name.startswith("ach_") or name.endswith("_IN") or name.endswith("_tie0") or name.endswith("_tie1")):
            # still include any remaining unrouted signal nets that have a BTerm
            if not net.getBTerms():
                continue
        targets.append(net)

    created = 0
    lines = [f"SRC {SRC}", f"UNROUTED_CANDIDATES {len(targets)}"]
    for net in targets:
        xs, ys = collect_xy(net)
        if not xs:
            lines.append(f"SKIP_NO_GEOM {net.getName()}")
            continue
        x1 = max(die.xMin(), min(xs) - pad)
        x2 = min(die.xMax(), max(xs) + pad)
        y1 = max(die.yMin(), min(ys) - pad)
        y2 = min(die.yMax(), max(ys) + pad)
        if x2 <= x1 or y2 <= y1:
            lines.append(f"SKIP_BAD_BOX {net.getName()} {x1} {y1} {x2} {y2}")
            continue
        rect = odb.Rect(int(x1), int(y1), int(x2), int(y2))
        n_ok = 0
        for layer in layers:
            try:
                via = via_for.get(layer.getName())
                odb.dbGuide.create(net, layer, via, rect, False)
                created += 1
                n_ok += 1
            except Exception as e:
                lines.append(f"GUIDE_FAIL {net.getName()} {layer.getName()} {e}")
                break
        lines.append(f"GUIDE {net.getName()} layers={n_ok} {x1} {y1} {x2} {y2}")

    still = sum(1 for n in block.getNets() if n.getSigType() not in ("POWER", "GROUND") and n.getWire() is None)
    lines.append(f"GUIDES_CREATED {created}")
    lines.append(f"SIGNAL_UNROUTED_AFTER_GUIDES {still}")
    design.writeDb(DST)
    lines.append(f"WROTE {DST}")
    text = "\n".join(lines) + "\n"
    open(LOG, "w").write(text)
    open("/tmp/add_ach_guides.txt", "w").write(text)
    os._exit(0)


if __name__ == "__main__":
    main()
