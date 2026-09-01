# 07 — LVS (m2-fix)

**PASS** — `Final result: Circuits match uniquely.`

| Side | Methodology |
|---|---|
| Layout | Magic 8.3 GDS extract of m2-fix GDS SHA `af6758ea9759ce7d48cb3b78bfea4cb13fdba6af8b18af94d56e73a09e6c8cd3` |
| Stdcells | extracted to real `nfet_05v0` / `pfet_05v0` |
| SRAM | official hard-macro blackbox; count **2** |
| Source | filled ECO powered netlist `butterfold_top.final.pnl.v` + official `CELL_SPICE_MODELS` |
| Setup | official `/foss/pdks/gf180mcuD/libs.tech/netgen/gf180mcuD_setup.tcl` |
| Compare | Netgen `-blackbox -json` |

Top: **11621 devices / 11640 nets** each side. Pins including `VDD`/`VSS` equivalent.

LibreLane default `setup.tcl` is **not** the team method. Mag `extract unique all`
pin-alias reconstruction plus the audited leftover SRAM `Q[3]` unique-split join
(already present in the odb parent) was applied to **this** extraction.

Evidence: [lvs_summary.rpt](evidence/lvs/lvs_summary.rpt),
[lvs.netgen.rpt](evidence/lvs/lvs.netgen.rpt),
[lvs.tcl](evidence/lvs/lvs.tcl),
[netgen.log](evidence/lvs/netgen.log)
