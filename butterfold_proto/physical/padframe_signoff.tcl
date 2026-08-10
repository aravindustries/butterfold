source [file join [file dirname [file normalize [info script]]] padframe_config.tcl]

set corner [expr {[info exists ::env(SIGNOFF_CORNER)] ? $::env(SIGNOFF_CORNER) : "ss_125C_4v50"}]
set rc_kind [expr {[info exists ::env(SIGNOFF_RC)] ? $::env(SIGNOFF_RC) : "max"}]
set out_dir "$phys_dir/results/padframe/signoff/${corner}_${rc_kind}"
file mkdir $out_dir
set sc_lib "$pdk_root/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__${corner}.lib"
set mem_lib "$pdk_root/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__${corner}.lib"
set pad_lib "$io_root/lib/gf180mcu_fd_io__${corner}.lib"
set rc_file "$pdk_root/libs.tech/librelane/rules.openrcx.gf180mcuD.${rc_kind}"
foreach f [list $sc_lib $mem_lib $pad_lib $rc_file "$pad_result/route.odb"] {
  if {![file exists $f]} { error "missing padframe signoff collateral: $f" }
}
read_lef $tech_lef
read_lef $io_site_lef
read_lef $cell_lef
read_lef $sram_lef
foreach lef $io_lefs {read_lef $lef}
read_liberty $sc_lib
read_liberty $mem_lib
read_liberty $pad_lib
read_db "$pad_result/route.odb"
read_sdc $pad_sdc
set_propagated_clock [get_clocks pad_clk_ext]
extract_parasitics -ext_model_file $rc_file

report_checks -path_delay max -group_path_count 100 -endpoint_path_count 1 -unique_paths_to_endpoint -sort_by_slack -format full_clock_expanded -fields {capacitance slew fanout input_pin net} > "$out_dir/setup.rpt"
report_checks -path_delay min -group_path_count 100 -endpoint_path_count 1 -unique_paths_to_endpoint -sort_by_slack -format full_clock_expanded -fields {capacitance slew fanout input_pin net} > "$out_dir/hold.rpt"
report_checks -from [get_ports {pad_din[*] pad_din_valid_i}] -path_delay max -group_path_count 50 -format full_clock_expanded > "$out_dir/input_setup.rpt"
report_checks -from [get_ports {pad_din[*] pad_din_valid_i}] -path_delay min -group_path_count 50 -format full_clock_expanded > "$out_dir/input_hold.rpt"
report_checks -to [get_ports {pad_din_ready_o pad_dout[*] pad_dout_valid_o}] -path_delay max -group_path_count 50 -format full_clock_expanded > "$out_dir/output_max.rpt"
report_checks -to [get_ports {pad_din_ready_o pad_dout[*] pad_dout_valid_o}] -path_delay min -group_path_count 50 -format full_clock_expanded > "$out_dir/output_min.rpt"
report_checks -from [all_registers] -to [all_registers] -path_delay max -group_path_count 50 -format full_clock_expanded > "$out_dir/internal_setup.rpt"
report_checks -from [all_registers] -to [all_registers] -path_delay min -group_path_count 50 -format full_clock_expanded > "$out_dir/internal_hold.rpt"
set sram_inputs [concat [get_pins -hierarchical *u_sram/A*] [get_pins -hierarchical *u_sram/D*] [get_pins -hierarchical *u_sram/CEN] [get_pins -hierarchical *u_sram/GWEN] [get_pins -hierarchical *u_sram/WEN*]]
report_checks -to $sram_inputs -path_delay max -group_path_count 50 -format full_clock_expanded > "$out_dir/sram_setup.rpt"
report_checks -to $sram_inputs -path_delay min -group_path_count 50 -format full_clock_expanded > "$out_dir/sram_hold.rpt"
report_checks -from [get_pins -hierarchical *u_sram/Q*] -path_delay max -group_path_count 50 -format full_clock_expanded > "$out_dir/sram_read.rpt"
report_wns -max > "$out_dir/setup_wns.rpt"
report_tns -max > "$out_dir/setup_tns.rpt"
report_wns -min > "$out_dir/hold_wns.rpt"
report_tns -min > "$out_dir/hold_tns.rpt"
report_clock_skew -setup > "$out_dir/clock_skew_setup.rpt"
report_clock_skew -hold > "$out_dir/clock_skew_hold.rpt"
report_check_types -max_slew -violators > "$out_dir/max_slew.rpt"
report_check_types -max_capacitance -violators > "$out_dir/max_cap.rpt"
write_spef "$out_dir/padframe.spef"
