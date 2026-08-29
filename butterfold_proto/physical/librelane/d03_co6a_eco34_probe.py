#!/usr/bin/env python3
"""Probe same-row filler/whitespace for the nine aoi221_2 cells."""
from openroad import Tech, Design
import odb

PDK = "/foss/pdks/gf180mcuD"
CAND = "physical/results/d03_ach_candidate"
INSTS = [
    "_11280_", "_11106_", "_11366_", "_11339_", "_11136_",
    "_11474_", "_11394_", "_11408_", "_11241_",
]
FILL_PREF = ("__fill_", "__fillcap_")
FILL_OK = ("__fill_", "__fillcap_", "__filltie", "__endcap")

tech = Tech()
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef")
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef")
tech.readLef(PDK + "/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef")
d = Design(tech)
d.readDb(CAND + "/butterfold_top_pgfix.odb")
block = tech.getDB().getChip().getBlock()
dbu = block.getDefUnits()
sites = list(block.getRows())
print("DBU", dbu, "NROWS", len(sites), "CORE", block.getCoreArea().xMin(), block.getCoreArea().yMin())
row0 = block.getRows()[0]
site = row0.getSite()
print("SITE", site.getName(), "W", site.getWidth(), "H", site.getHeight(),
      "um", site.getWidth() / float(dbu), site.getHeight() / float(dbu))
print("ROW0", row0.getName(), "orig", row0.getOrigin(), "orient", row0.getOrient(),
      "nsites", row0.getSiteCount())

SW = site.getWidth()
SH = site.getHeight()
RAD = int(round(20.0 * dbu))
CELLW = None


def um(v):
    return v / float(dbu)


def is_fill(mn, strict=False):
    keys = FILL_PREF if strict else FILL_OK
    return any(k in mn for k in keys)


# spatial: instances by row y
by_y = {}
for inst in block.getInsts():
    bb = inst.getBBox()
    by_y.setdefault(bb.yMin(), []).append(inst)

for name in INSTS:
    inst = block.findInst(name)
    bb = inst.getBBox()
    x, y = inst.getLocation()
    CELLW = inst.getMaster().getWidth()
    CELLH = inst.getMaster().getHeight()
    print("\nCELL", name, inst.getMaster().getName(), inst.getOrient(),
          "xy", um(x), um(y), "bbox", um(bb.xMin()), um(bb.yMin()), um(bb.xMax()), um(bb.yMax()),
          "w_sites", CELLW / SW, "h_sites", CELLH / SH)
    row_insts = by_y.get(bb.yMin(), [])
    # classify occupancy in ±20um on this row
    x0 = x - RAD
    x1 = x + CELLW + RAD
    fills = funcs = ties = 0
    for o in row_insts:
        if o.getName() == name:
            continue
        ob = o.getBBox()
        if ob.xMax() < x0 or ob.xMin() > x1:
            continue
        mn = o.getMaster().getName()
        if is_fill(mn, strict=True):
            fills += 1
        elif "__filltie" in mn or "__endcap" in mn:
            ties += 1
        else:
            funcs += 1
            if funcs <= 8:
                print("  FUNC", o.getName(), mn, um(ob.xMin()), um(ob.xMax()))
    print("  nearby fills", fills, "ties/endcap", ties, "functional", funcs)
    # candidate X: only fillers (strict) overlapping dest
    n_ok = n_tie = n_func = 0
    n_sites = int(RAD // SW)
    for k in range(-n_sites, n_sites + 1):
        nx = x + k * SW
        dest = odb.Rect(nx, y, nx + CELLW, y + CELLH)
        bad_func = bad_tie = False
        for o in row_insts:
            if o.getName() == name:
                continue
            ob = o.getBBox()
            if ob.xMax() <= dest.xMin() or dest.xMax() <= ob.xMin():
                continue
            mn = o.getMaster().getName()
            if is_fill(mn, strict=True):
                continue
            if "__filltie" in mn or "__endcap" in mn:
                bad_tie = True
            else:
                bad_func = True
                break
        if bad_func:
            n_func += 1
        elif bad_tie:
            n_tie += 1
        else:
            n_ok += 1
            if abs(k) <= 2 or n_ok <= 6:
                print("  OK_X k=%d x=%.3f dx=%.3f" % (k, um(nx), um(k * SW)))
    print("  candidates fill-only", n_ok, "tie-only-block", n_tie, "func-block", n_func)

print("PROBE_DONE")
