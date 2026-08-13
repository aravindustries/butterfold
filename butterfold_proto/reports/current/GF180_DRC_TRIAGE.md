# GF180 GDS DRC triage

## Scope and provenance

This triage is bound to `physical/results/padframe/gds/butterfold_padframe_candidate.gds`, SHA-256 `a7820a96542f2b443ea2f5e44cf227d777583f751d031f629d542aea3fde8f4d`, top `butterfold_padframe_top`.

The source result is the installed GF180 Open_PDKs KLayout 0.30.8 variant-C main FEOL/BEOL/connectivity deck run in deep mode:

- report database: `physical/results/padframe/drc_gf180_serial/butterfold_padframe_candidate_main.lyrdb`;
- rule-count summary: `physical/results/padframe/drc_gf180_serial/violations.json`;
- installed runner: `/foss/pdks/gf180mcuD/libs.tech/klayout/tech/drc/run_drc.py`.

No waiver, exclusion, GDS edit, or physical repair was applied.

## Result and attribution limit

**TOTAL MARKERS: 37,494**  
**TOTAL RULE CATEGORIES: 54**

The KLayout report database names a source cell context for every marker, but 37,006 markers (98.70%) are emitted in the flattened `butterfold_padframe_top` context. Only 488 markers retain a named foundry-leaf context. The official deck/report therefore does not preserve enough hierarchy to distinguish top-created integration polygons from flattened standard-cell, SRAM, I/O, or interaction geometry for the dominant marker population.

| Attribution established directly by the report | Markers |
| --- | ---: |
| True ButterFold top-level markers | **UNKNOWN (0 proven)** |
| Padframe / PDN markers | **UNKNOWN (0 proven)** |
| Standard-cell-internal, named leaf context | **64** |
| SRAM-internal, named leaf context | **0** |
| I/O-cell/bond-pad-internal, named leaf context | **424** |
| Configuration-related | **0 proven** |
| Unknown flattened top context | **37,006** |
| **Total** | **37,494** |

The zeroes above mean “not positively established,” not “verified absent.” In particular, SRAM geometry may contribute to markers flattened into the top context.

## Ranked rule table

Because the report loses source hierarchy for most markers, every category remains classification **G (UNKNOWN)** at category level. Rule names describe the violated geometry, not who authored that geometry.

| Rank | Rule | Markers | Classification |
| ---: | --- | ---: | --- |
| 1 | DF.13_MV | 14,410 | G |
| 2 | DF.14_MV | 11,355 | G |
| 3 | NW.2b_LV | 961 | G |
| 4 | PP.5b | 806 | G |
| 5 | DF.3b | 735 | G |
| 6 | PP.5dii | 642 | G |
| 7 | NP.2 | 573 | G |
| 8 | PP.2 | 561 | G |
| 9 | NP.3d | 544 | G |
| 10 | DF.4c_MV | 516 | G |
| 11 | LPW.12 | 486 | G |
| 12 | CO.10 | 465 | G |
| 13 | M1.2a | 458 | G |
| 14 | NP.3e | 442 | G |
| 15 | CUP.3 | 406 | G |
| 16 | PP.3d | 387 | G |
| 17 | PP.5di | 362 | G |
| 18 | DV.5 | 324 | G |
| 19 | PP.3e | 319 | G |
| 20 | CO.1 | 280 | G |
| 21 | NW.2a_LV | 210 | G |
| 22 | PL.2_MV | 193 | G |
| 23 | PL.12 | 162 | G |
| 24 | PP.12 | 162 | G |
| 25 | DF.17_MV | 156 | G |
| 26 | NP.5b | 156 | G |
| 27 | CO.2a | 139 | G |
| 28 | NW.4 | 135 | G |
| 29 | PP.5a | 124 | G |
| 30 | DF.16_MV | 119 | G |
| 31 | DF.4d_MV | 112 | G |
| 32 | NP.6 | 111 | G |
| 33 | PL.4_MV | 102 | G |
| 34 | NW.2b_MV | 96 | G |
| 35 | CO.4 | 71 | G |
| 36 | NP.12 | 45 | G |
| 37 | NP.5a | 39 | G |
| 38 | CO.3 | 33 | G |
| 39 | DF.3a_MV | 33 | G |
| 40 | CO.8 | 29 | G |
| 41 | DF.6_MV | 28 | G |
| 42 | NP.5dii | 27 | G |
| 43 | NP.5di | 22 | G |
| 44 | DV.6 | 21 | G |
| 45 | PL.5a_MV | 20 | G |
| 46 | PL.5b_MV | 20 | G |
| 47 | CO.7 | 19 | G |
| 48 | CO.9 | 17 | G |
| 49 | PP.6 | 17 | G |
| 50 | NP.8b | 16 | G |
| 51 | DV.7 | 15 | G |
| 52 | PP.8b | 5 | G |
| 53 | DV.3 | 5 | G |
| 54 | DF.13_LV | 3 | G |

## Official-flow evidence checked

- The PDK DRC README documents flat/deep execution and marker-browser review, but no hardened-cell waiver or instance-attribution mode.
- The GF180 LibreLane base configuration exposes `DRC_EXCLUDE_CELL_LIST`.
- The selected `gf180mcu_fd_sc_mcu9t5v0` configuration has no populated `drc_exclude.cells` file and no documented standard-cell, SRAM, or I/O waiver set was found in the installed configuration.
- Deep mode does not preserve source hierarchy for the 37,006 top-context markers produced by this deck.

## Automation gap and disposition

The requested attribution cannot be completed through the installed standard automation. Completing it would require either an official GF180 hardened-cell exclusion/waiver methodology or a geometry-aware correlation of marker coordinates with source cell shapes. The latter is explicitly outside this task’s no-custom-analysis policy.

Therefore physical repair was stopped before modifying PDN, routing, antenna, taps, ODB/DEF, or GDS. The existing separate pad/core supplies, three PDN via failures, and 24 antenna markers remain real open findings, but changing physical geometry before resolving the dominant DRC provenance would violate the required phase ordering.

**CURRENT FULL-GDS DRC STATUS: PARTIALLY CLASSIFIED — FAIL**
