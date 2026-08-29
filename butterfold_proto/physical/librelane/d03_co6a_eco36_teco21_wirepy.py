import odb
from openroad import Tech, Design

tech = Tech()
pdk = "/foss/pdks/gf180mcuD"
tech.readLef(pdk + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef")
tech.readLef(pdk + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef")
tech.readLef(pdk + "/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef")
design = Design(tech)
design.readDb("physical/results/d03_ach_candidate/co6a36/setup_eco25/butterfold_top_co6a36_teco21.odb")
block = design.getBlock()
net = block.findNet("rst_n")
print("terms", len(list(net.getITerms())))
w = net.getWire()
print("length", w.getLength(), "bbox", w.getBBox())
itr = odb.dbWirePathItr()
itr.begin(w)
n = 0
while True:
    path = odb.dbWirePath()
    ok = itr.getNextPath(path)
    if not ok:
        break
    n += 1
    if n <= 3:
        print("path", n, "dir", [x for x in dir(path) if not x.startswith("_")])
print("npaths", n)
print("done")
