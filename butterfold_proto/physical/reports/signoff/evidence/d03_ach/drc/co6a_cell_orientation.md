# CO.6a cell / orientation investigation (closed)

Library `gf180mcu_fd_sc_mcu9t5v0` AOI221 drive variants: `aoi221_1`, `aoi221_2`, `aoi221_4` only.

Isolated KLayout contact (already proven, not re-run):

| cell | orient | CO.6a | SIZE | row-legal on MX rows |
|---|---|---|---|---|
| aoi221_2 | MX | fail | 11.76 µm | yes (native) |
| aoi221_2 | R0 | 0 | 11.76 | no (wrong rail polarity) |
| aoi221_2 | MY | 0 | 11.76 | no (R0-rail) |
| aoi221_2 | R180 | 0 | 11.76 | yes (same VDD/VSS polarity as MX) |
| aoi221_1 | MX | 0 | 6.16 µm | yes |
| aoi221_4 | MX | 0 | 22.40 µm | no (does not fit 11.76 sites) |

Conclusion:

- No stronger pin-compatible AOI221 than `_2` is legal in the existing 11.76 µm sites (`_4` is too wide).
- MX `aoi221_2` is the CO.6a defect. Do not restore it.
- R180 `aoi221_2` at the original origin is placement-legal, same bbox, full `_2` drive, CO.6a-clean.
- eco27 (`aoi221_1` MX) closed CO.6a but left slew/cap on five ZN nets. Do not revert those swaps as the final candidate; eco28 supersedes it by keeping `_2` in R180.

Repair executed: `d03_co6a_eco28.tcl` on `butterfold_top_pgfix.odb` (not on eco27). Nine instances `_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_`: `setOrient R180` + `setLocation` original (x,y). 38 signal nets ripped, GRT 38 nets, TritonRoute on pgfix (no DRT-1010). DRT_OK.
