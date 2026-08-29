from openroad import Tech, Design
pdk = "/foss/pdks/gf180mcuD"
src = "/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_candidate/co6a36/setup_eco25/butterfold_top_co6a36_teco21.odb"
tech = Tech()
tech.readLef(pdk + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef")
tech.readLef(pdk + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef")
tech.readLef(pdk + "/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef")
design = Design(tech)
design.readDb(src)
dbtech = design.getTech().getDB().getTech() if False else None
block = design.getBlock()
# get odb tech from a layer
inst = block.findInst("rebuffer265")
# walk tech vias
odb_tech = inst.getMaster().getLib().getDb().getTech()
print("LAYERS")
for ly in odb_tech.getLayers():
    print(" ", ly.getName(), "type", ly.getType(), "dir", ly.getDirection(), "w", ly.getWidth())
print("VIAS (first 40)")
n = 0
for v in odb_tech.getVias():
    n += 1
    if n <= 40:
        print(" ", v.getName())
print("NVIA", n)
print("TECHVIAS")
n = 0
for v in odb_tech.getVias():
    pass
# tech vias are getVias on tech
tvs = list(odb_tech.getVias())
print("count", len(tvs))
# clkbuf_8 pins
m = None
for i in block.getInsts():
    if i.getMaster().getName().endswith("clkbuf_8"):
        m = i.getMaster()
        break
print("CLKBUF8", m.getName(), "w", m.getWidth())
for mt in m.getMTerms():
    pn = mt.getName()
    if pn in ("VDD", "VSS", "VNW", "VPW"):
        continue
    xs = []
    for mp in mt.getMPins():
        for b in mp.getGeometry():
            xs.append((b.xMin(), b.yMin(), b.xMax(), b.yMax(), b.getTechLayer().getName()))
    print(" PIN", pn, xs[:6], "nbox", len(xs))
# sample RN pin
net = block.findNet("rst_n")
for it in net.getITerms():
    if it.getMTerm().getName() == "RN":
        print("RN inst", it.getInst().getName(), it.getInst().getMaster().getName())
        for mp in it.getMTerm().getMPins():
            for b in mp.getGeometry():
                print("  RNbox", b.xMin(), b.yMin(), b.xMax(), b.yMax(), b.getTechLayer().getName())
        break
print("DONE")
