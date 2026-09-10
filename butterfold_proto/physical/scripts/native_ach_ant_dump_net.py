#!/usr/bin/env python3
"""Dump remaining antenna net geometry (SRAM Q[4] / mux I1)."""
from __future__ import annotations

import os
import sys

from openroad import Design, Tech
import odb

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
ODB = os.path.join(PROTO, "physical/results/native_power_ring_ach/ach_ant_routed_ant1.odb")


def main() -> int:
    tech = Tech()
    design = Design(tech)
    design.readDb(ODB)
    block = tech.getDB().getChip().getBlock()
    dbu = block.getDefUnits()
    inst = block.findInst("_17993_")
    iterm = inst.findITerm("I1")
    net = iterm.getNet()
    print(f"NET {net.getName()}")
    print(f"ITERMS {len(list(net.getITerms()))}")
    for t in net.getITerms():
        i = t.getInst()
        bb = i.getBBox()
        print(
            f"  {i.getName()} {i.getMaster().getName()} {t.getMTerm().getName()} "
            f"{bb.xMin()/dbu:.3f} {bb.yMin()/dbu:.3f} {bb.xMax()/dbu:.3f} {bb.yMax()/dbu:.3f}"
        )
    wire = net.getWire()
    print(f"WIRE {wire is not None}")
    layers = {}
    if wire is not None:
        decoder = odb.dbWireDecoder()
        decoder.begin(wire)
        opcode = decoder.peek()
        x = y = 0
        layer = None
        segs = []
        while opcode != odb.dbWireDecoder.END:
            op = decoder.next()
            opcode = decoder.peek() if True else None
            # dbWireDecoder API: use getValue after next
        # fallback: iterate swires + wire paths via getPath
    # Use def dump of boxes through dbWireCodec / getBBox of net
    bb = net.getBBox() if hasattr(net, "getBBox") else None
    if bb:
        print(f"NET_BBOX {bb.xMin()/dbu:.3f} {bb.yMin()/dbu:.3f} {bb.xMax()/dbu:.3f} {bb.yMax()/dbu:.3f}")

    # Walk dbWire via decoder more carefully
    if wire is not None:
        d = odb.dbWireDecoder()
        d.begin(wire)
        cur_layer = None
        px = py = None
        nseg = 0
        m2len = 0.0
        while True:
            op = d.next()
            if op == odb.dbWireDecoder.END:
                break
            if op == odb.dbWireDecoder.PATH or op == odb.dbWireDecoder.SHORT or op == odb.dbWireDecoder.VWIRE:
                cur_layer = d.getTechLayer().getName() if d.getTechLayer() else None
                px = py = None
                continue
            if op == odb.dbWireDecoder.VIA or op == odb.dbWireDecoder.VWIRE:
                via = d.getTechVia() or d.getBlockVia()
                if via:
                    layers[via.getName()] = layers.get(via.getName(), 0) + 1
                px = py = None
                continue
            if op in (odb.dbWireDecoder.POINT, odb.dbWireDecoder.POINT_EXT):
                pt = d.getPoint()
                x, y = pt[0], pt[1]
                if px is not None and cur_layer:
                    dx = abs(x - px) / dbu
                    dy = abs(y - py) / dbu
                    seglen = dx + dy
                    layers[cur_layer] = layers.get(cur_layer, 0.0) + seglen
                    if cur_layer == "Metal2":
                        m2len += seglen
                    nseg += 1
                px, py = x, y
        print(f"SEGMENTS {nseg} M2_LEN_UM {m2len:.1f}")
        for k, v in sorted(layers.items(), key=lambda kv: str(kv[0])):
            print(f"LAYER {k} {v}")
    os._exit(0)


if __name__ == "__main__":
    main()
