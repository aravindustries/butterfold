set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/d03_ach_resized
set pdk /foss/pdks/gf180mcuD
set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $out/routed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
read_spef -corner $c $out/spef/butterfold_top.max.spef
puts "CASE_ON SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count]"
report_check_types -max_slew -max_capacitance -violators -digits 4 > $out/elec_case_on.rpt
catch {unset_case_analysis rst_n}
catch {unset_case_analysis [get_ports rst_n]}
puts "CASE_OFF SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count]"
report_check_types -max_slew -max_capacitance -max_fanout -violators -digits 4 > $out/elec_reset_visible.rpt
report_net rst_n > $out/reset_net_port.rpt
# list nets matching rst
set block [ord::get_db_block]
set rst_like {}
foreach net [$block getNets] {
  set n [$net getName]
  if {[string match "*rst*" $n] || [string match "*RN*" $n]} {
    lappend rst_like $n
  }
}
puts "RST_LIKE [llength $rst_like]"
foreach n [lsort $rst_like] {
  if {[string length $n] < 80} { puts "RSTNET $n" }
}
puts "DUMP_DONE"
exit
