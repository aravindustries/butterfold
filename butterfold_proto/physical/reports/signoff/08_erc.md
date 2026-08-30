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
