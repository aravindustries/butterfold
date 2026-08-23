# 00 — Signoff manifest

## Purpose

Tools, PDK identity, freeze vs ECO artifacts.

## Tool

| Item | Value |
|---|---|
| Branch | `fft64` |
| LibreLane | 3.0.2 |
| OpenROAD / OpenSTA | 26Q2-254-g61932e897 |
| Magic | 8.3.636 |
| KLayout | 0.30.8 |
| Netgen | 1.5.318 |
| PDK | gf180mcuD (`PDKPATH=/foss/pdks/gf180mcuD`) |
| open_pdks | `7b70722e33c03fcb5dabcf4d479fb0822d9251c9` |
| SCL | `gf180mcu_fd_sc_mcu9t5v0` |
| SRAM | 2 × `gf180mcu_fd_ip_sram__sram256x8m8wm1` |
| Clock | 38.4 MHz / 26.041667 ns |
| TX pacing | `TX_BYTE_INTERVAL=10` |

Installed PDK is a ciel checkout of that open_pdks revision.

Chipathon density: team GDS must pass **minimum-clear / maximum-metal**.
Official `density.drc` maximum is **DCF.1d COMP ≤ 70%** only (no M2–MT max).
Minimum-metal M2.4–MT.3 is **integrator fill pending**.

Official dummy fill (not used for signoff after that guidance):

`libs.tech/klayout/tech/drc/filler_generation/fill_all.rb`

LibreLane `KLAYOUT_FILLER_SCRIPT` is **unset** in production `resolved.json`.
A prior fill experiment is preserved and was not promoted.

`mslot.drc` **crashes** in split-table mode (`TABLE_NAME=mslot`, `contact` nil).
The same official `mslot.drc` **PASSES** with `table_name=main` (contact/vias
loaded): 0 items on Metal1–Metal5.

## Starting freeze

| Artifact | SHA-256 |
|---|---|
| `physical/results/38p4_setup_closed/iter2_routed.odb` | `073bcd1b1029fdb8d7a3914cd65b43709a53ad2f7c76e83bfbce20ba9bfa1e64` |

Freeze timing (historical): setup +0.177954 ns, hold +0.111583 ns.

## ECO topology (timing/electrical/antenna closed)

| Artifact | SHA-256 |
|---|---|
| Routed ODB | `ca78b97b84868b6673513fbe152862fd5d2c182caa2298e362d29163cf4bdadd` |
| Max SPEF | `b822d55ddff3c06c6b4b3cff4a41e00615f8272757de9a0ff4e5c8ff71391d8c` |
| Min SPEF | `a65ef9f15dcbf0159dbd8586737c1a9969d8f9ba7c0765a25df8a40572be76ec` |
| Pre-dummy GDS | `5a99213aa4de522a96d3d83cae5651fbab961b8032b313d6e2420eba3dc9b8c6` |
| Dummy-filled GDS | `e02fb870efa2ca9aa1d72180cd5f09d6ab27ed7f76838a4045c098d27aa24f2e` |
| Netlist | `78ea4d7cbce894815ae771b5425baef810c593dfef2ab519adbd92747fd91cda` |
| CDL | `415ad8aac2bd7345250a56d979aa9b2fc3b771664528a5b549e44643fb19c9cf` |

Canonical `gds/butterfold_top.gds` was **not** overwritten (KLayout LVS FAIL;
min-metal still ERROR in `density.drc`).

## Evidence

Native copies: [evidence/](evidence/). Heavy ODB/SPEF/GDS remain gitignored
under `physical/results/`.
