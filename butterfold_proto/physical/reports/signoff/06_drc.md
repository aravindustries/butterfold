# 06 — Foundry DRC / density / mslot

## Result

Pre-fill (team) GDS SHA `f193cb1b7f4ec60f41e8993f662416ed2c2a4e63ae107d213a85d8f4749f3906`.

| Check | Official rule | Measured | Classification |
|---|---|---|---|
| COMP max (clear) | DCF.1d ≤ 70% | 35.72% | **PASS** |
| COMP min | DCF.1b ≥ 25% | 35.72% | **PASS** |
| Poly2 min | PL.8 ≥ 14% | 27.19% | **PASS** |
| Metal1 min | M1.4 > 30% | 33.21% | **PASS** |
| Metal2 min | M2.4 > 30% | 19.52% | **INTEGRATOR FILL PENDING** |
| Metal3 min | M3.4 > 30% | 24.54% | **INTEGRATOR FILL PENDING** |
| Metal4 min | M4.4 > 30% | 3.63% | **INTEGRATOR FILL PENDING** |
| Metal5 min | M5.4 > 30% | 4.17% | **INTEGRATOR FILL PENDING** |
| MetalTop min (5LM = Metal5) | MT.3 > 30% | 4.17% | **INTEGRATOR FILL PENDING** |
| CO.6a | 0 | 0 | **PASS** |
| M2.1 / M2.2a / M2.3 | 0 | 0 | **PASS** |
| M3.3 | 0 | 0 | **PASS** |
| M4.2a / M4.3 | 0 | 0 | **PASS** |
| MT.1 | 0 | 0 | **PASS** |
| Other KLayout drawing tables | 0 items | 0 | **PASS** |
| MSLOT | MSLOT.0–.9 | 0 items | **PASS** |

## MSLOT

Split-table `TABLE_NAME=mslot` still crashes (`via_below.sized` on nil).
Unified official invocation (`table_name=main`) **PASS**, 0 items.

## Status

Max/clear density: **PASS** (DCF.1d).
Min-metal M2–MT: **INTEGRATOR FILL PENDING**.
MSLOT: **PASS**.
Real non-fill drawing rules: 0 items including CO.6a.
