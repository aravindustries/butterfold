# Resized ACH validation — reviewer package

**RESIZED ACH VALIDATION INTEGRATION COMPLETE**

This is **not** final D03_A manufacturing signoff. Pad controls remain
`PENDING_FINAL_D03_A_DEF`.

Branch: `def-integration-resized`  
HEAD: `8b33cd53af2104f00672083fdd1772f8ab921c4d`

Canonical resized ACH validation GDS on this branch
(ACH_VALIDATION_ONLY, not final D03_A):
[`gds/butterfold_top.gds`](../../../../gds/butterfold_top.gds)
SHA-256 `93f2aba11dab0df4e3c9431ff2e2c060fce066da17924ad1ed2657b19e4e5dd7`.

Previous main/pre-ACH baseline (historical only, SHA `f193cb1b…`,
1092.66 × 1108.80 µm) remains in Git history on `main`.

Outer GDS bbox **1110 × 1675 µm** is intentional ACH validation geometry.
The compact ButterFold implementation stays inside CORE
`6.72 20.16 1085.84 1088.64` (1079.12 × 1068.48 µm, ≤1110 × 1110).
Zero standard-cell rows above y = 1088.64 µm.

All functional, timing, electrical, routing, antenna, non-fill DRC, MSLOT,
PG, and device-level LVS checks pass.

Official full-envelope density on the intentional 1110 × 1675 ACH validation
GDS reports DCF.1b = 23.56% and M1.4 = 21.71%, below their nominal standalone
team thresholds. DCF.1d = 23.56% ≤ 70% PASS. PL.8 = 17.93% ≥ 14% PASS.
M2.4–MT.3 remain INTEGRATOR FILL PENDING.

The 1110 × 1110 clipped GDS is diagnostic only and is **not** signoff evidence.

| Report | Check |
|---|---|
| [00_manifest.md](00_manifest.md) | artifacts, hashes, floorplan |
| [00_template_apply.md](00_template_apply.md) | ACH template / pins |
| [12_functional.md](12_functional.md) | foundry-SRAM FINAL-PIN + reset-recovery |
| [01_setup_max_ss.md](01_setup_max_ss.md) | max-SS setup |
| [02_hold_min_ff.md](02_hold_min_ff.md) | min-FF hold |
| [03_electrical.md](03_electrical.md) | slew / cap / fanout |
| [04_reset.md](04_reset.md) | reset electrical |
| [05_antenna.md](05_antenna.md) | antenna |
| [08_routing_pg_ir.md](08_routing_pg_ir.md) | routing, PG, IR |
| [06_drc.md](06_drc.md) | non-fill DRC / official density / MSLOT |
| [07_lvs.md](07_lvs.md) | Magic + Netgen LVS |
| [09_power.md](09_power.md) | vectorless power |
| [10_final_artifacts.md](10_final_artifacts.md) | final manifest |
| [11_signoff_summary.md](11_signoff_summary.md) | dashboard |

Native copies: [`evidence/`](evidence/).

Previous main/pre-ACH shrunk production baseline (historical, not this GDS):
1092.66 × 1108.80 µm, SHA
`f193cb1b7f4ec60f41e8993f662416ed2c2a4e63ae107d213a85d8f4749f3906`,
package [`../signoff/`](../signoff/README.md).
