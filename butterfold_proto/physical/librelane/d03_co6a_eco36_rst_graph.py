from openroad import Tech, Design
import odb
PDK="/foss/pdks/gf180mcuD"
SRC="/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_candidate/co6a36/setup_eco25/butterfold_top_co6a36_teco21.odb"
tech=Tech()
tech.readLef(PDK+"/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef")
tech.readLef(PDK+"/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef")
tech.readLef(PDK+"/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef")
d=Design(tech); d.readDb(SRC)
db=tech.getDB(); block=db.getChip().getBlock(); dbu=block.getDefUnits()
net=block.findNet("rst_n")
g=odb.dbWireGraph()
g.decode(net.getWire())
print("graph dir edges/nodes iterators")
# count nodes/edges
nn=ne=0
# try dump to file
g.dump()
print("DUMP_DONE")
print("begin_nodes", g.begin_nodes)
print("getEdge", g.getEdge)
