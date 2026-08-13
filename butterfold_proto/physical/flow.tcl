source [file join [file dirname [file normalize [info script]]] config.tcl]

proc save_stage {name} {
  global result_dir
  write_db "$result_dir/$name.odb"
  write_def "$result_dir/$name.def"
  report_design_area > "$result_dir/${name}_area.rpt"
  report_checks -path_delay max -group_path_count 50 -endpoint_path_count 1 \
    -unique_paths_to_endpoint -sort_by_slack -format full_clock_expanded \
    -fields {capacitance slew fanout input_pin net} > "$result_dir/${name}_setup.rpt"
  report_checks -path_delay min -group_path_count 20 -endpoint_path_count 1 \
    -unique_paths_to_endpoint -sort_by_slack -format full_clock_expanded \
    -fields {capacitance slew fanout input_pin net} > "$result_dir/${name}_hold.rpt"
  report_tns > "$result_dir/${name}_tns.rpt"
  report_wns > "$result_dir/${name}_wns.rpt"
}

read_lef $tech_lef
read_lef $cell_lef
read_lef $sram_lef
read_liberty $cell_lib
read_liberty $sram_lib
read_verilog $netlist
link_design butterfold_top
read_sdc $sdc

initialize_floorplan -die_area "0 0 $core_w $core_h" \
  -core_area "0 0 $core_w $core_h" -site $site

# Five-metal GF180 track grid from the installed PDK collateral.
foreach layer {Metal1 Metal2 Metal3 Metal4} {
  make_tracks $layer -x_offset 0.28 -x_pitch 0.56 -y_offset 0.28 -y_pitch 0.56
}
make_tracks Metal5 -x_offset 0.45 -x_pitch 0.90 -y_offset 0.45 -y_pitch 0.90

# Keep correlated byte macros adjacent. Arrangement C mirrors the high byte
# so corresponding edge pins face the shared logic channel.
if {$arrangement eq "A"} {
  set lo_xy [list 20.0 752.96]
  set hi_xy [list 491.86 752.96]
  set lo_or R0; set hi_or R0
} elseif {$arrangement eq "B"} {
  set lo_xy [list 20.0 20.0]
  set hi_xy [list 20.0 400.88]
  set lo_or R0; set hi_or R0
} elseif {$arrangement eq "C"} {
  set lo_xy [list 20.0 752.96]
  set hi_xy [list 923.72 752.96]
  set lo_or R0; set hi_or MY
} else {
  error "MACRO_ARRANGEMENT must be A, B, or C"
}
place_inst -name $lo_inst -origin $lo_xy -orientation $lo_or -status FIRM
place_inst -name $hi_inst -origin $hi_xy -orientation $hi_or -status FIRM

# Explicit 20-um placement halos around the hard macros.
cut_rows -halo_width_x $macro_halo -halo_width_y $macro_halo

place_pins -hor_layers Metal3 -ver_layers Metal2
tapcell -tapcell_master gf180mcu_fd_sc_mcu9t5v0__filltie \
  -endcap_master gf180mcu_fd_sc_mcu9t5v0__endcap -distance 120

# Yosys names the mapped constant-one/constant-zero supply nets one_/zero_.
# Bind every implicit standard-cell PG pin to those physical domain aliases.
add_global_connection -net one_ -inst_pattern .* -pin_pattern {VDD|VNW} -power
add_global_connection -net zero_ -inst_pattern .* -pin_pattern {VSS|VPW} -ground
global_connect

set_voltage_domain -name CORE -power one_ -ground zero_
define_pdn_grid -name core_grid -voltage_domains CORE -starts_with POWER
add_pdn_stripe -grid core_grid -layer Metal1 -followpins -width 0.48
add_pdn_stripe -grid core_grid -layer Metal4 -width 3.0 -pitch 80.0 \
  -offset 20.0 -starts_with POWER
add_pdn_stripe -grid core_grid -layer Metal5 -width 3.0 -pitch 80.0 \
  -offset 20.0 -starts_with GROUND
add_pdn_connect -grid core_grid -layers {Metal1 Metal4}
add_pdn_connect -grid core_grid -layers {Metal4 Metal5}
define_pdn_grid -name macro_grid -macro \
  -cells gf180mcu_fd_ip_sram__sram256x8m8wm1 -grid_over_pg_pins \
  -voltage_domains CORE -starts_with POWER
add_pdn_connect -grid macro_grid -layers {Metal3 Metal4}
pdngen -failed_via_report "$result_dir/pdn_failed_vias.rpt"
check_power_grid -net one_ > "$result_dir/pdn_power_check.rpt"
check_power_grid -net zero_ > "$result_dir/pdn_ground_check.rpt"

set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
set_routing_layers -signal Metal2-Metal5 -clock Metal3-Metal5
set_macro_extension 5
save_stage floorplan
if {$stage eq "floorplan"} { exit }

set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna}
global_placement -timing_driven -routability_driven -density $target_density
estimate_parasitics -placement
repair_design -slew_margin 5 -cap_margin 5
detailed_placement
optimize_mirroring
check_placement -verbose -report_file_name "$result_dir/place_check.rpt"
estimate_parasitics -placement
save_stage place
if {$stage eq "place"} { exit }

clock_tree_synthesis \
  -root_buf gf180mcu_fd_sc_mcu9t5v0__clkbuf_16 \
  -buf_list {gf180mcu_fd_sc_mcu9t5v0__clkbuf_2 gf180mcu_fd_sc_mcu9t5v0__clkbuf_4 gf180mcu_fd_sc_mcu9t5v0__clkbuf_8} \
  -sink_clustering_enable -balance_levels
set_propagated_clock [get_clocks core_clk]
estimate_parasitics -placement
repair_timing -setup -hold
detailed_placement
estimate_parasitics -placement
save_stage cts
if {$stage eq "cts"} { exit }

global_route -guide_file "$result_dir/route.guide" -congestion_iterations 30 \
  -congestion_report_file "$result_dir/congestion.rpt"
estimate_parasitics -global_routing
save_stage global_route_preopt
repair_timing -setup -max_passes 1 -max_iterations 1000 \
  -max_buffer_percent 5 -max_utilization 65
repair_timing -hold -allow_setup_violations -max_passes 1 \
  -max_iterations 1000 -max_buffer_percent 5 -max_utilization 65
detailed_placement
global_route -guide_file "$result_dir/route_repaired.guide" \
  -congestion_iterations 30 -congestion_report_file "$result_dir/congestion_repaired.rpt"
estimate_parasitics -global_routing
save_stage global_route

# Detailed routing is attempted but isolated from the reusable global-route
# result so a router limitation cannot destroy the deepest known-good database.
if {[catch {
  detailed_route -output_drc "$result_dir/detailed_route_drc.rpt" \
    -output_maze "$result_dir/detailed_route_maze.log"
  estimate_parasitics -global_routing
  save_stage route
  write_verilog "$result_dir/butterfold_physical.v"
} detail_error]} {
  puts "DETAILED_ROUTE_NOT_AVAILABLE: $detail_error"
}
