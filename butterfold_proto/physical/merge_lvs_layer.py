#!/usr/bin/env python3
"""Merge one conductor layer in a temporary LVS-only GDS view."""
import sys
from pathlib import Path
import klayout.db as db

source, output, layer_number = Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3])
layout = db.Layout(); layout.read(str(source)); top = layout.top_cell()
layer = layout.layer(layer_number, 0)
region = db.Region(top.shapes(layer))
top.shapes(layer).clear()
region.merge()
top.shapes(layer).insert(region)
layout.write(str(output))
print(f"layer={layer_number} merged_polygons={region.size()} output={output}")
