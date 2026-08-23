# ButterFold 24-pin core SDC.
# Clock: 38.4 MHz production period.  I/O uses the established zero
# board-level delay methodology: every synchronous core pin is constrained
# the same way.  dout_ready_i is a same-domain input and must not be
# false-pathed or left unconstrained relative to din/din_valid_i.
# rst_n is case-analyzed 1 for data-path STA only; reset electrical
# quality is checked separately with that case analysis removed.
create_clock -name core_clk -period 26.041667 [get_ports clk]
set_clock_uncertainty 0.0 [get_clocks core_clk]
set_input_delay 0.0 -clock core_clk [get_ports {din_valid_i dout_ready_i din[*]}]
set_output_delay 0.0 -clock core_clk [get_ports {din_ready_o dout_valid_o dout[*]}]
set_case_analysis 1 [get_ports rst_n]
