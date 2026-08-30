# 10 — Final artifact manifest (ACH validation)

**RESIZED ACH VALIDATION INTEGRATION COMPLETE**

This is the **canonical resized ACH validation GDS** on
`def-integration-resized` (`ACH_VALIDATION_ONLY`), not the final D03_A
manufacturing GDS. The previous main/pre-ACH baseline is SHA `f193cb1b…`
(historical only).

| Item | Path / value |
|---|---|
| Branch | `def-integration-resized` |
| HEAD | `8b33cd53af2104f00672083fdd1772f8ab921c4d` |
| Organizer DEF | `../D03.def/D03/project_defs/ACH/D03_ACH.def` |
| Organizer DEF SHA | `13a068191b9d827cc31cb0fc2fa36f25ecadb91d84730637ed9055323bc8e7c9` |
| Validation template | `physical/librelane/d03_ach_user_template.def` |
| Template SHA | `cd0254ecbc6e69872968dd3a6368b7901c33a56214807351872500b36181b947` |
| Candidate GDS | `physical/results/d03_ach_resized/candidate/butterfold_top.gds` |
| Candidate SHA | `93f2aba11dab0df4e3c9431ff2e2c060fce066da17924ad1ed2657b19e4e5dd7` |
| Canonical ACH validation GDS | `gds/butterfold_top.gds` |
| Canonical ACH validation SHA | `93f2aba11dab0df4e3c9431ff2e2c060fce066da17924ad1ed2657b19e4e5dd7` |
| Same GDS | **YES** (byte-identical) |
| Outer bbox | **1110 × 1675 µm** (intentional ACH validation envelope) |
| Internal CORE | `6.72 20.16 1085.84 1088.64` (1079.12 × 1068.48 µm) |
| SRAM count | **2** at (51.120, 720.560) and (531.120, 720.560) |
| Powered netlist | `physical/results/d03_ach_resized/butterfold_top.final.pnl.v` |
| SPEF (STA of record) | `physical/results/d03_ach_resized/spef/butterfold_top.{max,min}.spef` (re-extracted on `filled.odb`) |
| STA corners | `max_ss_125C_4v50` (setup / electrical / reset / power), `min_ff_n40C_5v50` (hold) |
| Final D03_A.def | **NOT AVAILABLE** |
| Pad controls | **PENDING_FINAL_D03_A_DEF** |
| Final integration signoff | still required later |

Heavy ODB/SPEF/Magic spice remain under `physical/results/` (not recommended for git).

## Native evidence (copied into this package)

| Check | Evidence |
|---|---|
| GDS SHA / bbox | [gds_sha_bbox.rpt](evidence/gds/gds_sha_bbox.rpt) |
| Floorplan / rows / SRAM | [core_rows_sram.rpt](evidence/floorplan/core_rows_sram.rpt) |
| Template / pins | [template_pins.rpt](evidence/template/template_pins.rpt) |
| Functional | [interval10_regression.log](evidence/functional/interval10_regression.log), [reset_recovery.log](evidence/functional/reset_recovery.log) |
| Setup | [max_ss_setup_summary.rpt](evidence/setup/max_ss_setup_summary.rpt), [extract_max_ss.log](evidence/setup/extract_max_ss.log) |
| Hold | [min_ff_hold_summary.rpt](evidence/hold/min_ff_hold_summary.rpt), [extract_min_ff.log](evidence/hold/extract_min_ff.log) |
| Electrical | [extract_elec.log](evidence/electrical/extract_elec.log), [max_slew_cap_violators.rpt](evidence/electrical/max_slew_cap_violators.rpt), [fanout.rpt](evidence/electrical/fanout.rpt) |
| Reset | [reset_visible_violators.rpt](evidence/reset/reset_visible_violators.rpt) |
| Routing | [grt_summary.rpt](evidence/routing/grt_summary.rpt), [drt_summary.rpt](evidence/routing/drt_summary.rpt) |
| PG | [psm_connectivity.rpt](evidence/pg/psm_connectivity.rpt) |
| Antenna | [openroad_check_antennas.rpt](evidence/antenna/openroad_check_antennas.rpt), [klayout_antenna.lyrdb](evidence/antenna/klayout_antenna.lyrdb) |
| Non-fill DRC | [non_fill_drc_summary.rpt](evidence/drc/non_fill_drc_summary.rpt), [klayout_contact.lyrdb](evidence/drc/klayout_contact.lyrdb) |
| Official density | [official_full_envelope_summary.rpt](evidence/density/official_full_envelope_summary.rpt), [official_full_envelope_density.log](evidence/density/official_full_envelope_density.log), [official_full_envelope_density.lyrdb](evidence/density/official_full_envelope_density.lyrdb) |
| MSLOT | [mslot_unified.lyrdb](evidence/mslot/mslot_unified.lyrdb), [mslot_unified.log](evidence/mslot/mslot_unified.log) |
| Magic extraction | [extract_spice_gds.tcl](evidence/lvs/extract_spice_gds.tcl) (spice under `physical/results/d03_ach_resized/lvs/`) |
| Netgen LVS | [lvs_summary.rpt](evidence/lvs/lvs_summary.rpt), [lvs.netgen.rpt](evidence/lvs/lvs.netgen.rpt), [lvs.tcl](evidence/lvs/lvs.tcl) |
| IR | [irdrop_summary.rpt](evidence/ir/irdrop_summary.rpt) |
| Power | [vectorless_power.rpt](evidence/power/vectorless_power.rpt) |

Official density is the unmodified GF180 `density.drc` on the full 1110 × 1675 µm
GDS. The 1110 × 1110 clip is diagnostic only.

## Previous main/pre-ACH baseline (not this artifact)

SHA `f193cb1b7f4ec60f41e8993f662416ed2c2a4e63ae107d213a85d8f4749f3906`,
1092.66 × 1108.80 µm, preserved on `main` and in
[`../signoff/`](../signoff/README.md). On this branch `gds/butterfold_top.gds`
is the ACH GDS above.
