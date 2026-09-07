set cmax max_ss_125C_4v50
set cmin min_ff_n40C_5v50
define_corners $cmax $cmin
read_liberty -corner $cmax $::env(LIB_STD_SS)
read_liberty -corner $cmax $::env(LIB_SRAM_SS)
read_liberty -corner $cmin $::env(LIB_STD_FF)
read_liberty -corner $cmin $::env(LIB_SRAM_FF)
read_db $::env(OUT_DIR)/route/routed.odb
read_sdc $::env(SDC)
set_propagated_clock [all_clocks]
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal2
read_spef -corner $cmax $::env(OUT_DIR)/spef_final/butterfold_top.max.spef
read_spef -corner $cmin $::env(OUT_DIR)/spef_final/butterfold_top.min.spef
puts "X_FINAL_SETUP_MAX_SS"; report_worst_slack -max -digits 6
puts "X_FINAL_SETUP_TNS";    report_tns -max -digits 6
puts "X_FINAL_HOLD_MIN_FF";  report_worst_slack -min -digits 6
puts "X_FINAL_SLEW [sta::max_slew_violation_count]"
puts "X_FINAL_CAP  [sta::max_capacitance_violation_count]"
