# 11 — Signoff summary (historical pre-ACH shrink baseline)

# HISTORICAL: BUTTERFOLD TEAM-SIDE SIGNOFF COMPLETE (pre-ACH)

This dashboard describes the **shrunk production baseline**
**1092.66 × 1108.80 µm (1.211541 mm²)**, SHA `f193cb1b…`.

Current ACH validation package (1110 × 1675 µm, SHA `93f2aba1…`):
[`../d03_ach_resized/11_signoff_summary.md`](../d03_ach_resized/11_signoff_summary.md).

Shrunk pre-integration team GDS **1092.66 × 1108.80 µm (1.211541 mm²)**
(previous main/pre-ACH SHA `f193cb1b…`; on this branch repo-root
`gds/butterfold_top.gds` is now the ACH GDS `93f2aba1…`).

Minimum-clear density: **PASS**
Minimum-metal density: **INTEGRATOR FILL PENDING**

This is **not** final post-integration manufacturing signoff. Official
`D03_A.def` is still unavailable.

| Check | Status | Metric | Report | Evidence |
|---|---|---|---|---|
| Functional | **PASS** | TX_BYTE_INTERVAL=10 foundry SRAM; FINAL-PIN OVERALL RESULT: PASS | — | [log](evidence/functional/interval10_regression.log) |
| Max-SS setup | PASS | +5.04 ns | [01](01_setup_max_ss.md) | [summary](evidence/setup/max_ss_setup_summary.rpt) |
| Min-FF hold | PASS | +0.26 ns | [02](02_hold_min_ff.md) | [summary](evidence/hold/min_ff_hold_summary.rpt) |
| Non-reset slew | PASS | 0 | [03](03_electrical.md) | [slew](evidence/electrical/max_slew.rpt) |
| Non-reset cap | PASS | 0 | [03](03_electrical.md) | [cap](evidence/electrical/max_cap.rpt) |
| Fanout | PASS | 0 violators | [03](03_electrical.md) | [fanout](evidence/electrical/fanout.rpt) |
| Reset electrical | PASS | 0 | [04](04_reset.md) | [reset](evidence/reset/reset_electrical.rpt) |
| Antenna | PASS | 0 nets/pins, 15 diodes | [05](05_antenna.md) | [OpenROAD](evidence/antenna/openroad_check_antennas.rpt) |
| Routing | PASS | overflow 0, DRT 0, opens 0, shorts 0 | [08](08_erc.md) | [GRT](evidence/routing/grt_summary.rpt) / [DRT](evidence/routing/drt_summary.rpt) |
| Max/clear density | **PASS** | DCF.1d COMP 35.72% ≤ 70% | [06](06_drc.md) | [prefill](evidence/drc/density_prefill_summary.rpt) |
| Min-metal density | **INTEGRATOR FILL PENDING** | M2.4 19.52% / M3.4 24.54% / M4.4 3.63% / M5.4=MT.3 4.17% | [06](06_drc.md) | [prefill](evidence/drc/density_prefill.rpt) |
| MSLOT | **PASS** | 0 items, Metal1–Metal5 (unified table) | [06](06_drc.md) | [pass](evidence/drc/mslot_pass.rpt) |
| Foundry DRC (non-density) | PASS | drawing tables 0 items including CO.6a | [06](06_drc.md) | [summary](evidence/drc/klayout_drc_summary.rpt) |
| Full device LVS | **PASS** | uniquely matched; 11612 devices / 11623 nets | [07](07_lvs.md) | [summary](evidence/lvs/full_netgen_lvs_summary.rpt) |
| IR | CHARACTERIZED | VDD 1.03 mV / VSS 1.00 mV (no README numeric threshold) | [08](08_erc.md) | [IR](evidence/ir/power_grid.rpt) |
| Power | INFO | 0.116 W **vectorless, no VCD/SAIF** | [09](09_power.md) | [power](evidence/power/vectorless_power.rpt) |
| Die area | PASS | 1.211541 mm² ≤ 1.25 mm²; 1092.66 × 1108.80 ≤ 1110 × 1110 | [00](00_manifest.md) | [area](evidence/area/final_area.rpt) |
| Historical shrink GDS | **on `main` / previous baseline** | SHA `f193cb1b7f4ec60f41e8993f662416ed2c2a4e63ae107d213a85d8f4749f3906` | [10](10_final_artifacts.md) | Git history of `gds/butterfold_top.gds` on `main` |

## Do not write READY FOR FINAL TAPEOUT REVIEW

Team-side package is complete. Integrator still owns minimum-metal fill.
Full integration signoff will be rerun after official D03_A.def arrives.
