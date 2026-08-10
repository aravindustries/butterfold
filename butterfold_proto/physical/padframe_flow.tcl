source [file join [file dirname [file normalize [info script]]] padframe_config.tcl]

proc pad_save {name} {
  global pad_result
  write_db "$pad_result/$name.odb"
  write_def "$pad_result/$name.def"
  report_design_area > "$pad_result/${name}_area.rpt"
  report_checks -path_delay max -group_path_count 50 -endpoint_path_count 1 \
    -unique_paths_to_endpoint -sort_by_slack -format full_clock_expanded > "$pad_result/${name}_setup.rpt"
  report_checks -path_delay min -group_path_count 50 -endpoint_path_count 1 \
    -unique_paths_to_endpoint -sort_by_slack -format full_clock_expanded > "$pad_result/${name}_hold.rpt"
  report_wns -max > "$pad_result/${name}_setup_wns.rpt"
  report_tns -max > "$pad_result/${name}_setup_tns.rpt"
  report_wns -min > "$pad_result/${name}_hold_wns.rpt"
  report_tns -min > "$pad_result/${name}_hold_tns.rpt"
}

read_lef $tech_lef
read_lef $io_site_lef
read_lef $cell_lef
read_lef $sram_lef
foreach lef $io_lefs {read_lef $lef}
read_liberty $cell_lib
read_liberty $sram_lib
read_liberty $io_lib
read_verilog $mapped_core
read_verilog $wrapper
link_design butterfold_padframe_top
read_sdc $pad_sdc

initialize_floorplan -die_area "0 0 $die_w $die_h" \
  -core_area "$core_ll $core_ll $core_ur $core_ur" -site $site
foreach layer {Metal1 Metal2 Metal3 Metal4} {
  make_tracks $layer -x_offset 0.28 -x_pitch 0.56 -y_offset 0.28 -y_pitch 0.56
}
make_tracks Metal5 -x_offset 0.45 -x_pitch 0.90 -y_offset 0.45 -y_pitch 0.90
make_io_sites -horizontal_site GF_IO_Site -vertical_site GF_IO_Site \
  -corner_site GF_COR_Site -offset 0
source "$phys_dir/padframe_place_pads.tcl"
place_pins -hor_layers Metal3 -ver_layers Metal2
source "$phys_dir/padframe_place_buffers.tcl"

# Preserve the correlated two-byte SRAM arrangement from the validated core.
place_inst -name $lo_inst -origin {390.0 1504.12} -orientation R0 -status FIRM
place_inst -name $hi_inst -origin {1845.0 1504.12} -orientation MY -status FIRM
cut_rows -halo_width_x 20 -halo_width_y 20

tapcell -tapcell_master gf180mcu_fd_sc_mcu9t5v0__filltie \
  -endcap_master gf180mcu_fd_sc_mcu9t5v0__endcap -distance 120
add_global_connection -net {u_core/one_} -inst_pattern .* -pin_pattern {VDD|VNW|DVDD} -power
add_global_connection -net {u_core/zero_} -inst_pattern .* -pin_pattern {VSS|VPW|DVSS} -ground
global_connect
foreach n {VDD VSS one_ zero_ {u_core/one_} {u_core/zero_}} {
  set dbnet [[ord::get_db_block] findNet $n]
  if {$dbnet ne "NULL"} { $dbnet setSpecial }
}
foreach n {pad_clk pad_rst_n pad_din_valid_i pad_din_ready_o pad_dout_valid_o} {
  set dbnet [[ord::get_db_block] findNet $n]
  if {$dbnet ne "NULL"} { $dbnet setSpecial }
}
for {set i 0} {$i < 8} {incr i} {
  foreach stem {pad_din pad_dout} {
    set dbnet [[ord::get_db_block] findNet "${stem}\[$i\]"]
    if {$dbnet ne "NULL"} { $dbnet setSpecial }
  }
}
set_voltage_domain -name CORE -power {u_core/one_} -ground {u_core/zero_}
define_pdn_grid -name core_grid -voltage_domains CORE -starts_with POWER
add_pdn_stripe -grid core_grid -layer Metal1 -followpins -width 0.48
add_pdn_stripe -grid core_grid -layer Metal4 -width 3.0 -pitch 80.0 -offset 390.0 -starts_with POWER
add_pdn_stripe -grid core_grid -layer Metal5 -width 3.0 -pitch 80.0 -offset 390.0 -starts_with GROUND
add_pdn_connect -grid core_grid -layers {Metal1 Metal4}
add_pdn_connect -grid core_grid -layers {Metal4 Metal5}
define_pdn_grid -name macro_grid -macro -cells gf180mcu_fd_ip_sram__sram256x8m8wm1 \
  -grid_over_pg_pins -voltage_domains CORE -starts_with POWER
