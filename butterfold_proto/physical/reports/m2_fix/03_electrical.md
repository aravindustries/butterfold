# 03 — Electrical slew / cap / fanout (m2-fix)

**PASS**

Extracted max-SS on filled ODB (of-record session):

| | |
|---|---|
| Max slew violations | **0** (`ELECV_CASE SLEW 0`) |
| Max cap violations | **0** (`CAP 0`) |
| Max fanout violations | **0** (`FANOUT 0`) |

`rst_n` case analysis 1 for the non-reset electrical check.

Evidence: [extract_elec.log](evidence/electrical/extract_elec.log),
[fanout.rpt](evidence/electrical/fanout.rpt)
