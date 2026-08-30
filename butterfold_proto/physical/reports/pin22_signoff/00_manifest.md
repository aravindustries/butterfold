# 00 — Signoff manifest (22-pin compact)

## Tools

| Item | Value |
|---|---|
| Branch | `pin-redesign-22` |
| LibreLane | 3.0.2 |
| OpenROAD / OpenSTA | 26Q1-1024 |
| Magic | 8.3 |
| KLayout | 0.30.8 |
| Netgen | 1.5.318 |
| PDK | gf180mcuD (`PDKPATH=/foss/pdks/gf180mcuD`) |
| SCL | `gf180mcu_fd_sc_mcu9t5v0` |
| SRAM | 2 × `gf180mcu_fd_ip_sram__sram256x8m8wm1` |
| Clock | 38.4 MHz / 26.041667 ns |
| TX pacing | `TX_BYTE_INTERVAL=10` |

## Floorplan (frozen compact, no ACH DEF)

| Item | Value |
|---|---|
| `FP_SIZING` | absolute |
| `FP_DEF_TEMPLATE` | **absent** |
| DIE_AREA | `[0, 0, 1092.66, 1108.80]` |
| CORE_AREA | `[6.72, 20.16, 1085.84, 1088.64]` |
| SRAM0 | 51.120, 720.560 R0 |
| SRAM1 | 531.120, 720.560 R0 |

## Interface (22 terminals)

Inputs (11): `rst_n`, `clk`, `din[7:0]`, `din_valid_i`  
Outputs (9): `stream_status_o`, `dout[7:0]`  
Power (2): `VDD`, `VSS`

No `din_ready_o`. No `dout_valid_o`. No ACH pad-control BTERMs.

## Canonical GDS

| Artifact | SHA-256 |
|---|---|
| Magic streamout / candidate / canonical | `31dbce1e19295c6678531c205bba780898b013a69976e6056837821c3de9a64e` |

Die **1092.66 × 1108.80 µm = 1.211541 mm²** (≤ 1110 × 1110).
Width margin to 1110 µm: **17.34 µm**. Height margin: **1.20 µm**.
