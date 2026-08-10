# Current authoritative physical run

Status: pad-aware two-SRAM routed implementation. Input-pad transitions and
clock-root architecture are closed; output-pad 5 pF slew/load closure remains
the current physical blocker.

- Run directory: `physical/results/padframe/route/`
- Top level: `butterfold_padframe_top`
- Routed ODB: `physical/results/padframe/route/route.odb`
- Routed DEF: `physical/results/padframe/route/route.def`
- Physical Verilog: `physical/results/padframe/route/butterfold_padframe_physical.v`
- Routing DRC: `physical/results/padframe/route/detailed_route_drc.rpt` (0 violations)
- SS/RCmax SPEF: `physical/results/padframe/signoff/ss_125C_4v50_max/padframe.spef`
- TT/RCnom SPEF: `physical/results/padframe/signoff/tt_025C_5v00_nom/padframe.spef`
- FF/RCmin SPEF: `physical/results/padframe/signoff/ff_n40C_5v50_min/padframe.spef`
- Multi-corner STA: `physical/results/padframe/signoff/`
- Current report: `reports/current/PAD_CORE_BUFFER_CTS_REPAIR_REPORT.md`
- Latest candidate GDS: `physical/results/padframe/gds/butterfold_padframe_candidate.gds`
- Candidate GDS SHA-256: `f4601ed31b30a58fb2b5c8aface9db1b62759e842c79f3d53788de2ec21c5da1`
- GDS status: **CANDIDATE — output-pad electrical/load specification is not frozen**
- Full GF180 GDS signoff DRC: **NOT RUN**
- LVS: **NOT RUN**

The reproducible `make -C physical candidate-gds` target loads and validates
the routed ODB, exports a stream-out DEF, then merges that routed geometry with
the installed GF180 standard-cell, SRAM, and I/O GDS views using KLayout. It
does not rerun or modify P&R. Do not substitute an older core-only or
experimental result for this run.

The candidate stream-out uses:

- `/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/gds/gf180mcu_fd_sc_mcu9t5v0.gds`
- `/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/gds/gf180mcu_fd_ip_sram__sram256x8m8wm1.gds`
- `/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_io/gds/gf180mcu_fd_io.gds`

The stream-out top is `butterfold_padframe_top`. The generated file reopens
successfully and contains exactly two 256x8 SRAM references, no 512x8 SRAM,
the selected pad cells, standard-cell layouts, routed metal, and the
2235 um x 2235 um die boundary. This structural validation makes it suitable
as input to future full GDS DRC/LVS; it is not final tapeout GDS.
