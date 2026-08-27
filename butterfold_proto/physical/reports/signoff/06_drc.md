# 06 — Foundry DRC / density / mslot

## Result

Authoritative KLayout main-deck on the North/West Magic GDS
SHA `6d66a47623c96dcbfb2e6258081934f7a26c033f953b57469b1730d0c5e7dd12`:

**Klayout DRC run is clean. GDS has no DRC violations.**

Main lyrdb **0 items**. Antenna lyrdb **0 items**. CO.6a **0**.

Chipathon guidance: **minimum-clear / maximum-metal must pass on the team
GDS**; **minimum-metal fill is integrator-side**.

| Check | Official rule | Filled Magic GDS | Classification |
|---|---|---|---|
| COMP max (clear) | DCF.1d ≤ 70% | 34.39% | **PASS** |
| COMP min | DCF.1b ≥ 25% | 34.39% | **PASS** |
| Poly2 min | PL.8 ≥ 14% | 26.28% | **PASS** |
| Metal1 min | M1.4 > 30% | 32.67% | **PASS** |
| Metal2 min | M2.4 > 30% | 19.66% | **INTEGRATOR FILL PENDING** |
| Metal3 min | M3.4 > 30% | 24.72% | **INTEGRATOR FILL PENDING** |
| Metal4 min | M4.4 > 30% | 4.22% | **INTEGRATOR FILL PENDING** |
| Metal5 min | M5.4 > 30% | 5.36% | **INTEGRATOR FILL PENDING** |
| MetalTop min (5LM = Metal5) | MT.3 > 30% | 5.36% | **INTEGRATOR FILL PENDING** |
| Main deck geometry/via/SRAM | — | 0 items | **PASS** |
| Antenna table | — | 0 items | **PASS** |
| CO.6a | M1 contact EOL 0.06 µm | 0 items | **PASS** |
| MSLOT | MSLOT.0–.9 Metal1–Metal5 | 0 items | **PASS** |

## CO.6a

The pre-repair candidate SHA `cd6a1dfc…` had **6 × CO.6a** (MX `aoi221_2`
Metal1 contact EOL, 5 nm short). Evidence:
[co6a_before_markers.rpt](evidence/drc/co6a_before_markers.rpt),
[co6a_before_6markers.lyrdb](evidence/drc/co6a_before_6markers.lyrdb).

Native repair: swap those six masters to `aoi221_1`, DRT cleanup to 0
violations, `filler_placement` (25705), Magic restream. After repair:

- isolated CO.6a script: 0 items
- official main-deck CO.6a: 0 edge-pairs
- official full main lyrdb: 0 items

[co6a_after_markers.rpt](evidence/drc/co6a_after_markers.rpt)

## MSLOT

Official unified deck (`table_name=main` so contact/via1–via4 load):
**0 items**. Do not use split-table `--table=mslot` (known crash).

## Evidence

| Item | Path |
|---|---|
| Official main-deck log (clean) | [evidence/drc/klayout_drc_full.log](evidence/drc/klayout_drc_full.log) |
| Compact summary | [evidence/drc/klayout_drc_summary.rpt](evidence/drc/klayout_drc_summary.rpt) |
| Main lyrdb (0 items) | [evidence/drc/klayout_main_after.lyrdb](evidence/drc/klayout_main_after.lyrdb) |
| Density log | [evidence/drc/density_filled.log](evidence/drc/density_filled.log) |
| Density summary | [evidence/drc/density_filled_summary.rpt](evidence/drc/density_filled_summary.rpt) |
| MSLOT PASS lyrdb | [evidence/drc/mslot_unified.lyrdb](evidence/drc/mslot_unified.lyrdb) |
| MSLOT log | [evidence/drc/mslot_unified.log](evidence/drc/mslot_unified.log) |

- Tool: KLayout 0.30.8 / GF180 `run_drc.py` variant D 5LM 11K, `run_mode=flat`
- Input GDS SHA `6d66a476…` (same SHA as density / MSLOT / LVS)

## Status

Max/clear density: **PASS** (DCF.1d).  
Min-metal M2–MT: **INTEGRATOR FILL PENDING**.  
MSLOT: **PASS**.  
CO.6a and all other non-fill main-deck rules: **PASS**.
