# 00 — final m2-fix ACH integration manifest

| Item | Value |
|---|---|
| Branch | `m2-fix` |
| ORIGINAL_MAIN_HEAD | `f56df5a94c1a020510612e7709794a5e1a66671e` |
| Classification | FINAL ACH INTEGRATION + organizer Metal2 keep-out |
| Pad controls | **102/102 CONNECTED** |
| Final organizer DEF | **D03_ACH.def** |
| Clock | 38.4 MHz / 26.041667 ns |
| SCL | `gf180mcu_fd_sc_mcu9t5v0` |
| SRAM | 2 × `gf180mcu_fd_ip_sram__sram256x8m8wm1` |
| Logical RTL | **unchanged** |
| Pin count | **23** (no `stream_status_o`) |

## GDS

| | Path | SHA-256 |
|---|---|---|
| Canonical final ACH GDS | `gds/butterfold_top.gds` | `b25fbd2fffaf138d211e33b281b8a8e248e0684ecded781003bc51f07532a5ed` |
| Candidate (byte-identical) | `physical/results/m2_fix/candidate/butterfold_top.gds` | same |
| Previous ACH (no M2 keep-out) | Git history of `gds/butterfold_top.gds` on `main` | `93f2aba11dab0df4e3c9431ff2e2c060fce066da17924ad1ed2657b19e4e5dd7` |

Outer bbox: **1110 × 1675 µm** (intentional).  
Evidence: [gds_sha_bbox.rpt](evidence/gds/gds_sha_bbox.rpt)

## Floorplan

| | |
|---|---|
| OUTER_DIE | 0 0 1110 1675 |
| INTERNAL_CORE | 6.72 20.16 1085.84 1088.64 |
| Core size | 1079.12 × 1068.48 µm (≤ 1110 × 1110) |
| Unique row Y | 212 (20.16–1083.60 µm) |
| Rows above 1088.64 µm | **0** |
| SRAM0 | 51.120, 720.560 R0 |
| SRAM1 | 531.120, 720.560 R0 |

Evidence: [core_rows_sram.rpt](evidence/floorplan/core_rows_sram.rpt)

## Template / organizer

| | |
|---|---|
| Package URL | https://github.com/user-attachments/files/31645362/D03.def.tgz |
| PACKAGE_SHA256 | `c14172c2129b8a25622aa9129578229995d421a763423f15255b70bf065f9978` |
| Organizer DEF | `../D03.def/D03/project_defs/ACH/D03_ACH.def` |
| Organizer SHA | `79bd0dcad427802b4ad71ab030a0c649b9ead74354ce6e0ee58d16c73cff2f99` |
| Template | `physical/librelane/d03_ach_user_template.def` |
| Template SHA | `112db498d3fb2fa277771376687d212ef9c1a58b10bdb253b615ec17223d0909` |
| BTERMs | 23 (21 functional + VDD + VSS) |
| Metal2 keep-out | 1 rect, (0,0)–(2.0, 65.0) µm |
| TEMPLATE_M2_BLOCKAGE_MATCH | **1/1** |
| OPENDB_M2_BLOCKAGE_MATCH | **1/1** |

See [00_template_apply.md](00_template_apply.md),
[organizer_def_delta.md](organizer_def_delta.md),
[m2_obstruction_manifest.md](m2_obstruction_manifest.md).

## Tools used for this artifact

LibreLane 3.0.2, OpenROAD `26Q1-1024`, Magic 8.3.636, KLayout 0.30.8,
Netgen 1.5, PDK `gf180mcuD`.
