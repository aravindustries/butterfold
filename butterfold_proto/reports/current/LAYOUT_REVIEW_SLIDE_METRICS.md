# ButterFold layout-review metrics

**61.44 MHz**  
TARGET CLOCK (16.2760416667 ns)

**3 / 3**  
ANALYZED PVT CORNERS PASS SETUP/HOLD

**21 / 21**  
TOP-LEVEL SIGNAL TERMINALS MATCH

**2 / 2**  
256x8 SRAM MACROS MATCH

**0**  
512x8 SRAM MACROS

**0**  
UNEXPLAINED HIERARCHICAL LVS NET MISMATCHES

**0**  
OPENROAD ROUTING DRC VIOLATIONS

**37,494 — FAIL**  
FULL GF180 GDS DRC MARKERS (54 NONZERO RULE CATEGORIES)

## Signoff-hardening status

- Hierarchical GDS LVS: **PASS**, negative control fails as expected.
- Full GF180 GDS DRC: **FAIL**; no waivers applied.
- PDN connectivity: **NOT ESTABLISHED**; pad/core supply nets are separate and OpenROAD has no physical supply BTerm.
- Failed PDN vias: **3**.
- Quantitative IR drop: **NOT ESTABLISHED**.
- Antenna: **FAIL — 24** PDK-deck violations; antenna diodes: **0**.
- Tap/well: **CONCERN**; 1,494 fillties and 592 endcaps exist, but full-deck well rules fail.
- ESD/I/O: foundry cells used and `ESD.*` deck markers are zero; system-level supply/discharge continuity remains **CONCERN**.
- Voltage-domain signal buffering: intended input/clock/reset isolation is present; supply-domain physical closure is **CONCERN**.
- Quantitative EM/current density: **NOT ESTABLISHED**.
- Known open issue: **5-pF output-pad slew/load closure** (4.61 ns worst SS versus 1.0 ns Liberty limit).

GDS: `physical/results/padframe/gds/butterfold_padframe_candidate.gds`  
SHA-256: `a7820a96542f2b443ea2f5e44cf227d777583f751d031f629d542aea3fde8f4d`
