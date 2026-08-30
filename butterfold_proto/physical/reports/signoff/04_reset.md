> **Historical pre-ACH shrunk production baseline** (die 1092.66 × 1108.80 µm, SHA `f193cb1b7f4ec60f41e8993f662416ed2c2a4e63ae107d213a85d8f4749f3906`). This is **not** the current `def-integration-resized` ACH validation GDS (`93f2aba1…`, 1110 × 1675 µm). See [`../d03_ach_resized/`](../d03_ach_resized/README.md).

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
