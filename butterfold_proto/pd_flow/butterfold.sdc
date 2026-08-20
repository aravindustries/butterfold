set clk_name   clk
set clk_port   clk
set clk_period 26       ;# 60 MHz

create_clock -name $clk_name -period $clk_period [get_ports $clk_port]

set_clock_uncertainty 0.25 [get_clocks $clk_name]
set_clock_transition  0.15 [get_clocks $clk_name]

# OpenSTA has no remove_from_collection
set clk_idx [lsearch [all_inputs] [get_port $clk_port]]
set non_clk [lreplace [all_inputs] $clk_idx $clk_idx]

set_input_delay  [expr $clk_period * 0.20] -clock $clk_name $non_clk
set_output_delay [expr $clk_period * 0.20] -clock $clk_name [all_outputs]

set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_4 -pin ZN $non_clk
set_load 0.05 [all_outputs]

set_max_fanout     16  [current_design]


# --- still commented until you've checked the FSM ---
# set_multicycle_path -setup 2 \
#   -to [get_pins {u_transform_scheduler_core.u_fft_scratch_sram.u_*.u_sram/D[*]}]
# set_multicycle_path -hold 1 \
#   -to [get_pins {u_transform_scheduler_core.u_fft_scratch_sram.u_*.u_sram/D[*]}]