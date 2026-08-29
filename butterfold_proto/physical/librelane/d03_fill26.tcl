# Restore LibreLane fill on hold26 (ECO ODB lost fill: 20022 vs ~54749).
# FIRM existing cells, filler_placement decap then fill, global_connect.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set cand $proto/physical/results/d03_ach_candidate
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $cand/butterfold_top.odb
set db [ord::get_db]
set block [ord::get_db_block]
puts "INST_BEFORE [llength [$block getInsts]]"
foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }
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
filler_placement $fill_list
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
puts "INST_AFTER [llength [$block getInsts]]"
if {[catch {check_placement}]} { puts "PLACE_BAD" } else { puts "PLACE_OK" }
puts "PG_VDD"
if {[catch {check_power_grid -net VDD} e]} { puts "VDD_ERR $e" } else { puts "VDD_OK" }
puts "PG_VSS"
if {[catch {check_power_grid -net VSS} e]} { puts "VSS_ERR $e" } else { puts "VSS_OK" }
write_db $cand/butterfold_top_filled.odb
write_def $cand/butterfold_top_filled.def
write_verilog $cand/butterfold_top.filled.v
write_verilog -include_pwr_gnd $cand/butterfold_top.filled.pnl.v
puts "FILL26_DONE"
exit
