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

report_checks -from [get_pins {_19540_/Q _19541_/Q _19542_/Q}] \
  -path_delay max -group_path_count 20 -format full_clock_expanded \
  -fields {capacitance slew fanout input_pin net} > "$result_dir/dft12_physical_paths.rpt"
report_checks -from [get_pins {_20283_/Q _20284_/Q _20285_/Q _20286_/Q _20287_/Q _20288_/Q _20289_/Q _20290_/Q _20321_/Q _20322_/Q _20323_/Q _20324_/Q _20325_/Q _20326_/Q _20327_/Q _20328_/Q _20329_/Q _20330_/Q}] \
  -path_delay max -group_path_count 20 -format full_clock_expanded \
  -fields {capacitance slew fanout input_pin net} > "$result_dir/multiplier_physical_paths.rpt"
report_checks -from [all_registers] -path_delay min -group_path_count 20 \
  -format full_clock_expanded -fields {capacitance slew fanout input_pin net} \
  > "$result_dir/internal_hold.rpt"
report_checks -to [get_pins -hierarchical *u_sram/A*] -path_delay max \
  -group_path_count 20 -format full_clock_expanded \
  -fields {capacitance slew fanout input_pin net} > "$result_dir/sram_address_setup.rpt"
report_checks -to [get_pins -hierarchical *u_sram/D*] -path_delay max \
  -group_path_count 20 -format full_clock_expanded \
  -fields {capacitance slew fanout input_pin net} > "$result_dir/sram_data_setup.rpt"
set sram_ctrl [concat [get_pins -hierarchical *u_sram/CEN] \
  [get_pins -hierarchical *u_sram/GWEN] \
  [get_pins -hierarchical *u_sram/WEN*]]
report_checks -to $sram_ctrl -path_delay max \
  -group_path_count 20 -format full_clock_expanded \
  -fields {capacitance slew fanout input_pin net} > "$result_dir/sram_control_setup.rpt"
report_checks -from [get_pins -hierarchical *u_sram/Q*] -path_delay max \
  -group_path_count 20 -format full_clock_expanded \
  -fields {capacitance slew fanout input_pin net} > "$result_dir/sram_read_capture.rpt"

report_clock_skew -setup > "$result_dir/clock_skew_setup.rpt"
report_clock_skew -hold > "$result_dir/clock_skew_hold.rpt"

set metric_file [open "$result_dir/physical_metrics.rpt" w]
set std_count 0; set std_area 0.0
set macro_count 0; set macro_area 0.0
set clock_count 0; set clock_area 0.0
set buf_inv_count 0
foreach inst [[ord::get_db_block] getInsts] {
  set master [$inst getMaster]
  set area [expr {double([$master getWidth]) * double([$master getHeight]) / 4000000.0}]
  set name [$inst getName]
  set mname [$master getName]
  if {[$master isBlock]} {
    incr macro_count; set macro_area [expr {$macro_area + $area}]
  } else {
    incr std_count; set std_area [expr {$std_area + $area}]
  }
  if {[string match "clkbuf*" $name]} {
    incr clock_count; set clock_area [expr {$clock_area + $area}]
  }
  if {[string match "*buf*" $mname] || [string match "*inv*" $mname]} {
    incr buf_inv_count
  }
}
puts $metric_file "standard_cell_count $std_count"
puts $metric_file "standard_cell_area_um2 [format %.3f $std_area]"
puts $metric_file "macro_count $macro_count"
puts $metric_file "macro_area_um2 [format %.3f $macro_area]"
puts $metric_file "clock_buffer_count $clock_count"
puts $metric_file "clock_buffer_area_um2 [format %.3f $clock_area]"
puts $metric_file "buffer_inverter_count $buf_inv_count"
close $metric_file
