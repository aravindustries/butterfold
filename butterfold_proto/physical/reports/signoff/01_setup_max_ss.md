# 01 — Setup STA (max-SS)

## Result

**PASS** — worst extracted path slack **+1.62 ns MET**, TNS **0**, setup
violations **0**. Period 26.041667 ns (`core_clk`).

## Corner / condition

`ss_125C_4v50` liberty + OpenRCX **max** rules, `physical/constraints.sdc`.

## Command / native step

`physical/scripts/nw_extracted_sta.tcl` with `STA_MODE=ss_setup` on the
CO.6a-repaired routed ODB (OpenROAD 26Q2 / OpenSTA).

## Evidence

| Item | Path |
|---|---|
| Native worst paths | [evidence/setup/max_ss_setup_paths.rpt](evidence/setup/max_ss_setup_paths.rpt) |
| WNS dump | [evidence/setup/max_ss_wns.rpt](evidence/setup/max_ss_wns.rpt) |
| TNS dump | [evidence/setup/max_ss_tns.rpt](evidence/setup/max_ss_tns.rpt) |
| Violations (empty) | [evidence/setup/max_ss_setup_violations.rpt](evidence/setup/max_ss_setup_violations.rpt) |

Path report: data required 27.83 ns, arrival 26.21 ns, slack **1.62 ns MET**.
`report_wns` prints `wns max 0.00` when there are no violating paths.

Six MX `aoi221_2` → `aoi221_1` swaps did not change the worst slack class
relative to the pre-repair North/West ECO (+1.62 ns).
