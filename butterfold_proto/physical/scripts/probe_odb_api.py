#!/usr/bin/env python3
"""Report which OpenDB wire-traversal API this build exposes."""
import sys
from openroad import Design, Tech
import odb

tech = Tech(); design = Design(tech)
design.readDb(sys.argv[1])
block = tech.getDB().getChip().getBlock()

print("odb attrs with Wire/Shape/Decoder:")
print("  ", sorted(a for a in dir(odb) if any(k in a for k in ("Wire", "Shape", "Decode", "Graph"))))

wire = None
for net in block.getNets():
    if net.getName() in ("VDD", "VSS"):
        continue
    w = net.getWire()
    if w is not None:
        wire = w; print("\nsample net:", net.getName()); break

if wire is None:
    print("no signal wire found"); sys.exit(1)

print("\ndbWire methods:")
print("  ", sorted(m for m in dir(wire) if not m.startswith("_")))

for cand in ("dbWireDecoder", "dbWireGraph", "dbShape"):
    if hasattr(odb, cand):
        obj = getattr(odb, cand)
        print(f"\n{cand} members:")
        print("  ", sorted(m for m in dir(obj) if not m.startswith("_"))[:60])
