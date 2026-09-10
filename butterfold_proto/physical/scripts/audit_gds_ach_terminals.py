#!/usr/bin/env python3
"""Confirm every YAML ACH terminal is physically present in the streamed GDS."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import gdstk
import yaml
from shapely.geometry import Polygon, box
from shapely.strtree import STRtree

# GF180 drawing layers used by the KLayout DEF map for PIN/NET geometry.
LAYER = {
    "Metal1": (34, 0),
    "Metal2": (36, 0),
    "Metal3": (42, 0),
    "Metal4": (46, 0),
    "Metal5": (81, 0),
}
PIN_DT = {
    "Metal1": (34, 10),
    "Metal2": (36, 10),
    "Metal3": (42, 10),
    "Metal4": (46, 10),
    "Metal5": (81, 10),
}
CONTROL_TERMS = {"IE", "OE", "PU", "PD", "CS", "SL", "PDRV0", "PDRV1"}


def collect(cell, layer, datatype):
    geoms = []
    for p in cell.polygons:
        if p.layer == layer and p.datatype == datatype:
            geoms.append(Polygon(p.points))
    for p in cell.paths:
        if p.layers[0] == layer and p.datatypes[0] == datatype:
            geoms.extend(Polygon(q.points) for q in p.to_polygons())
    return geoms


def covers(tree, geoms, region, tol=0.01):
    if region.area <= 0:
        return False
    hits = [geoms[int(i)] for i in tree.query(region)]
    if not hits:
        return False
    covered = region.intersection(hits[0].union_all() if hasattr(hits[0], "union_all") else hits[0])
    # shapely 2: unary union
    from shapely.ops import unary_union
    covered = region.intersection(unary_union(hits))
    return covered.area >= region.area * (1.0 - 1e-6) or region.difference(unary_union(hits)).area <= tol


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("yaml", type=Path)
    ap.add_argument("gds", type=Path)
    ap.add_argument("--json", type=Path)
    args = ap.parse_args()
    spec = yaml.safe_load(args.yaml.read_text())
    pins = spec["pins"]
    lib = gdstk.read_gds(str(args.gds))
    top = next(c for c in lib.top_level() if c.name == "butterfold_top")
    trees = {}
    geoms = {}
    for name, key in {**LAYER, **{f"{k}_pin": v for k, v in PIN_DT.items()}}.items():
        pass
    for lname, (ly, dt) in LAYER.items():
        geoms[lname] = collect(top, ly, dt) + collect(top, *PIN_DT[lname])
        trees[lname] = STRtree(geoms[lname]) if geoms[lname] else None

    missing = []
    present = []
    controls_present = 0
    controls_total = 0
    for entry in pins:
        name = entry["project_pin"]
        term = entry["cell_terminal"]
        ok_any = False
        details = []
        for r in entry["rectangles"]:
            lname = r["routing_layer"]
            x1, y1, x2, y2 = (v / 200.0 for v in r["translated_user"])
            region = box(min(x1, x2), min(y1, y2), max(x1, x2), max(y1, y2))
            tree = trees.get(lname)
            hit = bool(tree is not None and covers(tree, geoms[lname], region))
            details.append({"layer": lname, "um": [x1, y1, x2, y2], "present": hit})
            ok_any = ok_any or hit
        rec = {"project_pin": name, "cell_terminal": term, "present": ok_any, "rects": details}
        if ok_any:
            present.append(rec)
        else:
            missing.append(rec)
        if term in CONTROL_TERMS:
            controls_total += 1
            if ok_any:
                controls_present += 1

    result = {
        "gds": str(args.gds),
        "gds_sha256": hashlib.sha256(args.gds.read_bytes()).hexdigest(),
        "yaml_sha256": hashlib.sha256(args.yaml.read_bytes()).hexdigest(),
        "ach_terminals_yaml": len(pins),
        "ach_terminals_present_in_gds": len(present),
        "ach_terminals_missing_in_gds": [m["project_pin"] for m in missing],
        "required_io_controls": controls_total,
        "io_controls_present_in_gds": controls_present,
        "PASS_135": len(present) == 135 and len(pins) == 135,
        "PASS_102": controls_present == 102 and controls_total == 102,
    }
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    return 0 if result["PASS_135"] and result["PASS_102"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
