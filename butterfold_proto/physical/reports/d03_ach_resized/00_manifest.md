# 00 — ACH validation manifest

| Item | Value |
|---|---|
| Branch | `def-integration-resized` |
| HEAD | `8b33cd53af2104f00672083fdd1772f8ab921c4d` |
| Classification | ACH_VALIDATION_ONLY |
| Pad controls | PENDING_FINAL_D03_A_DEF |
| Final D03_A.def | **NOT AVAILABLE** |
| Clock | 38.4 MHz / 26.041667 ns |
| SCL | `gf180mcu_fd_sc_mcu9t5v0` |
| SRAM | 2 × `gf180mcu_fd_ip_sram__sram256x8m8wm1` |

## GDS

| | Path | SHA-256 |
|---|---|---|
| Canonical ACH validation GDS (this branch; not final D03_A) | `gds/butterfold_top.gds` | `93f2aba11dab0df4e3c9431ff2e2c060fce066da17924ad1ed2657b19e4e5dd7` |
| Candidate (byte-identical) | `physical/results/d03_ach_resized/candidate/butterfold_top.gds` | same |
| Previous main/pre-ACH baseline (historical only) | Git history of `gds/butterfold_top.gds` on `main` | `f193cb1b7f4ec60f41e8993f662416ed2c2a4e63ae107d213a85d8f4749f3906` |

Outer bbox: **1110 × 1675 µm** (intentional).  
Evidence: [gds_sha_bbox.rpt](evidence/gds/gds_sha_bbox.rpt)

## Floorplan

| | |
|---|---|
| DIE_AREA | 0 0 1110 1675 |
| CORE_AREA | 6.72 20.16 1085.84 1088.64 |
| Core size | 1079.12 × 1068.48 µm (≤ 1110 × 1110) |
| Unique row Y | 212 (20.16–1083.60 µm) |
| Rows above 1088.64 µm | **0** |
| SRAM0 | 51.120, 720.560 R0 |
| SRAM1 | 531.120, 720.560 R0 |

Evidence: [core_rows_sram.rpt](evidence/floorplan/core_rows_sram.rpt)

## Template

| | |
|---|---|
| Organizer DEF | `../D03.def/D03/project_defs/ACH/D03_ACH.def` |
| Organizer SHA | `13a068191b9d827cc31cb0fc2fa36f25ecadb91d84730637ed9055323bc8e7c9` |
| Template | `physical/librelane/d03_ach_user_template.def` |
| Template SHA | `cd0254ecbc6e69872968dd3a6368b7901c33a56214807351872500b36181b947` |
| BTERMs | 23 (21 functional + VDD + VSS) |

See [00_template_apply.md](00_template_apply.md).

## Tools used for this ACH artifact

LibreLane 3.0.2, OpenROAD `26Q1-1024` (ODB schema compatible with LibreLane),
Magic 8.3, KLayout 0.30.8, Netgen 1.5, PDK `gf180mcuD`.
