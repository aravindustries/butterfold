set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco33
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $src/butterfold_top_co6a36_teco29.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
catch {set_thread_count 22}
# drop unused overlap leftover if present
set block [ord::get_db_block]
set u [$block findInst teco29_buf_11164]
if {$u ne "NULL" && $u ne ""} {
  set nconn 0
  foreach it [$u getITerms] {
    set n [$it getNet]
    if {$n ne "NULL" && $n ne ""} { incr nconn }
  }
  puts "ORPHAN teco29_buf_11164 nets $nconn"
}
puts "EXTRACT_MAX"
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef $src/after.max.spef
read_spef $src/after.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "SLEW [sta::max_slew_violation_count]"
puts "CAP [sta::max_capacitance_violation_count]"
report_wns -max > $src/setup_wns.rpt
report_tns -max > $src/setup_tns.rpt
report_checks -path_delay max -group_path_count 2 > $src/setup_top2.rpt
report_check_types -max_slew -max_cap -violators > $src/elec_liberty_violators.rpt
puts "TECO29_MAX_DONE"
exit
