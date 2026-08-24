set c min_ff_n40C_5v50
define_corners $c
read_liberty -corner $c /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
read_liberty -corner $c /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
read_db /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/butterfold_top_routed.odb
read_sdc /headless/aravindustries-repos/butterfold/butterfold_proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
read_spef -corner $c /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/spef/butterfold_top.min.spef
set n 0
foreach p [find_timing_paths -unique_paths_to_endpoint -path_delay min -sort_by_slack -group_path_count 999999999 -slack_max 0] {
  if {[get_property $p slack] < 0} { incr n }
}
puts "HOLD_COUNT $n"
report_worst_slack -min -digits 6
report_tns -min -digits 6
report_worst_slack -max -digits 6
report_tns -max -digits 6
report_checks -path_delay min -sort_by_slack -group_path_count 1 -endpoint_path_count 1 -digits 6 > /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/sta_min_ff/hold.rpt
