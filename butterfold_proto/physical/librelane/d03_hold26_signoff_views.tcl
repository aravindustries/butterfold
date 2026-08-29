# Hold26 signoff views: geometry, pins, SRAM, reset electrical, IR, DEF/pnl.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set cand $proto/physical/results/d03_ach_candidate
set out $proto/physical/reports/signoff/evidence/d03_ach/setup
file mkdir $cand
file mkdir $cand/irdrop
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_hold26.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set block [ord::get_db_block]
set die [$block getDieArea]
set core [$block getCoreArea]
puts [format "DIE_UM %.3f %.3f %.3f %.3f" \
  [expr {[$die xMin]/2000.0}] [expr {[$die yMin]/2000.0}] \
  [expr {[$die xMax]/2000.0}] [expr {[$die yMax]/2000.0}]]
puts [format "CORE_UM %.3f %.3f %.3f %.3f" \
  [expr {[$core xMin]/2000.0}] [expr {[$core yMin]/2000.0}] \
  [expr {[$core xMax]/2000.0}] [expr {[$core yMax]/2000.0}]]
puts "BTERM_COUNT [llength [$block getBTerms]]"
set nsram 0
foreach inst [$block getInsts] {
  set mn [[$inst getMaster] getName]
  if {[string match "*sram256x8m8wm1*" $mn]} {
    incr nsram
    lassign [$inst getLocation] x y
    puts [format "SRAM [$inst getName] %.3f %.3f %s" [expr {$x/2000.0}] [expr {$y/2000.0}] [$inst getOrient]]
  }
}
puts "SRAM_COUNT $nsram"
set pf [open $out/hold26_pins.rpt w]
puts $pf "pin edge x_um y_um"
foreach bt [$block getBTerms] {
  set boxes {}
  foreach pin [$bt getBPins] {
    foreach box [$pin getBoxes] {
      lappend boxes [list [$box xMin] [$box yMin] [$box xMax] [$box yMax]]
    }
  }
  set box [lindex $boxes 0]
  lassign $box x0 y0 x1 y1
  puts $pf [format "%-16s %.3f-%.3f %.3f-%.3f" [$bt getName] \
    [expr {$x0/2000.0}] [expr {$x1/2000.0}] [expr {$y0/2000.0}] [expr {$y1/2000.0}]]
  puts [format "PIN %-16s %.3f-%.3f %.3f-%.3f" [$bt getName] \
    [expr {$x0/2000.0}] [expr {$x1/2000.0}] [expr {$y0/2000.0}] [expr {$y1/2000.0}]]
}
close $pf
if {[catch {check_placement}]} { puts "PLACE_BAD" } else { puts "PLACE_OK" }
puts "ANT"
catch {check_antennas}
puts "PG_VDD"
if {[catch {check_power_grid -net VDD} e]} { puts "VDD_ERR $e" } else { puts "VDD_OK" }
puts "PG_VSS"
if {[catch {check_power_grid -net VSS} e]} { puts "VSS_ERR $e" } else { puts "VSS_OK" }

read_spef $eco/hold26.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "ELEC"
report_check_types -max_slew -max_cap -max_fanout -violators
puts "UNSET_CASE_FOR_RESET_ELEC"
unset_case_analysis [get_ports rst_n]
puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
puts "RESET_VISIBLE_CAP [sta::max_capacitance_violation_count]"
report_check_types -max_slew -max_capacitance -violators > $out/hold26_reset_electrical.rpt
set_case_analysis 1 [get_ports rst_n]
report_power -digits 6 > $cand/vectorless_power.rpt
puts "POWER_DONE"

write_db $cand/butterfold_top.odb
write_def $cand/butterfold_top.def
write_verilog $cand/butterfold_top.final.v
write_verilog -include_pwr_gnd $cand/butterfold_top.final.pnl.v
puts "WROTE_VIEWS"

set_pdnsim_net_voltage -net VDD -voltage 4.5
set_pdnsim_net_voltage -net VSS -voltage 0
puts "IRDROP_VDD"
analyze_power_grid -net VDD -voltage_file $cand/irdrop/net-VDD.csv
puts "IRDROP_VSS"
analyze_power_grid -net VSS -voltage_file $cand/irdrop/net-VSS.csv
puts "HOLD26_VIEWS_DONE"
exit
