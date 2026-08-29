from openroad import Tech, Design
import odb
PDK="/foss/pdks/gf180mcuD"
SRC="/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_candidate/co6a36/setup_eco25/butterfold_top_co6a36_teco21.odb"
tech=Tech()
tech.readLef(PDK+"/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef")
tech.readLef(PDK+"/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef")
tech.readLef(PDK+"/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef")
d=Design(tech); d.readDb(SRC)
db=tech.getDB(); block=db.getChip().getBlock()
net=block.findNet("rst_n")
g=odb.dbWireGraph()
g.decode(net.getWire())
print("methods", [x for x in dir(g) if not x.startswith("_")])
# try iterating
try:
    n0 = g.begin_nodes()
    print("begin_nodes type", type(n0), n0)
    print("dir node", [x for x in dir(n0) if not x.startswith("_")][:40])
except Exception as e:
    print("begin_nodes err", e)
try:
    e0 = g.begin_edges()
    print("begin_edges type", type(e0), e0)
    print("dir edge", [x for x in dir(e0) if not x.startswith("_")][:40])
except Exception as e:
    print("begin_edges err", e)

# path iterator shapes count by layer
w=net.getWire()
pitr=odb.dbWirePathItr()
path=odb.dbWirePath()
shape=odb.dbWirePathShape()
pitr.begin(w)
nlayers={}
nsh=0
npath=0
while pitr.getNextPath(path):
    npath+=1
    while pitr.getNextShape(shape):
        nsh+=1
        lyr=shape.layer
        name=lyr.getName() if lyr else "none"
        nlayers[name]=nlayers.get(name,0)+1
print("npath", npath, "nshape", nsh, "layers", nlayers)
print("path fields", [x for x in dir(path) if not x.startswith("_")])
print("shape fields", [x for x in dir(shape) if not x.startswith("_")])
