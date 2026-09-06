# Final power-ring signoff

GDS SHA `cb44902373b3189249cefb8f7085823e1aa2b0dcd9e483ff7426c30397c5bf9f`

Candidate: `physical/results/m2_fix/candidate_power_ring/butterfold_top.gds`  
Canonical: `gds/butterfold_top.gds` (byte-identical)

KLayout DEF→GDS streamout of `power_ring.odb` / `power_ring.def`, same method as the signed-off ACH GDS.

## Result

| Gate | Result |
|---|---|
| FINAL_POWER_RING | **PASS** |
| FINAL_PDN | **PASS** |
| FULL_SIGNOFF | **PASS** |
| SAME_GDS_FOR_ALL_FINAL_CHECKS | **YES** |
| SAFE_TO_PUSH | **YES** |
| SAFE_TO_MERGE_TO_MAIN | **YES** |
| SAFE_FOR_TAPEOUT | **YES** |
| AUTO_PUSHED / AUTO_MERGED | **NO** |

## Ring

Closed Metal5 VDD/VSS ring in the ACH envelope, 8.0 µm, Via4 3×3 tech-generated arrays. Core-width M5 bars were removed because they overlayed signal Metal4 (tiel abutment and SRAM Q routing) and Mag LVS merged nets. Envelope ring + existing core M4/M5 grid is the production topology. Rejected second VSS branch not recreated.

See [power_ring_connectivity.md](power_ring_connectivity.md).
