# 05 — Antenna

## Result

**PASS** on the CO.6a-repaired routed topology and on the streamed GDS.

| Check | Result |
|---|---|
| OpenROAD `check_antennas` | 0 nets / 0 pins |
| Physical diode cells | **35** |
| KLayout `antenna.drc` | 0 items |

Diode cells were not removed to force LVS counts. Netgen reduces 35→31
equivalent antenna devices on **both** sides after official
`property parallel`.

## Evidence

| Item | Path |
|---|---|
| OpenROAD `check_antennas` | [evidence/antenna/openroad_check_antennas.rpt](evidence/antenna/openroad_check_antennas.rpt) |
| Diode inventory | [evidence/antenna/diode_inventory.rpt](evidence/antenna/diode_inventory.rpt) |
| KLayout antenna lyrdb | [evidence/antenna/klayout_antenna.lyrdb](evidence/antenna/klayout_antenna.lyrdb) |

- Tool: OpenROAD 26Q2 `check_antennas`; KLayout 0.30.8 `antenna.drc`
- Input GDS SHA `6d66a476…`
