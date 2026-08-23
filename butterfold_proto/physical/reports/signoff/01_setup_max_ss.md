# 01 — Setup STA (max-SS)

## Result

**PASS** — WNS **+0.183361 ns**, TNS **0**, setup violations **0**.

## Corner / condition

`max_ss_125C_4v50`, max SPEF, period 26.041667 ns, `physical/constraints.sdc`.

## Command / native step

OpenSTA `report_worst_slack -max`, `report_tns -max`, `find_timing_paths`
inside OpenROAD 26Q2-254-g61932e897 after OpenRCX max extraction.

## Evidence

| Item | Path |
|---|---|
| Native STA log (WNS/TNS/viol count) | [evidence/setup/max_ss_setup_summary.rpt](evidence/setup/max_ss_setup_summary.rpt) |
| Native worst path | [evidence/setup/max_ss_worst_paths.rpt](evidence/setup/max_ss_worst_paths.rpt) |

- Tool: OpenROAD/OpenSTA 26Q2-254-g61932e897
- Original source: `physical/results/final_signoff/04_sta_max.log`, `sta_max_ss/setup.rpt`
- Input: routed ODB SHA `ca78b97b…`, max SPEF SHA `b822d55d…`
- Path report shows `clock core_clk (rise edge)` **26.041668 ns** and slack MET **0.183361 ns**

## Remaining risk

Production SDC case-analyzes `rst_n`. See [04_reset.md](04_reset.md).
