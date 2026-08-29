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
net=odb.dbNet_create(block, "jidtest")
w=odb.dbWire_create(net)
e=odb.dbWireEncoder(); e.begin(w)
e.newPath(m3, "ROUTED")
r1=e.addPoint(10000,20000)
print("addPoint ret", r1, type(r1))
r2=e.addPoint(50000,20000)
print("addPoint2", r2, type(r2))
# try newPath from junction
for args in [(m2,"ROUTED",r2), (r2,m2,"ROUTED"), (m2,"ROUTED")]:
    try:
        e2ok=e.newPath(*args)
        print("newPath", args, "->", e2ok)
        break
    except Exception as ex:
        print("newPath fail", args, ex)
e.addPoint(50000,40000)
e.end()
print("wire len", w.getLength())
# count paths
pitr=odb.dbWirePathItr(); path=odb.dbWirePath(); shape=odb.dbWirePathShape()
pitr.begin(w); np=0
while pitr.getNextPath(path):
    np+=1
    ns=0
    while pitr.getNextShape(shape):
        ns+=1
    print("path", np, "shapes", ns, "iterm", path.iterm)
print("np", np)
