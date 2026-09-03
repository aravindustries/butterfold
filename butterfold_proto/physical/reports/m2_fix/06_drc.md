# 06 — Foundry DRC / official density / MSLOT (m2-fix)

GDS SHA `af6758ea9759ce7d48cb3b78bfea4cb13fdba6af8b18af94d56e73a09e6c8cd3`.
Outer DIE **1110 × 1675 µm** (final ACH envelope).
Compact CORE `6.72 20.16 1085.84 1088.64`.
Metal2 keep-out (0, 0)–(2.0, 65.0) µm: **zero drawing Metal2** in the GDS
([final_m2_intersection.json](evidence/m2_audit/final_m2_intersection.json)).

## Non-fill drawing DRC

Official `run_drc.py --variant=D --table=<name> --run_mode=flat`. Metal/via/contact/nplus/pplus/comp/poly2 use `--no_connectivity` (ACH methodology). Nwell uses default connectivity (`CONNECTIVITY_RULES enabled: true`), matching ACH.

| Table | Result |
|---|---|
| Metal1 | 0 items **PASS** |
| Metal2 | 0 items **PASS** |
| Metal3 | 0 items **PASS** |
| Metal4 | 0 items **PASS** |
| Metal5 | 0 items **PASS** |
| MetalTop | 0 items **PASS** |
| Via1–Via4 | 0 items **PASS** |
| Poly2 | 0 items **PASS** |
| Nwell (connectivity on) | 0 items **PASS** |
| Nplus | 0 items **PASS** |
| Pplus | 0 items **PASS** |
| COMP | 0 items **PASS** |
| KLayout antenna | 0 items **PASS** |
| Contact CO.1–CO.11 (includes CO.6a) | 0 items **PASS** |

Evidence: [non_fill_drc_summary.rpt](evidence/drc/non_fill_drc_summary.rpt)

## Official full-GDS density

The official GF180 `density.drc` sets `CHIP = extent.sized(0.0)` and evaluates
the **entire 1110 × 1675 µm** top-cell GDS bbox.

| Rule | Limit | Official 1110×1675 | Classification |
|---|---|---|---|
| DCF.1d COMP | ≤ 70% | **23.75%** | **PASS** |
| DCF.1b COMP | ≥ 25% | **23.75%** | **BELOW NOMINAL THRESHOLD ON ACH VALIDATION ENVELOPE** |
| PL.8 Poly2 | ≥ 14% | **18.06%** | **PASS** |
| M1.4 Metal1 | > 30% | **21.77%** | **BELOW NOMINAL THRESHOLD ON ACH VALIDATION ENVELOPE** |
| M2.4 Metal2 | > 30% | **13.42%** | **INTEGRATOR FILL PENDING** |
| M3.4 Metal3 | > 30% | **16.59%** | **INTEGRATOR FILL PENDING** |
| M4.4 Metal4 | > 30% | **2.34%** | **INTEGRATOR FILL PENDING** |
| M5.4 Metal5 | > 30% | **2.67%** | **INTEGRATOR FILL PENDING** |
| MT.3 MetalTop | > 30% | **2.67%** | **INTEGRATOR FILL PENDING** |

Evidence: [official_full_envelope_summary.rpt](evidence/density/official_full_envelope_summary.rpt),
[official_full_envelope_density.log](evidence/density/official_full_envelope_density.log),
[official_full_envelope_density.lyrdb](evidence/density/official_full_envelope_density.lyrdb)

## MSLOT

**PASS — 0 items.** Unified official deck (`mslot_unified.drc`,
`table_name=main`) invoked with `-rd beol=true -rd feol=true -rd metal_top=11K
-rd mim_option=B -rd metal_level=5LM`. MSLOT.0–.9 all executed.

Evidence: [mslot_unified.lyrdb](evidence/mslot/mslot_unified.lyrdb),
[mslot_unified.log](evidence/mslot/mslot_unified.log)
