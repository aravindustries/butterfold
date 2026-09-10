# Stdcell fill/fillcap on antenna-closed ACH-shell ODB. Does not touch PDN.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/native_power_ring_ach
set src $out/ach_ant_routed.odb
if {[info exists env(FILL_SRC)] && $env(FILL_SRC) ne ""} { set src $env(FILL_SRC) }
puts "FILL_SRC $src"
read_db $src
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
set db [ord::get_db]
set fills {}
set decaps {}
foreach lib [$db getLibs] {
  foreach m [$lib getMasters] {
    set n [$m getName]
    if {[string match "gf180mcu_fd_sc_mcu9t5v0__fillcap_*" $n]} { lappend decaps $n }
    if {[string match "gf180mcu_fd_sc_mcu9t5v0__fill_*" $n]} { lappend fills $n }
  }
}
set fill_list [concat [lsort -decreasing $decaps] [lsort -decreasing $fills]]
puts "FILL_LIST $fill_list"
set n0 [llength [[ord::get_db_block] getInsts]]
filler_placement $fill_list
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
set n1 [llength [[ord::get_db_block] getInsts]]
puts "INST_BEFORE $n0 INST_AFTER $n1 ADDED [expr {$n1-$n0}]"
if {[catch {check_placement -verbose} m]} { puts "PLACE $m"; exit 1 }
puts "BTERMS [llength [[ord::get_db_block] getBTerms]]"
set ant [check_antennas]
puts "ANTENNA_CHECK $ant"
if {$ant} { puts "FILL_ANTENNA_FAIL"; exit 1 }
write_db $out/filled.odb
write_def $out/filled.def
write_verilog -include_pwr_gnd $out/butterfold_top.final.pnl.v
write_verilog $out/butterfold_top.final.v
puts "FILL_DONE"
exit
