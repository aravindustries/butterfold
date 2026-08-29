# Retry DRT on eco27b (18 buffer nets have GRT, no wires). No new GRT.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set cand $proto/physical/results/d03_ach_candidate
set eco $proto/physical/results/d03_ach_setup_eco
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $cand/butterfold_top_co6a27b.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/co6a27c.drc} dmsg]} {
    puts "DRT_WARN $dmsg"
} else { puts "DRT_OK" }
if {[catch {check_placement}]} { puts "PLACE_BAD" } else { puts "PLACE_OK" }
puts "ANT"; catch {check_antennas}
puts "PG_VDD"; if {[catch {check_power_grid -net VDD} e]} { puts "VDD_ERR $e" } else { puts "VDD_OK" }
puts "PG_VSS"; if {[catch {check_power_grid -net VSS} e]} { puts "VSS_ERR $e" } else { puts "VSS_OK" }
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef $cand/co6a27c.max.spef
read_spef $cand/co6a27c.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "ELEC"; report_check_types -max_slew -max_cap -max_fanout -violators
unset_case_analysis [get_ports rst_n]
puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
puts "RESET_VISIBLE_CAP [sta::max_capacitance_violation_count]"
set_case_analysis 1 [get_ports rst_n]
write_db $cand/butterfold_top_co6a27c.odb
write_def $cand/butterfold_top_co6a27c.def
puts "CO6A27C_DONE"
exit
