source [file join [file dirname [file normalize [info script]]] config.tcl]

set corner [expr {[info exists ::env(SIGNOFF_CORNER)] ? $::env(SIGNOFF_CORNER) : "ss_125C_4v50"}]
set rc_kind [expr {[info exists ::env(SIGNOFF_RC)] ? $::env(SIGNOFF_RC) : "max"}]
set contract [expr {[info exists ::env(SIGNOFF_IO_CONTRACT)] ? $::env(SIGNOFF_IO_CONTRACT) : 0}]
set suffix [expr {$contract ? "_contract" : ""}]
set corner_dir "$phys_dir/results/signoff/${corner}_${rc_kind}${suffix}"
file mkdir $corner_dir

set cell_lib_corner "$pdk_root/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__${corner}.lib"
set sram_lib_corner "$pdk_root/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__${corner}.lib"
set rc_file "$pdk_root/libs.tech/librelane/rules.openrcx.gf180mcuD.${rc_kind}"

foreach required [list $cell_lib_corner $sram_lib_corner $rc_file "$phys_dir/results/C/route.odb"] {
  if {![file exists $required]} { error "missing signoff collateral: $required" }
}

read_lef $tech_lef
read_lef $cell_lef
read_lef $sram_lef
read_liberty $cell_lib_corner
read_liberty $sram_lib_corner
read_db "$phys_dir/results/C/route.odb"
read_sdc $sdc
if {$contract} {
  # Candidate pad-aware contract sensitivity.  At the core boundary these
  # include worst-case data-pad/clock-pad differential delay.  The associated
  # external pad-pin contract is documented in the signoff report.
  set_input_delay -min 0.75 -clock core_clk [get_ports {din[*] din_valid_i}]
  set_input_delay -max 2.04 -clock core_clk [get_ports {din[*] din_valid_i}]
  set_input_transition 0.50 [get_ports {clk din[*] din_valid_i}]
  set_load 0.04 [get_ports {stream_status_o dout[*]}]
  set_clock_uncertainty -setup 0.10 [get_clocks core_clk]
  set_clock_uncertainty -hold 0.05 [get_clocks core_clk]
}
set_propagated_clock [get_clocks core_clk]
extract_parasitics -ext_model_file $rc_file

report_checks -path_delay max -group_path_count 50 -endpoint_path_count 1 \
  -unique_paths_to_endpoint -sort_by_slack -format full_clock_expanded \
  -fields {capacitance slew fanout input_pin net} > "$corner_dir/setup.rpt"
report_checks -path_delay min -group_path_count 50 -endpoint_path_count 1 \
  -unique_paths_to_endpoint -sort_by_slack -format full_clock_expanded \
  -fields {capacitance slew fanout input_pin net} > "$corner_dir/hold.rpt"
report_checks -path_delay max -slack_max 0.0 -group_path_count 1000 \
  -endpoint_path_count 1 > "$corner_dir/setup_violations.rpt"
report_checks -path_delay min -slack_max 0.0 -group_path_count 1000 \
  -endpoint_path_count 1 > "$corner_dir/hold_violations.rpt"
report_wns -max > "$corner_dir/setup_wns.rpt"
report_tns -max > "$corner_dir/setup_tns.rpt"
report_wns -min > "$corner_dir/hold_wns.rpt"
report_tns -min > "$corner_dir/hold_tns.rpt"

report_checks -from [all_registers] -path_delay min -group_path_count 50 -format full_clock_expanded > "$corner_dir/internal_hold.rpt"
report_checks -from [get_ports {din[*] din_valid_i}] -path_delay max -group_path_count 50 -format full_clock_expanded > "$corner_dir/input_setup.rpt"
report_checks -from [get_ports {din[*] din_valid_i}] -path_delay min -group_path_count 50 -format full_clock_expanded > "$corner_dir/input_hold.rpt"
report_checks -to [get_ports {stream_status_o dout[*]}] -path_delay max -group_path_count 50 -format full_clock_expanded > "$corner_dir/output_max.rpt"
report_checks -to [get_ports {stream_status_o dout[*]}] -path_delay min -group_path_count 50 -format full_clock_expanded > "$corner_dir/output_min.rpt"
report_checks -from [get_pins {_19540_/Q _19541_/Q _19542_/Q}] -path_delay max -group_path_count 20 -format full_clock_expanded > "$corner_dir/dft12.rpt"
report_checks -from [get_pins {_20283_/Q _20284_/Q _20285_/Q _20286_/Q _20287_/Q _20288_/Q _20289_/Q _20290_/Q _20321_/Q _20322_/Q _20323_/Q _20324_/Q _20325_/Q _20326_/Q _20327_/Q _20328_/Q _20329_/Q _20330_/Q}] -path_delay max -group_path_count 20 -format full_clock_expanded > "$corner_dir/multiplier.rpt"
report_checks -to [get_pins -hierarchical *u_sram/A*] -path_delay max -group_path_count 20 -format full_clock_expanded > "$corner_dir/sram_address_setup.rpt"
report_checks -to [get_pins -hierarchical *u_sram/D*] -path_delay max -group_path_count 20 -format full_clock_expanded > "$corner_dir/sram_data_setup.rpt"
set sram_ctrl [concat [get_pins -hierarchical *u_sram/CEN] \
  [get_pins -hierarchical *u_sram/GWEN] [get_pins -hierarchical *u_sram/WEN*]]
report_checks -to $sram_ctrl -path_delay max -group_path_count 20 -format full_clock_expanded > "$corner_dir/sram_control_setup.rpt"
report_checks -from [get_pins -hierarchical *u_sram/Q*] -path_delay max -group_path_count 20 -format full_clock_expanded > "$corner_dir/sram_read_capture.rpt"
set sram_inputs [concat [get_pins -hierarchical *u_sram/A*] \
  [get_pins -hierarchical *u_sram/D*] $sram_ctrl]
report_checks -to $sram_inputs -path_delay min -group_path_count 50 \
  -format full_clock_expanded > "$corner_dir/sram_input_hold.rpt"
report_checks -from [get_pins -hierarchical *u_sram/Q*] -path_delay min \
  -group_path_count 50 -format full_clock_expanded \
  > "$corner_dir/sram_read_hold.rpt"
report_clock_skew -setup > "$corner_dir/clock_skew_setup.rpt"
report_clock_skew -hold > "$corner_dir/clock_skew_hold.rpt"
unset_case_analysis [get_ports rst_n]
report_checks -from [get_ports rst_n] -path_delay max -group_path_count 50 \
  -format full_clock_expanded > "$corner_dir/reset_recovery.rpt"
report_checks -from [get_ports rst_n] -path_delay min -group_path_count 50 \
  -format full_clock_expanded > "$corner_dir/reset_removal.rpt"
write_spef "$corner_dir/routed.spef"
