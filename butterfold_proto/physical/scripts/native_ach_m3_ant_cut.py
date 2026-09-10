from openroad import Design, Tech
import odb, os
PROTO="/headless/aravindustries-repos/butterfold/butterfold_proto"
SRC=os.environ.get(
    "M3CUT_SRC",
    PROTO+"/physical/results/native_power_ring_ach/ach_applied.odb",
)
DST=os.environ.get(
    "M3CUT_DST",
    PROTO+"/physical/results/native_power_ring_ach/predrt/applied_m3cut.odb",
)
tech=Tech(); d=Design(tech); d.readDb(SRC)
db=tech.getDB(); block=db.getChip().getBlock(); dbtech=db.getTech(); dbu=block.getDefUnits()
net=block.findNet("_07203_")
old=net.getWire()
dec=odb.dbWireDecoder(); dec.begin(old)
events=[]
while True:
    op=dec.next()
    if op==odb.dbWireDecoder.END_DECODE: break
    if op in (odb.dbWireDecoder.PATH, odb.dbWireDecoder.SHORT, odb.dbWireDecoder.VWIRE):
        lyr=dec.getLayer(); events.append(("PATH", lyr.getName() if lyr else None)); continue
    if op==odb.dbWireDecoder.TECH_VIA:
        v=dec.getTechVia(); events.append(("TVIA", v.getName() if v else None)); continue
    if op in (odb.dbWireDecoder.POINT, odb.dbWireDecoder.POINT_EXT):
        pt=dec.getPoint(); events.append(("PT", int(pt[0]), int(pt[1]))); continue
odb.dbWire_destroy(old)
wire=odb.dbWire.create(net)
enc=odb.dbWireEncoder(); enc.begin(wire)
via3=dbtech.findVia("Via3_HV")
m3=dbtech.findLayer("Metal3")
m4=dbtech.findLayer("Metal4")
groups=[]; cur=None
for ev in events:
    if ev[0]=="PATH":
        if cur: groups.append(cur)
        cur={"layer":ev[1],"ops":[]}
    else:
        if cur: cur["ops"].append(ev)
if cur: groups.append(cur)
ncut=0
for g in groups:
    lyrname=g["layer"]
    lyr=dbtech.findLayer(lyrname)
    pts=[op for op in g["ops"] if op[0]=="PT"]
    # detect the 773um M3 at y~712.60
    skip_long=False
    if lyrname=="Metal3" and len(pts)==2:
        x1,y1,x2,y2=pts[0][1],pts[0][2],pts[1][1],pts[1][2]
        if abs(y1-y2)<dbu and abs(x2-x1)>500*dbu:
            # cut into two M3 + M4 bridge
            xa,xb=min(x1,x2),max(x1,x2)
            y=y1
            g1=int(xa+ (xb-xa)*0.48)
            g2=int(xa+ (xb-xa)*0.52)
            enc.newPath(m3,"ROUTED"); enc.addPoint(xa,y); enc.addPoint(g1,y)
            enc.addTechVia(via3)
            enc.newPath(m4,"ROUTED"); enc.addPoint(g1,y); enc.addPoint(g2,y)
            enc.addTechVia(via3)
            enc.newPath(m3,"ROUTED"); enc.addPoint(g2,y); enc.addPoint(xb,y)
            ncut+=1
            skip_long=True
    if skip_long: continue
    enc.newPath(lyr,"ROUTED")
    for op in g["ops"]:
        if op[0]=="PT":
            enc.addPoint(op[1],op[2])
        elif op[0]=="TVIA":
            v=dbtech.findVia(op[1])
            if v: enc.addTechVia(v)
enc.end()
d.writeDb(DST)
open("/tmp/m3cut.txt","w").write(f"ncut {ncut} groups {len(groups)}\n")
os._exit(0)
