#!/usr/bin/env python3
"""Place 9 R180 aoi221_2 at same-row X with legal Via1 sites; slide neighbors;
jog blocking foreign M2 locally; add 0.28 um endpoint connections.
Starts from pgfix. No TritonRoute.
"""
from __future__ import annotations
import math
from collections import defaultdict
from openroad import Tech, Design
import odb

PDK = "/foss/pdks/gf180mcuD"
CAND = "physical/results/d03_ach_candidate"
OUT = "physical/reports/signoff/evidence/d03_ach/drc"
INSTS = [
    "_11280_", "_11106_", "_11366_", "_11339_", "_11136_",
    "_11474_", "_11394_", "_11408_", "_11241_",
]
SKIP = {"VDD", "VSS", "VNW", "VPW"}
KMAX = 42

tech = Tech()
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef")
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef")
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef")
d = Design(tech)
d.readDb(CAND + "/butterfold_top_pgfix.odb")
db = tech.getDB(); block = db.getChip().getBlock(); ttech = db.getTech()
m2 = ttech.findLayer("Metal2")
via_vv = ttech.findVia("Via1_VV"); via_vh = ttech.findVia("Via1_VH")
dbu = block.getDefUnits(); SW = block.getRows()[0].getSite().getWidth()
W = int(round(0.28 * dbu)); HW = W // 2; S = int(round(0.28 * dbu))
WIDE = int(round(10.0 * dbu)); GRID = 10; STEP = 140
print("DBU", dbu, "SITE", SW / float(dbu), flush=True)

def um(v): return v / float(dbu)
def snap(v, g=GRID): return int(round(v / float(g)) * g)
def overlaps(a, b, slack=0):
    return not (a.xMax() < b.xMin()-slack or b.xMax() < a.xMin()-slack
                or a.yMax() < b.yMin()-slack or b.yMax() < a.yMin()-slack)
def gap_euclid(a, b):
    dx = 0 if not (a.xMax() < b.xMin() or b.xMax() < a.xMin()) else (b.xMin()-a.xMax() if a.xMax()<b.xMin() else a.xMin()-b.xMax())
    dy = 0 if not (a.yMax() < b.yMin() or b.yMax() < a.yMin()) else (b.yMin()-a.yMax() if a.yMax()<b.yMin() else a.yMin()-b.yMax())
    if dx==0 and dy==0: return 0
    if dx==0: return dy
    if dy==0: return dx
    return int(round(math.hypot(dx, dy)))
def is_fill(mn): return ("__fill_" in mn) or ("__fillcap_" in mn) or ("__filltie" in mn) or ("__endcap" in mn)
def is_sram(mn): return "sram" in mn

