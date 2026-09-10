#!/usr/bin/env python3
"""Force a Metal2->Metal3 hop on the remaining SRAM Q[4] antenna net.

Destroy that net's signal wire, block its previous long Metal2 runs, then
leave an ODB for incremental DRT. Uses generated routing obstructions, not
hand-drawn via cuts.
"""
from __future__ import annotations

import os
from collections import defaultdict

from openroad import Design, Tech
import odb

PROTO = "/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC = os.path.join(PROTO, "physical/results/native_power_ring_ach/ach_ant_routed_ant1.odb")
DST = os.path.join(PROTO, "physical/results/native_power_ring_ach/ach_ant_hop.odb")
LOG = os.path.join(PROTO, "physical/results/native_power_ring_ach/logs/ant_hop_prep.log")


def decode_segments(wire, dbu):
    d = odb.dbWireDecoder()
    d.begin(wire)
    cur_layer = None
    px = py = None
    segs = []
    while True:
        op = d.next()
        if op == odb.dbWireDecoder.END_DECODE:
            break
        if op in (odb.dbWireDecoder.PATH, odb.dbWireDecoder.SHORT, odb.dbWireDecoder.VWIRE):
            lyr = d.getLayer()
            cur_layer = lyr.getName() if lyr else None
            px = py = None
            continue
        if op in (odb.dbWireDecoder.VIA, odb.dbWireDecoder.TECH_VIA):
            px = py = None
            continue
        if op in (odb.dbWireDecoder.POINT, odb.dbWireDecoder.POINT_EXT):
            pt = d.getPoint()
            x, y = int(pt[0]), int(pt[1])
            if px is not None and cur_layer:
                segs.append((cur_layer, px, py, x, y))
            px, py = x, y
    return segs


def main() -> None:
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    tech = Tech()
    design = Design(tech)
    design.readDb(SRC)
    block = tech.getDB().getChip().getBlock()
    dbu = block.getDefUnits()
    inst = block.findInst("_17993_")
    net = inst.findITerm("I1").getNet()
    wire = net.getWire()
    segs = decode_segments(wire, dbu)
    lens = defaultdict(float)
    long_m2 = []
    for layer, x1, y1, x2, y2 in segs:
        length = (abs(x2 - x1) + abs(y2 - y1)) / dbu
        lens[layer] += length
        if layer == "Metal2" and length >= 20.0:
            long_m2.append((x1, y1, x2, y2, length))
    lines = [
        f"NET {net.getName()}",
        f"SEGMENTS {len(segs)}",
        f"LONG_M2 {len(long_m2)}",
    ]
    for k, v in sorted(lens.items()):
        lines.append(f"LEN {k} {v:.1f}")
    for s in long_m2:
        lines.append(f"M2 {s[0]/dbu:.3f} {s[1]/dbu:.3f} {s[2]/dbu:.3f} {s[3]/dbu:.3f} len={s[4]:.1f}")

    # Temporary Metal2 keepouts are applied in Tcl around these boxes so they
    # never persist into the streamed GDS.
    coord_path = os.path.join(
        PROTO, "physical/results/native_power_ring_ach/logs/ant_hop_m2_obs.tcl"
    )
    hw = int(round(0.22 * dbu))
    end_keep = int(round(8.0 * dbu))
    obs_cmds = ["# generated hop keepouts; destroyed after DRT", "set ::hop_obs {}"]
    created = 0
    for x1, y1, x2, y2, length in long_m2:
        if x1 == x2:
            ylo, yhi = sorted((y1, y2))
            ylo += end_keep
            yhi -= end_keep
            if yhi - ylo < 4 * dbu:
                continue
            ox1, oy1, ox2, oy2 = x1 - hw, ylo, x2 + hw, yhi
        elif y1 == y2:
            xlo, xhi = sorted((x1, x2))
            xlo += end_keep
            xhi -= end_keep
            if xhi - xlo < 4 * dbu:
                continue
            ox1, oy1, ox2, oy2 = xlo, y1 - hw, xhi, y2 + hw
        else:
            continue
        obs_cmds.append(
            f"lappend ::hop_obs [odb::dbObstruction_create $block $m2 {ox1} {oy1} {ox2} {oy2}]"
        )
        created += 1
    obs_cmds.append(f'puts "HOP_OBS {created}"')
    open(coord_path, "w").write("\n".join(obs_cmds) + "\n")
    lines.append(f"OBS_TCL {created} {coord_path}")
    odb.dbWire.destroy(wire)
    lines.append("DESTROYED_WIRE")
    design.writeDb(DST)
    lines.append(f"WROTE {DST}")
    open(LOG, "w").write("\n".join(lines) + "\n")
    open("/tmp/ant_hop_prep.txt", "w").write("\n".join(lines) + "\n")
    os._exit(0)


if __name__ == "__main__":
    main()
