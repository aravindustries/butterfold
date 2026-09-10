#!/usr/bin/env python3
"""Write OpenROAD guides for every signal net from pin/wire bounding boxes."""
from __future__ import annotations

import os

from openroad import Design, Tech

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.path.join(PROTO, "physical/results/native_power_ring_ach/setup_buf_pre_drt.odb")
GUIDE = os.path.join(PROTO, "physical/results/native_power_ring_ach/setup_buf.guide")


def main() -> None:
    tech = Tech()
    design = Design(tech)
    design.readDb(SRC)
    block = tech.getDB().getChip().getBlock()
    pad = 8000
    n = 0
    with open(GUIDE, "w") as f:
        for net in block.getNets():
            st = net.getSigType()
            if st in ("POWER", "GROUND"):
                continue
            xs, ys = [], []
            for it in net.getITerms():
                bb = it.getInst().getBBox()
                xs += [bb.xMin(), bb.xMax()]
                ys += [bb.yMin(), bb.yMax()]
            for bt in net.getBTerms():
                for bp in bt.getBPins():
                    for box in bp.getBoxes():
                        xs += [box.xMin(), box.xMax()]
                        ys += [box.yMin(), box.yMax()]
            w = net.getWire()
            if w is not None:
                try:
                    bb = w.getBBox()
                    xs += [bb.xMin(), bb.xMax()]
                    ys += [bb.yMin(), bb.yMax()]
                except Exception:
                    pass
            if not xs:
                continue
            x1, x2 = min(xs) - pad, max(xs) + pad
            y1, y2 = min(ys) - pad, max(ys) + pad
            name = net.getName()
            f.write(f"{name}\n(\n")
            for layer in ("Metal1", "Metal2", "Metal3", "Metal4", "Metal5"):
                f.write(f"{int(x1)} {int(y1)} {int(x2)} {int(y2)} {layer}\n")
            f.write(")\n")
            n += 1
    open("/tmp/write_guides.txt", "w").write(f"NETS {n} FILE {GUIDE}\n")
    os._exit(0)


if __name__ == "__main__":
    main()
