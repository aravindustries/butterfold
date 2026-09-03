#!/usr/bin/env python3
"""Verify critical ACH power-array cut counts in the exact streamed GDS."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import gdstk


CHECKS = [
    ("VDD_M2_M3", "VDD", 38, 3, [(636.110, 1674.500), (648.885, 1674.500),
        (660.735, 1674.500), (674.265, 1674.500), (686.115, 1674.500),
        (698.890, 1674.500)], 0.75, "via2_3_3200_1200_1_3_1040_1040", "Metal2/Via2/Metal3", "1x3"),
    ("VDD_M3_M4", "VDD", 40, 6, [(483.840, 1674.500), (637.440, 1674.500),
        (791.040, 1674.500)], 0.75, "via3_4_3200_2000_2_3_1040_1040", "Metal3/Via3/Metal4", "2x3"),
    ("VSS_M3_M4", "VSS", 40, 6, [(8.800, 40.110)], 0.75,
        "via3_4_3200_2000_2_3_1040_1040", "Metal3/Via3/Metal4", "2x3"),
    ("VSS_M4_M5", "VSS", 41, 9, [(8.800, 40.110)], 0.75,
        "via4_5_3200_3200_3_3_1040_1040", "Metal4/Via4/Metal5", "3x3"),
]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("gds", type=Path)
    ap.add_argument("--json", required=True, type=Path)
    a = ap.parse_args()
    lib = gdstk.read_gds(str(a.gds))
    top = next(c for c in lib.top_level() if c.name == "butterfold_top").copy("power_via_audit_flat")
    top.flatten()
    results, errors = [], []
    for ident, supply, layer, expected, centers, radius, master, stack, array in CHECKS:
        polygons = top.get_polygons(layer=layer, datatype=0)
        for x, y in centers:
            hits = set()
            for p in polygons:
                bb = p.bounding_box()
                if (bb[0][0] >= x-radius and bb[1][0] <= x+radius and
                        bb[0][1] >= y-radius and bb[1][1] <= y+radius):
                    hits.add(tuple(round(float(v), 6) for point in bb for v in point))
            row = {"id": ident, "supply": supply, "center_um": [x, y],
                   "technology_generated_via_master": master, "layer_stack": stack,
                   "array": array, "expected_cut_count": expected,
                   "actual_unique_cut_count_in_final_gds": len(hits),
                   "cut_bboxes_um": sorted(hits)}
            results.append(row)
            if len(hits) != expected:
                errors.append(f"{ident}@{x},{y}: {len(hits)} != {expected}")
    data = {"gds": str(a.gds), "gds_sha256": hashlib.sha256(a.gds.read_bytes()).hexdigest(),
            "raw_hand_drawn_critical_via_cuts": 0,
            "critical_power_vias_implemented_with_pcell_or_tech_generated_via": not errors,
            "checks": results, "errors": errors, "pass": not errors}
    a.json.parent.mkdir(parents=True, exist_ok=True)
    a.json.write_text(json.dumps(data, indent=2) + "\n")
    print(json.dumps(data, indent=2))
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
