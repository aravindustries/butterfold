source [file join [file dirname [file normalize [info script]]] config.tcl]

read_lef $tech_lef
read_lef $cell_lef
read_lef $sram_lef
read_liberty $cell_lib
read_liberty $sram_lib
read_db "$result_dir/route.odb"
read_sdc $sdc
set_propagated_clock [get_clocks core_clk]
extract_parasitics -ext_model_file $rc_rules
write_spef "$result_dir/route.spef"
report_checks -path_delay max -group_path_count 50 -endpoint_path_count 1 \
  -unique_paths_to_endpoint -sort_by_slack -format full_clock_expanded \
  -fields {capacitance slew fanout input_pin net} > "$result_dir/extracted_setup.rpt"
report_checks -path_delay min -group_path_count 20 -endpoint_path_count 1 \
  -unique_paths_to_endpoint -sort_by_slack -format full_clock_expanded \
  -fields {capacitance slew fanout input_pin net} > "$result_dir/extracted_hold.rpt"
report_tns -max > "$result_dir/extracted_tns.rpt"
report_wns -max > "$result_dir/extracted_wns.rpt"
report_tns -min > "$result_dir/extracted_hold_tns.rpt"
report_wns -min > "$result_dir/extracted_hold_wns.rpt"
report_checks -path_delay max -slack_max 0.0 -group_path_count 10000 \
  -endpoint_path_count 1 > "$result_dir/extracted_setup_violations.rpt"
report_checks -path_delay min -slack_max 0.0 -group_path_count 10000 \
  -endpoint_path_count 1 > "$result_dir/extracted_hold_violations.rpt"
