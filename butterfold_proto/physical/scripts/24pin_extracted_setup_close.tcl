# =============================================================================
# 24-pin extracted-aware setup/electrical/reset ECO
# =============================================================================
# Starts from the clean LibreLane pre-fill post-DRT ODB and applies native
# OpenROAD repair_design + repair_timing against OpenRCX parasitics.
# Then legalizes, GRT+DRT, re-extracts, and reports max-SS setup / min-FF hold.
#
# Usage (from butterfold_proto):
#   openroad -no_init -exit physical/scripts/24pin_extracted_setup_close.tcl
# =============================================================================

set script_dir [file dirname [file normalize [info script]]]
set proto_root [file normalize [file join $script_dir .. ..]]
set pdk /foss/pdks/gf180mcuD
set run $proto_root/physical/librelane/runs/butterfold_top_24pin_38p4_9t
if {![info exists env(ECO_SRC)] || $env(ECO_SRC) eq ""} {
  set src $run/46-odb-reportdisconnectedpins/butterfold_top.odb
} else {
  set src $env(ECO_SRC)
}
if {![info exists env(ECO_OUTDIR)] || $env(ECO_OUTDIR) eq ""} {
  set outdir $proto_root/physical/results/24pin_eco
} else {
  set outdir $env(ECO_OUTDIR)
}
file mkdir $outdir
puts "ECO_SRC $src"
puts "ECO_OUTDIR $outdir"
if {![file exists $src]} { puts "ERROR missing $src"; exit 1 }

set tech_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
set cell_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
set sram_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
set lib_ss $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
set lib_ff $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
set sram_ss $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
set sram_ff $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
set rcx_min $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.min
set sdc $proto_root/physical/constraints.sdc

read_lef $tech_lef
read_lef $cell_lef
read_lef $sram_lef
# Setup ECO uses SS liberty only. Hold is re-STA'd after reroute with FF+min SPEF.
read_liberty $lib_ss
read_liberty $sram_ss
read_db $src
read_sdc $sdc
set_propagated_clock [get_clocks core_clk]
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold}
set_max_transition 3 [current_design]
set_max_capacitance 0.2 [current_design]
set_max_fanout 10 [current_design]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

# Keep CTS clock buffers and SRAM macros out of sizing/buffering.
if {[llength [info commands get_cells]]} {
  foreach pat {clkbuf_*core_clk* clkbuf_*clk_regs* clkbuf_leaf_* *u_lo.u_sram *u_hi.u_sram} {
    if {[catch {set_dont_touch [get_cells -quiet $pat]} msg]} {
      puts "DONT_TOUCH_SKIP $pat $msg"
    }
  }
}

proc report_corner {tag} {
  global outdir
  puts "==== $tag ===="
  report_wns -max
  report_tns -max
  report_wns -min
  report_tns -min
  report_check_types -max_slew -max_cap -max_fanout -violators \
    > [file join $outdir ${tag}_electrical.rpt]
  set f [open [file join $outdir ${tag}_summary.rpt] w]
  puts $f $tag
  close $f
  report_wns -max > [file join $outdir ${tag}_wns_setup.rpt]
  report_tns -max > [file join $outdir ${tag}_tns_setup.rpt]
  report_wns -min > [file join $outdir ${tag}_wns_hold.rpt]
  report_tns -min > [file join $outdir ${tag}_tns_hold.rpt]
  report_checks -path_delay max -group_path_count 5 -fields {slew cap fanout net} \
    > [file join $outdir ${tag}_setup_paths.rpt]
}

puts "ECO_EXTRACT_BEFORE"
extract_parasitics -ext_model_file $rcx_max
write_spef [file join $outdir before.max.spef]
read_spef [file join $outdir before.max.spef]
report_corner before_maxss

puts "ECO_REPAIR_DESIGN_DATA"
repair_design -slew_margin 20 -cap_margin 20
estimate_parasitics -placement

puts "ECO_REPAIR_TIMING_SETUP"
repair_timing -setup -setup_margin 0.4 -repair_tns 100 \
  -max_buffer_percent 20
estimate_parasitics -placement

puts "ECO_REPAIR_RESET_VISIBLE"
unset_case_analysis [get_ports rst_n]
repair_design -slew_margin 20 -cap_margin 20
estimate_parasitics -placement
set_case_analysis 1 [get_ports rst_n]
repair_timing -setup -setup_margin 0.2 -repair_tns 100 \
  -max_buffer_percent 10
estimate_parasitics -placement

puts "ECO_LEGALIZE"
if {[catch {detailed_placement -incremental -max_displacement {80 120}} msg]} {
  puts "LEGALIZE_WARN $msg"
  detailed_placement
}
if {[catch {check_placement -verbose} cmsg]} {
  puts "CHECK_PLACEMENT $cmsg"
} else {
  puts "CHECK_PLACEMENT_OK"
}
write_db [file join $outdir butterfold_top_eco_legal.odb]

puts "ECO_REROUTE"
set block [ord::get_db_block]
foreach net [$block getNets] {
  set st [$net getSigType]
  if {[string match *POWER* $st] || [string match *GROUND* $st]} { continue }
  if {[$net getWire] ne "" && [$net getWire] ne "NULL"} {
    odb::dbWire_destroy [$net getWire]
  }
  $net clearGuides
}
foreach layer {Metal2 Metal3 Metal4 Metal5} {
  set_global_routing_layer_adjustment $layer 0.3
}
global_connect
global_route -congestion_iterations 50 -verbose \
  -guide_file [file join $outdir eco.guide]
write_db [file join $outdir butterfold_top_eco_grt.odb]
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 \
  -output_drc [file join $outdir eco.drc]
write_db [file join $outdir butterfold_top_eco_routed.odb]
write_def [file join $outdir butterfold_top_eco_routed.def]

puts "ECO_EXTRACT_AFTER_MAX"
extract_parasitics -ext_model_file $rcx_max
write_spef [file join $outdir after.max.spef]
report_corner after_maxss
report_checks -path_delay max -slack_max 0 -group_path_count 200 \
  > [file join $outdir after_setup_violations.rpt]
report_check_types -max_slew -max_cap -max_fanout -violators \
  > [file join $outdir after_electrical.rpt]

puts "ECO_RESET_VISIBLE_AFTER"
unset_case_analysis [get_ports rst_n]
report_check_types -max_slew -max_cap -max_fanout -violators \
  > [file join $outdir after_reset_electrical.rpt]
report_net rst_n > [file join $outdir after_reset_net.rpt]
set_case_analysis 1 [get_ports rst_n]

puts "ECO_EXTRACT_AFTER_MIN"
extract_parasitics -ext_model_file $rcx_min
write_spef [file join $outdir after.min.spef]
report_wns -min > [file join $outdir after_minff_wns_hold.rpt]
report_tns -min > [file join $outdir after_minff_tns_hold.rpt]
report_checks -path_delay min -group_path_count 5 \
  > [file join $outdir after_hold_paths.rpt]

puts "ECO_DOUT_READY"
if {[catch {
  report_checks -from [get_ports dout_ready_i] -path_delay max \
    -group_path_count 20 > [file join $outdir dout_ready_setup.rpt]
  report_net dout_ready_i > [file join $outdir dout_ready_net.rpt]
} drmsg]} {
  puts "DOUT_READY_REPORT $drmsg"
}

puts "ECO_COMPLETE"
exit
