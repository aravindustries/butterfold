# Native extract + STA. STA_MODE=ss_setup|ff_hold
set script_dir [file dirname [file normalize [info script]]]
set proto_root [file normalize [file join $script_dir .. ..]]
set pdk /foss/pdks/gf180mcuD
set eco $proto_root/physical/results/nw_pins_eco
set out $eco/sta
file mkdir $out
set mode ss_setup
if {[info exists env(STA_MODE)] && $env(STA_MODE) ne ""} { set mode $env(STA_MODE) }

set tech_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
set cell_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
set sram_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_lef $tech_lef
read_lef $cell_lef
read_lef $sram_lef
if {$mode eq "ff_hold"} {
  read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
  read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
  set rcx $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.min
} else {
  read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
  read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
  set rcx $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
}
set odb $eco/hold_eco/routed.odb
if {[info exists env(STA_ODB)] && $env(STA_ODB) ne ""} {
  set odb $env(STA_ODB)
} elseif {![file exists $odb]} {
  set odb $eco/butterfold_top_eco_routed.odb
}
puts "STA_ODB $odb STA_MODE $mode"
read_db $odb
read_sdc $proto_root/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
extract_parasitics -ext_model_file $rcx
if {$mode eq "ff_hold"} {
  report_wns -min > $out/minff_extract_wns.rpt
  report_tns -min > $out/minff_extract_tns.rpt
  report_checks -path_delay min -group_path_count 8 -fields {slew cap fanout net} \
    > $out/minff_extract_hold_paths.rpt
  report_checks -path_delay min -slack_max 0 -group_path_count 20 \
    > $out/minff_extract_hold_violations.rpt
  puts "HOLD_WNS"
  report_wns -min
  puts "HOLD_TNS"
  report_tns -min
} else {
  report_wns -max > $out/maxss_extract_wns.rpt
  report_tns -max > $out/maxss_extract_tns.rpt
  report_checks -path_delay max -group_path_count 8 -fields {slew cap fanout net} \
    > $out/maxss_extract_setup_paths.rpt
  report_checks -path_delay max -slack_max 0 -group_path_count 20 \
    > $out/maxss_extract_setup_violations.rpt
  report_check_types -max_slew -violators > $out/maxss_extract_slew.rpt
  report_check_types -max_cap -violators > $out/maxss_extract_cap.rpt
  report_check_types -max_fanout -violators > $out/maxss_extract_fanout.rpt
  unset_case_analysis [get_ports rst_n]
  report_check_types -max_slew -violators > $out/reset_extract_slew.rpt
  report_check_types -max_cap -violators > $out/reset_extract_cap.rpt
  report_net rst_n > $out/reset_extract_net.rpt
  puts "SETUP_WNS"
  report_wns -max
  puts "SETUP_TNS"
  report_tns -max
}
exit
