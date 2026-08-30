set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/shrink_signoff
set pdk /foss/pdks/gf180mcuD
set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $out/butterfold_top_closed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
read_spef -corner $c $out/spef/butterfold_top.max.spef
report_check_types -max_fanout -violators -digits 4 > $out/elec_fanout.rpt
puts FANOUT_DUMP_DONE
