set dir [file dirname [info script]]; # <WORK_DIR>/tools/vivado/subscripts
source -notrace [file join $dir init.vivado.tcl]

launch_simulation
set sim_time all
if {[info exists argv] && [llength $argv] > 0 && [lindex $argv 0] ne "" && [lindex $argv 0] ne "0"} {
    set sim_time [lindex $argv 0]
}
run $sim_time
quit

