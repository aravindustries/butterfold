# 9-track PDK collateral gap

`/foss/pdks/gf180mcuD/libs.tech/librelane/gf180mcu_fd_sc_mcu9t5v0/` ships
`config.tcl`, `no_synth.cells` and `tracks.info` but **no `drc_exclude.cells`**.
The 7-track directory does ship one.  Newer LibreLane validates that the path
in `PNR_EXCLUDED_CELL_FILE` exists and aborts; older versions did not, which is
why runs before Sept 2026 resolved the missing path without complaint and no
exclusion was ever actually applied.

`gf180mcu_fd_sc_mcu9t5v0_drc_exclude.cells` in this directory is intentionally
**empty**, which reproduces that historical behaviour exactly.

## Open question: mux2_1

The 7-track exclusion list contains:

    gf180mcu_fd_sc_mcu7t5v0__mux2_1
    gf180mcu_fd_sc_mcu7t5v0__oai33_2

Both have 9-track equivalents.  `gf180mcu_fd_sc_mcu9t5v0__mux2_1` is used
**1902 times** in the shipped netlist; `oai33_2` is unused.

Upstream did not publish a 9-track exclusion list, so there is no evidence the
9-track `mux2_1` shares the 7-track DRC problem, and excluding it would replace
1902 instances with consequences for area and timing.  The decision was
therefore left to measurement rather than speculation:

**If the GF180 KLayout DRC run attributes markers to `mux2_1` instances, add**

    gf180mcu_fd_sc_mcu9t5v0__mux2_1

**to the empty file above and re-run.**  Otherwise leave it empty.
