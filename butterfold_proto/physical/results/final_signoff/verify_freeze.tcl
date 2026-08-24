# One-shot freeze timing check. Does not modify the ODB.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set odb $proto/physical/results/38p4_setup_closed/iter2_routed.odb

set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
read_spef -corner $c $proto/physical/results/38p4_setup_closed/spef/butterfold_top.max.spef
puts "FREEZE_SETUP"
report_worst_slack -max -digits 6
report_tns -max -digits 6
puts "FREEZE_SLEW [sta::max_slew_violation_count]"
puts "FREEZE_CAP [sta::max_capacitance_violation_count]"
puts "DONE_MAX"
