# 11 — ACH validation dashboard

# RESIZED ACH VALIDATION INTEGRATION COMPLETE

Outer GDS **1110 × 1675 µm** is the intentional ACH validation envelope.
Compact implementation CORE `6.72 20.16 1085.84 1088.64` (≤1110 × 1110).
Zero rows above y = 1088.64 µm.

Canonical resized ACH validation GDS on this branch:
`gds/butterfold_top.gds` SHA
`93f2aba11dab0df4e3c9431ff2e2c060fce066da17924ad1ed2657b19e4e5dd7`.
Previous main/pre-ACH baseline SHA `f193cb1b…` is historical only.

This is **not** `FULL TEAM-SIDE SIGNOFF COMPLETE` for a 1110 × 1110 participant
die. Final D03_A integration remains **PENDING**.

| Check | Status | Result | Report | Evidence |
|---|---|---|---|---|
| ACH DEF/template | **PASS** | 23 BTERMs, 21/21 functional, VDD/VSS geometry | [00_template](00_template_apply.md) | [template_pins.rpt](evidence/template/template_pins.rpt) |
| ACH outer GDS | **PASS** | exactly 1110 × 1675 µm | [00](00_manifest.md) | [gds_sha_bbox.rpt](evidence/gds/gds_sha_bbox.rpt) |
| Internal compact core | **PASS** | ≤1110 × 1110; 212 unique Y; 0 rows above 1088.64 | [00](00_manifest.md) | [core_rows_sram.rpt](evidence/floorplan/core_rows_sram.rpt) |
| Functional regression | **PASS** | FINAL-PIN OVERALL RESULT PASS; RESET-RECOVERY PASS | [12](12_functional.md) | [log](evidence/functional/interval10_regression.log) |
| Max-SS setup | **PASS** | worst MET **+3.88 ns**, WNS 0, TNS 0, 0 viol | [01](01_setup_max_ss.md) | [summary](evidence/setup/max_ss_setup_summary.rpt) |
| Min-FF hold | **PASS** | worst MET **+0.08 ns**, WNS 0, TNS 0, 0 viol | [02](02_hold_min_ff.md) | [summary](evidence/hold/min_ff_hold_summary.rpt) |
| Electrical | **PASS** | slew/cap/fanout = 0 | [03](03_electrical.md) | [extract_elec.log](evidence/electrical/extract_elec.log) / [fanout](evidence/electrical/fanout.rpt) |
| Reset | **PASS** | slew/cap = 0 | [04](04_reset.md) | [violators](evidence/reset/reset_visible_violators.rpt) |
| Routing | **PASS** | GRT 0, DRT 0, opens/shorts/unrouted 0 | [08](08_routing_pg_ir.md) | [GRT](evidence/routing/grt_summary.rpt) / [DRT](evidence/routing/drt_summary.rpt) |
| PG | **PASS** | VDD/VSS connected (PSM all shapes) | [08](08_routing_pg_ir.md) | [psm](evidence/pg/psm_connectivity.rpt) |
| Antenna | **PASS** | 0 nets / 0 pins, **7** diodes | [05](05_antenna.md) | [OpenROAD](evidence/antenna/openroad_check_antennas.rpt) |
| Non-fill DRC | **PASS** | 0 items, CO.6a = 0 | [06](06_drc.md) | [summary](evidence/drc/non_fill_drc_summary.rpt) |
| DCF.1d | **PASS** | 23.56% ≤ 70% (full 1110×1675) | [06](06_drc.md) | [density](evidence/density/official_full_envelope_summary.rpt) |
| DCF.1b | **BELOW NOMINAL THRESHOLD ON ACH VALIDATION ENVELOPE** | 23.56% < 25% | [06](06_drc.md) | [density](evidence/density/official_full_envelope_summary.rpt) |
| Poly2 PL.8 | **PASS** | 17.93% ≥ 14% | [06](06_drc.md) | [density](evidence/density/official_full_envelope_summary.rpt) |
| M1.4 | **BELOW NOMINAL THRESHOLD ON ACH VALIDATION ENVELOPE** | 21.71% < 30% | [06](06_drc.md) | [density](evidence/density/official_full_envelope_summary.rpt) |
| M2.4–MT.3 | **INTEGRATOR FILL PENDING** | 13.08 / 16.41 / 2.49 / 2.53 / 2.53 % | [06](06_drc.md) | [density](evidence/density/official_full_envelope_summary.rpt) |
| MSLOT | **PASS** | 0 items | [06](06_drc.md) | [lyrdb](evidence/mslot/mslot_unified.lyrdb) |
| Full device-level LVS | **PASS** | uniquely matched; **11537** devices / **11552** nets; 2 SRAM | [07](07_lvs.md) | [summary](evidence/lvs/lvs_summary.rpt) |
| IR | **CHARACTERIZED** | VDD **0.149 V**, VSS **0.088 V** | [08](08_routing_pg_ir.md) | [IR](evidence/ir/irdrop_summary.rpt) |
| Power | **INFO** | **0.134196 W** vectorless, no VCD/SAIF | [09](09_power.md) | [power](evidence/power/vectorless_power.rpt) |
| Final D03_A integration | **PENDING** | D03_A.def not available; pad controls pending | [10](10_final_artifacts.md) | — |

Full-envelope ACH density reflects the intentional 1110 × 1675 validation
extent; DCF.1b and M1.4 are below standalone team thresholds on this
validation artifact. Do not treat a 1110 × 1110 clip as official.
