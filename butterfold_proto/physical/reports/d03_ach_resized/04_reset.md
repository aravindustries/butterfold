# 04 — Reset electrical (ACH validation)

**PASS**

With `rst_n` case analysis unset (reset visible):

| | |
|---|---|
| Reset slew violations | **0** |
| Reset cap violations | **0** |

Functional reset-recovery: **PASS**
([reset_recovery.log](evidence/functional/reset_recovery.log)).

Evidence: [extract_elec.log](evidence/electrical/extract_elec.log)
(`RESET_SLEW 0 RESET_CAP 0`),
[reset_visible_violators.rpt](evidence/reset/reset_visible_violators.rpt)
