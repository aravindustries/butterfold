set ::env(STD_CELL_LIBRARY) gf180mcu_fd_sc_mcu9t5v0
set ::env(STEP_ID) OpenROAD.TapEndcapInsertion
set ::env(TECH_LEF) /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
set ::env(MACRO_LEFS) /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
set ::env(VDD_PIN) VDD
set ::env(GND_PIN) VSS
set ::env(TECH_LEFS) "\"nom_*\" /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef \"min_*\" /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__min.tlef \"max_*\" /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__max.tlef"
set ::env(PRIMARY_GDSII_STREAMOUT_TOOL) magic
set ::env(DEFAULT_CORNER) nom_tt_025C_5v00
set ::env(STA_CORNERS) "nom_tt_025C_5v00 nom_ss_125C_4v50 nom_ff_n40C_5v50 min_tt_025C_5v00 min_ss_125C_4v50 min_ff_n40C_5v50 max_tt_025C_5v00 max_ss_125C_4v50 max_ff_n40C_5v50"
set ::env(RT_MIN_LAYER) Metal2
set ::env(RT_MAX_LAYER) Metal5
set ::env(SCL_GROUND_PINS) "VSS VPW"
set ::env(SCL_POWER_PINS) "VDD VNW"
set ::env(TRISTATE_CELLS) "\"gf180mcu_fd_sc_mcu9t5v0__bufz*\""
set ::env(FILL_CELLS) "\"gf180mcu_fd_sc_mcu9t5v0__fill_*\""
set ::env(DECAP_CELLS) "\"gf180mcu_fd_sc_mcu9t5v0__fillcap_*\""
set ::env(LIB) "\"*_tt_025C_5v00\" /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__tt_025C_5v00.lib \"*_ss_125C_4v50\" /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib \"*_ff_n40C_5v50\" /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib"
set ::env(CELL_LEFS) /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
set ::env(CELL_GDS) /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/gds/gf180mcu_fd_sc_mcu9t5v0.gds
set ::env(CELL_VERILOG_MODELS) "/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/verilog/gf180mcu_fd_sc_mcu9t5v0.v /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/verilog/primitives.v"
set ::env(CELL_SPICE_MODELS) /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/spice/gf180mcu_fd_sc_mcu9t5v0.spice
set ::env(CELL_CDLS) /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/cdl/gf180mcu_fd_sc_mcu9t5v0.cdl
set ::env(SYNTH_EXCLUDED_CELL_FILE) /foss/pdks/gf180mcuD/libs.tech/librelane/gf180mcu_fd_sc_mcu9t5v0/no_synth.cells
set ::env(PNR_EXCLUDED_CELL_FILE) /foss/pdks/gf180mcuD/libs.tech/librelane/gf180mcu_fd_sc_mcu9t5v0/drc_exclude.cells
set ::env(OUTPUT_CAP_LOAD) 72.91
set ::env(MAX_FANOUT_CONSTRAINT) 10
set ::env(MAX_TRANSITION_CONSTRAINT) 3
set ::env(MAX_CAPACITANCE_CONSTRAINT) 0.2
set ::env(CLOCK_UNCERTAINTY_CONSTRAINT) 0.25
set ::env(CLOCK_TRANSITION_CONSTRAINT) 0.1499999999999999944488848768742172978818416595458984375
set ::env(TIME_DERATING_CONSTRAINT) 5
set ::env(IO_DELAY_CONSTRAINT) 20
set ::env(SYNTH_DRIVING_CELL) gf180mcu_fd_sc_mcu9t5v0__inv_1/ZN
set ::env(SYNTH_CLK_DRIVING_CELL) gf180mcu_fd_sc_mcu9t5v0__inv_4/ZN
set ::env(SYNTH_TIEHI_CELL) gf180mcu_fd_sc_mcu9t5v0__tieh/Z
set ::env(SYNTH_TIELO_CELL) gf180mcu_fd_sc_mcu9t5v0__tiel/ZN
set ::env(SYNTH_BUFFER_CELL) gf180mcu_fd_sc_mcu9t5v0__buf_1/I/Z
set ::env(PLACE_SITE) GF018hv5v_green_sc9
set ::env(CELL_PAD_EXCLUDE) "gf180mcu_fd_sc_mcu9t5v0__filltie \"gf180mcu_fd_sc_mcu9t5v0__fill_*\" gf180mcu_fd_sc_mcu9t5v0__endcap"
set ::env(DIODE_CELL) gf180mcu_fd_sc_mcu9t5v0__antenna/I
set ::env(WELLTAP_CELL) gf180mcu_fd_sc_mcu9t5v0__filltie
set ::env(ENDCAP_CELL) gf180mcu_fd_sc_mcu9t5v0__endcap
set ::env(DESIGN_NAME) butterfold_top
set ::env(CLOCK_PERIOD) 20.000
set ::env(CLOCK_PORT) clk
set ::env(VDD_NETS) VDD
set ::env(GND_NETS) VSS
set ::env(DIE_AREA) "0 0 1116.640 1113.840"
set ::env(MACROS) "gf180mcu_fd_ip_sram__sram256x8m8wm1 \"gds /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/gds/gf180mcu_fd_ip_sram__sram256x8m8wm1.gds lef /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef instances \\\"u_transform_scheduler_core.u_fft_scratch_sram.u_lo.u_sram \\\\\\\"location \\\\\\\\\\\\\\\"51.120 720.560\\\\\\\\\\\\\\\" orientation N\\\\\\\" u_transform_scheduler_core.u_fft_scratch_sram.u_hi.u_sram \\\\\\\"location \\\\\\\\\\\\\\\"531.120 720.560\\\\\\\\\\\\\\\" orientation N\\\\\\\"\\\" vh /headless/aravindustries-repos/butterfold/butterfold_proto/physical/librelane/gf180mcu_fd_ip_sram__sram256x8m8wm1.vh nl \\\"\\\" pnl \\\"\\\" spef \\\"\\\" lib \\\"\\\\\\\"*ss_125C_4v50*\\\\\\\" /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib \\\\\\\"*tt_025C_5v00*\\\\\\\" /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__tt_025C_5v00.lib \\\\\\\"*ff_n40C_5v50*\\\\\\\" /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib\\\" spice /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/cdl/gf180mcu_fd_ip_sram__sram256x8m8wm1.cdl sdf \\\"\\\" json_h None\""
set ::env(FALLBACK_SDC) /usr/local/lib/python3.12/dist-packages/librelane/scripts/base.sdc
set ::env(PAD_EDGE_SPACING) 0
set ::env(SET_RC_VERBOSE) 0
set ::env(PDN_CONNECT_MACROS_TO_GRID) 1
set ::env(PDN_MACRO_CONNECTIONS) "\".*u_lo.*u_sram VDD VSS VDD VSS\" \".*u_hi.*u_sram VDD VSS VDD VSS\""
set ::env(PDN_ENABLE_GLOBAL_CONNECTIONS) 1
set ::env(PNR_SDC_FILE) /headless/aravindustries-repos/butterfold/butterfold_proto/physical/constraints.sdc
set ::env(DEDUPLICATE_CORNERS) 0
set ::env(FP_TAPCELL_DIST) 20
set ::env(FP_MACRO_HORIZONTAL_HALO) 10
set ::env(FP_MACRO_VERTICAL_HALO) 10
set ::env(CURRENT_ODB) /headless/aravindustries-repos/butterfold/butterfold_proto/physical/librelane/runs/butterfold_top_fft64_50mhz_final_gds/14-openroad-cutrows/butterfold_top.odb
set ::env(SAVE_ODB) /headless/aravindustries-repos/butterfold/butterfold_proto/physical/librelane/runs/butterfold_top_fft64_50mhz_final_gds/15-openroad-tapendcapinsertion/butterfold_top.odb
set ::env(SAVE_DEF) /headless/aravindustries-repos/butterfold/butterfold_proto/physical/librelane/runs/butterfold_top_fft64_50mhz_final_gds/15-openroad-tapendcapinsertion/butterfold_top.def
set ::env(SAVE_SDC) /headless/aravindustries-repos/butterfold/butterfold_proto/physical/librelane/runs/butterfold_top_fft64_50mhz_final_gds/15-openroad-tapendcapinsertion/butterfold_top.sdc
set ::env(SAVE_NL) /headless/aravindustries-repos/butterfold/butterfold_proto/physical/librelane/runs/butterfold_top_fft64_50mhz_final_gds/15-openroad-tapendcapinsertion/butterfold_top.nl.v
set ::env(SAVE_PNL) /headless/aravindustries-repos/butterfold/butterfold_proto/physical/librelane/runs/butterfold_top_fft64_50mhz_final_gds/15-openroad-tapendcapinsertion/butterfold_top.pnl.v
