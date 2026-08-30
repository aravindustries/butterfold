# 06 — Foundry DRC / density / MSLOT (22-pin compact)

GDS SHA `31dbce1e19295c6678531c205bba780898b013a69976e6056837821c3de9a64e`
(1092.66 × 1108.80 µm). Official variant C, flat.

## Compact-team density (gate)

| Check | Official rule | Measured | Classification |
|---|---|---|---|
| COMP min | DCF.1b ≥ 25% | **36.338%** | **PASS** |
| COMP max (clear) | DCF.1d ≤ 70% | 36.338% (no ERROR) | **PASS** |
| Poly2 min | PL.8 ≥ 14% | **27.600%** | **PASS** |
| Metal1 min | M1.4 > 30% | **33.325%** | **PASS** |
| Metal2 min | M2.4 > 30% | 19.753% | **INTEGRATOR FILL PENDING** |
| Metal3 min | M3.4 > 30% | 25.264% | **INTEGRATOR FILL PENDING** |
| Metal4 min | M4.4 > 30% | 3.423% | **INTEGRATOR FILL PENDING** |
| Metal5 min | M5.4 > 30% | 4.620% | **INTEGRATOR FILL PENDING** |
| MetalTop min (5LM = Metal5) | MT.3 > 30% | 4.620% | **INTEGRATOR FILL PENDING** |

Official M2.4–MT.3 >30% ERRORs are characterized and **not** the compact-team gate.

## MSLOT

**PASS** — 0 items.

## Antenna (KLayout)

**PASS** — 0 items.

## Non-fill geometric DRC / CO.6a

**PASS** — official variant C main table: **0 items**, 0 `[ERROR]`,
`Klayout DRC run is clean`.

Contact table (including **CO.6a**): **0 items**, clean.

aoi221_2 remaining instances are R0 only (FAILORI 0).

Density evidence: [density.log](evidence/density/density.log)
MSLOT evidence: [mslot.lyrdb](evidence/mslot/mslot.lyrdb)
