# m2-fix — organizer Metal2 obstruction integration

**M2-FIX ACH VALIDATION INTEGRATION COMPLETE**

This is **not** final D03_A manufacturing signoff. Pad controls remain
`PENDING_FINAL_D03_A_DEF`.

Branch: `m2-fix`  
Base / original main: `f56df5a94c1a020510612e7709794a5e1a66671e`

The organizers replaced the D03 ACH DEF with a Metal2 corner keep-out so
neighboring non-A I/O cells cannot short. ButterFold is a non-A ACH block.
This package routes with that obstruction present from ApplyDEFTemplate,
proves the final GDS has **zero Metal2** in the prohibited rectangle, and
re-closes the 23-pin reviewer design.

Canonical m2-fix ACH validation GDS on this branch
(ACH_VALIDATION_ONLY, not final D03_A):
[`gds/butterfold_top.gds`](../../../../gds/butterfold_top.gds)
SHA-256 `af6758ea9759ce7d48cb3b78bfea4cb13fdba6af8b18af94d56e73a09e6c8cd3`.

Previous ACH (no Metal2 keep-out) SHA `93f2aba1…` remains in Git history on
`main`. Previous main/pre-ACH shrink SHA `f193cb1b…` is historical only.

| Item | Value |
|---|---|
| New package | https://github.com/user-attachments/files/31645362/D03.def.tgz |
| PACKAGE_SHA256 | `c14172c2129b8a25622aa9129578229995d421a763423f15255b70bf065f9978` |
| New organizer DEF | `D03.def/D03/project_defs/ACH/D03_ACH.def` |
| NEW_ORGANIZER_DEF_SHA256 | `79bd0dcad427802b4ad71ab030a0c649b9ead74354ce6e0ee58d16c73cff2f99` |
| Metal2 keep-out | **1** rectangle: (0, 0)–(2.0, 65.0) µm |
| Interface | **23** BTERMs (no `stream_status_o`) |
| Outer DIE | **1110 × 1675 µm** |
| Compact CORE | `6.72 20.16 1085.84 1088.64` |
| SRAM | 2 × sram256x8m8wm1 R0 at (51.120, 720.560) and (531.120, 720.560) |
| Clock | 38.4 MHz / 26.041667 ns |
| FINAL_M2_VIOLATING_REGIONS | **0** |
| RTL / golden | unchanged |

| Report | Check |
|---|---|
| [organizer_def_delta.md](organizer_def_delta.md) | old vs new organizer DEF |
| [m2_obstruction_manifest.md](m2_obstruction_manifest.md) | exact Metal2 rectangles |
| [00_manifest.md](00_manifest.md) | artifacts, hashes, floorplan |
| [00_template_apply.md](00_template_apply.md) | template / pins / OpenDB blockages |
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
