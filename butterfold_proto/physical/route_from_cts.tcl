source [file join [file dirname [file normalize [info script]]] config.tcl]

read_lef $tech_lef
read_lef $cell_lef
read_lef $sram_lef
read_liberty $cell_lib
read_liberty $sram_lib
read_db "$result_dir/cts.odb"
read_sdc $sdc
set_propagated_clock [get_clocks core_clk]
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
set_routing_layers -signal Metal2-Metal5 -clock Metal3-Metal5
set_macro_extension 5

global_route -guide_file "$result_dir/route.guide" -congestion_iterations 30 \
  -congestion_report_file "$result_dir/congestion.rpt"
estimate_parasitics -global_routing
write_db "$result_dir/global_route.odb"
write_def "$result_dir/global_route.def"
report_checks -path_delay max -group_path_count 50 -endpoint_path_count 1 \
  -unique_paths_to_endpoint -sort_by_slack -format full_clock_expanded \
  -fields {capacitance slew fanout input_pin net} > "$result_dir/global_route_setup.rpt"
report_checks -path_delay min -group_path_count 20 -endpoint_path_count 1 \
  -unique_paths_to_endpoint -sort_by_slack -format full_clock_expanded \
  -fields {capacitance slew fanout input_pin net} > "$result_dir/global_route_hold.rpt"
report_tns > "$result_dir/global_route_tns.rpt"
report_wns > "$result_dir/global_route_wns.rpt"

if {[catch {
  detailed_route -output_drc "$result_dir/detailed_route_drc.rpt" \
    -output_maze "$result_dir/detailed_route_maze.log"
  estimate_parasitics -global_routing
  write_db "$result_dir/route.odb"
  write_def "$result_dir/route.def"
  report_checks -path_delay max -group_path_count 50 -endpoint_path_count 1 \
    -unique_paths_to_endpoint -sort_by_slack -format full_clock_expanded \
    -fields {capacitance slew fanout input_pin net} > "$result_dir/route_setup.rpt"
  report_checks -path_delay min -group_path_count 20 -endpoint_path_count 1 \
    -unique_paths_to_endpoint -sort_by_slack -format full_clock_expanded \
    -fields {capacitance slew fanout input_pin net} > "$result_dir/route_hold.rpt"
  report_tns > "$result_dir/route_tns.rpt"
  report_wns > "$result_dir/route_wns.rpt"
  write_verilog "$result_dir/butterfold_physical.v"
} detail_error]} {
  puts "DETAILED_ROUTE_NOT_AVAILABLE: $detail_error"
}
