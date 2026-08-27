# 09 — Power

## VECTORLESS ESTIMATE — NO VCD/SAIF

This is **not** activity-accurate silicon power.

## Result

**INFO** — OpenSTA `report_power` total **0.120 W** at TT, 38.4 MHz, on the
CO.6a-repaired ODB.

| | Internal | Switching | Leakage | Total |
|---|---:|---:|---:|---:|
| Total (W) | 9.23e-02 | 2.82e-02 | 3.44e-06 | 1.20e-01 |

## Evidence

| Item | Path |
|---|---|
| Native `report_power` | [evidence/power/vectorless_power.rpt](evidence/power/vectorless_power.rpt) |

Tool: OpenSTA in OpenROAD 26Q2-254-g61932e897.
