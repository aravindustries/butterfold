# 06 — Foundry DRC / density / mslot

## Result

**FAIL** — density. Official dummy fill did **not** close coverage.

| Rule | After official `fill_all.rb` |
|---|---|
| M2.4 | **FAIL** |
| M3.4 | **FAIL** |
| M4.4 | **FAIL** |
| M5.4 | **FAIL** |
| MT.3 | **FAIL** |

Pre-dummy KLayout run (53 tables): only those five density rules failed;
geometry/via/SRAM/antenna tables were 0 items.

`mslot.drc` **crashed** in this open_pdks revision (`via_below.sized` on nil
at metal1 in split-table mode). MSLOT is **not signed off**.

## PDK fill audit

- open_pdks `7b70722e33c03fcb5dabcf4d479fb0822d9251c9`
- Official script: `$PDKPATH/libs.tech/klayout/tech/drc/filler_generation/fill_all.rb`
- LibreLane `KLAYOUT_FILLER_SCRIPT` unset → Classic skips `KLayout.Filler`
- Invoked native KLayout the same way `KLayout.Filler` would:

```
klayout -b -zz -r fill_all.rb -rd input=<pre_dummy.gds> -rd output=<dummy_filled.gds>
```

Dummy layers after fill (native density log): metal2_dummy 174, metal3_dummy
497, metal4_dummy 2756, metal5_dummy 39193 polygons. Coverage still < 30%.

Dummy fill is GDS datatype 4. OpenRCX extracts routed LEF metals from the
ODB, not GDS dummy. Timing SPEFs are unchanged by this fill.

## Command / native step

Density-only DRC on dummy-filled GDS: `run_drc.py --density_only --table=density --variant=D --topcell=butterfold_top`.

## Evidence

| Item | Path |
|---|---|
| Pre-dummy foundry DRC errors | [evidence/drc/klayout_drc_summary.rpt](evidence/drc/klayout_drc_summary.rpt) |
| Official fill log | [evidence/drc/dummy_fill.log](evidence/drc/dummy_fill.log) |
| Density DRC after dummy fill | [evidence/drc/density.rpt](evidence/drc/density.rpt) |
| mslot crash (pre-dummy full DRC) | [evidence/drc/mslot.rpt](evidence/drc/mslot.rpt) |

- Tool: KLayout 0.30.8 / GF180 `run_drc.py`
- Pre-dummy GDS SHA `5a99213a…`
- Dummy-filled GDS SHA `e02fb870…` (not promoted)

## Status

Density: **FAIL** (hard stop: official fill cannot satisfy 30%).  
MSLOT: **FAIL** (deck crash; not N/A).  
Other pre-dummy tables: 0 items.

Canonical GDS not promoted.