add_pdn_connect -grid macro_grid -layers {Metal3 Metal4}
pdngen -failed_via_report "$pad_result/pdn_failed_vias.rpt"
# The mapped core represents supplies as constant nets without top-level
# BTerms; PSM therefore cannot seed check_power_grid even though pdngen binds
# the SRAM and pad-ring PG pins.  Preserve this limitation explicitly.
set fp [open "$pad_result/pdn_check_scope.rpt" w]
puts $fp "pdngen completed for u_core/one_ and u_core/zero_; check_power_grid requires a physical supply BTerm not present in the mapped core handoff."
close $fp

set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
set_routing_layers -signal Metal2-Metal5 -clock Metal3-Metal5
set_macro_extension 5
pad_save floorplan
if {$pad_stage eq "floorplan"} { exit }

set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna}
global_placement -timing_driven -routability_driven -density $target_density
estimate_parasitics -placement
# The GF bi_t Liberty imposes a 1-ns PAD transition even when its intrinsic
# pad capacitance makes that unattainable at the characterized external load.
# Do not let this external-pad model prevent repair of real core-side nets;
# output transition is reported separately at extracted signoff.
set_max_transition 5.0 [get_ports {pad_din_ready_o pad_dout_valid_o pad_dout[*]}]
unset_case_analysis [get_ports pad_rst_n]
repair_design -slew_margin 0 -cap_margin 0
set_case_analysis 1 [get_ports pad_rst_n]
detailed_placement
optimize_mirroring
check_placement -verbose -report_file_name "$pad_result/place_check.rpt"
estimate_parasitics -placement
pad_save place
if {$pad_stage eq "place"} { exit }

clock_tree_synthesis -root_buf gf180mcu_fd_sc_mcu9t5v0__clkbuf_16 \
  -buf_list {gf180mcu_fd_sc_mcu9t5v0__clkbuf_2 gf180mcu_fd_sc_mcu9t5v0__clkbuf_4 gf180mcu_fd_sc_mcu9t5v0__clkbuf_8} \
  -sink_clustering_enable -balance_levels
set_propagated_clock [get_clocks pad_clk_ext]
estimate_parasitics -placement
repair_timing -setup -hold
detailed_placement
estimate_parasitics -placement
pad_save cts
if {$pad_stage eq "cts"} { exit }

global_route -guide_file "$pad_result/route.guide" -congestion_iterations 60 -allow_congestion \
  -congestion_report_file "$pad_result/congestion.rpt"
estimate_parasitics -global_routing
repair_timing -setup -max_passes 1 -max_iterations 1000 -max_buffer_percent 5 -max_utilization 65
repair_timing -hold -allow_setup_violations -max_passes 1 -max_iterations 1000 -max_buffer_percent 5 -max_utilization 65
detailed_placement
global_route -guide_file "$pad_result/route_repaired.guide" -congestion_iterations 60 -allow_congestion \
  -congestion_report_file "$pad_result/congestion_repaired.rpt"
estimate_parasitics -global_routing
pad_save global_route
if {$pad_stage eq "global_route"} { exit }

detailed_route -output_drc "$pad_result/detailed_route_drc.rpt" \
  -output_maze "$pad_result/detailed_route_maze.log"
estimate_parasitics -global_routing
pad_save route
write_verilog "$pad_result/butterfold_padframe_physical.v"
