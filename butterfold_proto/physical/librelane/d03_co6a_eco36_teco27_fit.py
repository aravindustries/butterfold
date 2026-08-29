"""Which remaining slew/cap output drivers on teco26 can KEEP_WIRES upsize."""
from collections import defaultdict
from openroad import Tech, Design

PDK="/foss/pdks/gf180mcuD"
SRC="/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_candidate/co6a36/setup_eco30/butterfold_top_co6a36_teco26.odb"
tech=Tech()
tech.readLef(PDK+"/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef")
tech.readLef(PDK+"/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef")
tech.readLef(PDK+"/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef")
d=Design(tech); d.readDb(SRC)
db=tech.getDB(); block=db.getChip().getBlock(); dbu=block.getDefUnits()

INSTS = [
"_11198_","_12553_","_11447_","_12601_","_12474_","_11434_","_11183_","_12577_",
"_12214_","_17231_","_11765_","_12569_","_20030_","_11527_","_15762_","_11150_",
"_12458_","_11164_","_12617_","_13042_","_12519_","_12188_","_10236_","_12482_",
"_09563_","_11094_","_11925_","_11225_","_09860_","_12169_","_11559_","_11319_",
"_11898_","_11739_","clone388","_19230_","_11461_","_09262_","_12466_","_14265_","_11785_",
]
NINE={"_11280_","_11106_","_11366_","_11339_","_11136_","_11474_","_11394_","_11408_","_11241_"}

# occupancy by row
rows=defaultdict(list)
for inst in block.getInsts():
    bb=inst.getBBox()
    rows[bb.yMin()].append((bb.xMin(), bb.xMax(), inst.getName()))

def gaps(inst):
    bb=inst.getBBox()
    xmin,xmax,ymin=bb.xMin(),bb.xMax(),bb.yMin()
    items=sorted(rows[ymin])
    gl=gr=999.0
    for x0,x1,n in items:
        if n==inst.getName(): continue
        if x1<=xmin: gl=min(gl,(xmin-x1)/dbu)
        if x0>=xmax: gr=min(gr,(x0-xmax)/dbu)
    return gl, gr

ok=[]
for name in INSTS:
    if name in NINE: continue
    inst=block.findInst(name)
    if inst is None:
        print("NO", name); continue
    src=inst.getMaster().getName()
    if src.endswith("_1"):
        tgt=src[:-1]+"2"
    elif src.endswith("_2"):
        tgt=src[:-1]+"4"
    else:
        print("SKIP", name, src); continue
    m2=db.findMaster(tgt)
    if m2 is None:
        print("NOMASTER", name, tgt); continue
    if "aoi221" in src:
        print("SKIP_AOI221", name, src); continue
    if "dff" in src:
        print("SKIP_DFF", name, src); continue
    w1=inst.getMaster().getWidth()/dbu
    w2=m2.getWidth()/dbu
    dw=w2-w1
    gl,gr=gaps(inst)
    fitR=gr+0.001>=dw
    fitL=gl+gr+0.001>=dw
    shift=0.0 if fitR else max(0.0, dw-gr)
    print(f"{name:12s} {src.split('__')[-1]:12s}->{tgt.split('__')[-1]:12s} dw={dw:5.2f} gL={gl:5.2f} gR={gr:5.2f} fitR={int(fitR)} fit={int(fitL)} shift={shift:.2f}")
    if fitL:
        ok.append((name, tgt, shift))
print("OK", len(ok))
for t in ok:
    print("DO", t[0], t[1], "shift", t[2])
print("DONE")
