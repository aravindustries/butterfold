# 02 — Hold STA (min-FF)

## Result

**PASS** — WNS **+0.152106 ns**, TNS **0**, hold violations **0**.

## Corner / condition

`min_ff_n40C_5v50`, min SPEF, same SDC/period.

## Command / native step

OpenSTA `report_worst_slack -min`, `report_tns -min` after OpenRCX min
extraction. OpenROAD 26Q2-254-g61932e897.

## Evidence

| Item | Path |
|---|---|
| Native STA log | [evidence/hold/min_ff_hold_summary.rpt](evidence/hold/min_ff_hold_summary.rpt) |
| Native worst path | [evidence/hold/min_ff_worst_paths.rpt](evidence/hold/min_ff_worst_paths.rpt) |

- Original source: `physical/results/final_signoff/04_sta_min.log`, `sta_min_ff/hold.rpt`
- Input: same routed ODB, min SPEF SHA `a65ef9f1…`
- Path slack MET **0.152106 ns** (`din[0]` → `_18681_/D`)

`repair_timing -hold` was not required.
