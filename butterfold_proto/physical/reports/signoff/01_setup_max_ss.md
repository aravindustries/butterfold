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
