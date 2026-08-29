# Fill + PG check after template PG stitch on eco36 routed ODB.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_candidate/co6a36
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $eco/butterfold_top_co6a36_pg.odb
set db [ord::get_db]
set block [ord::get_db_block]
puts "INST_BEFORE [llength [$block getInsts]]"
if {[catch {check_placement}]} { puts "PLACE_BAD" } else { puts "PLACE_OK" }
puts "PG_BEFORE_FILL"
if {[catch {check_power_grid -net VDD} e]} { puts "VDD_ERR $e" } else { puts "VDD_OK" }
if {[catch {check_power_grid -net VSS} e]} { puts "VSS_ERR $e" } else { puts "VSS_OK" }
puts "ANT_BEFORE_FILL"
catch {check_antennas}

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
set fill_list [concat [lsort -decreasing $decaps] [lsort -decreasing $fills]]
puts "FILL_LIST $fill_list"
filler_placement $fill_list
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
puts "INST_AFTER [llength [$block getInsts]]"
if {[catch {check_placement}]} { puts "PLACE_BAD" } else { puts "PLACE_OK" }
puts "PG_AFTER_FILL"
if {[catch {check_power_grid -net VDD} e]} { puts "VDD_ERR $e" } else { puts "VDD_OK" }
if {[catch {check_power_grid -net VSS} e]} { puts "VSS_ERR $e" } else { puts "VSS_OK" }
puts "ANT_AFTER_FILL"
catch {check_antennas}

set n_mx 0; set n_r180 0; set n_r0 0; set n_my 0
foreach inst [$block getInsts] {
  if {[[$inst getMaster] getName] eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
    switch -- [$inst getOrient] {
      MX {incr n_mx} R180 {incr n_r180} R0 {incr n_r0} MY {incr n_my}
    }
  }
}
puts "AOI221_2 MX $n_mx R180 $n_r180 R0 $n_r0 MY $n_my"
foreach name {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_} {
  set i [$block findInst $name]
  puts "CELL $name [[$i getMaster] getName] [$i getOrient]"
}
write_db $eco/butterfold_top_co6a36_filled.odb
write_def $eco/butterfold_top_co6a36_filled.def
write_verilog -include_pwr_gnd $eco/butterfold_top.co6a36.filled.pnl.v
puts "CO6A36_FILL_DONE"
exit
