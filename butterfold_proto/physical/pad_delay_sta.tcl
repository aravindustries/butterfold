source [file join [file dirname [file normalize [info script]]] config.tcl]
set corner [expr {[info exists ::env(SIGNOFF_CORNER)] ? $::env(SIGNOFF_CORNER) : "ss_125C_4v50"}]
set result "$phys_dir/results/signoff/pads_${corner}"
file mkdir $result
set pad_lib "$pdk_root/libs.ref/gf180mcu_fd_io/lib/gf180mcu_fd_io__${corner}.lib"
read_lef $tech_lef
read_lef "$pdk_root/libs.ref/gf180mcu_fd_io/lef/gf180mcu_fd_io__in_c.lef"
read_lef "$pdk_root/libs.ref/gf180mcu_fd_io/lef/gf180mcu_fd_io__bi_24t.lef"
read_liberty $pad_lib
read_verilog "$phys_dir/pad_delay_netlist.v"
link_design pad_delay_netlist
set_input_transition 0.5 [get_ports {input_pad output_core}]
set_load 0.10 [get_ports input_core]
set_load 10.0 [get_ports output_pad]
set_case_analysis 0 [get_pins u_input/PU]
set_case_analysis 0 [get_pins u_input/PD]
set_case_analysis 1 [get_pins u_output/OE]
set_case_analysis 0 [get_pins u_output/IE]
set_case_analysis 0 [get_pins u_output/SL]
set_case_analysis 0 [get_pins u_output/CS]
set_case_analysis 0 [get_pins u_output/PU]
set_case_analysis 0 [get_pins u_output/PD]
report_checks -unconstrained -from [get_ports input_pad] -to [get_ports input_core] \
  -path_delay max -format full -fields {capacitance slew fanout input_pin net} \
  > "$result/input_max.rpt"
report_checks -unconstrained -from [get_ports input_pad] -to [get_ports input_core] \
  -path_delay min -format full -fields {capacitance slew fanout input_pin net} \
  > "$result/input_min.rpt"
report_checks -unconstrained -from [get_ports output_core] -to [get_ports output_pad] \
  -path_delay max -format full -fields {capacitance slew fanout input_pin net} \
  > "$result/output_max.rpt"
report_checks -unconstrained -from [get_ports output_core] -to [get_ports output_pad] \
  -path_delay min -format full -fields {capacitance slew fanout input_pin net} \
  > "$result/output_min.rpt"
