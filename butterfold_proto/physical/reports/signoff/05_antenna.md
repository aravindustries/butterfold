# 05 — Antenna

## Result

**PASS** on the ECO routed topology (ODB).

OpenROAD: 0 nets / 0 pins. Diodes **14**. KLayout antenna table: 0 items
on the pre-dummy GDS.

Dummy-metal fill is GDS-only (datatype 4) and is not connected to signal
nets. Foundry density on the dummy-filled GDS still fails coverage; antenna
table was 0 on pre-dummy. Full KLayout antenna was not re-run as a multi-hour
full DRC after dummy fill because density already fails (hard stop).

## Evidence

| Item | Path |
|---|---|
| OpenROAD `check_antennas` / diode lines from final DRT | [evidence/antenna/openroad_check_antennas.rpt](evidence/antenna/openroad_check_antennas.rpt) |
| KLayout antenna lyrdb | [evidence/antenna/klayout_antenna.rpt](evidence/antenna/klayout_antenna.rpt) |
| Diode count from OpenROAD inventory | [evidence/antenna/diode_inventory.rpt](evidence/antenna/diode_inventory.rpt) |

- Tool: OpenROAD 26Q2-254-g61932e897 `check_antennas`; KLayout 0.30.8 `antenna.drc`
- Original: `09_drt3.log` (`ANT-0002`/`ANT-0001` Found 0; `FINAL_ANTENNA DIODE 14`), `klayout_drc/butterfold_top_antenna.lyrdb`
- Input ODB SHA `ca78b97b…`; pre-dummy GDS SHA `5a99213a…`
