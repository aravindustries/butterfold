# 11 — Signoff summary (pin-placement-redesign)

# BUTTERFOLD NORTH/WEST PIN-PLACEMENT SIGNOFF COMPLETE

This dashboard is for the **North/West pin-placement** layout on
`pin-placement-redesign`. RTL, golden models, FFT64/DFT12, 38.4 MHz, and
SRAM count are unchanged. Canonical `gds/butterfold_top.gds` is the promoted
North/West Magic GDS.

Canonical Magic GDS (repo root):

`gds/butterfold_top.gds`

byte-identical copy of
`butterfold_proto/physical/results/nw_pins_eco/co6a_repair/magic_gds/butterfold_top.magic.gds`

SHA-256 `6d66a47623c96dcbfb2e6258081934f7a26c033f953b57469b1730d0c5e7dd12`

Same SHA used for main DRC, density, MSLOT, and full-device LVS.

| Check | Status | Metric | Report | Evidence |
|---|---|---|---|---|
| Branch | PASS | pin-placement-redesign | — | git |
| RTL / golden | PASS | unchanged | — | git diff |
| SRAM | PASS | 2 | [00a](00a_pin_placement.md) | LibreLane |
| Terminals | PASS | 23 | [00a](00a_pin_placement.md) | [pins](evidence/pins/final_odb_pins.rpt) |
| North / West / East / South | PASS | 12 / 11 / 0 / 0 | [00a](00a_pin_placement.md) | [pins](evidence/pins/final_odb_pins.rpt) |
| Area | PASS | 1.223277 mm² | — | [area](evidence/area/librelane_area.rpt) |
| Pin access / DRT | PASS | DRT = 0 | [08](08_erc.md) | [DRT](evidence/routing/drt_summary.rpt) |
| GRT | PASS | overflow 0 | [08](08_erc.md) | [GRT](evidence/routing/grt_summary.rpt) |
| Max-SS setup | PASS | WNS +1.62 ns MET, TNS 0 | [01](01_setup_max_ss.md) | [paths](evidence/setup/max_ss_setup_paths.rpt) |
| Min-FF hold | PASS | WNS +0.25 ns MET, TNS 0 | [02](02_hold_min_ff.md) | [paths](evidence/hold/min_ff_hold_paths.rpt) |
| Slew / cap / fanout | PASS | empty violator files | [03](03_electrical.md) | [slew](evidence/electrical/max_slew.rpt) |
| Reset electrical | PASS | empty violator files | [04](04_reset.md) | [reset](evidence/reset/reset_slew.rpt) |
| Antenna | PASS | 0 nets / 0 pins, 35 diodes | [05](05_antenna.md) | [OpenROAD](evidence/antenna/openroad_check_antennas.rpt) |
| DCF.1d min-clear | PASS | COMP 34.39% ≤ 70% | [06](06_drc.md) | [density](evidence/drc/density_filled_summary.rpt) |
| Min-metal M2–MT | INTEGRATOR FILL PENDING | M2.4 19.66% / M3.4 24.72% / M4.4 4.22% / M5.4=MT.3 5.36% | [06](06_drc.md) | [density](evidence/drc/density_filled_summary.rpt) |
| MSLOT | PASS | 0 items (unified table_name=main) | [06](06_drc.md) | [mslot](evidence/drc/mslot_unified.lyrdb) |
| CO.6a | PASS | 0 | [06](06_drc.md) | [after](evidence/drc/co6a_after_markers.rpt) |
| Foundry DRC (non-fill) | PASS | 0 items; official log clean | [06](06_drc.md) | [full log](evidence/drc/klayout_drc_full.log) |
| Full device LVS | PASS | uniquely match; 12770 devices / 12761 nets; SRAM 2 | [07](07_lvs.md) | [summary](evidence/lvs/full_netgen_lvs_summary.rpt) |
| IR | PASS | VDD/VSS connected; distributed VSRC worst 7.42 / 7.39 mV | [08](08_erc.md) | [IR](evidence/ir/ir_antenna.log) |
| Power | INFO | 0.120 W vectorless | [09](09_power.md) | [power](evidence/power/vectorless_power.rpt) |
| Canonical GDS | **PROMOTED** | `6d66a476…` | [10](10_final_artifacts.md) | [SHA](evidence/final/gds.sha256) |

CO.6a repair: six MX `aoi221_2` instances swapped to `aoi221_1`, then DRT=0,
25705 fillers, Magic restream. LVS unique-match required tying filler/antenna
power pins in the source netlist (`global_connect`); layout GDS was not
changed for that step.
