# 03 — Electrical (slew / cap / fanout)

## Result

**PASS** at max-SS extracted: slew **0**, cap **0**, fanout violators **0**.

Evidence files from `report_check_types -max_slew/-max_cap/-max_fanout
-violators` are empty (native OpenSTA result when the violator list is empty).

## Corner / condition

`ss_125C_4v50` + max OpenRCX. Production SDC (`rst_n` case-analyzed 1) for
ordinary checks.

## Evidence

| Item | Path |
|---|---|
| max slew violators | [evidence/electrical/max_slew.rpt](evidence/electrical/max_slew.rpt) |
| max cap violators | [evidence/electrical/max_cap.rpt](evidence/electrical/max_cap.rpt) |
| fanout violators | [evidence/electrical/fanout.rpt](evidence/electrical/fanout.rpt) |

Tool: OpenSTA in OpenROAD 26Q2-254. Same ODB as [01](01_setup_max_ss.md).
