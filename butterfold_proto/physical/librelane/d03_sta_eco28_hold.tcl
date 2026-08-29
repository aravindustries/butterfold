# eco28 min-FF extracted hold.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set cand $proto/physical/results/d03_ach_candidate
set out $proto/physical/reports/signoff/evidence/d03_ach/setup
file mkdir $out
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
read_db $cand/butterfold_top_co6a28.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
if {[catch {check_placement}]} { puts "PLACE_BAD" } else { puts "PLACE_OK" }
set rcx_min $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.min
extract_parasitics -ext_model_file $rcx_min
write_spef $cand/co6a28.min.spef
read_spef $cand/co6a28.min.spef
puts "HOLD_WNS"; report_wns -min
puts "HOLD_TNS"; report_tns -min
report_checks -path_delay min -group_path_count 5
catch {report_wns -min > $out/co6a28_hold_wns.rpt}
catch {report_tns -min > $out/co6a28_hold_tns.rpt}
catch {report_checks -path_delay min -slack_max 0 -group_path_count 10 > $out/co6a28_hold_violations.rpt}
puts "ECO28_HOLD_DONE"
exit
