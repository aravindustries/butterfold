source [file join [file dirname [file normalize [info script]]] padframe_config.tcl]
read_lef $tech_lef
read_lef $io_site_lef
read_lef $cell_lef
read_lef $sram_lef
foreach lef $io_lefs {read_lef $lef}
read_liberty $cell_lib
read_liberty $sram_lib
read_liberty $io_lib
read_db "$pad_result/cts.odb"
foreach n {VDD VSS one_ zero_ {u_core/one_} {u_core/zero_}} {
  set dbnet [[ord::get_db_block] findNet $n]
  if {$dbnet ne "NULL"} { $dbnet setSpecial }
}
source [file join [file dirname [file normalize [info script]]] padframe_connect_signal_pads.tcl]
source [file join [file dirname [file normalize [info script]]] padframe_connect_static_controls.tcl]
read_sdc $pad_sdc
set_propagated_clock [get_clocks pad_clk_ext]
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
set_routing_layers -signal Metal2-Metal5 -clock Metal3-Metal5
set_macro_extension 5
global_route -guide_file "$pad_result/route.guide" -congestion_iterations 60 -allow_congestion -congestion_report_file "$pad_result/congestion.rpt"
write_db "$pad_result/global_route.odb"
detailed_route -output_drc "$pad_result/detailed_route_drc.rpt" -output_maze "$pad_result/detailed_route_maze.log"
write_db "$pad_result/route.odb"
write_def "$pad_result/route.def"
write_verilog "$pad_result/butterfold_padframe_physical.v"
report_design_area > "$pad_result/route_area.rpt"
report_wns -max > "$pad_result/route_setup_wns.rpt"
report_tns -max > "$pad_result/route_setup_tns.rpt"
report_wns -min > "$pad_result/route_hold_wns.rpt"
report_tns -min > "$pad_result/route_hold_tns.rpt"
