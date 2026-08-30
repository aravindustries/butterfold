# 08 — Routing, PG, IR (ACH validation)

## Routing

**PASS**

| | |
|---|---|
| GRT overflow | **0** (Metal2–Metal5 0 / 0 / 0) |
| DRT violations | **0** (`route__drc_errors=0`) |
| Unrouted / opens / shorts | **0** (DRT `route__drc_errors=0`, disconnected pins 0, post-ECO DRT violation files 0 bytes) |
| Disconnected pins | **0** |

Evidence: [grt_summary.rpt](evidence/routing/grt_summary.rpt),
[drt_summary.rpt](evidence/routing/drt_summary.rpt)

## PG

**PASS** — template VDD/VSS ports connected to compact-core PDN.
OpenROAD PSM: all shapes connected on VDD and VSS.

Evidence: [psm_connectivity.rpt](evidence/pg/psm_connectivity.rpt)

## IR

**CHARACTERIZED** (no numeric README pass/fail threshold).

| Rail | Worst | Fraction of 4.5 V | Nodes |
|---|---|---|---|
| VDD | **0.149 V** drop | 3.32% | 42936, all connected |
| VSS | **0.088 V** | 1.96% | 42936, all connected |

Six VDD north + six VSS west ACH pin-box sources.

Evidence: [irdrop_summary.rpt](evidence/ir/irdrop_summary.rpt)
