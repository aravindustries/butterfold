set layout $::env(LVS_LAYOUT)
set source $::env(LVS_SOURCE)
set report $::env(LVS_REPORT)
file mkdir [file dirname $report]
set circuit1 [readnet spice $layout]
set circuit2 [readnet verilog /dev/null]
readnet spice /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/spice/gf180mcu_fd_sc_mcu9t5v0.spice $circuit2
readnet verilog $source $circuit2
lvs "$circuit1 butterfold_top" "$circuit2 butterfold_top" /foss/pdks/gf180mcuD/libs.tech/netgen/gf180mcuD_setup.tcl $report -blackbox -json
