# 11 — Signoff summary

ECO topology is timing/electrical/antenna closed. Chipathon **max/clear
density PASSES** on the pre-fill GDS. Minimum-metal M2–MT is **integrator
fill pending**. Canonical `gds/butterfold_top.gds` was **not** promoted
(KLayout LVS FAIL; foundry density deck still reports the five min-metal
errors).

| Check | Status | Metric | Report | Evidence |
|---|---|---|---|---|
| Functional | **EVIDENCE INCOMPLETE** | no interval-10 RTL sim log in repo | — | [golden only](evidence/functional/golden_validation.txt) |
| Max-SS setup | PASS | +0.183361 ns | [01](01_setup_max_ss.md) | [summary](evidence/setup/max_ss_setup_summary.rpt) |
| Min-FF hold | PASS | +0.152106 ns | [02](02_hold_min_ff.md) | [summary](evidence/hold/min_ff_hold_summary.rpt) |
| Non-reset slew | PASS | 0 | [03](03_electrical.md) | [slew](evidence/electrical/max_slew.rpt) |
| Non-reset cap | PASS | 0 | [03](03_electrical.md) | [cap](evidence/electrical/max_cap.rpt) |
| Fanout | PASS | 0 violators | [03](03_electrical.md) | [fanout](evidence/electrical/fanout.rpt) |
| Reset electrical | PASS | 0 | [04](04_reset.md) | [reset](evidence/reset/reset_electrical.rpt) |
| Antenna | PASS | 0 nets/pins, 14 diodes | [05](05_antenna.md) | [OpenROAD](evidence/antenna/openroad_check_antennas.rpt) |
| Routing | PASS | overflow 0, DRT 0 | [08](08_erc.md) | [GRT](evidence/routing/grt_summary.rpt) / [DRT](evidence/routing/drt_summary.rpt) |
| Max/clear density | **PASS** | DCF.1d COMP 36.18% ≤ 70%; no metal-max rule | [06](06_drc.md) | [prefill](evidence/drc/density_prefill_summary.rpt) |
| Min-metal density | **INTEGRATOR FILL PENDING** | M2.4 19.03% / M3.4 24.25% / M4.4 3.40% / M5.4=MT.3 3.90% | [06](06_drc.md) | [prefill](evidence/drc/density_prefill.rpt) |
| MSLOT | **PASS** | 0 items, Metal1–Metal5 | [06](06_drc.md) | [pass](evidence/drc/mslot_pass.rpt) |
| Foundry DRC (non-density) | PASS | other pre-fill tables 0 items | [06](06_drc.md) | [summary](evidence/drc/klayout_drc_summary.rpt) |
| Netgen LVS | PASS | uniquely matched | [07](07_lvs.md) | [netgen](evidence/lvs/netgen_lvs_summary.rpt) |
| KLayout LVS | **FAIL** | top paired then Skipped; 108 stdcell NoMatch | [07](07_lvs.md) | [pairs](evidence/lvs/klayout_lvs_circuit_pairs.rpt) |
| ERC | **N/A** | no standalone ERC deck | [08](08_erc.md) | [pins](evidence/routing/disconnected_pins.rpt) |
| IR | PASS | VDD 1.01 mV / VSS 1.13 mV | [08](08_erc.md) | [IR](evidence/ir/power_grid.rpt) |
| Power | INFO | 0.115 W **vectorless, no VCD/SAIF** | [09](09_power.md) | [power](evidence/power/vectorless_power.rpt) |
| Die area | PASS | 1.223277 mm² | [00](00_manifest.md) | [area](evidence/area/final_area.rpt) |
| Canonical GDS | **NOT PROMOTED** | KLayout LVS FAIL; min-metal still ERROR in density.drc | [10](10_final_artifacts.md) | — |

## Density (Chipathon)

Official `density.drc` maximum-metal/clear: **DCF.1d only** (COMP ≤ 70%) —
**PASS** at 36.18%. No M2–MT maximum exists in this deck.

Minimum-metal M2.4–M5.4/MT.3 remain foundry `[ERROR]` on the pre-fill GDS.
Organizer: fill will be added at integration (or later here). Team dummy fill
was **not** continued. The earlier `fill_all.rb` GDS (`e02fb870…`) is kept as
experiment evidence and was not promoted.

Dummy GDS datatype 4 is not in OpenRCX ODB LEF extraction. ECO SPEF/STA remain
the timing signoff numbers.

## Do not write READY FOR FINAL TAPEOUT REVIEW

KLayout LVS, interval-10 functional evidence, and foundry min-metal (pending
integrator fill) are open.
