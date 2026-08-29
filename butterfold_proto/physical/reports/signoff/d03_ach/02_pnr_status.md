# D03/ACH P&R status (not signoff)

Template application **PASS**. Full promotion gate **not closed**. Canonical GDS **not replaced**.

| Item | Result |
|---|---|
| Die / core | 1110×1675 µm / 6.72 20.16 1103.20 1653.12 |
| Pins | 23/23 at official ACH translated Metal2 abutment |
| SRAM | 2 macros, locations unchanged |
| DRT (drt-run-0) | **0 violations**, 1.092 mm wire |
| Fill | LibreLane `OpenROAD.FillInsertion` |
| max-SS setup | **WNS -8.578 ns**, TNS -3015 ns, 735 violators |
| min-FF hold | **WNS 0** |
| Antenna | 8 nets / 8 pins after pre-DRT repair |
| PG connectivity | ECO stitch: VDD_OK VSS_OK (`check_power_grid`) |
| Magic GDS SHA | `ae6a454f94a8b64d1f04b2583388233938cf3712cfa2de0077df6f6451f54ff9` |
| Promoted? | **No** |

Still required before promotion: extracted setup closure, antenna 0, same-GDS KLayout main/density/MSLOT/antenna, Magic+Netgen unique-match LVS, IR with distributed VSRC.
