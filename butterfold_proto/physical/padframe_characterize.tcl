source [file join [file dirname [file normalize [info script]]] config.tcl]
set corner [expr {[info exists ::env(PAD_CORNER)] ? $::env(PAD_CORNER) : "ss_125C_4v50"}]
set load [expr {[info exists ::env(PAD_LOAD)] ? $::env(PAD_LOAD) : 5.0}]
set out "$phys_dir/results/padframe/characterize/${corner}_load${load}pF"
file mkdir $out
set io_root "$pdk_root/libs.ref/gf180mcu_fd_io"
read_lef $tech_lef
read_lef $cell_lef
foreach lef {in_c in_s bi_t} { read_lef "$io_root/lef/gf180mcu_fd_io__${lef}.lef" }
read_liberty "$pdk_root/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__${corner}.lib"
read_liberty "$io_root/lib/gf180mcu_fd_io__${corner}.lib"
read_verilog "$phys_dir/padframe_characterize_netlist.v"
link_design padframe_characterize_netlist
set_input_transition 0.50 [get_ports {pad_in out_a}]
set_load 0.10 [get_ports {in_c_y in_s_y chain2_y chain4_y chain6_y chain8_y}]
set_load $load [get_ports {out_pad out_pad01 out_pad10 out_pad11 out_pad11f}]
foreach pair {
  {in_c_y input_in_c}
  {in_s_y input_in_s}
  {chain2_y input_chain2}
  {chain4_y input_chain4}
  {chain6_y input_chain6}
  {chain8_y input_chain8}
} {
  lassign $pair endpoint name
  report_checks -unconstrained -from [get_ports pad_in] -to [get_ports $endpoint] \
    -path_delay min -format full -fields {capacitance slew fanout input_pin net} > "$out/${name}_min.rpt"
  report_checks -unconstrained -from [get_ports pad_in] -to [get_ports $endpoint] \
    -path_delay max -format full -fields {capacitance slew fanout input_pin net} > "$out/${name}_max.rpt"
}
report_checks -unconstrained -from [get_ports out_a] -to [get_ports out_pad] \
  -path_delay min -format full -fields {capacitance slew fanout input_pin net} > "$out/output_min.rpt"
report_checks -unconstrained -from [get_ports out_a] -to [get_ports out_pad] \
  -path_delay max -format full -fields {capacitance slew fanout input_pin net} > "$out/output_max.rpt"
foreach mode {01 10 11} {
  report_checks -unconstrained -from [get_ports out_a] -to [get_ports out_pad$mode] \
    -path_delay min -format full -fields {capacitance slew fanout input_pin net} > "$out/output_${mode}_min.rpt"
  report_checks -unconstrained -from [get_ports out_a] -to [get_ports out_pad$mode] \
    -path_delay max -format full -fields {capacitance slew fanout input_pin net} > "$out/output_${mode}_max.rpt"
}
report_checks -unconstrained -from [get_ports out_a] -to [get_ports out_pad11f] -path_delay min -format full -fields {capacitance slew fanout input_pin net} > "$out/output_11f_min.rpt"
report_checks -unconstrained -from [get_ports out_a] -to [get_ports out_pad11f] -path_delay max -format full -fields {capacitance slew fanout input_pin net} > "$out/output_11f_max.rpt"
