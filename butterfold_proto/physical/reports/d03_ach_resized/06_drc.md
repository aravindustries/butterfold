# 06 — Foundry DRC / official density / MSLOT (ACH validation)

GDS SHA `93f2aba11dab0df4e3c9431ff2e2c060fce066da17924ad1ed2657b19e4e5dd7`.
Outer DIE **1110 × 1675 µm** (intentional ACH validation extent).
Compact CORE `6.72 20.16 1085.84 1088.64`.

## Non-fill drawing DRC

**PASS — 0 items, including CO.6a = 0.**

| Table | Result |
|---|---|
| Contact CO.1–CO.11 (includes CO.6a) | 0 items **PASS** |
| Metal1 / Metal2 / Metal3 / Metal4 / Metal5 / MetalTop | 0 items **PASS** |
| Via1–Via4 | 0 items **PASS** |
| Poly2 / Nwell / Nplus / Pplus / COMP drawing | 0 items **PASS** |
| KLayout antenna | 0 items **PASS** |

Evidence: [non_fill_drc_summary.rpt](evidence/drc/non_fill_drc_summary.rpt),
[klayout_contact.lyrdb](evidence/drc/klayout_contact.lyrdb)

## Official full-GDS density

The official GF180 `density.drc` sets `CHIP = extent.sized(0.0)` and evaluates
the **entire 1110 × 1675 µm** top-cell GDS bbox. These are the **only** density
numbers used for this ACH artifact.

A 1110 × 1110 clipped GDS was generated as a diagnostic. It is **not** signoff
evidence and is not cited as PASS for DCF.1b or M1.4.

| Rule | Limit | Official 1110×1675 | Classification |
|---|---|---|---|
| DCF.1d COMP | ≤ 70% | **23.56%** | **PASS** |
| DCF.1b COMP | ≥ 25% | **23.56%** | **BELOW NOMINAL THRESHOLD ON ACH VALIDATION ENVELOPE** |
| PL.8 Poly2 | ≥ 14% | **17.93%** | **PASS** |
| M1.4 Metal1 | > 30% | **21.71%** | **BELOW NOMINAL THRESHOLD ON ACH VALIDATION ENVELOPE** |
| M2.4 Metal2 | > 30% | **13.08%** | **INTEGRATOR FILL PENDING** |
| M3.4 Metal3 | > 30% | **16.41%** | **INTEGRATOR FILL PENDING** |
| M4.4 Metal4 | > 30% | **2.49%** | **INTEGRATOR FILL PENDING** |
| M5.4 Metal5 | > 30% | **2.53%** | **INTEGRATOR FILL PENDING** |
| MT.3 MetalTop | > 30% | **2.53%** | **INTEGRATOR FILL PENDING** |

Evidence: [official_full_envelope_summary.rpt](evidence/density/official_full_envelope_summary.rpt),
[official_full_envelope_density.log](evidence/density/official_full_envelope_density.log),
[official_full_envelope_density.lyrdb](evidence/density/official_full_envelope_density.lyrdb)

## MSLOT

**PASS — 0 items.** Unified official deck with `table_name=main` (split-table
`TABLE_NAME=mslot` crashes in this PDK).

Evidence: [mslot_unified.lyrdb](evidence/mslot/mslot_unified.lyrdb),
[mslot_unified.log](evidence/mslot/mslot_unified.log)
