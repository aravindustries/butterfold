# Extracted max-SS path dump from the best R180 setup2 ODB.
# Re-extract (authoritative). No ECO.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco2/butterfold_top_co6a36_setup2.odb
set out $proto/physical/results/d03_ach_candidate/co6a36/setup_eco2
file mkdir $out
puts "SRC $src"

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $src
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_max_transition 3 [current_design]
set_max_capacitance 0.2 [current_design]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
catch {set_thread_count 22}

puts "EXTRACT"
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef $out/setup2_reextract.max.spef
read_spef $out/setup2_reextract.max.spef

puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "HOLD_WNS"; report_wns -min
puts "HOLD_TNS"; report_tns -min
catch {puts "SLEW [sta::max_slew_violation_count]"}
catch {puts "CAP [sta::max_capacitance_violation_count]"}
if {[catch {unset_case_analysis [get_ports rst_n]}]} {}
catch {puts "RESET_SLEW [sta::max_slew_violation_count]"}
catch {puts "RESET_CAP [sta::max_capacitance_violation_count]"}
if {[catch {set_case_analysis 1 [get_ports rst_n]}]} {}

report_wns -max > $out/setup2_wns.rpt
report_tns -max > $out/setup2_tns.rpt
report_checks -path_delay max -group_path_count 50 -fields {slew cap fanout net} \
  > $out/setup2_top50.rpt
report_checks -path_delay max -slack_max 0 -group_path_count 80 \
  > $out/setup2_violations80.rpt
puts "WROTE_PATHS"
puts "SETUP2_PATHS_DONE"
exit
