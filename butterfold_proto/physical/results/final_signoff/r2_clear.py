import odb
S='/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/r2_legal.odb'
O='/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/r2_clean.odb'
db=odb.dbDatabase.create(); odb.read_db(db,S); b=db.getChip().getBlock()
dw=0
for n in b.getNets():
    if str(n.getSigType()) in ('POWER','GROUND'): continue
    if n.getWire(): odb.dbWire.destroy(n.getWire()); dw+=1
    if n.getGuides(): n.clearGuides()
print('DESTROYED', dw)
odb.write_db(db,O)
