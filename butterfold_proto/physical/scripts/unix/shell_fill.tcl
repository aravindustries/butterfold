read_db $::env(ITER_DIR)/routed.odb
set db [ord::get_db]; set block [ord::get_db_block]
set fills {}; set decaps {}
foreach lib [$db getLibs] { foreach m [$lib getMasters] {
  set n [$m getName]
  if {[string match "gf180mcu_fd_sc_mcu9t5v0__fillcap_*" $n]} { lappend decaps $n }
  if {[string match "gf180mcu_fd_sc_mcu9t5v0__fill_*" $n]}    { lappend fills $n }
}}
filler_placement [concat [lsort -decreasing $decaps] [lsort -decreasing $fills]]
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
puts "X_FILLED_INST [llength [$block getInsts]]  BTERMS [llength [$block getBTerms]]"
puts "X_PSM_VDD"; check_power_grid -net VDD
puts "X_PSM_VSS"; check_power_grid -net VSS
write_db      $::env(ITER_DIR)/filled.odb
write_def     $::env(ITER_DIR)/filled.def
write_verilog -include_pwr_gnd $::env(ITER_DIR)/butterfold_top.final.pnl.v
puts "X_WROTE_FILL_VIEWS"