BIN=2000
idx=defaultdict(list); eco=[]
def add_idx(nn, r):
    for bx in range(r.xMin()//BIN, r.xMax()//BIN+1):
        for by in range(r.yMin()//BIN, r.yMax()//BIN+1):
            idx[(bx,by)].append((nn,r))
def query(win, slack=S):
    seen,out=set(),[]
    for bx in range((win.xMin()-slack)//BIN,(win.xMax()+slack)//BIN+1):
        for by in range((win.yMin()-slack)//BIN,(win.yMax()+slack)//BIN+1):
            for rec in idx.get((bx,by),()):
                k=id(rec[1])
                if k in seen: continue
                seen.add(k)
                if overlaps(win, rec[1], slack=slack): out.append(rec)
    return out

print("INDEX", flush=True)
for net in block.getNets():
    w=net.getWire()
    if w is None: continue
    pitr=odb.dbWirePathItr(); path=odb.dbWirePath(); shape=odb.dbWirePathShape()
    pitr.begin(w)
    while pitr.getNextPath(path):
        while pitr.getNextShape(shape):
            lyr=shape.layer
            if lyr is None or lyr.getName()!="Metal2": continue
            sh=shape.shape
            add_idx(net.getName(), odb.Rect(sh.xMin(), sh.yMin(), sh.xMax(), sh.yMax()))
print("INDEXED", flush=True)

def rebuild_idx():
    idx.clear()
    for net in block.getNets():
        w = net.getWire()
        if w is None:
            continue
        pitr = odb.dbWirePathItr(); path = odb.dbWirePath(); shape = odb.dbWirePathShape()
        pitr.begin(w)
        while pitr.getNextPath(path):
            while pitr.getNextShape(shape):
                lyr = shape.layer
                if lyr is None or lyr.getName() != "Metal2":
                    continue
                sh = shape.shape
                add_idx(net.getName(), odb.Rect(sh.xMin(), sh.yMin(), sh.xMax(), sh.yMax()))
    for nn, r in eco:
        add_idx(nn, r)

def reindex_net(nn):
    # drop old entries for nn (scan bins is heavy); just add new eco
    pass

def legal(rect, nn):
    win=odb.Rect(rect.xMin()-S-20, rect.yMin()-S-20, rect.xMax()+S+20, rect.yMax()+S+20)
    for onet,ob in list(query(win,S+20))+[e for e in eco if overlaps(win,e[1], slack=S)]:
        g=gap_euclid(rect,ob)
        if onet==nn:
            if g==0: continue
            if g<S: return False
        else:
            need=int(round(0.30*dbu)) if ((ob.xMax()-ob.xMin())>WIDE and (ob.yMax()-ob.yMin())>WIDE) else S
            if g<need: return False
    return True

def via_m2(vx,vy,vert):
    return odb.Rect(vx-280,vy-380,vx+280,vy+380) if vert else odb.Rect(vx-380,vy-280,vx+380,vy+280)
def via_m1(vx,vy,vert):
    return odb.Rect(vx-260,vy-380,vx+260,vy+380) if vert else odb.Rect(vx-380,vy-260,vx+380,vy+260)
def seg(x1,y1,x2,y2):
    if int(x1)==int(x2):
        return odb.Rect(int(x1)-HW, min(int(y1),int(y2))-HW, int(x1)+HW, max(int(y1),int(y2))+HW)
    return odb.Rect(min(int(x1),int(x2))-HW, int(y1)-HW, max(int(x1),int(x2))+HW, int(y1)+HW)
def unique_pts(pts):
    out=[]
    for p in pts:
        p=(snap(p[0]), snap(p[1]))
        if not out or out[-1]!=p: out.append(p)
    return out

def collect_shapes(net):
    w=net.getWire(); out=[]
    if w is None: return out
    pitr=odb.dbWirePathItr(); path=odb.dbWirePath(); shape=odb.dbWirePathShape()
    pitr.begin(w)
    while pitr.getNextPath(path):
        while pitr.getNextShape(shape):
            lyr=shape.layer
            if lyr is None: continue
            sh=shape.shape
            out.append((lyr.getName(), odb.Rect(sh.xMin(), sh.yMin(), sh.xMax(), sh.yMax())))
    return out

def pin_box(it):
    bb=it.getBBox(); return odb.Rect(bb.xMin(), bb.yMin(), bb.xMax(), bb.yMax())
def pin_hit(pin, shapes):
    for _ly,box in shapes:
        if overlaps(pin, box, slack=1): return True
    return False
def nearest_m2(shapes, x, y, k=6):
    cands=[]
    for ly,box in shapes:
        if ly!="Metal2": continue
        cx=min(max(x, box.xMin()), box.xMax()); cy=min(max(y, box.yMin()), box.yMax())
        cands.append((abs(cx-x)+abs(cy-y), snap(cx), snap(cy)))
    cands.sort(); out,seen=[],set()
    for dist,cx,cy in cands:
        if (cx,cy) in seen: continue
        seen.add((cx,cy)); out.append((cx,cy,dist))
        if len(out)>=k: break
    return out

def via_candidates(pin, nn):
    out=[]
    pad=400; x=snap(pin.xMin()-pad)
    while x<=pin.xMax()+pad and len(out)<24:
        y=snap(pin.yMin()-pad)
        while y<=pin.yMax()+pad and len(out)<24:
            for vert in (True, False):
                if overlaps(via_m1(x,y,vert), pin, slack=0) and legal(via_m2(x,y,vert), nn):
                    out.append((x,y,vert))
            y+=STEP
        x+=STEP
    seen,uniq=set(),[]
    for rec in out:
        if rec in seen: continue
        seen.add(rec); uniq.append(rec)
    return uniq

def path_ok(pts, nn, vert, vx, vy):
    rects=[]
    for a,b in zip(pts, pts[1:]):
        if a==b: continue
        if a[0]!=b[0] and a[1]!=b[1]: return False, []
        r=seg(a[0],a[1],b[0],b[1])
        if not legal(r, nn): return False, []
        rects.append(r)
    vb=via_m2(vx,vy,vert)
    if not legal(vb, nn): return False, []
    rects.append(vb)
    return True, rects

def blockers_for(rects, nn):
    """Foreign M2 rects that violate spacing to proposed rects."""
    hits=[]
    for r in rects:
        win=odb.Rect(r.xMin()-S-20, r.yMin()-S-20, r.xMax()+S+20, r.yMax()+S+20)
        for onet,ob in query(win, S+20):
            if onet==nn: continue
            g=gap_euclid(r, ob)
            if g<S:
                hits.append((onet, ob, g))
    return hits

def intended_path(pin, net, shapes):
    nn=net.getName()
    vias=via_candidates(pin, nn)
    anchors=nearest_m2(shapes, (pin.xMin()+pin.xMax())//2, (pin.yMin()+pin.yMax())//2)
    if not vias or not anchors: return None
    vx,vy,vert=vias[0]; ax,ay,_=anchors[0]
    pts=unique_pts([(ax,ay),(vx,ay),(vx,vy)])
    if pts[-1]!=(vx,vy): pts.append((vx,vy))
    rects=[seg(a[0],a[1],b[0],b[1]) for a,b in zip(pts,pts[1:]) if a!=b]
    rects.append(via_m2(vx,vy,vert))
    return pts, vert, vx, vy, rects

def find_patch(pin, net, shapes):
    nn=net.getName()
    if pin_hit(pin, shapes): return "HIT", None
    vias=via_candidates(pin, nn)
    if not vias: return "FAIL", "no_via"
    anchors=nearest_m2(shapes, (pin.xMin()+pin.xMax())//2, (pin.yMin()+pin.yMax())//2)
    if not anchors: return "FAIL", "no_anchor"
    best=None
    for vx,vy,vert in vias[:10]:
        for ax,ay,_d in anchors[:3]:
            fam=[]
            if ax==vx or ay==vy: fam.append([(ax,ay),(vx,vy)])
            fam += [[(ax,ay),(vx,ay),(vx,vy)],[(ax,ay),(ax,vy),(vx,vy)]]
            for dy in (-1120,1120):
                fam.append([(ax,ay),(ax,ay+dy),(vx,ay+dy),(vx,vy)])
            for pts in fam:
                pts=unique_pts(pts)
                if len(pts)<2: continue
                if pts[-1]!=(vx,vy): pts=unique_pts(pts+[(vx,vy)])
                ok, rects=path_ok(pts, nn, vert, vx, vy)
                if not ok: continue
                nb=max(0,len(pts)-2)
                ln=sum(abs(b[0]-a[0])+abs(b[1]-a[1]) for a,b in zip(pts,pts[1:]))
                cand=(nb,ln,pts,vert,vx,vy,rects)
                if best is None or cand[0]<best[0] or (cand[0]==best[0] and cand[1]<best[1]):
                    best=cand
                if nb<=1: break
            if best is not None and best[0]<=1: break
    if best is None: return "FAIL", "no_path"
    return "PATCH", best

def encode(net, pts, via_obj, iterm):
    e=odb.dbWireEncoder(); e.append(net.getWire())
    try: e.newPath(m2, "ROUTED", W)
    except TypeError: e.newPath(m2, "ROUTED")
    prev=None
    for p in pts:
        if prev is not None and p==prev: continue
        e.addPoint(int(p[0]), int(p[1])); prev=p
    for a,b in zip(pts, pts[1:]):
        if a==b: continue
        r=seg(a[0],a[1],b[0],b[1]); e.addRect(r.xMin(), r.yMin(), r.xMax(), r.yMax())
    e.addTechVia(via_obj); e.addITerm(iterm); e.end()

# --- foreign M2 local U-jog by rebuilding net M2 rects ---
def _ptxy(pt):
    if hasattr(pt, "getX"):
        return int(pt.getX()), int(pt.getY())
    if isinstance(pt, (tuple, list)):
        return int(pt[0]), int(pt[1])
    return int(pt.x), int(pt.y)


def jog_foreign(net, keepout, nn_self):
    """Copy net wire, replacing Metal2 segments that intersect keepout with a U-jog."""
    global foreign_jogs
    w = net.getWire()
    if w is None:
        return False
    ko = odb.Rect(keepout.xMin() - S, keepout.yMin() - S, keepout.xMax() + S, keepout.yMax() + S)
    bypass_x = ko.xMin() - S - HW
    dec = odb.dbWireDecoder()
    dec.begin(w)
    events = []
    op = dec.next()
    hit = False
    while op != dec.END_DECODE:
        if op == dec.PATH:
            events.append(("PATH", dec.getLayer(), "ROUTED"))
        elif op == dec.POINT:
            x, y = _ptxy(dec.getPoint())
            events.append(("PT", x, y))
        elif op == dec.TECH_VIA:
            events.append(("TVIA", dec.getTechVia()))
        elif op == dec.VIA:
            events.append(("VIA", dec.getVia()))
        elif op == dec.ITERM:
            events.append(("ITERM", dec.getITerm()))
        elif op == dec.BTERM:
            events.append(("BTERM", dec.getBTerm()))
        elif op == dec.RECT:
            events.append(("OP", "RECT"))
        else:
            events.append(("OP", int(op)))
        op = dec.next()
    # Rewrite PT pairs on Metal2 that cross keepout.
    out_ev = []
    i = 0
    cur_layer = None
    while i < len(events):
        ev = events[i]
        if ev[0] == "PATH":
            cur_layer = ev[1]
            out_ev.append(ev)
            i += 1
            continue
        if ev[0] == "PT" and i + 1 < len(events) and events[i + 1][0] == "PT" and cur_layer is not None and cur_layer.getName() == "Metal2":
            x1, y1 = ev[1], ev[2]
            x2, y2 = events[i + 1][1], events[i + 1][2]
            sr = seg(x1, y1, x2, y2)
            if overlaps(sr, ko, slack=0):
                hit = True
                # emit first point, then U-jog, then second point
                out_ev.append(("PT", x1, y1))
                if x1 == x2:  # vertical
                    yb, yt = (ko.yMin(), ko.yMax()) if y1 < y2 else (ko.yMax(), ko.yMin())
                    out_ev.append(("PT", x1, yb))
                    out_ev.append(("PT", bypass_x, yb))
                    out_ev.append(("PT", bypass_x, yt))
                    out_ev.append(("PT", x2, yt))
                else:
                    xl, xr = (ko.xMin(), ko.xMax()) if x1 < x2 else (ko.xMax(), ko.xMin())
                    by = ko.yMin() - S - HW
                    out_ev.append(("PT", xl, y1))
                    out_ev.append(("PT", xl, by))
                    out_ev.append(("PT", xr, by))
                    out_ev.append(("PT", xr, y2))
                out_ev.append(("PT", x2, y2))
                i += 2
                continue
        out_ev.append(ev)
        i += 1
    if not hit:
        return False
    odb.dbWire.destroy(w)
    nw = odb.dbWire.create(net)
    e = odb.dbWireEncoder()
    e.begin(nw)
    for ev in out_ev:
        t = ev[0]
        if t == "PATH":
            e.newPath(ev[1], ev[2])
        elif t == "PT":
            e.addPoint(int(ev[1]), int(ev[2]))
        elif t == "TVIA":
            e.addTechVia(ev[1])
        elif t == "VIA":
            e.addVia(ev[1])
        elif t == "ITERM":
            e.addITerm(ev[1])
        elif t == "BTERM":
            e.addBTerm(ev[1])
        elif t == "RECT":
            e.addRect(int(ev[1]), int(ev[2]), int(ev[3]), int(ev[4]))
    e.end()
    # reindex new M2
    for ly, box in collect_shapes(net):
        if ly == "Metal2":
            add_idx(net.getName(), box)
            eco.append((net.getName(), box))
    foreign_jogs += 1
    print("  JOG", net.getName(), "keepout", um(ko.xMin()), um(ko.yMin()), um(ko.xMax()), um(ko.yMax()), flush=True)
    return True

def via_ok(pin, nn):
    return bool(via_candidates(pin, nn))

origins={}
for name in INSTS:
    inst=block.findInst(name)
    x,y=inst.getLocation(); origins[name]=(x,y)
    inst.setPlacementStatus("PLACED"); inst.setOrient("R180"); inst.setLocation(x,y)
    print("R180", name, um(x), um(y), flush=True)

def row_funcs(y0):
    out=[]
    for inst in block.getInsts():
        mn=inst.getMaster().getName()
        if is_fill(mn) or is_sram(mn): continue
        bb=inst.getBBox()
        if abs(bb.yMin()-y0)>50: continue
        out.append(inst)
    out.sort(key=lambda i: i.getLocation()[0])
    return out

def plan_shift(target, nx, y0, window):
    tw=target.getMaster().getWidth()
    dest_l, dest_r = nx, nx+tw
    win_l, win_r = window
    funcs=row_funcs(y0)
    prop={i.getName(): i.getLocation()[0] for i in funcs}
    tname=target.getName(); prop[tname]=nx
    for _ in range(30):
        moved=False
        tl,tr=dest_l,dest_r
        for nm,x in list(prop.items()):
            if nm==tname: continue
            inst=block.findInst(nm)
            a=x; b=x+inst.getMaster().getWidth()
            if b<=tl or a>=tr: continue
            if a+(b-a)/2 < (tl+tr)/2:
                new_x=int(round((tl-inst.getMaster().getWidth())/float(SW))*SW)
            else:
                new_x=int(round(tr/float(SW))*SW)
            if new_x==prop[nm]:
                new_x = prop[nm]-SW if a+(b-a)/2 < (tl+tr)/2 else prop[nm]+SW
            if new_x<win_l or new_x+inst.getMaster().getWidth()>win_r: return None
            if new_x!=prop[nm]:
                prop[nm]=new_x; moved=True
        ordered=sorted(prop.keys(), key=lambda n: prop[n])
        for i in range(len(ordered)-1):
            a,b=ordered[i], ordered[i+1]
            ia,ib=block.findInst(a), block.findInst(b)
            ar=prop[a]+ia.getMaster().getWidth()
            if ar>prop[b]+1:
                nxb=int(math.ceil(ar/float(SW))*SW)
                if nxb+ib.getMaster().getWidth()>win_r:
                    nxa=int(math.floor((prop[b]-ia.getMaster().getWidth())/float(SW))*SW)
                    if nxa<win_l: return None
                    if nxa!=prop[a]: prop[a]=nxa; moved=True
                elif nxb!=prop[b]:
                    prop[b]=nxb; moved=True
        if not moved: break
    else:
        return None
    items=sorted((prop[n], prop[n]+block.findInst(n).getMaster().getWidth(), n) for n in prop)
    for i in range(len(items)-1):
        if items[i][1]>items[i+1][0]+1: return None
    return prop

foreign_jogs=0
moved_func={}
rpt=open(OUT+"/co6a35_cluster.rpt","w")
rpt.write("cell k old_x new_x delta n_func_moved patches fails jogs\n")

for name in INSTS:
    inst=block.findInst(name)
    x0,y0=origins[name]
    cw=inst.getMaster().getWidth()
    win=(x0-KMAX*SW-cw, x0+cw+KMAX*SW)
    pick=None
    for ak in range(0, KMAX+1):
        ks=[0] if ak==0 else [ak,-ak]
        for k in ks:
            nx=x0+k*SW
            inst.setPlacementStatus("PLACED"); inst.setLocation(int(nx), int(y0))
            ok_all=True; nhit=nvia=0
            for it in inst.getITerms():
                pn=it.getMTerm().getName()
                if pn in SKIP: continue
                net=it.getNet()
                if net is None or net.getWire() is None: ok_all=False; break
                pin=pin_box(it)
                sh=collect_shapes(net)
                if pin_hit(pin, sh): nhit+=1
                elif via_ok(pin, net.getName()): nvia+=1
                else: ok_all=False; break
            inst.setLocation(int(x0), int(y0))
            if not ok_all: continue
            plan=plan_shift(inst, nx, y0, win)
            print("  VIA_OK", name, "k", k, "hits", nhit, "vias", nvia, "plan", bool(plan), flush=True)
            if plan is None: continue
            nmove=sum(1 for n,x in plan.items() if n!=name and abs(x-block.findInst(n).getLocation()[0])>1)
            pick=(k,nx,plan,nmove); break
        if pick: break
    if pick is None:
        print("NO_VIA_SITE_X", name, flush=True)
        rpt.write("%s NO_VIA_X\n"%name); continue
    k,nx,plan,nmove=pick
    # destroy fillers
    new_boxes=[]
    for nm,newx in plan.items():
        ci=block.findInst(nm)
        new_boxes.append((newx, newx+ci.getMaster().getWidth(), ci.getBBox().yMin(),
                          ci.getBBox().yMin()+ci.getMaster().getHeight()))
    kill=[]
    for o in list(block.getInsts()):
        if not is_fill(o.getMaster().getName()): continue
        ob=o.getBBox()
        for a,b,y1,y2 in new_boxes:
            if ob.xMax()<=a or b<=ob.xMin() or ob.yMax()<=y1 or y2<=ob.yMin(): continue
            kill.append(o); break
    for o in kill: odb.dbInst.destroy(o)
    for nm,newx in plan.items():
        ci=block.findInst(nm)
        ox,oy=ci.getLocation()
        ci.setPlacementStatus("PLACED")
        if abs(newx-ox)>1:
            ci.setLocation(int(newx), int(oy))
            if nm!=name:
                moved_func[nm]=(ox,newx)
                print("  MOVE_FUNC", nm, um(ox), "->", um(newx), "d", um(newx-ox), flush=True)
        ci.setPlacementStatus("FIRM")
    # connect + jog
    npatch=nfail=nj=0
    inst=block.findInst(name)
    for it in inst.getITerms():
        pn=it.getMTerm().getName()
        if pn in SKIP: continue
        net=it.getNet(); pin=pin_box(it)
        if net is None or net.getWire() is None:
            nfail+=1; print("FAIL", name, pn, "nonet", flush=True); continue
        sh=collect_shapes(net)
        kind, payload=find_patch(pin, net, sh)
        if kind=="FAIL" and payload=="no_path":
            # Jog only foreign M2 that crosses the pin, then retry.
            ko = odb.Rect(pin.xMin() - S, pin.yMin() - S, pin.xMax() + S, pin.yMax() + S)
            bl = blockers_for([ko], net.getName())
            seen = set()
            for onet, ob, g in bl:
                if onet in seen:
                    continue
                seen.add(onet)
                fn = block.findNet(onet)
                if fn is None:
                    continue
                if jog_foreign(fn, ko, net.getName()):
                    nj += 1
                    rebuild_idx()
            sh = collect_shapes(net)
            kind, payload = find_patch(pin, net, sh)
        if kind=="PATCH":
            nb,ln,pts,vert,vx,vy,rects=payload
            via_obj=via_vv if vert else via_vh
            try: encode(net, pts, via_obj, it)
            except Exception as ex:
                print("ENCODE_FAIL", name, pn, ex, flush=True); nfail+=1; continue
            for r in rects:
                eco.append((net.getName(), r)); add_idx(net.getName(), r)
            npatch+=1
            print("PATCH", name, pn, "bends", nb, "len", um(ln), flush=True)
        elif kind=="FAIL":
            nfail+=1; print("FAIL", name, pn, payload, flush=True)
        else:
            print("HIT", name, pn, flush=True)
    print("COMMIT", name, "k", k, "x", um(nx), "d", um(nx-x0), "func", nmove,
          "patches", npatch, "fails", nfail, "jogs", nj, flush=True)
    rpt.write("%s %d %.3f %.3f %.3f %d %d %d %d\n"%(name,k,um(x0),um(nx),um(nx-x0),nmove,npatch,nfail,nj))

rpt.close()
miss=0
for name in INSTS:
    inst=block.findInst(name)
    for it in inst.getITerms():
        pn=it.getMTerm().getName()
        if pn in SKIP: continue
        net=it.getNet()
        if not pin_hit(pin_box(it), [] if net is None else collect_shapes(net)):
            miss+=1
            print("STILL_MISS", name, pn, "-" if net is None else net.getName(), flush=True)
print("STILL_MISS_COUNT", miss, "FUNCTIONAL_CELLS_MOVED", len(moved_func),
      "FOREIGN_M2_JOGS", foreign_jogs, flush=True)
if moved_func:
    print("MAX_FUNC_DISPLACEMENT_UM", um(max(abs(b-a) for a,b in moved_func.values())), flush=True)
nshort=0
for nn,r in eco:
    for onet,ob in query(r,0):
        if onet!=nn and gap_euclid(r,ob)==0 and id(ob)!=id(r):
            nshort+=1; print("SHORT", nn, onet, flush=True)
print("PRESCREEN_SHORTS", nshort, flush=True)
n_mx=n_r180=n_r0=nsram=0
for inst in block.getInsts():
    mn=inst.getMaster().getName()
    if "sram256x8m8wm1" in mn: nsram+=1
    if mn.endswith("__aoi221_2"):
        o=str(inst.getOrient()); n_mx+=o=="MX"; n_r180+=o=="R180"; n_r0+=o=="R0"
print("AOI221_2 MX", n_mx, "R180", n_r180, "R0", n_r0, "SRAM", nsram,
      "BTERMS", len(list(block.getBTerms())), flush=True)
d.writeDb(CAND+"/butterfold_top_co6a35.odb")
d.writeDef(CAND+"/butterfold_top_co6a35.def")
print("WROTE_CO6A35", flush=True)
