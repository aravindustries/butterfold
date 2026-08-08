###############################################################################
# Created by write_sdc
###############################################################################
current_design counter
###############################################################################
# Timing Constraints
###############################################################################
create_clock -name clk -period 50.0000 [get_ports {clk}]
set_clock_transition 0.1500 [get_clocks {clk}]
set_clock_uncertainty 0.2500 clk
set_input_delay 10.0000 -clock [get_clocks {clk}] -add_delay [get_ports {rst}]
set_output_delay 10.0000 -clock [get_clocks {clk}] -add_delay [get_ports {q[0]}]
set_output_delay 10.0000 -clock [get_clocks {clk}] -add_delay [get_ports {q[1]}]
set_output_delay 10.0000 -clock [get_clocks {clk}] -add_delay [get_ports {q[2]}]
set_output_delay 10.0000 -clock [get_clocks {clk}] -add_delay [get_ports {q[3]}]
###############################################################################
# Environment
###############################################################################
set_load -pin_load 0.0729 [get_ports {q[3]}]
set_load -pin_load 0.0729 [get_ports {q[2]}]
set_load -pin_load 0.0729 [get_ports {q[1]}]
set_load -pin_load 0.0729 [get_ports {q[0]}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_4 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {clk}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {rst}]
###############################################################################
# Design Rules
###############################################################################
set_max_transition 3.0000 [current_design]
set_max_capacitance 0.2000 [current_design]
set_max_fanout 10.0000 [current_design]
