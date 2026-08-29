# Cheap connectivity/PG/antenna/placement after local pin-access ECO.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set cand $proto/physical/results/d03_ach_candidate
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $cand/butterfold_top_co6a32.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set block [ord::get_db_block]
set dbu [$block getDefUnits]
set die [$block getDieArea]
set core [$block getCoreArea]
puts [format "DIE %.3f %.3f %.3f %.3f" \
  [expr {[$die xMin]*1.0/$dbu}] [expr {[$die yMin]*1.0/$dbu}] \
  [expr {[$die xMax]*1.0/$dbu}] [expr {[$die yMax]*1.0/$dbu}]]
puts [format "CORE %.3f %.3f %.3f %.3f" \
  [expr {[$core xMin]*1.0/$dbu}] [expr {[$core yMin]*1.0/$dbu}] \
  [expr {[$core xMax]*1.0/$dbu}] [expr {[$core yMax]*1.0/$dbu}]]
if {[catch {check_placement}]} { puts "PLACE_BAD" } else { puts "PLACE_OK" }
set nopen 0
foreach n [$block getNets] {
  if {[$n isSpecial]} continue
  set w [$n getWire]
  if {$w eq "" || $w eq "NULL"} {
    incr nopen
    puts "OPEN [$n getName]"
  }
}
puts "OPEN_COUNT $nopen"
puts "BTERMS [llength [$block getBTerms]]"
puts "ANT"; catch {check_antennas}
puts "PG_VDD"; if {[catch {check_power_grid -net VDD} e]} { puts "VDD_ERR $e" } else { puts "VDD_OK" }
puts "PG_VSS"; if {[catch {check_power_grid -net VSS} e]} { puts "VSS_ERR $e" } else { puts "VSS_OK" }
puts "ECO32_CHECKS_DONE"
exit
