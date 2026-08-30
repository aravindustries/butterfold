> **Historical pre-ACH shrunk production baseline** (die 1092.66 × 1108.80 µm, SHA `f193cb1b7f4ec60f41e8993f662416ed2c2a4e63ae107d213a85d8f4749f3906`). This is **not** the current `def-integration-resized` ACH validation GDS (`93f2aba1…`, 1110 × 1675 µm). See [`../d03_ach_resized/`](../d03_ach_resized/README.md).

# 08 — ERC / IR / disconnected pins

## Result

Power-grid: **VDD connected, VSS connected**.

Standalone foundry ERC deck: **NOT AVAILABLE**.

IR (`analyze_power_grid`, max-SS, 4.50 V, vectorless):

- VDD: connected, worst drop **1.03 mV** (0.02%)
- VSS: connected, worst drop **1.00 mV**

README does not define an IR numeric PASS threshold. Status: **CHARACTERIZED**.

GRT overflow **0**. Final DRT `Number of violations = 0`. Unrouted **0**.
Opens **0**. Shorts **0** (final DRT iteration).

Evidence: [power_grid.rpt](evidence/ir/power_grid.rpt) /
[grt_summary.rpt](evidence/routing/grt_summary.rpt) /
[drt_summary.rpt](evidence/routing/drt_summary.rpt)
