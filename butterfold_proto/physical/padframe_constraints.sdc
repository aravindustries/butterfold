create_clock -name pad_clk_ext -period 16.2760416667 [get_ports pad_clk]
set_clock_uncertainty -setup 0.10 [get_clocks pad_clk_ext]
set_clock_uncertainty -hold 0.05 [get_clocks pad_clk_ext]
# Candidate die-pad contract.  Negative max delay expresses setup before the
# active sampling edge; the final report derives the equivalent positive
# setup requirement.  The 0.25-ns input transition is required by the actual
# in_c SS Liberty arc even after its load is isolated to one buf_1 input.
set_input_delay -min 0.10 -clock pad_clk_ext [get_ports {pad_din_valid_i pad_din[*]}]
set_input_delay -max -3.50 -clock pad_clk_ext [get_ports {pad_din_valid_i pad_din[*]}]
set_input_transition 0.25 [get_ports {pad_clk pad_din_valid_i pad_din[*]}]
set_output_delay -min 0.0 -clock pad_clk_ext [get_ports {pad_din_ready_o pad_dout_valid_o pad_dout[*]}]
set_output_delay -max -6.0 -clock pad_clk_ext [get_ports {pad_din_ready_o pad_dout_valid_o pad_dout[*]}]
set_load 5.0 [get_ports {pad_din_ready_o pad_dout_valid_o pad_dout[*]}]
set_case_analysis 1 [get_ports pad_rst_n]
