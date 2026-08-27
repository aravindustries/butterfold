# 04 — Reset electrical

## Result

**PASS** at max-SS with `rst_n` visible: slew **0**, cap **0**.

Production SDC still has `set_case_analysis 1 rst_n`. That was unset
**in-memory only** for the reset-visible dump in `nw_extracted_sta.tcl`.

## Evidence

| Item | Path |
|---|---|
| Reset-visible slew violators (empty = 0) | [evidence/reset/reset_slew.rpt](evidence/reset/reset_slew.rpt) |
| Reset-visible cap violators (empty = 0) | [evidence/reset/reset_cap.rpt](evidence/reset/reset_cap.rpt) |

Tool: OpenSTA `unset_case_analysis` + `report_check_types`.
