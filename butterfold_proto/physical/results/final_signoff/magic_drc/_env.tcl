source /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/magic_streamout/_env.tcl

set ::env(STEP_ID) Magic.DRC
set ::env(STEP_DIR) /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/magic_drc
set ::env(_MAGIC_SCRIPT) /usr/local/lib/python3.12/dist-packages/librelane/scripts/magic/drc.tcl
set ::env(_TCL_ENV_IN) /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/magic_drc/_env.tcl
set ::env(MAGIC_DRC_USE_GDS) 1
set ::env(CURRENT_GDS) /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/butterfold_top.gds
set ::env(MAGIC_DRC_MAGLEFS) "$::env(CELL_MAGLEFS) /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/maglef/gf180mcu_fd_ip_sram__sram256x8m8wm1.mag"
set ::env(MAGTYPE) maglef
