set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_hold19c.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
read_spef $eco/hold19c.max.spef
puts "ELEC"
report_check_types -max_slew -max_cap -max_fanout -violators
set block [ord::get_db_block]
set i [$block findInst _11319_]
if {$i ne "NULL" && $i ne ""} { puts "CAPDRV [[$i getMaster] getName]" }
puts "ANTENNA"
if {[catch {check_antennas -verbose -report_file $out/setup/hold19c_antenna.rpt} amsg]} {
  puts "ANT_WARN $amsg"
}
puts "ANTENNA_DONE"
# die/core um
set die [$block getDieArea]
set core [$block getCoreArea]
puts "DIE_UM [expr {[$die xMax]/2000.0}] [expr {[$die yMax]/2000.0}]"
puts "CORE_UM [expr {[$core xMin]/2000.0}] [expr {[$core yMin]/2000.0}] [expr {[$core xMax]/2000.0}] [expr {[$core yMax]/2000.0}]"
set nsram 0
foreach inst [$block getInsts] {
  if {[string match "*sram256x8*" [[$inst getMaster] getName]]} { incr nsram }
}
puts "NSRAM $nsram"
puts "PINS [llength [$block getBTerms]]"
exit
