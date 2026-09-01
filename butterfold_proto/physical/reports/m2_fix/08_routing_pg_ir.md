# 08 — Routing, PG, IR (m2-fix)

## Routing

**PASS**

Metal2 keep-out was present from ApplyDEFTemplate / PDN / GRT / DRT.
No post-streamout Metal2 polygon patching.

| | |
|---|---|
| GRT overflow | **0** |
| DRT violations | **0** |
| Unrouted / opens / shorts | **0** |
| Placement legal | **YES** |
| AOI221_2 MX/MY | **0** |

Evidence: [grt_summary.rpt](evidence/routing/grt_summary.rpt),
[drt_summary.rpt](evidence/routing/drt_summary.rpt)

## PG

**PASS** — template VDD/VSS ports connected to compact-core PDN
(`eco_connect_template_pg.py`). OpenROAD PSM: all shapes connected on VDD
and VSS. No Metal2 PG was waived into the keep-out.

Evidence: [psm_connectivity.rpt](evidence/pg/psm_connectivity.rpt)

## IR

**CHARACTERIZED** (no numeric README pass/fail threshold).

| Rail | Worst | Fraction of 4.5 V |
|---|---|---|
| VDD | **0.153 V** drop (4.50 → 4.35) | 3.40% |
| VSS | **0.090 V** | 2.00% |

Evidence: [irdrop_summary.rpt](evidence/ir/irdrop_summary.rpt),
[ir_power2.log](evidence/ir/ir_power2.log)
