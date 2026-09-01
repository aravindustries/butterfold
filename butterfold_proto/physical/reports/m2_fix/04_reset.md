# 04 — Reset electrical (m2-fix)

**PASS**

With `rst_n` case analysis unset (reset visible), max-SS extracted:

| | |
|---|---|
| Reset slew violations | **0** |
| Reset cap violations | **0** |
| Reset fanout violations | **0** |

Functional reset-recovery: **PASS**
([reset_recovery.log](evidence/functional/reset_recovery.log)).

A light `repair_design -max_wire_length 0 -slew_margin 20` inserted a few
`buf_20` cells on `rst_n`. Broad 4×4 `clkbuf_16` trees and
`repair_design -max_wire_length 250` were rejected (setup regression).

Evidence: [extract_elec.log](evidence/electrical/extract_elec.log)
(`MAX_RESET SLEW 0 CAP 0 FANOUT 0`),
[reset_visible_violators.rpt](evidence/reset/reset_visible_violators.rpt)
