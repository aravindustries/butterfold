# 02 — Hold STA (min-FF)

## Result

**PASS** — worst extracted path slack **+0.25 ns MET**, TNS **0**, hold
violations **0**.

## Corner / condition

`ff_n40C_5v50` liberty + OpenRCX **min** rules, same SDC/period.

## Command / native step

`physical/scripts/nw_extracted_sta.tcl` with `STA_MODE=ff_hold` on the
CO.6a-repaired routed ODB.

## Evidence

| Item | Path |
|---|---|
| Native worst paths | [evidence/hold/min_ff_hold_paths.rpt](evidence/hold/min_ff_hold_paths.rpt) |
| WNS dump | [evidence/hold/min_ff_wns.rpt](evidence/hold/min_ff_wns.rpt) |
| TNS dump | [evidence/hold/min_ff_tns.rpt](evidence/hold/min_ff_tns.rpt) |
| Violations (empty) | [evidence/hold/min_ff_hold_violations.rpt](evidence/hold/min_ff_hold_violations.rpt) |

SRAM `D[7]` path slack **0.25 ns MET**. `report_wns -min` prints `wns min 0.00`
when there are no violating paths.
