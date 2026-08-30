# 11 — 22-pin compact signoff summary

# TEAM-SIDE REVIEWER SIGNOFF COMPLETE (22-pin compact core)

Compact production GDS **1092.66 × 1108.80 µm (1.211541 mm²)**, SHA
`31dbce1e19295c6678531c205bba780898b013a69976e6056837821c3de9a64e`.

**22 physical terminals including VDD and VSS.** No ACH DEF. No `FP_DEF_TEMPLATE`.

`stream_status_o` = READY in the input/command phase, VALID in the output phase.

| Check | Status | Metric | Report | Evidence |
|---|---|---|---|---|
| Functional | **PASS** | TX_BYTE_INTERVAL=10 foundry SRAM; FINAL-PIN OVERALL RESULT: PASS | [12](12_functional.md) | [log](evidence/functional/interval10_regression.log) |
| Stream-status protocol | **PASS** | mux matches din_ready/dout_valid by FSM phase | [12](12_functional.md) | [stream](evidence/functional/stream_status.log) |
| Reset recovery | **PASS** | RESET-RECOVERY RESULT: PASS | [12](12_functional.md) | [reset](evidence/functional/reset_recovery.log) |
| Max-SS setup | **PASS** | +0.079 ns, TNS 0, 0 vio | [01](01_setup_max_ss.md) | [STA](evidence/setup/sta_filled.log) |
| Min-FF hold | **PASS** | +0.027 ns, TNS 0, 0 vio | [02](02_hold_min_ff.md) | [STA](evidence/hold/sta_capfix_ff.log) |
| Electrical | **PASS** | slew/cap/fanout = 0 | [03](03_electrical.md) | [elec](evidence/electrical/elec_filled.rpt) |
| Reset electrical | **PASS** | slew 0, cap 0 | [04](04_reset.md) | [reset](evidence/reset/reset_visible.rpt) |
| Antenna | **PASS** | 0 nets/pins, 23 diodes; KLayout 0 items | [05](05_antenna.md) | [OpenROAD](evidence/routing/fill.log) / [KLayout](evidence/antenna/klayout_antenna.lyrdb) |
| Routing | **PASS** | overflow 0, DRT 0, opens 0, shorts 0 | [08](08_routing_pg_ir.md) | [GRT](evidence/routing/capfix_route.log) / [fill](evidence/routing/fill.log) |
| PG | **PASS** | VDD connected, VSS connected | [08](08_routing_pg_ir.md) | [IR](evidence/ir/ir_power.log) |
| DCF.1b | **PASS** | COMP **36.338%** ≥ 25% | [06](06_drc.md) | [density](evidence/density/density.log) |
| DCF.1d | **PASS** | COMP **36.338%** ≤ 70% | [06](06_drc.md) | [density](evidence/density/density.log) |
| Poly2 PL.8 | **PASS** | **27.600%** ≥ 14% | [06](06_drc.md) | [density](evidence/density/density.log) |
| M1.4 | **PASS** | **33.325%** > 30% | [06](06_drc.md) | [density](evidence/density/density.log) |
| M2.4–MT.3 | **INTEGRATOR FILL PENDING** | 19.75 / 25.26 / 3.42 / 4.62 / 4.62 % | [06](06_drc.md) | [density](evidence/density/density.log) |
| MSLOT | **PASS** | 0 items | [06](06_drc.md) | [lyrdb](evidence/mslot/mslot.lyrdb) |
| Non-fill DRC | **PASS** | 0 items; contact table clean including CO.6a | [06](06_drc.md) | [main](evidence/drc/main.lyrdb) / [contact](evidence/drc/contact.lyrdb) |
| Full device LVS | **PASS** | uniquely matched; 11568 devices / 11582 nets; 2 SRAM; 22 pins | [07](07_lvs.md) | [summary](evidence/lvs/lvs_summary.rpt) |
| IR | **CHARACTERIZED** | VDD 1.82 mV / VSS 2.26 mV | [08](08_routing_pg_ir.md) | [IR](evidence/ir/ir_power.log) |
| Power | **INFO** | 0.1465 W vectorless, no VCD/SAIF | [09](09_power.md) | [power](evidence/power/power_vectorless_max_ss.rpt) |
| Die area | **PASS** | 1.211541 mm²; 1092.66 × 1108.80 ≤ 1110 × 1110 | [00](00_manifest.md) | [sha](evidence/gds/butterfold_top.gds.sha256) |

Canonical GDS: repo-root `gds/butterfold_top.gds` (same SHA as all GDS checks).
