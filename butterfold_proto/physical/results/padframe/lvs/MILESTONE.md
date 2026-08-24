# ButterFold hierarchical LVS milestone

- Top: `butterfold_padframe_top`
- GDS: `physical/results/padframe/gds/butterfold_padframe_candidate.gds`
- GDS SHA-256: `a7820a96542f2b443ea2f5e44cf227d777583f751d031f629d542aea3fde8f4d`
- Reference: `physical/results/padframe/route/butterfold_padframe_physical.v`
- Hierarchical GDS LVS: **PASS**
- Top signal terminals: **21 / 21 MATCH**
- Standard-cell leaf connectivity: **PASS**
- I/O-pad leaf connectivity: **PASS**
- SRAM macros: **2 / 2 MATCH**
- 512x8 SRAM: **0**
- Modeled supplies: **PASS** (single-supply VDD/DVDD/VNW and VSS/DVSS/VPW normalization)
- Unexplained unmatched nets: **0**
- Unexplained unmatched instances: **0**
- Negative control: **FAIL AS EXPECTED**
- Full transistor LVS: **NOT RUN**
- Full GDS signoff DRC: **NOT RUN**
- Output 5-pF slew: **KNOWN UNRESOLVED ISSUE**

This remains a candidate physical snapshot, not final or tapeout GDS.
