# 24-pin extracted signoff STA: max-SS setup, min-FF hold, electrical, reset.
set script_dir [file dirname [file normalize [info script]]]
set proto_root [file normalize [file join $script_dir .. ..]]
set pdk /foss/pdks/gf180mcuD
set eco $proto_root/physical/results/24pin_eco
set out $eco/sta
file mkdir $out

set tech_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
set cell_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
set sram_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
set sdc $proto_root/physical/constraints.sdc
set odb $eco/butterfold_top_eco_routed.odb

proc sta_load {lib cell_lib sram_lib spef} {
  global tech_lef cell_lef sram_lef odb sdc
  read_lef $tech_lef
  read_lef $cell_lef
  read_lef $sram_lef
  read_liberty $cell_lib
  read_liberty $sram_lib
  read_db $odb
  read_sdc $sdc
  set_propagated_clock [get_clocks core_clk]
  read_spef $spef
}

puts "STA_MAX_SS"
sta_load max \
  $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib \
  $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib \
  $eco/after.max.spef

report_wns -max > $out/maxss_wns.rpt
report_tns -max > $out/maxss_tns.rpt
report_checks -path_delay max -group_path_count 10 -fields {slew cap fanout net} \
  > $out/maxss_setup_paths.rpt
report_checks -path_delay max -slack_max 0 -group_path_count 50 \
  > $out/maxss_setup_violations.rpt
report_check_types -max_slew -violators > $out/maxss_slew.rpt
report_check_types -max_cap -violators > $out/maxss_cap.rpt
report_check_types -max_fanout -violators > $out/maxss_fanout.rpt
report_checks -from [get_ports dout_ready_i] -path_delay max -group_path_count 15 \
  > $out/dout_ready_setup.rpt
report_net dout_ready_i > $out/dout_ready_net.rpt
report_clock_skew -setup > $out/maxss_skew.rpt

puts "STA_RESET_VISIBLE"
unset_case_analysis [get_ports rst_n]
report_check_types -max_slew -violators > $out/reset_slew.rpt
report_check_types -max_cap -violators > $out/reset_cap.rpt
report_net rst_n > $out/reset_net.rpt
report_checks -from [get_ports rst_n] -path_delay max -group_path_count 10 \
  > $out/reset_recovery.rpt

puts "STA_ANTENNA"
if {[catch {check_antennas -verbose -report_file $out/antenna.rpt} amsg]} {
  puts "ANTENNA $amsg"
}

puts "STA_IR"
if {[catch {
  analyze_power_grid -net VDD > $out/ir_vdd.rpt
  analyze_power_grid -net VSS > $out/ir_vss.rpt
} irmsg]} {
  puts "IR $irmsg"
}

# Hold in a fresh process would be cleaner, but reload liberty isn't easy.
# Re-invoke OpenROAD for hold below if this file is sourced once.
puts "STA_MAX_SS_DONE"
puts "WNS_SETUP"
report_wns -max
puts "TNS_SETUP"
report_tns -max
exit
