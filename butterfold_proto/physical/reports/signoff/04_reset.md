# 04 — Reset electrical

**PASS**

`unset_case_analysis rst_n` so `rst_n` is visible.

| Check | Violators |
|---|---|
| reset slew | 0 |
| reset cap | 0 |

Regional buffered `rst_n` tree (`rst_root` / `rst_n_int` / `rst_n_r0`…`r8`)
on the 1092.66 × 1108.80 floorplan. Native routing, not ACH spines.

Evidence: [reset_electrical.rpt](evidence/reset/reset_electrical.rpt)
