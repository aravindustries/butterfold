#!/usr/bin/env python3
"""Exact Metal2 ∩ organizer keep-out audit using gdstk."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import gdstk

# Organizer D03_ACH.def BLOCKAGES, UNITS 200 dbu/µm:
#   - LAYER Metal2 + RECT ( 0 0 ) ( 400 13000 ) ;
KEEPOUTS_UM = [
    {
        "id": 0,
        "layer": "Metal2",
        "dbu": [0, 0, 400, 13000],
        "um": [0.0, 0.0, 2.0, 65.0],
        "units_distance_microns": 200,
    }
]

M2_LAYERS = {
    "Metal2_draw": (36, 0),
    "Metal2_slot": (36, 3),
    "Metal2_dummy": (36, 4),
    "Metal2_blk": (36, 5),
    "Metal2_label": (36, 10),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def audit(gds_path: Path) -> dict:
    lib = gdstk.read_gds(str(gds_path))
    tops = [c for c in lib.top_level() if c.name == "butterfold_top"]
    cell = tops[0] if tops else lib.top_level()[0]
    flat = cell.copy("m2_audit_flat")
    flat.flatten()
    bbox = cell.bounding_box()
    regions = []
    total_polys = 0
    total_area = 0.0
    violating = 0
    for ko in KEEPOUTS_UM:
        x1, y1, x2, y2 = ko["um"]
        keep = gdstk.rectangle((x1, y1), (x2, y2))
        per_layer = {}
        region_polys = 0
        region_area = 0.0
        for lname, ld in M2_LAYERS.items():
            hits = []
            for p in flat.get_polygons(layer=ld[0], datatype=ld[1]):
                for q in gdstk.boolean(p, keep, "and") or []:
                    a = float(q.area())
                    bb = q.bounding_box()
                    hits.append(
                        {
                            "bbox_um": [bb[0][0], bb[0][1], bb[1][0], bb[1][1]],
                            "area_um2": a,
                        }
                    )
                    region_area += a
                    region_polys += 1
            per_layer[lname] = {"intersect_polygons": len(hits), "hits": hits}
        if region_polys:
            violating += 1
        total_polys += region_polys
        total_area += region_area
        regions.append(
            {
                **ko,
                "intersect_polygons": region_polys,
                "intersect_area_um2": region_area,
                "layers": per_layer,
            }
        )
    return {
        "gds": str(gds_path),
        "gds_sha256": sha256(gds_path),
        "bbox_um": None if bbox is None else [bbox[0][0], bbox[0][1], bbox[1][0], bbox[1][1]],
        "regions_checked": len(KEEPOUTS_UM),
        "violating_regions": violating,
        "intersect_polygons": total_polys,
        "intersect_area_um2": total_area,
        "regions": regions,
        "pass": violating == 0 and total_polys == 0 and total_area == 0.0,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("gds")
    ap.add_argument("-o", "--output", required=True)
    args = ap.parse_args()
    gds = Path(args.gds)
    result = audit(gds)
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2) + "\n")
    print(f"GDS {result['gds_sha256']}")
    print(f"REGIONS {result['regions_checked']}")
    print(f"VIOLATING {result['violating_regions']}")
    print(f"POLYS {result['intersect_polygons']}")
    print(f"AREA_UM2 {result['intersect_area_um2']}")
    print(f"PASS {result['pass']}")
    print(f"wrote {out}")
    return 0 if result["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
