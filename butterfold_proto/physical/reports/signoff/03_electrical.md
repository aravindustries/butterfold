# 03 — Electrical (slew / cap / fanout)

## Result

**PASS** at max-SS extracted: non-reset slew **0**, cap **0**, fanout violators
listed **0**.

`sta::max_fanout_violation_count` is not used (this OpenSTA build can crash on
huge nets). Fanout evidence is `report_check_types -max_fanout -violators`
output: empty file.

## Corner / condition

`max_ss_125C_4v50` + max SPEF. Production SDC (`rst_n` case-analyzed 1) for
ordinary checks.

## Evidence

| Item | Path |
|---|---|
| Native violators (slew/cap/fanout combined) | [evidence/electrical/extracted_violators.rpt](evidence/electrical/extracted_violators.rpt) |
| max slew violators | [evidence/electrical/max_slew.rpt](evidence/electrical/max_slew.rpt) |
| max cap violators | [evidence/electrical/max_cap.rpt](evidence/electrical/max_cap.rpt) |
| fanout violators | [evidence/electrical/fanout.rpt](evidence/electrical/fanout.rpt) |
| Counts `SLEW 0` / `CAP 0` | [evidence/setup/max_ss_setup_summary.rpt](evidence/setup/max_ss_setup_summary.rpt) |

Empty `-violators` reports are the native OpenSTA result when the violator
list is empty (zero length). Tool: OpenSTA in OpenROAD 26Q2-254-g61932e897.
Input ODB/SPEF as in [00_manifest.md](00_manifest.md).
