# 08 — Routing / PG / IR

**PASS** (routing, PG). IR characterized.

| Check | Result |
|---|---|
| GRT overflow | 0 / 0 / 0 all layers |
| DRT violations | 0 (`capfix.drc` empty) |
| Unrouted / opens / shorts | 0 |
| Placement | legal; 26524 fillers |
| aoi221_2 orientations | 3 remaining, all R0 (FAILORI 0) |
| PG VDD | all shapes connected (PSM-0040) |
| PG VSS | all shapes connected (PSM-0040) |
| IR VDD | worst **1.82 mV** (0.04% of 4.5 V) |
| IR VSS | worst **2.26 mV** (0.05%) |

Evidence: [capfix_route.log](evidence/routing/capfix_route.log),
[fill.log](evidence/routing/fill.log),
[ir_power.log](evidence/ir/ir_power.log)
