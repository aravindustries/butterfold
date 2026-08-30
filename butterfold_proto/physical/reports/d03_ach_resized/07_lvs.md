# 07 — LVS (resized ACH validation)

**PASS** — `Final result: Circuits match uniquely.`

| Side | Methodology |
|---|---|
| Layout | Magic 8.3 GDS extract of ACH GDS SHA `93f2aba11dab0df4e3c9431ff2e2c060fce066da17924ad1ed2657b19e4e5dd7` |
| Stdcells | extracted to real `nfet_05v0` / `pfet_05v0` |
| SRAM | official hard-macro blackbox; count **2** |
| Source | filled ECO powered netlist `butterfold_top.final.pnl.v` + official `CELL_SPICE_MODELS` |
| Setup | official `/foss/pdks/gf180mcuD/libs.tech/netgen/gf180mcuD_setup.tcl` |
| Compare | Netgen `-blackbox -json` |

Top: **11537 devices / 11552 nets** each side. Pins including `VDD`/`VSS` equivalent.

LibreLane default `setup.tcl` is **not** the team method (it failed pin matching
on the same extract). Mag `extract unique all` pin-alias reconstruction plus one
audited leftover SRAM `Q[3]` unique-split join was applied to **this**
extraction (not a copied old six-net list).

Evidence: [lvs_summary.rpt](evidence/lvs/lvs_summary.rpt),
[lvs.netgen.rpt](evidence/lvs/lvs.netgen.rpt),
[lvs.tcl](evidence/lvs/lvs.tcl),
[extract_spice_gds.tcl](evidence/lvs/extract_spice_gds.tcl)
