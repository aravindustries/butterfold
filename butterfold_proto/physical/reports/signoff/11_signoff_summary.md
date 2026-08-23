# 11 — Signoff summary

ECO topology is timing/electrical/antenna closed. Foundry **density DRC still
FAILS** after official OpenPDKs `fill_all.rb`. Canonical `gds/butterfold_top.gds`
was **not** promoted.

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
| Density | **FAIL** | M2.4 M3.4 M4.4 M5.4 MT.3 after `fill_all.rb` | [06](06_drc.md) | [density](evidence/drc/density.rpt) |
| MSLOT | **FAIL** | PDK `mslot.drc` crash | [06](06_drc.md) | [mslot](evidence/drc/mslot.rpt) |
| Foundry DRC | **FAIL** | density only (pre-dummy other tables 0) | [06](06_drc.md) | [summary](evidence/drc/klayout_drc_summary.rpt) |
| Netgen LVS | PASS | uniquely matched | [07](07_lvs.md) | [netgen](evidence/lvs/netgen_lvs_summary.rpt) |
| KLayout LVS | **FAIL** | name-case; top not compared | [07](07_lvs.md) | [klayout](evidence/lvs/klayout_lvs.log) |
| ERC | **N/A** | no standalone ERC deck | [08](08_erc.md) | [pins](evidence/routing/disconnected_pins.rpt) |
| IR | PASS | VDD 1.01 mV / VSS 1.13 mV | [08](08_erc.md) | [IR](evidence/ir/power_grid.rpt) |
| Power | INFO | 0.115 W **vectorless, no VCD/SAIF** | [09](09_power.md) | [power](evidence/power/vectorless_power.rpt) |
| Die area | PASS | 1.223277 mm² | [00](00_manifest.md) | [area](evidence/area/final_area.rpt) |
| Canonical GDS | **NOT PROMOTED** | density FAIL | [10](10_final_artifacts.md) | — |

## Dummy fill

Official `fill_all.rb` (open_pdks `7b70722e…`) produced dummy polygons
(`metal5_dummy` 39193, etc.) but coverage remained below 30%. Do not waive.
Do not write a custom filler.

Dummy layers are GDS datatype 4. OpenRCX uses ODB routed metals. ECO SPEF/STA
remain the timing signoff numbers.

## Do not write READY FOR FINAL TAPEOUT REVIEW

Density, MSLOT, KLayout LVS, and interval-10 functional evidence are open.
