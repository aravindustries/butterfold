# LibreLane-equivalent filler_placement (decap then fill) on the closed ECO ODB.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/shrink_signoff
read_db $out/butterfold_top_closed.odb
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
set decaps [lsort -decreasing $decaps]
set fills [lsort -decreasing $fills]
set fill_list [concat $decaps $fills]
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
if {[catch {check_placement -verbose} m]} { puts "PLACE $m" }
set ant [check_antennas]
puts "ANTENNA_CHECK $ant"
write_db $out/butterfold_top_closed.odb
write_def $out/butterfold_top_closed.def
write_verilog -include_pwr_gnd $out/butterfold_top.final.pnl.v
write_verilog $out/butterfold_top.final.v
puts "FILL_DONE"
