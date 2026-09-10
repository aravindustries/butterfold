set pdk /foss/pdks/gf180mcuD
set odb $::env(STA_ODB)
set spef [file dirname $odb]/spef_sta/final.max.spef
set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $odb
read_sdc /foss/designs/butterfold/butterfold_proto/physical/constraints.sdc
set_output_delay 0.0 -clock core_clk [get_ports {din_ready_o_OUT dout_valid_o_OUT dout_OUT[*]}]
set_propagated_clock [all_clocks]
read_spef -corner $c $spef
puts "=== WORST 3 SETUP PATHS ==="
report_checks -path_delay max -group_count 3 -digits 4
puts "=== ENDPOINT SUMMARY ==="
puts "violations [sta::endpoint_violation_count max]"
