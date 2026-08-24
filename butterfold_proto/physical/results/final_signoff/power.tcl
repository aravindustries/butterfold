set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/butterfold_top_routed.odb
read_sdc /headless/aravindustries-repos/butterfold/butterfold_proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
read_spef -corner $c /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/spef/butterfold_top.max.spef
report_power -digits 6 > /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/power_vectorless_max_ss.rpt
puts POWER_DONE
