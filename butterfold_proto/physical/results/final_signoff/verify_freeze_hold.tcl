set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set c min_ff_n40C_5v50
define_corners $c
read_liberty -corner $c /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
read_liberty -corner $c /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
read_db $proto/physical/results/38p4_setup_closed/iter2_routed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
read_spef -corner $c $proto/physical/results/38p4_setup_closed/spef/butterfold_top.min.spef
puts "FREEZE_HOLD"
report_worst_slack -min -digits 6
report_tns -min -digits 6
puts "DONE_MIN"
