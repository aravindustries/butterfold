set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set layout $proto/physical/results/m2_fix/final_ach_lvs/butterfold_top.unique_fixed.spice
set source $proto/physical/results/m2_fix/butterfold_top.final.pnl.v
set report $proto/physical/results/m2_fix/final_ach_lvs/lvs.netgen.rpt
set circuit1 [readnet spice $layout]
set circuit2 [readnet verilog /dev/null]
readnet spice /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/spice/gf180mcu_fd_sc_mcu9t5v0.spice $circuit2
readnet verilog $source $circuit2
lvs "$circuit1 butterfold_top" "$circuit2 butterfold_top" /foss/pdks/gf180mcuD/libs.tech/netgen/gf180mcuD_setup.tcl $report -blackbox -json
