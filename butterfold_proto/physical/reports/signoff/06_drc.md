# 06 — Foundry DRC / density / mslot

## Result

Chipathon guidance: **minimum-clear / maximum-metal must pass on the team
GDS**; **minimum-metal fill is integrator-side** (or later fill here), not a
team dummy-fill closure task.

Pre-fill GDS SHA `5a99213aa4de522a96d3d83cae5651fbab961b8032b313d6e2420eba3dc9b8c6`.

| Check | Official rule | Pre-fill | Classification |
|---|---|---|---|
| COMP max (clear) | DCF.1d ≤ 70% | 36.18% | **PASS** |
| COMP min | DCF.1b ≥ 25% | 36.18% | **PASS** |
| Poly2 min | PL.8 ≥ 14% | 27.54% | **PASS** |
| Metal1 min | M1.4 > 30% | 33.29% | **PASS** |
| Metal2 min | M2.4 > 30% | 19.03% | **INTEGRATOR FILL PENDING** |
| Metal3 min | M3.4 > 30% | 24.25% | **INTEGRATOR FILL PENDING** |
| Metal4 min | M4.4 > 30% | 3.40% | **INTEGRATOR FILL PENDING** |
| Metal5 min | M5.4 > 30% | 3.90% | **INTEGRATOR FILL PENDING** |
| MetalTop min (5LM = Metal5) | MT.3 > 30% | 3.90% | **INTEGRATOR FILL PENDING** |
| Other KLayout tables (pre-fill, 53 tables) | geometry/via/SRAM/antenna | 0 items | **PASS** |
| MSLOT | MSLOT.0–.9 on Metal1–Metal5 | 0 items | **PASS** |

The official `density.drc` has **no maximum-metal / min-clear rule on M2–MT**.
The only maximum-density rule in that deck is **DCF.1d (COMP ≤ 70%)**. It
executed with no `[ERROR]`. Metal clear fractions on the pre-fill GDS are
66–97% (sparse, not over-filled).

## Chipathon vs foundry min-metal

M2.4 / M3.4 / M4.4 / M5.4 / MT.3 remain `[ERROR]` in the native density deck
because global coverage is below 30%. The deck comments say dummy metal must
be added to meet those minima. Organizer: integrators (or a later fill step)
will add fill. **Do not treat those five minima as a team dummy-fill hard
stop.** They are **not waived**; they are **not closed by team fill**.

Prior official `fill_all.rb` experiment is preserved (dummy polygons appeared;
minima still failed). That GDS SHA `e02fb870…` was not promoted.

## MSLOT

Split-table `run_drc.py --mp --table=mslot` **crashes** in this PDK revision:
`via_below.sized` on nil because `layers_def.drc` does not load `contact` when
`TABLE_NAME=mslot`. That crash is preserved as evidence and is **not** a PASS.

Official single-deck invocation (same `mslot.drc`, `table_name=main` so
contact/via1–via4 load) **completed** on the pre-fill GDS:

- Metal1–Metal5 each ran MSLOT.0–.9
- lyrdb **0 items**
- no `[ERROR]`

## Command / native step

Density-only on **pre-fill** GDS:

```
python3 $PDKPATH/libs.tech/klayout/tech/drc/run_drc.py \
  --path=<pre_dummy.gds> --variant=D --density_only --table=density \
  --topcell=butterfold_top --run_mode=flat
```

MSLOT unified (official `main.drc` + `mslot.drc` + `tail.drc`, `-rd table_name=main`).

## Evidence

| Item | Path |
|---|---|
| Native pre-fill density log (ratios + errors) | [evidence/drc/density_prefill.rpt](evidence/drc/density_prefill.rpt) |
| Compact pre-fill density excerpt | [evidence/drc/density_prefill_summary.rpt](evidence/drc/density_prefill_summary.rpt) |
| Pre-fill density lyrdb | [evidence/drc/density_prefill.lyrdb](evidence/drc/density_prefill.lyrdb) |
| Pre-fill other-table errors (only the five min-metal rules) | [evidence/drc/klayout_drc_summary.rpt](evidence/drc/klayout_drc_summary.rpt) |
| MSLOT PASS (unified, table_name=main) | [evidence/drc/mslot_pass.rpt](evidence/drc/mslot_pass.rpt) |
| MSLOT PASS lyrdb (0 items) | [evidence/drc/mslot_unified.lyrdb](evidence/drc/mslot_unified.lyrdb) |
| MSLOT PASS full log | [evidence/drc/mslot_unified.log](evidence/drc/mslot_unified.log) |
| Split-table MSLOT crash (preserved) | [evidence/drc/mslot.rpt](evidence/drc/mslot.rpt) |
| Official fill experiment (preserved, not used for signoff) | [evidence/drc/dummy_fill.log](evidence/drc/dummy_fill.log) / [density.rpt](evidence/drc/density.rpt) |

- Tool: KLayout 0.30.8 / GF180 `run_drc.py` / `mslot.drc`
- PDK: gf180mcuD, open_pdks `7b70722e33c03fcb5dabcf4d479fb0822d9251c9`
- Input: pre-dummy GDS SHA `5a99213a…`

## Status

Max/clear density: **PASS** (DCF.1d).  
Min-metal M2–MT: **INTEGRATOR FILL PENDING**.  
MSLOT: **PASS** (unified official deck).  
Other pre-fill tables: 0 items.  
Canonical GDS not promoted (KLayout LVS still FAIL; min-metal still ERROR in the foundry density deck).
