# Final organizer blockage manifest

The authoritative `D03_ACH.def` contains one explicit routing blockage:

| Index | Layer | Rectangle (µm) | Imported | Final-GDS overlap |
|---:|---|---|---|---:|
| 0 | Metal2 | `(0.000, 0.000)-(2.000, 65.000)` | YES | 0 polygons / 0.000 µm² |

The obstruction is installed before global and detailed routing. Exact-GDS
geometry auditing confirms the southwest Metal2 region remains clean.

`ORGANIZER_BLOCKAGES_IMPORTED = 1/1`  
`BLOCKAGE_VIOLATING_REGIONS = 0`
