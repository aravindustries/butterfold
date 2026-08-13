###############################################################################
# Created by write_sdc
###############################################################################
current_design butterfold_top
###############################################################################
# Timing Constraints
###############################################################################
create_clock -name clk_i -period 30.0000 [get_ports {clk_i}]
set_clock_transition 0.1500 [get_clocks {clk_i}]
set_clock_uncertainty 0.2500 clk_i
set_input_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {din[0]}]
set_input_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {din[1]}]
set_input_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {din[2]}]
set_input_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {din[3]}]
set_input_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {din[4]}]
set_input_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {din[5]}]
set_input_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {din[6]}]
set_input_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {din[7]}]
set_input_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {din_valid_i}]
set_input_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {dout_ready_i}]
set_input_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {rst_ni}]
set_input_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {scan_en_i}]
set_input_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {scan_in_i}]
set_output_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {din_ready_o}]
set_output_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {done_irq_o}]
set_output_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {dout[0]}]
set_output_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {dout[1]}]
set_output_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {dout[2]}]
set_output_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {dout[3]}]
set_output_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {dout[4]}]
set_output_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {dout[5]}]
set_output_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {dout[6]}]
set_output_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {dout[7]}]
set_output_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {dout_valid_o}]
set_output_delay 6.0000 -clock [get_clocks {clk_i}] -add_delay [get_ports {scan_out_o}]
###############################################################################
# Environment
###############################################################################
set_load -pin_load 0.0729 [get_ports {din_ready_o}]
set_load -pin_load 0.0729 [get_ports {done_irq_o}]
set_load -pin_load 0.0729 [get_ports {dout_valid_o}]
set_load -pin_load 0.0729 [get_ports {scan_out_o}]
set_load -pin_load 0.0729 [get_ports {dout[7]}]
set_load -pin_load 0.0729 [get_ports {dout[6]}]
set_load -pin_load 0.0729 [get_ports {dout[5]}]
set_load -pin_load 0.0729 [get_ports {dout[4]}]
set_load -pin_load 0.0729 [get_ports {dout[3]}]
set_load -pin_load 0.0729 [get_ports {dout[2]}]
set_load -pin_load 0.0729 [get_ports {dout[1]}]
set_load -pin_load 0.0729 [get_ports {dout[0]}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_4 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {clk_i}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {din_valid_i}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {dout_ready_i}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {rst_ni}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {scan_en_i}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {scan_in_i}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {din[7]}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {din[6]}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {din[5]}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {din[4]}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {din[3]}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {din[2]}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {din[1]}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {din[0]}]
###############################################################################
# Design Rules
###############################################################################
set_max_transition 3.0000 [current_design]
set_max_capacitance 0.2000 [current_design]
set_max_fanout 10.0000 [current_design]
