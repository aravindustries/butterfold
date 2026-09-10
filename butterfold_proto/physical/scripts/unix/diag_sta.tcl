# Apples-to-apples setup STA + path dump. STA_ODB, TAG, and OUT_DIR from env.
set proto /foss/designs/butterfold/butterfold_proto
set pdk   /foss/pdks/gf180mcuD
set odb   $::env(STA_ODB)
set tag   $::env(TAG)
set out   $::env(OUT_DIR)
file mkdir $out
set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $odb
read_sdc $proto/physical/constraints.sdc

# the shell renames the outputs; constrain whichever spelling this database has
set outs [get_ports -quiet {din_ready_o_OUT dout_valid_o_OUT dout_OUT[*]}]
if {[llength $outs] > 0} {
  set_output_delay 0.0 -clock core_clk $outs
  puts "DIAG_$tag OUTPUT_DELAY_PORTS [llength $outs] (shelled spelling)"
} else {
  puts "DIAG_$tag OUTPUT_DELAY_PORTS from constraints.sdc (original spelling)"
}
set_propagated_clock [all_clocks]

# is the reset actually held? if these two clocks differ, case analysis is live
puts "DIAG_$tag CLOCKS [get_full_name [all_clocks]]"
puts "DIAG_$tag CLK_PERIOD [sta::clock_property [lindex [all_clocks] 0] period]"

set spef [file dirname $odb]/spef_sta/final.max.spef
file mkdir [file dirname $spef]
if {![file exists $spef]} {
  define_process_corner -ext_model_index 0 CURRENT_CORNER
  extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max -lef_res
  write_spef $spef
  puts "DIAG_$tag SPEF extracted fresh -> $spef"
} else {
  puts "DIAG_$tag SPEF reused -> $spef"
}
read_spef -corner $c $spef

puts -nonewline "DIAG_$tag CASE_ON_WNS "; report_worst_slack -max -digits 6
puts "DIAG_$tag CASE_ON_VIO [sta::endpoint_violation_count max]"
puts -nonewline "DIAG_$tag CASE_ON_TNS "; report_tns -max -digits 6

report_checks -path_delay max -group_count 5 -slack_max 0 -digits 4 \
  -fields {slew cap input net fanout} > $out/paths_$tag.rpt
puts "DIAG_$tag PATHS -> $out/paths_$tag.rpt"

# if unsetting the reset case changes nothing, the case analysis was never live
catch {unset_case_analysis [get_ports rst_n]}
puts -nonewline "DIAG_$tag CASE_OFF_WNS "; report_worst_slack -max -digits 6
puts "DIAG_$tag CASE_OFF_VIO [sta::endpoint_violation_count max]"
puts "DIAG_$tag DONE"
exit
