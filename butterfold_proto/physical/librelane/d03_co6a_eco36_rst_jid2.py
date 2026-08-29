from openroad import Tech, Design
import odb
PDK="/foss/pdks/gf180mcuD"
SRC="/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_candidate/co6a36/setup_eco25/butterfold_top_co6a36_teco21.odb"
tech=Tech()
tech.readLef(PDK+"/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef")
tech.readLef(PDK+"/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef")
tech.readLef(PDK+"/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef")
d=Design(tech); d.readDb(SRC)
db=tech.getDB(); block=db.getChip().getBlock(); ttech=db.getTech()
m2=ttech.findLayer("Metal2"); m3=ttech.findLayer("Metal3")
g=odb.dbWireGraph()
print("createNode", g.createNode)
print("createSegment", g.createSegment)
print("encode", g.encode)
try:
    n1=g.createNode(10000,20000,m3)
    print("n1 ok", type(n1).__name__)
    print("n1 dir", [x for x in dir(n1) if not x.startswith("_")])
except Exception as e:
    print("createNode err", type(e), e)
