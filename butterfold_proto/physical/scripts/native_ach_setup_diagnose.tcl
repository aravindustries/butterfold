# Extracted setup diagnosis on the clean ACH-integrated filled ODB/SPEF.
# Read-only: does not modify the ODB.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/native_power_ring_ach
set pdk /foss/pdks/gf180mcuD
set c max_ss_125C_4v50
file mkdir $out/sta
set odb $out/filled.odb
if {[info exists ::env(STA_ODB)] && $::env(STA_ODB) ne ""} { set odb $::env(STA_ODB) }
set spef $out/spef/final.max.spef
if {[info exists ::env(STA_SPEF)] && $::env(STA_SPEF) ne ""} { set spef $::env(STA_SPEF) }
puts "STA_ODB $odb"
puts "STA_SPEF $spef"
define_corners $c
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $odb
puts "CLOCKS_BEFORE_SDC [llength [all_clocks]]"
read_sdc $proto/physical/constraints.sdc
puts "CLOCKS_AFTER_SDC [get_property [all_clocks] full_name]"
puts "CLOCK_PERIOD [get_property [get_clocks core_clk] period]"
if {[catch {puts "CLOCK_UNCERTAINTY [get_property [get_clocks core_clk] uncertainty]"} m]} {
  puts "CLOCK_UNCERTAINTY_CAUGHT $m"
}
puts "PORTS [llength [get_ports *]]"
puts "PORT_NAMES_BEGIN"
foreach p [get_ports *] { puts "PORT [get_property $p full_name] dir=[get_property $p direction]" }
puts "PORT_NAMES_END"
# SDC output delay looks for pre-shell names; apply ACH names exactly as native STA did.
set_output_delay 0.0 -clock core_clk [get_ports {din_ready_o_OUT dout_valid_o_OUT dout_OUT[*]}]
set_propagated_clock [all_clocks]
read_spef -corner $c $spef
puts "SETUP_WNS"
report_worst_slack -max -digits 6
puts "SETUP_TNS"
report_tns -max -digits 6
if {[catch {puts "SETUP_VIO [sta::endpoint_violation_count max]"} m]} { puts "SETUP_VIO_CAUGHT $m" }
if {[catch {puts "PATH_GROUPS"; report_path_group} m]} { puts "PATH_GROUPS_CAUGHT $m" }
puts "OUTPUT_DELAY_REPORT"
if {[catch {report_checks -path_delay max -group_path_count 20 -path_group output -digits 4} m]} {
  puts "OUTPUT_GROUP_CAUGHT $m"
}
puts "UNCONSTRAINED"
if {[catch {report_checks -unconstrained -path_delay max -group_path_count 10 -digits 4} m]} {
  puts "UNCONSTRAINED_CAUGHT $m"
}
report_checks -path_delay max -digits 4 -format full_clock_expanded \
  -group_path_count 100 > $out/sta/setup_worst100.rpt
report_checks -path_delay max -digits 4 \
  -group_path_count 300 > $out/sta/setup_worst300_summary.rpt
puts "WROTE_SETUP_DIAG"
exit
