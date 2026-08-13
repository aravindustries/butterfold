# AREA STUDY ONLY -- same audited constraints/corner as timing/sta.tcl.
set sc_lib /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
set sram256_lib /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_liberty $sc_lib
read_liberty $sram256_lib
read_verilog two_sram_experiment/results/butterfold_mapped.v
link_design butterfold_top
create_clock -name core_clk -period 16.276041667 -waveform {0.0 8.1380208335} [get_ports clk]
set_clock_uncertainty 0.0 [get_clocks core_clk]
set_input_delay 0.0 -clock core_clk [get_ports {din[*] din_valid_i}]
set_output_delay 0.0 -clock core_clk [get_ports {din_ready_o dout[*] dout_valid_o}]
set_case_analysis 1 [get_ports rst_n]
check_setup -verbose > two_sram_experiment/results/check_setup.rpt
report_checks -path_delay max -group_path_count 10 -endpoint_path_count 1 \
  -unique_paths_to_endpoint -sort_by_slack -format full_clock_expanded \
  > two_sram_experiment/results/setup_top10.rpt
report_checks -path_delay max -slack_max 0.0 -group_path_count 100000 \
  -endpoint_path_count 1 -unique_paths_to_endpoint -format end \
  > two_sram_experiment/results/setup_violations.rpt
set edge_q [all_registers -edge_triggered -output_pins]
set edge_d [all_registers -edge_triggered -data_pins]
report_checks -path_delay max -from $edge_q -to $edge_d -group_path_count 10 \
  -endpoint_path_count 1 -unique_paths_to_endpoint -sort_by_slack \
  -format full_clock_expanded > two_sram_experiment/results/setup_edge_top10.rpt
report_wns -max
report_tns -max
report_clock_min_period [get_clocks core_clk]
