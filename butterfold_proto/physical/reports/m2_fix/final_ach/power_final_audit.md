# Final ACH-to-core power-interface audit

| Supply | Organizer pad/terminal | Source locations | Source width | Internal target | Connectivity | Worst IR drop |
|---|---|---:|---:|---|---|---:|
| VDD | N07 / DVDD | 6 north-edge Metal2 feeds | 1.000 µm each | ButterFold VDD PDN | all shapes connected | 0.125 V at 4.50 V |
| VSS | W07 / DVSS | 6 west-edge Metal2 feeds | 1.000 µm each | ButterFold VSS PDN | all shapes connected | 0.0889 V |

The six VDD source coordinates and six VSS source coordinates are recorded in
the final PSM source files used by `final_ach_ir_power.tcl`. OpenROAD PSM reports
that all shapes on each supply net are connected. The exact routed implementation
also passes the organizer Metal2 port-spacing and southwest-blockage audits, so
power has no exemption from the protected-geometry rules.

```
ACH_TO_BUTTERFOLD_VDD_PATH: PASS
ACH_TO_BUTTERFOLD_VSS_PATH: PASS
VDD_FEED_PATHS: 6
VSS_FEED_PATHS: 6
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
```

The organizer maps DVDD only to ButterFold VDD and DVSS only to ButterFold VSS;
no distinct named supply domains were shorted by name inference.
