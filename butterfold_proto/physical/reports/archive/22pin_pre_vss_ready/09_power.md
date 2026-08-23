# 09 — Power

## VECTORLESS ESTIMATE — NO VCD/SAIF

This is **not** activity-accurate silicon power.

## Result

**INFO** — OpenSTA `report_power` total **0.115058 W** (shown as 1.149672e-01
in the native table) at max-SS, 38.4 MHz.

| | Internal | Switching | Leakage | Total |
|---|---:|---:|---:|---:|
| Total (W) | 7.571e-02 | 3.924e-02 | 1.299e-05 | 1.150e-01 |

## Evidence

| Item | Path |
|---|---|
| Native `report_power` | [evidence/power/vectorless_power.rpt](evidence/power/vectorless_power.rpt) |

- Tool: OpenSTA in OpenROAD 26Q2-254-g61932e897
- Original: `power_vectorless_max_ss.rpt`
- Corner: max_ss_125C_4v50 + max SPEF
