> **Historical pre-ACH shrunk production baseline** (die 1092.66 × 1108.80 µm, SHA `f193cb1b7f4ec60f41e8993f662416ed2c2a4e63ae107d213a85d8f4749f3906`). This is **not** the current `def-integration-resized` ACH validation GDS (`93f2aba1…`, 1110 × 1675 µm). See [`../d03_ach_resized/`](../d03_ach_resized/README.md).

# 03 — Non-reset electrical

**PASS**

max-SS extracted, `rst_n` case-analysis on (reset hidden):

| Check | Violators |
|---|---|
| max slew | 0 |
| max capacitance | 0 |
| max fanout | 0 |

Empty `-violators` dumps are the native OpenSTA result.

Evidence: [max_slew.rpt](evidence/electrical/max_slew.rpt) /
[max_cap.rpt](evidence/electrical/max_cap.rpt) /
[fanout.rpt](evidence/electrical/fanout.rpt)
