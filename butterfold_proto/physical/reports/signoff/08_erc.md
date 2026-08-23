# 08 — ERC / IR / disconnected pins

## Result

Power-grid and disconnected-pin checks: **PASS**.

Standalone foundry ERC deck: **NOT AVAILABLE** (no ERC runset in this
gf180mcuD / LibreLane install; `conn_drc` is inside KLayout DRC).

IR (`analyze_power_grid`, max-SS, 4.50 V, vectorless 0.115 W):

- VDD: connected, worst drop **1.01 mV** (0.02%)
- VSS: connected, worst drop **1.13 mV**

Disconnected pins: **0** (0 critical).

GRT overflow **0** (native congestion table). Final DRT `Number of violations = 0`.

## Routing evidence

| Item | Path |
|---|---|
| GRT congestion (native log excerpt) | [evidence/routing/grt_summary.rpt](evidence/routing/grt_summary.rpt) |
| DRT log | [evidence/routing/drt_summary.rpt](evidence/routing/drt_summary.rpt) |

## Evidence

| Item | Path |
|---|---|
| Native `analyze_power_grid` | [evidence/ir/power_grid.rpt](evidence/ir/power_grid.rpt) |
| Native disconnected pins | [evidence/routing/disconnected_pins.rpt](evidence/routing/disconnected_pins.rpt) |

- Tool: OpenROAD 26Q2-254-g61932e897
- Original: `11_irdrop.log`, `disconnected_pins/disconnected_pins.log`
- Click `SystemExit: 0` traceback after “Found 0 disconnected pin(s)” is the
  Python wrapper exiting; the count line is the native result.
