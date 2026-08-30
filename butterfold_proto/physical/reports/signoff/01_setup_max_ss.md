> **Historical pre-ACH shrunk production baseline** (die 1092.66 × 1108.80 µm, SHA `f193cb1b7f4ec60f41e8993f662416ed2c2a4e63ae107d213a85d8f4749f3906`). This is **not** the current `def-integration-resized` ACH validation GDS (`93f2aba1…`, 1110 × 1675 µm). See [`../d03_ach_resized/`](../d03_ach_resized/README.md).

# 01 — Max-SS setup

**PASS**

| Item | Value |
|---|---|
| Corner | `max_ss_125C_4v50` + OpenRCX max SPEF |
| Clock | 38.4 MHz / 26.041667 ns |
| WNS | **+5.04 ns** (MET) |
| TNS | 0 |
| Violations | 0 |
| GDS SHA | `f193cb1b…` |

`report_wns -max` printed 0.000000 (no negative slack). Worst-path MET slack
from `setup_worst.rpt` is +5.04 ns.

Evidence: [max_ss_setup_summary.rpt](evidence/setup/max_ss_setup_summary.rpt)
