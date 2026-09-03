# Final ACH-to-core power-interface audit

| Supply | Organizer pad/terminal | Source locations | Source width | Internal target | Connectivity | Worst IR drop |
|---|---|---:|---:|---|---|---:|
| VDD | N07 / DVDD | 6 north-edge Metal2 feeds | 1.000 µm each | ButterFold VDD PDN | all shapes connected | 0.125 V at 4.50 V |
| VSS | W07 / DVSS | 6 west-edge Metal2 feeds | 1.000 µm each | ButterFold VSS PDN | all shapes connected | 0.0889 V |

The six source coordinates per supply are recorded in the final PSM source
files. OpenROAD PSM reports all shapes connected. Physical adequacy is proven
separately: VDD has three independent generated-array entries; the constrained
VSS entry has 6-cut and 9-cut generated transitions. See
`power_via_audit_post_fix.md` for final-GDS cut bboxes and before/after evidence.

```
ACH_TO_BUTTERFOLD_VDD_PATH: PASS
ACH_TO_BUTTERFOLD_VSS_PATH: PASS
VDD_SOURCE_PORTS: 6
VSS_SOURCE_PORTS: 6
TRUE_INDEPENDENT_VDD_ENTRY_PATHS: 3
TRUE_INDEPENDENT_VSS_ENTRY_PATHS: 1
VDD_SINGLE_VIA_BOTTLENECKS: 0
VSS_SINGLE_VIA_BOTTLENECKS: 0
MIN_CRITICAL_VDD_VIA_CUT_COUNT: 3
MIN_CRITICAL_VSS_VIA_CUT_COUNT: 6
RAW_HAND_DRAWN_CRITICAL_VIA_CUTS: 0
CRITICAL_POWER_VIAS_IMPLEMENTED_WITH_PCELL_OR_TECH_GENERATED_VIA: YES
MIN_POWER_SOURCE_WIDTH_UM: 1.000
POWER_TO_UNRELATED_PIN_OVERLAPS: 0
POWER_TO_BLOCKAGE_OVERLAPS: 0
POWER_DOMAIN_CROSS_SHORTS: 0
PG_VDD: PASS
PG_VSS: PASS
IR_VDD_WORST_DROP_V: 0.125
IR_VSS_WORST_DROP_V: 0.0889
VECTORLESS_POWER_W: 0.120
POWER_INTERFACE_PHYSICALLY_AUDITED: YES
POWER_INTERFACE_STRENGTHENED: PASS
REVIEWER_SINGLE_VIA_POWER_CONCERN: RESOLVED
```

The organizer maps DVDD only to ButterFold VDD and DVSS only to ButterFold VSS;
no distinct named supply domains were shorted by name inference.
