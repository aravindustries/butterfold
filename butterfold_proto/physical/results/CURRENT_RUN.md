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
- Current report: `reports/current/PAD_BOUNDARY_CONNECTIVITY_REPAIR_REPORT.md`
- Layout-review evidence: `reports/current/LAYOUT_REVIEW_RUBRIC_EVIDENCE.md`
- Slide metrics: `reports/current/LAYOUT_REVIEW_SLIDE_METRICS.md`
- Latest candidate GDS: `physical/results/padframe/gds/butterfold_padframe_candidate.gds`
- Candidate GDS SHA-256: `a7820a96542f2b443ea2f5e44cf227d777583f751d031f629d542aea3fde8f4d`
- GDS status: **CANDIDATE — output-pad electrical/load specification is not frozen**
- Full GF180 GDS DRC: **FAIL — 37,494 markers in 54 nonzero rule categories**
- Full GDS DRC tool: **KLayout 0.30.8 with installed GF180 Open_PDKs variant-C main FEOL/BEOL/connectivity deck; optional density mode not run**
- Full GDS DRC report: `physical/results/padframe/drc_gf180_serial/butterfold_padframe_candidate_main.lyrdb`
- Full GDS DRC summary: `physical/results/padframe/drc_gf180_serial/violations.json`
- GF180 antenna check: **FAIL — 24 `ANT.16_ii_ANT.3` markers; 0 antenna diodes**
- Antenna report: `physical/results/padframe/antenna_gf180/butterfold_padframe_candidate_antenna.lyrdb`
- Power-grid connectivity: **NOT ESTABLISHED — pad `VDD`/`VSS` are separate from core `u_core/one_`/`u_core/zero_`; no physical supply BTerm**
- Failed PDN vias: **3** (`physical/results/padframe/route/pdn_failed_vias.rpt`)
- Quantitative IR drop: **NOT ESTABLISHED**
- LVS GDS: `physical/results/padframe/gds/butterfold_padframe_candidate.gds`
- LVS GDS SHA-256: `a7820a96542f2b443ea2f5e44cf227d777583f751d031f629d542aea3fde8f4d`
- LVS top: `butterfold_padframe_top`
- LVS reference: `physical/results/padframe/route/butterfold_padframe_physical.v`
- LVS tool: **Magic 8.3 hierarchical extraction + Netgen 1.5.318**
- LVS setup: `/foss/pdks/gf180mcuD/libs.tech/netgen/gf180mcuD_setup.tcl`
- LVS report: `physical/results/padframe/lvs/lvs_report.out`
- LVS status: **PASS — hierarchical foundry-leaf connectivity; 21/21 signal terminals, 2/2 SRAM macros, negative control fails as expected**
- Full transistor LVS: **NOT RUN**

Current extracted STA was regenerated from the authoritative `route.odb` with
the established OpenROAD/OpenRCX padframe-signoff target. At 61.44 MHz all
three analyzed corners pass setup and hold: SS/RCmax +0.45/+1.29 ns,
TT/RCnom +7.64/+0.66 ns, and FF/RCmin +10.78/+0.40 ns overall path slack.
The 5-pF output-pad max-transition failure remains open.

The original boundary failure is preserved in the diagnostic history. The
current milestone treats GF180 standard cells, I/O cells, and SRAMs as verified
leaf cells and compares their instance/pin connectivity against the current
post-route physical netlist. It does not claim transistor-level library LVS.
See `reports/current/HIERARCHICAL_LVS_MILESTONE_REPORT.md`.

Candidate hash history:

- `f4601ed31b30a58fb2b5c8aface9db1b62759e842c79f3d53788de2ec21c5da1`: old tracked candidate.
- `beedd2310bbe56e0ff14a1391c59bec4da8625eb234b285dc4a46fff0ec8424c`: superseded intermediate candidate.
- `a7820a96542f2b443ea2f5e44cf227d777583f751d031f629d542aea3fde8f4d`: current authoritative candidate and hierarchical-LVS milestone.

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
