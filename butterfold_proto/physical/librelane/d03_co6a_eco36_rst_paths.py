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
w=net.getWire()
pitr=odb.dbWirePathItr()
path=odb.dbWirePath()
shape=odb.dbWirePathShape()
pitr.begin(w)
shown=0
npath=0
iterm_paths=0
bterm_paths=0
lens=[]
while pitr.getNextPath(path):
    npath+=1
    pts=[]
    itn=None; btn=None
    pitr2_shapes=[]
    # getNextShape consumes
    shs=[]
    while pitr.getNextShape(shape):
        pt=shape.point
        lyr=shape.layer.getName() if shape.layer else "?"
        x,y=pt.getX(), pt.getY()
        shs.append((x,y,lyr, shape.iterm.getName() if shape.iterm else None,
                    shape.bterm.getName() if shape.bterm else None))
        if shape.iterm: itn=shape.iterm.getInst().getName()+"/"+shape.iterm.getMTerm().getName()
        if shape.bterm: btn=shape.bterm.getName()
    if itn: iterm_paths+=1
    if btn: bterm_paths+=1
    if shs:
        x0,y0=shs[0][0],shs[0][1]
        x1,y1=shs[-1][0],shs[-1][1]
        manh=abs(x1-x0)+abs(y1-y0)
        lens.append(manh/dbu)
    if shown<8:
        print("PATH", npath, "nsh", len(shs), "iterm", itn, "bterm", btn, "layers",
              sorted(set(s[2] for s in shs)))
        print("  first", shs[0][0]/dbu, shs[0][1]/dbu, shs[0][2], "last", shs[-1][0]/dbu, shs[-1][1]/dbu, shs[-1][2])
        shown+=1
print("npath", npath, "iterm_paths", iterm_paths, "bterm_paths", bterm_paths)
if lens:
    lens.sort()
    print("manh_um min/med/max", lens[0], lens[len(lens)//2], lens[-1], "sum", sum(lens))
