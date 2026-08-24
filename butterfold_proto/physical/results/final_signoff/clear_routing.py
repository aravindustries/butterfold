import odb, hashlib, time
S='/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/butterfold_top_elec_legal.odb'
O='/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/butterfold_top_clean_unrouted.odb'
D='/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/butterfold_top_clean_unrouted.def'
db=odb.dbDatabase.create(); odb.read_db(db,S); b=db.getChip().getBlock()
def snap():
    i=[(x.getName(),x.getMaster().getName(),x.getLocation(),str(x.getOrient()),str(x.getPlacementStatus())) for x in b.getInsts()]
    c=[]; ndr=[]
    for n in b.getNets():
        c.append((n.getName(),str(n.getSigType()),tuple(sorted([f'I:{x.getInst().getName()}/{x.getMTerm().getName()}' for x in n.getITerms()]+[f'B:{x.getName()}' for x in n.getBTerms()]))))
        r=n.getNonDefaultRule(); ndr.append((n.getName(), r.getName() if r else ''))
    h=lambda x:hashlib.sha256(repr(sorted(x)).encode()).hexdigest(); return h(i),h(c),h(ndr)
def inv(x):
    ns=list(b.getNets()); sw=[s for n in ns for s in n.getSWires()]
    print(x,'DBWIRES',sum(bool(n.getWire()) for n in ns),'GUIDES',sum(len(n.getGuides()) for n in ns),'SWIRES',len(sw))
a=snap(); inv('BEFORE'); dw=gd=0
for n in b.getNets():
    if str(n.getSigType()) in ('POWER','GROUND'): continue
    if n.getWire(): odb.dbWire.destroy(n.getWire()); dw+=1
    if n.getGuides(): gd+=len(n.getGuides()); n.clearGuides()
z=snap(); inv('AFTER')
print('DESTROYED',dw,'CLEARED_GUIDES',gd,'PLACEMENT_IDENTICAL',a[0]==z[0],'CONNECTIVITY_IDENTICAL',a[1]==z[1],'NDR_IDENTICAL',a[2]==z[2])
odb.write_db(db,O); odb.write_def(b,D)
