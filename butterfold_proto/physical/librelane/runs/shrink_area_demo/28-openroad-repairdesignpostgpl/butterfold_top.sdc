###############################################################################
# Created by write_sdc
###############################################################################
current_design butterfold_top
###############################################################################
# Timing Constraints
###############################################################################
create_clock -name core_clk -period 26.0417 [get_ports {clk}]
set_clock_uncertainty 0.0000 core_clk
set_input_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {din[0]}]
set_input_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {din[1]}]
set_input_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {din[2]}]
set_input_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {din[3]}]
set_input_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {din[4]}]
set_input_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {din[5]}]
set_input_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {din[6]}]
set_input_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {din[7]}]
set_input_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {din_valid_i}]
set_output_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {din_ready_o}]
set_output_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {dout[0]}]
set_output_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {dout[1]}]
set_output_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {dout[2]}]
set_output_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {dout[3]}]
set_output_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {dout[4]}]
set_output_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {dout[5]}]
set_output_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {dout[6]}]
set_output_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {dout[7]}]
set_output_delay 0.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {dout_valid_o}]
###############################################################################
# Environment
###############################################################################
set_case_analysis 1 [get_ports {rst_n}]
###############################################################################
# Design Rules
###############################################################################
