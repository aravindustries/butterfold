#!/usr/bin/env python3
"""Report the connectivity of the bounded fft128_active buffer ECO."""
import os
import odb

src = os.environ.get("TREE_AUDIT_SRC", "physical/results/native_power_ring_ach/predrt/odb_buf3.odb")
db = odb.dbDatabase.create()
odb.read_db(db, src)
block = db.getChip().getBlock()
for inst in sorted(block.getInsts(), key=lambda x: x.getName()):
    if not inst.getName().startswith(("cone_buf_", "cone3_buf_")):
        continue
    pins = []
    for iterm in inst.getITerms():
        net = iterm.getNet()
        pins.append(f"{iterm.getMTerm().getName()}={net.getName() if net else '-'}")
    print(inst.getName(), inst.getMaster().getName(), " ".join(pins))
for name in ("_20043_", "_20041_"):
    inst = block.findInst(name)
    if inst:
        print("ROOT", name, " ".join(
            f"{it.getMTerm().getName()}={it.getNet().getName() if it.getNet() else '-'}"
            for it in inst.getITerms()))
for name in ("rst_n", "net226", "net227", "net228"):
    net = block.findNet(name)
    if net:
        print("NET", name, "ITERM_COUNT", len(net.getITerms()), "BTERMS", len(net.getBTerms()))
        for it in net.getITerms():
            if it.getMTerm().getIoType() == "OUTPUT":
                print("DRIVER", name, it.getInst().getName(), it.getMTerm().getName(), it.getInst().getMaster().getName())
