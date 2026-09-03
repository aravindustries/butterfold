# Final D03 ACH integration signoff

This directory is the reviewer-facing evidence package for the **FINAL ACH
INTEGRATION**. Connectivity comes only from `D03_ACH_interface.yaml`; geometry
comes only from `D03_ACH.def`. There is no future organizer DEF integration.

Final candidate SHA256:
`12876f003ed41f9b6229ef95207e50af71b16ef45a63ffb8516eb1be5dd71d2d`.

| Gate | Result |
|---|---|
| YAML terminal handling | PASS, 135/135 |
| ButterFold logical API | unchanged, 23 terminals |
| Core-to-ACH padring connectivity | PASS |
| Functional signal mapping | PASS, 21/21 |
| Output core driver / correct enabled pad | PASS, 10/10 |
| Input receiver / core load | PASS, 11/11 |
| Required digital I/O controls | PASS, 102/102; floating 0; illegal 0 |
| Application-selected pad controls | 102, GF180 PDK policy |
| Unrelated/unknown DEF pins | 0 / 0 |
| Organizer blockage import | PASS, 1/1 |
| Southwest Metal2 blockage | PASS, 0 intersection |
| Organizer pad/PORT spacing | PASS, 145 regions, 0 violations |
| Known `din_ready_o` spacing | PASS, 0.350 µm vs 0.280 µm |
| ACH-to-core VDD/VSS | PASS / PASS; reviewer single-via concern resolved |
| Critical PG via arrays | VDD min 3 cuts/source and 6 cuts/core entry; VSS 6/9 cuts; raw cuts 0 |
| Functional + reset regression | PASS / PASS |
| Setup max SS | PASS, WNS +0.039952 ns, TNS 0 |
| Hold min FF | PASS, WNS +0.181811 ns, TNS 0 |
| Slew / capacitance | 0 / 0 |
| Routing / antenna | DRT 0; antenna nets/pins 0/0 |
| Full non-fill DRC | PASS, 0 total |
| MSLOT | PASS, 0 total |
| Magic + Netgen core device-level LVS | PASS, circuits match uniquely |
| SRAM | exactly 2 |
| PSM | all VDD and VSS shapes connected |
| IR | VDD 0.125 V; VSS 0.0889 V |
| Vectorless power | 0.120 W |

The final ACH-envelope density results are recorded without clipping or
fabricated passes: COMP 23.7219%, Poly2 18.0378%, M1 21.7777%, M2 13.9114%,
M3 16.8523%, M4 4.3078%, and M5/MT 2.7698%.

The ButterFold GDS does not contain the physical padring hierarchy. Signoff is
therefore split correctly into exact-GDS device-level core LVS and deterministic
structural padring connectivity proof; it does not claim extracted full-chip
padring LVS.

Key evidence:

- [`interface_yaml_manifest.md`](interface_yaml_manifest.md)
- [`core_to_padring_connectivity.md`](core_to_padring_connectivity.md)
- [`full_def_pin_manifest.md`](full_def_pin_manifest.md)
- [`blockage_manifest.md`](blockage_manifest.md)
- [`pad_spacing_pre_fix.md`](pad_spacing_pre_fix.md)
- [`pad_spacing_post_fix.md`](pad_spacing_post_fix.md)
- [`current_power_interface_audit.md`](current_power_interface_audit.md)
- [`power_final_audit.md`](power_final_audit.md)
- [`power_via_audit_pre_fix.md`](power_via_audit_pre_fix.md)
- [`power_via_audit_post_fix.md`](power_via_audit_post_fix.md)
- [`final_signoff_summary.md`](final_signoff_summary.md)
