#!/usr/bin/env python3
"""Ignore occupancy: which same-row X give all 6 R180 pins legal 0.28 um access?"""
from __future__ import annotations
import math
from collections import defaultdict
from openroad import Tech, Design
import odb

PDK = "/foss/pdks/gf180mcuD"
CAND = "physical/results/d03_ach_candidate"
INSTS = [
    "_11280_", "_11106_", "_11366_", "_11339_", "_11136_",
    "_11474_", "_11394_", "_11408_", "_11241_",
]
SKIP = {"VDD", "VSS", "VNW", "VPW"}

tech = Tech()
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef")
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef")
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef")
d = Design(tech)
d.readDb(CAND + "/butterfold_top_pgfix.odb")
db = tech.getDB()
block = db.getChip().getBlock()
ttech = db.getTech()
m2 = ttech.findLayer("Metal2")
via_vv = ttech.findVia("Via1_VV")
via_vh = ttech.findVia("Via1_VH")
dbu = block.getDefUnits()
SW = block.getRows()[0].getSite().getWidth()
W = int(round(0.28 * dbu)); HW = W // 2; S = int(round(0.28 * dbu))
WIDE = int(round(10.0 * dbu)); GRID = 10; STEP = 280
print("DBU", dbu, "SITE", SW / dbu, flush=True)

def um(v):
    return v / float(dbu)
def snap(v, g=GRID):
    return int(round(v / float(g)) * g)
def overlaps(a, b, slack=0):
    return not (a.xMax() < b.xMin() - slack or b.xMax() < a.xMin() - slack
                or a.yMax() < b.yMin() - slack or b.yMax() < a.yMin() - slack)
def gap_euclid(a, b):
    dx = 0 if not (a.xMax() < b.xMin() or b.xMax() < a.xMin()) else (b.xMin()-a.xMax() if a.xMax()<b.xMin() else a.xMin()-b.xMax())
    dy = 0 if not (a.yMax() < b.yMin() or b.yMax() < a.yMin()) else (b.yMin()-a.yMax() if a.yMax()<b.yMin() else a.yMin()-b.yMax())
    if dx==0 and dy==0: return 0
    if dx==0: return dy
    if dy==0: return dx
    return int(round(math.hypot(dx, dy)))

BIN=2000
idx=defaultdict(list)
def add_idx(nn, r):
    for bx in range(r.xMin()//BIN, r.xMax()//BIN+1):
        for by in range(r.yMin()//BIN, r.yMax()//BIN+1):
            idx[(bx,by)].append((nn,r))
def query(win, slack=S):
    seen,out=set(),[]
    for bx in range((win.xMin()-slack)//BIN, (win.xMax()+slack)//BIN+1):
        for by in range((win.yMin()-slack)//BIN, (win.yMax()+slack)//BIN+1):
            for rec in idx.get((bx,by),()):
                k=id(rec[1])
                if k in seen: continue
                seen.add(k)
                if overlaps(win, rec[1], slack=slack):
                    out.append(rec)
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

def legal(rect, nn):
    win=odb.Rect(rect.xMin()-S-20, rect.yMin()-S-20, rect.xMax()+S+20, rect.yMax()+S+20)
    for onet,ob in query(win, S+20):
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

def pin_hit(pin, shapes):
    for _ly,box in shapes:
        if overlaps(pin, box, slack=1):
            return True
    return False

def via_ok_on_pin(pin, nn):
    pad=400
    x=snap(pin.xMin()-pad)
    while x<=pin.xMax()+pad:
        y=snap(pin.yMin()-pad)
        while y<=pin.yMax()+pad:
            for vert in (True, False):
                if overlaps(via_m1(x,y,vert), pin, slack=0) and legal(via_m2(x,y,vert), nn):
                    return True
            y+=STEP
        x+=STEP
    return False

def eval_pins(inst):
    hits=vias=fails=0
    miss=[]
    for it in inst.getITerms():
        pn=it.getMTerm().getName()
        if pn in SKIP: continue
        net=it.getNet()
        bb=it.getBBox()
        pin=odb.Rect(bb.xMin(), bb.yMin(), bb.xMax(), bb.yMax())
        if net is None:
            fails+=1; miss.append(pn+":nonet"); continue
        sh=collect_shapes(net)
        if pin_hit(pin, sh):
            hits+=1
        elif via_ok_on_pin(pin, net.getName()):
            vias+=1
        else:
            fails+=1
            miss.append(pn)
    return hits, vias, fails, miss

for name in INSTS:
    inst=block.findInst(name)
    x,y=inst.getLocation()
    inst.setPlacementStatus("PLACED")
    inst.setOrient("R180")
    inst.setLocation(x,y)

# ±2 cell widths = 21*2 sites
NS=42
print("SCAN k=-%d..+%d" % (NS,NS), flush=True)
for name in INSTS:
    inst=block.findInst(name)
    x0,y0=inst.getLocation()
    zeros=[]
    best=None
    for k in range(0, NS+1):
        ks=[k] if k==0 else [k,-k]
        for kk in ks:
            if kk<-NS or kk>NS: continue
            nx=x0+kk*SW
            inst.setLocation(int(nx), int(y0))
            h,v,f,miss=eval_pins(inst)
            rec=(f, -(h+v), abs(kk), kk)
            if best is None or rec<best:
                best=(f,h,v,kk,miss)
            if f==0:
                zeros.append((kk, h, v))
                if abs(kk)<=8:
                    pass
    inst.setLocation(int(x0), int(y0))
    print("CELL", name, "best_fails", best[0], "k", best[3], "hits", best[1], "viasites", best[2],
          "miss", ",".join(best[4]), "n_zero_fail_X", len(zeros),
          "zero_k", [z[0] for z in zeros[:12]], flush=True)
print("SCAN_DONE", flush=True)
