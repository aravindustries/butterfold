# 07 — LVS

## Full device-level Netgen LVS (team signoff)

**PASS** — `Final result: Circuits match uniquely.`

| Side | Methodology |
|---|---|
| Layout | Magic 8.3 native GDS extraction, `MAGIC_EXT_USE_GDS=1`, `MAGTYPE=mag` |
| GDS | filled team GDS SHA `f193cb1b7f4ec60f41e8993f662416ed2c2a4e63ae107d213a85d8f4749f3906` |
| Stdcells | extracted to real `nfet_05v0` / `pfet_05v0` |
| SRAM | official hard-macro blackbox; count **2** |
| Source | filled ECO powered netlist `butterfold_top.final.pnl.v` + official `CELL_SPICE_MODELS` |
| Setup | official `/foss/pdks/gf180mcuD/libs.tech/netgen/gf180mcuD_setup.tcl` |
| Compare | Netgen 1.5.318 `-blackbox -json` |

Top: **11612 devices / 11623 nets** each side. Pins including `VDD`/`VSS` equivalent.

KLayout GDS vs OpenROAD CDL remains a documented non-record FAIL (zero-device
CDL stubs). Team LVS of record is Magic + Netgen.

Evidence: [full_netgen_lvs_summary.rpt](evidence/lvs/full_netgen_lvs_summary.rpt)
