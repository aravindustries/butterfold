# 10 — Final artifact manifest (m2-fix)

**M2-FIX ACH VALIDATION INTEGRATION COMPLETE**

This is the **canonical m2-fix ACH validation GDS** on `m2-fix`
(`ACH_VALIDATION_ONLY` + organizer Metal2 keep-out), not the final D03_A
manufacturing GDS. Previous ACH SHA `93f2aba1…` is historical on `main`.

| Item | Path / value |
|---|---|
| Branch | `m2-fix` |
| ORIGINAL_MAIN_HEAD | `f56df5a94c1a020510612e7709794a5e1a66671e` |
| Organizer package | https://github.com/user-attachments/files/31645362/D03.def.tgz |
| PACKAGE_SHA256 | `c14172c2129b8a25622aa9129578229995d421a763423f15255b70bf065f9978` |
| Organizer DEF | `../D03.def/D03/project_defs/ACH/D03_ACH.def` |
| Organizer DEF SHA | `79bd0dcad427802b4ad71ab030a0c649b9ead74354ce6e0ee58d16c73cff2f99` |
| Validation template | `physical/librelane/d03_ach_user_template.def` |
| Template SHA | `112db498d3fb2fa277771376687d212ef9c1a58b10bdb253b615ec17223d0909` |
| Candidate GDS | `physical/results/m2_fix/candidate/butterfold_top.gds` |
| Candidate SHA | `af6758ea9759ce7d48cb3b78bfea4cb13fdba6af8b18af94d56e73a09e6c8cd3` |
| Canonical GDS | `gds/butterfold_top.gds` |
| Canonical SHA | `af6758ea9759ce7d48cb3b78bfea4cb13fdba6af8b18af94d56e73a09e6c8cd3` |
| Same GDS | **YES** (byte-identical after promote) |
| Outer bbox | **1110 × 1675 µm** |
| Internal CORE | `6.72 20.16 1085.84 1088.64` (1079.12 × 1068.48 µm) |
| SRAM count | **2** at (51.120, 720.560) and (531.120, 720.560) |
| Metal2 keep-out | (0, 0)–(2.0, 65.0) µm; final intersection **0** |
| Powered netlist | `physical/results/m2_fix/butterfold_top.final.pnl.v` |
| SPEF (STA of record) | `physical/results/m2_fix/spef/filled.{max,min}.spef` |
| STA corners | `max_ss_125C_4v50` (setup / electrical / reset / power), `min_ff_n40C_5v50` (hold) |
| Final D03_A.def | **NOT AVAILABLE** |
| Pad controls | **PENDING_FINAL_D03_A_DEF** |

Heavy ODB/SPEF/Magic spice remain under `physical/results/` (not recommended for git).

## Native evidence (copied into this package)

| Check | Evidence |
|---|---|
| Organizer delta | [organizer_def_delta.md](organizer_def_delta.md) |
| M2 obstruction manifest | [m2_obstruction_manifest.md](m2_obstruction_manifest.md), [json](evidence/m2_obstruction_manifest.json) |
| Baseline GDS ∩ keep-out | [baseline_m2_intersection.json](evidence/m2_audit/baseline_m2_intersection.json) |
| Final GDS ∩ keep-out | [final_m2_intersection.json](evidence/m2_audit/final_m2_intersection.json) |
| GDS SHA / bbox | [gds_sha_bbox.rpt](evidence/gds/gds_sha_bbox.rpt) |
| Floorplan / rows / SRAM | [core_rows_sram.rpt](evidence/floorplan/core_rows_sram.rpt) |
| Template / pins / OpenDB | [template_pins.rpt](evidence/template/template_pins.rpt), [opendb](evidence/template/opendb_m2_blockage.rpt) |
| Functional | [interval10_regression.log](evidence/functional/interval10_regression.log), [reset_recovery.log](evidence/functional/reset_recovery.log) |
| Setup | [max_ss_setup_summary.rpt](evidence/setup/max_ss_setup_summary.rpt), [extract_max_ss.log](evidence/setup/extract_max_ss.log) |
| Hold | [min_ff_hold_summary.rpt](evidence/hold/min_ff_hold_summary.rpt), [extract_min_ff.log](evidence/hold/extract_min_ff.log) |
| Electrical | [extract_elec.log](evidence/electrical/extract_elec.log), [fanout.rpt](evidence/electrical/fanout.rpt) |
| Reset | [reset_visible_violators.rpt](evidence/reset/reset_visible_violators.rpt) |
| Routing | [grt_summary.rpt](evidence/routing/grt_summary.rpt), [drt_summary.rpt](evidence/routing/drt_summary.rpt) |
| PG | [psm_connectivity.rpt](evidence/pg/psm_connectivity.rpt) |
| Antenna | [openroad_check_antennas.rpt](evidence/antenna/openroad_check_antennas.rpt), [klayout_antenna.lyrdb](evidence/antenna/klayout_antenna.lyrdb) |
| Non-fill DRC | [non_fill_drc_summary.rpt](evidence/drc/non_fill_drc_summary.rpt) |
| Official density | [official_full_envelope_summary.rpt](evidence/density/official_full_envelope_summary.rpt) |
| MSLOT | [mslot_unified.lyrdb](evidence/mslot/mslot_unified.lyrdb), [mslot_unified.log](evidence/mslot/mslot_unified.log) |
| Netgen LVS | [lvs_summary.rpt](evidence/lvs/lvs_summary.rpt), [lvs.netgen.rpt](evidence/lvs/lvs.netgen.rpt) |
| IR | [irdrop_summary.rpt](evidence/ir/irdrop_summary.rpt) |
| Power | [vectorless_power.rpt](evidence/power/vectorless_power.rpt) |
