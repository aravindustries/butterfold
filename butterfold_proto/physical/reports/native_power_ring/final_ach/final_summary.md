# Final native ACH tapeout closure

Candidate 38 is the accepted native-PDN ACH implementation. Its exact GDS SHA256 is
`fb327176ba6957ff6ba964c68217a7da07997e175f93e00f5cc49354fc7b4e09` and its bbox is
1110 x 1675 um.

## Hard gates

| Gate | Final result |
|---|---:|
| ACH terminals | 135/135 |
| Required I/O controls | 102/102 |
| Functional padframe mappings | 21/21 PASS |
| Native PDN | PASS; Metal4 vertical / Metal5 horizontal core ring, 2.0 um width, 1.7 um spacing, 0.6 um offset |
| Placement / unrouted signals / DRT | legal / 0 / 0 |
| Setup, max_ss_125C_4v50 | WNS +0.152161 ns, TNS 0, 0 violations |
| Hold, min_ff_n40C_5v50 | WNS +0.400962 ns, TNS 0, 0 violations |
| Slew / capacitance / fanout | 0 / 0 / 0 |
| Antenna nets / pins | 0 / 0 |
| GF180 non-fill DRC | 0 across all 16 established tables |
| MSLOT | 0 |
| Pad-pin spacing | 145/145 regions checked, 0 violations; `din_ready_o` 0.350 um versus 0.280 um M2.2a |
| SW Metal2 corner keepout | PASS; 0 polygons, 0 area |
| PSM VDD / VSS | PASS / PASS, all shapes connected |
| IR, VDD / VSS | 0.0772 V / 0.0533 V worst-case drop |
| Vectorless power | 0.0964 W |
| Magic + Netgen LVS | Circuits match uniquely; 11,875 devices and 11,849 nets per compared circuit; 2 SRAMs |
| Functional regression | FINAL-PIN OVERALL RESULT PASS, TX_BYTE_INTERVAL=10 |
| Reset recovery | PASS |

The exact final GDS was used for ACH terminal, pad spacing, organizer keepout,
non-fill DRC, MSLOT, density, Magic extraction, Netgen LVS, and bbox checks.
Timing and IR use the exact final ODB that streamed this GDS and the committed
max/min extraction products.

## Final ACH-envelope density

The official density deck was run on the complete, unclipped ACH bbox. Results
are recorded without converting package-fill responsibility into a false core pass:

| Layer/rule | Density |
|---|---:|
| COMP / DCF.1b | 23.3637834275% (below 25% minimum) |
| DCF.1d | no maximum-density marker |
| Poly2 / PL.8 | 17.7747600242% |
| Metal1 | 21.6981596665% (below 30% minimum) |
| Metal2 | 14.0964287374% (below 30% minimum) |
| Metal3 | 17.1445448998% (below 30% minimum) |
| Metal4 | 5.1661857416% (below 30% minimum) |
| Metal5 | 3.7789315477% (below 30% minimum) |
| MetalTop | 3.7789315477% (below 30% minimum) |

These values are final ACH-envelope characterization; top-level/package fill is
required to meet global minimum-density rules.

## Provenance

The powered netlist is `artifacts/butterfold_top.pnl.v`; it contains all 135 ACH
ports, 102 deterministic tie-cell control sources, and exactly two SRAM macro
instances. The complete artifact hashes are in `SHA256SUMS`.

Magic extraction originally failed because the wrapper imported both GDS and DEF,
duplicating all devices. The final extraction imports the exact GDS once, matching
the established flow. This was an extraction-wrapper correction, not a layout ECO.
