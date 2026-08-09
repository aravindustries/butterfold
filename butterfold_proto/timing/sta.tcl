set sc_lib /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
set sram128_lib /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram128x8m8wm1__ss_125C_4v50.lib
set sram512_lib /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram512x8m8wm1__ss_125C_4v50.lib

read_liberty $sc_lib
read_liberty $sram128_lib
read_liberty $sram512_lib
read_verilog timing/results/butterfold_mapped.v
link_design butterfold_top

# 61.44 MHz target. The waveform is stated explicitly for latch analysis.
create_clock -name core_clk -period 16.276041667 \
    -waveform {0.0 8.1380208335} [get_ports clk]
set_clock_uncertainty 0.0 [get_clocks core_clk]

# Ideal zero-delay chip boundary used only for synthesis-level internal timing.
# No board delay, input slew, or output capacitance is invented here.
set_input_delay 0.0 -clock core_clk [get_ports {din[*] din_valid_i}]
set_output_delay 0.0 -clock core_clk \
    [get_ports {din_ready_o dout[*] dout_valid_o}]

# Analyze normal operation with asynchronous reset deasserted. This avoids
# treating reset recovery/removal and reset-fed latch constants as data paths.
set_case_analysis 1 [get_ports rst_n]

report_units
report_clock_properties [get_clocks core_clk]
check_setup -verbose > timing/results/check_setup.rpt
report_checks -path_delay max -group_path_count 10 \
    -endpoint_path_count 1 -unique_paths_to_endpoint -sort_by_slack \
    -format full_clock_expanded -fields {capacitance slew fanout input_pin net} \
    > timing/results/setup_top10.rpt
report_checks -path_delay max -slack_max 0.0 -group_path_count 100000 \
    -endpoint_path_count 1 -unique_paths_to_endpoint -format end \
    > timing/results/setup_violations.rpt
set edge_register_data_pins [all_registers -edge_triggered -data_pins]
set edge_register_output_pins [all_registers -edge_triggered -output_pins]
report_checks -path_delay max -from $edge_register_output_pins \
    -to $edge_register_data_pins -group_path_count 10 \
    -endpoint_path_count 1 -unique_paths_to_endpoint -sort_by_slack \
    -format full_clock_expanded -fields {capacitance slew fanout input_pin net} \
    > timing/results/setup_edge_top10.rpt
report_checks -path_delay max -from $edge_register_output_pins \
    -to $edge_register_data_pins -slack_max 0.0 \
    -group_path_count 100000 -endpoint_path_count 1 \
    -unique_paths_to_endpoint -format end \
    > timing/results/setup_edge_violations.rpt
report_checks -path_delay min -group_path_count 10 \
    -endpoint_path_count 1 -unique_paths_to_endpoint -sort_by_slack \
    -format full_clock_expanded -fields {capacitance slew fanout input_pin net} \
    > timing/results/hold_top10.rpt
report_checks -unconstrained -path_delay max -group_path_count 100000 \
    -endpoint_path_count 1 -format end \
    > timing/results/unconstrained.rpt
report_wns -max
report_tns -max
report_clock_min_period [get_clocks core_clk]

set sram_a_pins [get_pins -hierarchical *u_sram*/A*]
set sram_d_pins [get_pins -hierarchical *u_sram*/D*]
set sram_control_pins [get_pins -hierarchical *u_sram*/CEN]
set sram_control_pins [concat $sram_control_pins \
    [get_pins -hierarchical *u_sram*/GWEN] \
    [get_pins -hierarchical *u_sram*/WEN*]]
set sram_q_pins [get_pins -hierarchical *u_sram*/Q*]

report_checks -path_delay max -to $sram_a_pins -group_path_count 3 \
    -endpoint_path_count 1 -format full_clock_expanded \
    > timing/results/sram_address_setup.rpt
report_checks -path_delay min -to $sram_a_pins -group_path_count 3 \
    -endpoint_path_count 1 -format full_clock_expanded \
    > timing/results/sram_address_hold.rpt
report_checks -path_delay max -to $sram_d_pins -group_path_count 3 \
    -endpoint_path_count 1 -format full_clock_expanded \
    > timing/results/sram_data_setup.rpt
report_checks -path_delay min -to $sram_d_pins -group_path_count 3 \
    -endpoint_path_count 1 -format full_clock_expanded \
    > timing/results/sram_data_hold.rpt
report_checks -path_delay max -to $sram_control_pins -group_path_count 3 \
    -endpoint_path_count 1 -format full_clock_expanded \
    > timing/results/sram_control_setup.rpt
report_checks -path_delay min -to $sram_control_pins -group_path_count 3 \
    -endpoint_path_count 1 -format full_clock_expanded \
    > timing/results/sram_control_hold.rpt
report_checks -path_delay max -from $sram_q_pins -group_path_count 5 \
    -endpoint_path_count 1 -format full_clock_expanded \
    > timing/results/sram_clk_q.rpt
