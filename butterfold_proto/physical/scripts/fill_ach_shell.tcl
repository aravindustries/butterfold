# Stage 3: re-insert fill (removed before the shell was applied), verify power
# grid connectivity, and write the signoff views.
read_db $::env(OUT_DIR)/shell_routed.odb
set db [ord::get_db]
set block [ord::get_db_block]
set fills {}; set decaps {}
foreach lib [$db getLibs] {
  foreach m [$lib getMasters] {
    set n [$m getName]
    if {[string match "gf180mcu_fd_sc_mcu9t5v0__fillcap_*" $n]} { lappend decaps $n }
    if {[string match "gf180mcu_fd_sc_mcu9t5v0__fill_*" $n]} { lappend fills $n }
  }
}
set fill_list [concat [lsort -decreasing $decaps] [lsort -decreasing $fills]]
puts "X_FILL_LIST $fill_list"
filler_placement $fill_list
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
puts "X_FILLED_INST [llength [$block getInsts]]"
puts "X_BTERMS      [llength [$block getBTerms]]"

puts "X_PSM_VDD"; check_power_grid -net VDD
puts "X_PSM_VSS"; check_power_grid -net VSS

write_db      $::env(OUT_DIR)/filled.odb
write_def     $::env(OUT_DIR)/filled.def
write_verilog $::env(OUT_DIR)/butterfold_top.final.v
write_verilog -include_pwr_gnd $::env(OUT_DIR)/butterfold_top.final.pnl.v
puts "X_WROTE_FILL_VIEWS"
