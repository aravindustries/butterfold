# 10 — Final artifacts

Canonical tapeout GDS was **not** promoted. Density DRC still FAIL after
official dummy fill.

## Hashes

| Artifact | SHA-256 |
|---|---|
| Freeze ODB | `073bcd1b1029fdb8d7a3914cd65b43709a53ad2f7c76e83bfbce20ba9bfa1e64` |
| ECO routed ODB | `ca78b97b84868b6673513fbe152862fd5d2c182caa2298e362d29163cf4bdadd` |
| Max SPEF | `b822d55ddff3c06c6b4b3cff4a41e00615f8272757de9a0ff4e5c8ff71391d8c` |
| Min SPEF | `a65ef9f15dcbf0159dbd8586737c1a9969d8f9ba7c0765a25df8a40572be76ec` |
| Pre-dummy GDS (DRC/LVS input that ran) | `5a99213aa4de522a96d3d83cae5651fbab961b8032b313d6e2420eba3dc9b8c6` |
| Dummy-filled GDS (density recheck) | `e02fb870efa2ca9aa1d72180cd5f09d6ab27ed7f76838a4045c098d27aa24f2e` |
| ECO netlist | `78ea4d7cbce894815ae771b5425baef810c593dfef2ab519adbd92747fd91cda` |
| CDL | `415ad8aac2bd7345250a56d979aa9b2fc3b771664528a5b549e44643fb19c9cf` |
| `gds/butterfold_top.gds` | **unchanged / not the dummy-filled file** |

## Tools

LibreLane 3.0.2, OpenROAD 26Q2-254-g61932e897, Magic 8.3.636, KLayout 0.30.8,
Netgen 1.5.318, open_pdks `7b70722e33c03fcb5dabcf4d479fb0822d9251c9`.

## Evidence index

See [11_signoff_summary.md](11_signoff_summary.md) for per-check evidence
links. Dummy fill is GDS datatype 4; OpenRCX is ODB LEF metals — dummy fill
does not invalidate the ECO SPEF/STA numbers above.
