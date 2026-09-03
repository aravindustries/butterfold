#!/usr/bin/env python3
"""Audit top-level final-GDS Metal2 against authoritative organizer ports."""
from __future__ import annotations

import argparse, hashlib, json, re
from pathlib import Path
import gdstk
from shapely.geometry import Polygon, box
from shapely.strtree import STRtree

RULE_UM = 0.280  # GF180 M2.2a
def ports(path: Path):
    text = path.read_text()
    units = int(re.search(r"UNITS DISTANCE MICRONS (\d+)", text).group(1))
    section = re.search(r"^PINS\s+\d+\s*;\n(.*?)\nEND PINS", text, re.S | re.M).group(1)
    answer = []
    for block in re.split(r"\n(?=- )", section):
        head = re.match(r"-\s+(\S+).*?\+\s+NET\s+(\S+)", block, re.S)
        if not head: continue
        for hit in re.finditer(r"\+\s+LAYER\s+(\S+)\s+\(\s*(-?\d+)\s+(-?\d+)\s*\)\s+\(\s*(-?\d+)\s+(-?\d+)\s*\)", block):
            if hit.group(1) != "Metal2": continue
            coords = [int(hit.group(i)) / units for i in range(2, 6)]
            answer.append((head.group(1), head.group(2), coords, box(*coords)))
    return answer

def shapes(path: Path):
    lib = gdstk.read_gds(str(path))
    top = next(c for c in lib.top_level() if c.name == "butterfold_top")
    result = []
    for p in top.polygons:
        if p.layer == 36 and p.datatype == 0: result.append(Polygon(p.points))
    for p in top.paths:
        if p.layers[0] == 36 and p.datatypes[0] == 0:
            result.extend(Polygon(q.points) for q in p.to_polygons())
    return result

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("organizer_def", type=Path)
    ap.add_argument("gds", type=Path)
    ap.add_argument("--json", type=Path)
    args = ap.parse_args()
    pp, gg = ports(args.organizer_def), shapes(args.gds)
    tree = STRtree(gg)
    violations = []
    minimums = {}
    for name, net, bbox, region in pp:
        # The final ACH shell contains every YAML-defined terminal.  Recover
        # the terminal's net geometry from the exact GDS by following only
        # zero-distance Metal2 connectivity from its PORT rectangle.  All
        # other Metal2 remains unrelated and must meet M2.2a.
        connected = set(int(i) for i in tree.query(region) if gg[int(i)].intersects(region))
        frontier = list(connected)
        while frontier:
            current = gg[frontier.pop()]
            for candidate in tree.query(current):
                idx = int(candidate)
                if idx not in connected and gg[idx].intersects(current):
                    connected.add(idx)
                    frontier.append(idx)
        best = None
        for idx in tree.query(region.buffer(2.0)):
            idx = int(idx)
            geom = gg[idx]
            if idx in connected:
                continue
            distance = region.distance(geom)
            best = distance if best is None else min(best, distance)
            if distance < RULE_UM - 1e-9:
                violations.append({"pin": name, "net": net, "pin_bbox_um": bbox,
                    "metal_bbox_um": list(geom.bounds), "spacing_um": distance,
                    "required_um": RULE_UM})
        minimums[name] = best
    result = {
        "gds": str(args.gds),
        "gds_sha256": hashlib.sha256(args.gds.read_bytes()).hexdigest(),
        "rule": "GF180 M2.2a", "required_spacing_um": RULE_UM,
        "pad_pin_spacing_regions_checked": len(pp),
        "metal2_top_level_shapes_checked": len(gg),
        "pad_pin_spacing_violations": len(violations),
        "minimum_unrelated_spacing_um": minimums,
        "violations": violations,
    }
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    raise SystemExit(bool(violations))

if __name__ == "__main__": main()
