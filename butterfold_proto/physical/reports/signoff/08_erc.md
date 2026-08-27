# 08 — ERC / IR / disconnected pins

## Result

Power-grid connectivity: **PASS** (PSM-0040, VDD and VSS fully connected).

Standalone foundry ERC deck: **NOT AVAILABLE** (no ERC runset in this
gf180mcuD install; `conn_drc` is inside KLayout DRC).

North-edge physical `VDD`/`VSS` terminals are preserved. PDNSim sources were
restored to a **distributed Metal4/Metal5 strap VSRC** (17 locations each),
matching the previous successful mesh-source methodology. The north-only
BTerm VSRC (175 / 290 mV) was an analysis representation issue, not a
disconnected grid.

IR (`analyze_power_grid`, TT, 5.00 V, vectorless 0.120 W):

- VDD: connected, worst drop **7.42 mV** (0.15%)
- VSS: connected, worst drop **7.39 mV** (0.15%)

GRT overflow **0**. Final DRT `Number of violations = 0`.

## Routing evidence

| Item | Path |
|---|---|
| GRT | [evidence/routing/grt_summary.rpt](evidence/routing/grt_summary.rpt) |
| DRT | [evidence/routing/drt_summary.rpt](evidence/routing/drt_summary.rpt) |

## Evidence

| Item | Path |
|---|---|
| Native `analyze_power_grid` log | [evidence/ir/ir_antenna.log](evidence/ir/ir_antenna.log) |
| Same log (power_grid alias) | [evidence/ir/power_grid.rpt](evidence/ir/power_grid.rpt) |
| Distributed VSRC VDD | [evidence/ir/vsrc_VDD.loc](evidence/ir/vsrc_VDD.loc) |
| Distributed VSRC VSS | [evidence/ir/vsrc_VSS.loc](evidence/ir/vsrc_VSS.loc) |
