# 07 — LVS (22-pin compact)

**PASS** — `Final result: Circuits match uniquely.`

| Side | Methodology |
|---|---|
| Layout | Magic 8.3 GDS extract of SHA `31dbce1e19295c6678531c205bba780898b013a69976e6056837821c3de9a64e` |
| Stdcells | extracted to real `nfet_05v0` / `pfet_05v0` |
| SRAM | official hard-macro blackbox; count **2** |
| Source | filled ECO powered netlist `butterfold_top.final.pnl.v` + official `CELL_SPICE_MODELS` |
| Setup | official `/foss/pdks/gf180mcuD/libs.tech/netgen/gf180mcuD_setup.tcl` |
| Compare | Netgen `-blackbox -json` |

Top: **11568 devices / 11582 nets** each side.

Pins (22, equivalent): `stream_status_o`, `dout[7:0]`, `din[7:0]`,
`din_valid_i`, `rst_n`, `clk`, `VDD`, `VSS`.

No `din_ready_o`. No `dout_valid_o`.

Mag `extract unique all` pin-alias reconstruction from this extraction + ODB
(`d03_resized_lvs_unique_fix.py`). The historical leftover SRAM `Q[3]` join
was already absorbed by the ODB parent remap (leftover count 0).

Evidence: [lvs_summary.rpt](evidence/lvs/lvs_summary.rpt),
[lvs.netgen.rpt](evidence/lvs/lvs.netgen.rpt),
[lvs.tcl](evidence/lvs/lvs.tcl)
