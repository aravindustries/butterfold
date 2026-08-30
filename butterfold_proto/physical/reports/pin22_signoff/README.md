# ButterFold 22-pin compact production signoff

This package is the **current** team-side signoff for the compact 22-pin
ButterFold core. It does **not** use ACH DEF / `FP_DEF_TEMPLATE`.

Canonical GDS: repo-root `gds/butterfold_top.gds`

| | |
|---|---|
| Die | 1092.66 × 1108.80 µm (1.211541 mm²) |
| SHA-256 | `31dbce1e19295c6678531c205bba780898b013a69976e6056837821c3de9a64e` |
| Pins | **22** including VDD and VSS |
| Status pin | `stream_status_o` (READY in input phase, VALID in output phase) |
| SRAM | 2 × `gf180mcu_fd_ip_sram__sram256x8m8wm1` R0 at 51.12/531.12, 720.56 |
| Clock | 38.4 MHz / 26.041667 ns |
| `FP_DEF_TEMPLATE` | **absent** |

Start at [11_signoff_summary.md](11_signoff_summary.md).
