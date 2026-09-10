set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set layout $proto/physical/results/native_power_ring_ach/lvs/butterfold_top.unique_fixed.spice
if {[info exists ::env(LVS_LAYOUT)] && $::env(LVS_LAYOUT) ne ""} {
    set layout $::env(LVS_LAYOUT)
}
set source $proto/physical/results/native_power_ring_ach/butterfold_top.final.pnl.v
if {[info exists ::env(LVS_SOURCE)] && $::env(LVS_SOURCE) ne ""} {
    set source $::env(LVS_SOURCE)
}
set report $proto/physical/results/native_power_ring_ach/lvs/lvs.netgen.rpt
if {[info exists ::env(LVS_REPORT)] && $::env(LVS_REPORT) ne ""} {
    set report $::env(LVS_REPORT)
}
file mkdir [file dirname $report]
set circuit1 [readnet spice $layout]
set circuit2 [readnet verilog /dev/null]
readnet spice /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/spice/gf180mcu_fd_sc_mcu9t5v0.spice $circuit2
readnet verilog $source $circuit2
lvs "$circuit1 butterfold_top" "$circuit2 butterfold_top" /foss/pdks/gf180mcuD/libs.tech/netgen/gf180mcuD_setup.tcl $report -blackbox -json
