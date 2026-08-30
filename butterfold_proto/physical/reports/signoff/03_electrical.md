# 03 — Non-reset electrical

**PASS**

max-SS extracted, `rst_n` case-analysis on (reset hidden):

| Check | Violators |
|---|---|
| max slew | 0 |
| max capacitance | 0 |
| max fanout | 0 |

Empty `-violators` dumps are the native OpenSTA result.

Evidence: [max_slew.rpt](evidence/electrical/max_slew.rpt) /
[max_cap.rpt](evidence/electrical/max_cap.rpt) /
[fanout.rpt](evidence/electrical/fanout.rpt)
