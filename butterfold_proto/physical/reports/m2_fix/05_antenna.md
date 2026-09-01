# 05 — Antenna (m2-fix)

**PASS**

| | |
|---|---|
| OpenROAD violating nets | **0** |
| OpenROAD violating pins | **0** |
| Diode count | **3** |
| GDS SHA | `af6758ea9759ce7d48cb3b78bfea4cb13fdba6af8b18af94d56e73a09e6c8cd3` |
| KLayout antenna_only items | **0** |

Automatic LibreLane antenna-repair DRT was not used as a destructive full-chip
loop. Targeted diode insertion, then fill.

Evidence: [openroad_check_antennas.rpt](evidence/antenna/openroad_check_antennas.rpt),
[klayout_antenna.lyrdb](evidence/antenna/klayout_antenna.lyrdb),
[klayout_antenna.log](evidence/antenna/klayout_antenna.log)
