# 11 — m2-fix ACH validation dashboard

# M2-FIX ACH VALIDATION INTEGRATION COMPLETE

Outer GDS **1110 × 1675 µm** is the intentional ACH validation envelope.
Compact implementation CORE `6.72 20.16 1085.84 1088.64` (≤1110 × 1110).
Organizer Metal2 keep-out **(0, 0)–(2.0, 65.0) µm** is empty of Metal2.

Canonical m2-fix ACH validation GDS on this branch:
`gds/butterfold_top.gds` SHA
`af6758ea9759ce7d48cb3b78bfea4cb13fdba6af8b18af94d56e73a09e6c8cd3`.
Previous ACH SHA `93f2aba1…` is historical on `main`.

This is **not** `FULL TEAM-SIDE SIGNOFF COMPLETE` for a 1110 × 1110 participant
die. Final D03_A integration remains **PENDING**.

| Check | Status | Result | Report | Evidence |
|---|---|---|---|---|
| New organizer DEF / M2 keep-out | **PASS** | 1 Metal2 rect (0,0)–(2.0,65.0) µm; pins unchanged | [delta](organizer_def_delta.md) | [manifest](m2_obstruction_manifest.md) |
| ACH DEF/template | **PASS** | 23 BTERMs, 21/21 functional, VDD/VSS, M2 1/1 | [00_template](00_template_apply.md) | [template_pins.rpt](evidence/template/template_pins.rpt) |
| OpenDB blockage import | **PASS** | OPENDB_M2_BLOCKAGE_MATCH 1/1 | [00_template](00_template_apply.md) | [opendb](evidence/template/opendb_m2_blockage.rpt) |
| Final GDS M2 keep-out | **PASS** | 0 violating regions, 0 polygons, 0 µm² | [06](06_drc.md) | [final](evidence/m2_audit/final_m2_intersection.json) |
| ACH outer GDS | **PASS** | exactly 1110 × 1675 µm | [00](00_manifest.md) | [gds_sha_bbox.rpt](evidence/gds/gds_sha_bbox.rpt) |
| Internal compact core | **PASS** | ≤1110 × 1110; 0 rows above 1088.64 | [00](00_manifest.md) | [core_rows_sram.rpt](evidence/floorplan/core_rows_sram.rpt) |
| Functional regression | **PASS** | FINAL-PIN OVERALL RESULT PASS; RESET-RECOVERY PASS | [12](12_functional.md) | [log](evidence/functional/interval10_regression.log) |
| Max-SS setup | **PASS** | WNS **+0.119382 ns**, TNS 0, 0 viol | [01](01_setup_max_ss.md) | [summary](evidence/setup/max_ss_setup_summary.rpt) |
| Min-FF hold | **PASS** | WNS **+0.180110 ns**, TNS 0, 0 viol | [02](02_hold_min_ff.md) | [summary](evidence/hold/min_ff_hold_summary.rpt) |
| Electrical | **PASS** | slew/cap/fanout = 0 | [03](03_electrical.md) | [extract_elec.log](evidence/electrical/extract_elec.log) |
| Reset | **PASS** | slew/cap/fanout = 0 | [04](04_reset.md) | [violators](evidence/reset/reset_visible_violators.rpt) |
| Routing | **PASS** | GRT 0, DRT 0, opens/shorts/unrouted 0 | [08](08_routing_pg_ir.md) | [GRT](evidence/routing/grt_summary.rpt) / [DRT](evidence/routing/drt_summary.rpt) |
| PG | **PASS** | VDD/VSS connected (PSM all shapes) | [08](08_routing_pg_ir.md) | [psm](evidence/pg/psm_connectivity.rpt) |
| Antenna | **PASS** | 0 nets / 0 pins, **3** diodes | [05](05_antenna.md) | [OpenROAD](evidence/antenna/openroad_check_antennas.rpt) |
| Non-fill DRC | **PASS** | 0 items, CO.6a = 0 | [06](06_drc.md) | [summary](evidence/drc/non_fill_drc_summary.rpt) |
| DCF.1d | **PASS** | 23.75% ≤ 70% (full 1110×1675) | [06](06_drc.md) | [density](evidence/density/official_full_envelope_summary.rpt) |
| DCF.1b | **BELOW NOMINAL THRESHOLD ON ACH VALIDATION ENVELOPE** | 23.75% < 25% | [06](06_drc.md) | [density](evidence/density/official_full_envelope_summary.rpt) |
| Poly2 PL.8 | **PASS** | 18.06% ≥ 14% | [06](06_drc.md) | [density](evidence/density/official_full_envelope_summary.rpt) |
| M1.4 | **BELOW NOMINAL THRESHOLD ON ACH VALIDATION ENVELOPE** | 21.77% < 30% | [06](06_drc.md) | [density](evidence/density/official_full_envelope_summary.rpt) |
| M2.4–MT.3 | **INTEGRATOR FILL PENDING** | 13.42 / 16.59 / 2.34 / 2.67 / 2.67 % | [06](06_drc.md) | [density](evidence/density/official_full_envelope_summary.rpt) |
| MSLOT | **PASS** | 0 items (BEOL-enabled unified deck) | [06](06_drc.md) | [lyrdb](evidence/mslot/mslot_unified.lyrdb) |
| Full device-level LVS | **PASS** | uniquely matched; **11621** devices / **11640** nets; 2 SRAM | [07](07_lvs.md) | [summary](evidence/lvs/lvs_summary.rpt) |
| IR | **CHARACTERIZED** | VDD **0.153 V**, VSS **0.090 V** | [08](08_routing_pg_ir.md) | [IR](evidence/ir/irdrop_summary.rpt) |
| Power | **INFO** | **0.136970 W** vectorless, no VCD/SAIF | [09](09_power.md) | [power](evidence/power/vectorless_power.rpt) |
| Final D03_A integration | **PENDING** | D03_A.def not available; pad controls pending | [10](10_final_artifacts.md) | — |

Full-envelope ACH density reflects the intentional 1110 × 1675 validation
extent; DCF.1b and M1.4 are below standalone team thresholds on this
validation artifact. Do not treat a 1110 × 1110 clip as official.
