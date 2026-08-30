# 05 — Antenna (ACH validation)

**PASS**

| | |
|---|---|
| OpenROAD violating nets | **0** |
| OpenROAD violating pins | **0** |
| Diode count | **7** |
| GDS SHA | `93f2aba11dab0df4e3c9431ff2e2c060fce066da17924ad1ed2657b19e4e5dd7` |
| KLayout antenna_only items | **0** |

Automatic LibreLane antenna-repair DRT was disabled
(`DRT_ANTENNA_REPAIR_ITERS = 0`). Diodes were inserted without a second
full-chip DRT.

Evidence: [openroad_check_antennas.rpt](evidence/antenna/openroad_check_antennas.rpt),
[klayout_antenna.lyrdb](evidence/antenna/klayout_antenna.lyrdb)
