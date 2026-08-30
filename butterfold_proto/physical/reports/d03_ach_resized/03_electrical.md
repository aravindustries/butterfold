# 03 — Electrical slew / cap / fanout (ACH validation)

**PASS**

Extracted max-SS on filled ODB (of-record session):

| | |
|---|---|
| Max slew violations | **0** (`SLEW 0` in extract_elec.log) |
| Max cap violations | **0** (`CAP 0` in extract_elec.log) |
| Max fanout violations | **0** |

The of-record extracted log prints slew/cap counts. The OpenSTA `-violators`
dump for that session is empty
([max_slew_cap_violators.rpt](evidence/electrical/max_slew_cap_violators.rpt)).
A companion dump with `-max_slew -max_capacitance -max_fanout -violators` is
also empty ([fanout.rpt](evidence/electrical/fanout.rpt)).

Evidence: [extract_elec.log](evidence/electrical/extract_elec.log),
[max_slew_cap_violators.rpt](evidence/electrical/max_slew_cap_violators.rpt),
[fanout.rpt](evidence/electrical/fanout.rpt)
