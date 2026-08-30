# Pin-22 compact ECO chain. PHASE=sta|setup|setup_route|hold|hold_route|elec|elec_route|ant|fill
# Setup uses extracted repair_timing only (no broad repair_design).
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/pin22_signoff
set pdk /foss/pdks/gf180mcuD
set sdc $proto/physical/constraints.sdc
set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
set rcx_min $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.min
set lib_ss $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
set lib_sram_ss $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
set lib_ff $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
set lib_sram_ff $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
file mkdir $out
file mkdir $out/drt
file mkdir $out/spef
file mkdir $out/antenna
file mkdir $out/logs

set phase sta
if {[info exists env(PHASE)] && $env(PHASE) ne ""} { set phase $env(PHASE) }
puts "PIN22_PHASE $phase"

proc diode_count {} {
  set n 0
  foreach inst [[ord::get_db_block] getInsts] {
    if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr n }
  }
  return $n
}
proc destroy_signal_wires {} {
  foreach net [[ord::get_db_block] getNets] {
    set st [$net getSigType]
    if {$st eq "POWER" || $st eq "GROUND"} { continue }
    set w [$net getWire]
    if {$w ne "NULL" && $w ne ""} { catch {odb::dbWire_destroy $w} }
    catch {$net clearGuides}
  }
}
proc pg_connect {} {
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
  global_connect
}
proc legalize {} {
  catch {remove_fillers}
  foreach inst [[ord::get_db_block] getInsts] {
    if {[string match "*__antenna" [[$inst getMaster] getName]]} {
      $inst setPlacementStatus PLACED
    }
  }
  set_placement_padding -global -left 1 -right 1
  foreach wildcard {gf180mcu_fd_sc_mcu9t5v0__filltie* gf180mcu_fd_sc_mcu9t5v0__fill_* gf180mcu_fd_sc_mcu9t5v0__endcap*} {
    catch {set_placement_padding -masters $wildcard -right 0 -left 0}
  }
  if {[catch {detailed_placement -max_displacement {500 100}}]} {
    puts "PLACE_RETRY"
    detailed_placement -max_displacement {2000 400}
  }
  if {[catch {check_placement -verbose} cmsg]} { puts "PLACE_FAIL $cmsg"; exit 1 }
  pg_connect
}
proc protect_specials {} {
  foreach inst [[ord::get_db_block] getInsts] {
    set n [$inst getName]
    set m [[$inst getMaster] getName]
    if {[regexp {^(clkbuf|delaybuf|clkload|rst_root|rst_reg)} $n]} { catch {set_dont_touch $n} }
    if {[string match "*__antenna" $m]} {
      catch {set_dont_touch $n}
      $inst setPlacementStatus FIRM
    }
  }
}
proc dont_use_exclude {} {
  set exclude_file /foss/pdks/gf180mcuD/libs.tech/librelane/gf180mcu_fd_sc_mcu9t5v0/drc_exclude.cells
  if {[file exists $exclude_file]} {
    set ef [open $exclude_file r]
    while {[gets $ef line] >= 0} {
      set line [string trim $line]
      if {$line eq "" || [string match "#*" $line]} { continue }
      set cells [get_lib_cells -quiet $line]
      if {[llength $cells]} { set_dont_use $cells }
    }
    close $ef
  }
  catch {set_dont_use [get_lib_cells *bufz_*]}
  catch {set_dont_use [get_lib_cells *antenna]}
}
proc load_ss {odb} {
  set c max_ss_125C_4v50
  define_corners $c
  read_liberty -corner $c $::lib_ss
  read_liberty -corner $c $::lib_sram_ss
  read_db $odb
  read_sdc $::sdc
  set_propagated_clock [all_clocks]
  set_wire_rc -signal -layer Metal2
  set_wire_rc -clock -layer Metal2
}
proc load_ff {odb} {
  set c min_ff_n40C_5v50
  define_corners $c
  read_liberty -corner $c $::lib_ff
  read_liberty -corner $c $::lib_sram_ff
  read_db $odb
  read_sdc $::sdc
  set_propagated_clock [all_clocks]
  set_wire_rc -signal -layer Metal2
  set_wire_rc -clock -layer Metal2
}
proc report_setup {} {
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  puts "SETUP_VIO [sta::endpoint_violation_count max]"
  puts "SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count] FANOUT [sta::max_fanout_violation_count]"
}
proc report_hold {} {
  report_worst_slack -min -digits 6
  report_tns -min -digits 6
  puts "HOLD_VIO [sta::endpoint_violation_count min]"
}
proc route_fresh {tag} {
  set_thread_count 16
  destroy_signal_wires
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} {
    set_global_routing_layer_adjustment $layer 0.3
  }
  puts "GRT $tag"
  global_route -congestion_iterations 50 -verbose
  puts "GRT_DONE $tag"
  repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -iterations 3 -ratio_margin 10
  catch {detailed_placement -max_displacement {500 100}}
  puts "DRT $tag DIODE [diode_count]"
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $::out/drt/${tag}.drc
  puts "DRT_DONE $tag"
  check_antennas
}

if {$phase eq "sta"} {
  load_ss $out/routed.odb
  define_process_corner -ext_model_index 0 CURRENT_CORNER
  extract_parasitics -ext_model_file $rcx_max -lef_res
  write_spef $out/spef/butterfold_top.max.spef
  read_spef -corner max_ss_125C_4v50 $out/spef/butterfold_top.max.spef
  report_setup
  report_hold
  unset_case_analysis [get_ports rst_n]
  puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count] FANOUT [sta::max_fanout_violation_count]"
  report_net rst_n > $out/reset_net.rpt
  catch {report_net rst_n_int > $out/reset_net_int.rpt}
  puts "STA_DONE"
  exit 0
}

if {$phase eq "setup2"} {
  # SPEF-backed repair_timing SIGSEGVs in GRouteDbCbk::instItermsDirty on a
  # DRT ODB. Use GRT parasitics after destroying wires (proven resizer path).
  load_ss $out/setup_routed.odb
  dont_use_exclude
  foreach inst [[ord::get_db_block] getInsts] {
    set n [$inst getName]
    if {[regexp {^(clkbuf|delaybuf|clkload|rst_root|rst_reg)} $n]} { catch {set_dont_touch $n} }
    if {[string match "*__antenna" [[$inst getMaster] getName]]} {
      catch {unset_dont_touch $n}
      $inst setPlacementStatus PLACED
    }
  }
  destroy_signal_wires
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} {
    set_global_routing_layer_adjustment $layer 0.3
  }
  set_thread_count 16
  puts "SETUP2_GRT"
  global_route -congestion_iterations 50 -verbose
  estimate_parasitics -global_routing
  set n0 [llength [[ord::get_db_block] getInsts]]
  puts "SETUP2_BEFORE INST $n0"
  report_setup
  puts "SETUP2_REPAIR_TIMING"
  if {[catch {
    repair_timing -setup -verbose -setup_margin 0.2 -repair_tns 100 \
      -max_buffer_percent 15 -max_utilization 80
  } rmsg]} { puts "SETUP2_REPAIR_CAUGHT $rmsg" }
  puts "SETUP2_AFTER"
  report_setup
  report_hold
  set n1 [llength [[ord::get_db_block] getInsts]]
  puts "SETUP2_AFTER INST $n1 DELTA [expr {$n1-$n0}]"
  legalize
  write_db $out/setup2_eco.odb
  write_def $out/setup2_eco.def
  puts "WROTE_SETUP2"
  exit 0
}

if {$phase eq "setup2_route"} {
  read_db $out/setup2_eco.odb
  route_fresh setup2
  write_db $out/setup2_routed.odb
  write_def $out/setup2_routed.def
  puts "WROTE_SETUP2_ROUTED DIODE [diode_count]"
  exit 0
}

if {$phase eq "setup3_route"} {
  read_db $out/setup3_eco.odb
  route_fresh setup3
  write_db $out/setup3_routed.odb
  write_def $out/setup3_routed.def
  puts "WROTE_SETUP3_ROUTED DIODE [diode_count]"
  exit 0
}

if {$phase eq "setup4_route"} {
  read_db $out/setup4_eco.odb
  route_fresh setup4
  write_db $out/setup4_routed.odb
  write_def $out/setup4_routed.def
  puts "WROTE_SETUP4_ROUTED DIODE [diode_count]"
  exit 0
}

if {$phase eq "setup"} {
  load_ss $out/routed.odb
  read_spef -corner max_ss_125C_4v50 $out/spef/butterfold_top.max.spef
  protect_specials
  dont_use_exclude
  set n0 [llength [[ord::get_db_block] getInsts]]
  puts "SETUP_BEFORE INST $n0"
  report_setup
  # Compact production recipe: slew-inflated SS cell delay is the setup
  # problem (nand2/oai21 cells at 9-13 ns). repair_design first, then
  # repair_timing -setup. Keep-wires is not possible after buffer insert.
  puts "SETUP_REPAIR_DESIGN"
  if {[catch {
    repair_design -verbose -max_wire_length 0 -slew_margin 20 -cap_margin 20
  } dmsg]} { puts "SETUP_REPAIR_DESIGN_CAUGHT $dmsg" }
  puts "SETUP_AFTER_DESIGN"
  report_setup
  puts "SETUP_REPAIR_TIMING"
  if {[catch {
    repair_timing -setup -verbose -setup_margin 0.1 -repair_tns 100 \
      -max_buffer_percent 8 -max_utilization 75
  } rmsg]} { puts "SETUP_REPAIR_CAUGHT $rmsg" }
  puts "SETUP_AFTER"
  report_setup
  report_hold
  set n1 [llength [[ord::get_db_block] getInsts]]
  puts "SETUP_AFTER INST $n1 DELTA [expr {$n1-$n0}]"
  legalize
  write_db $out/setup_eco.odb
  write_def $out/setup_eco.def
  puts "WROTE_SETUP"
  exit 0
}

if {$phase eq "setup_route"} {
  read_db $out/setup_eco.odb
  route_fresh setup
  write_db $out/setup_routed.odb
  write_def $out/setup_routed.def
  puts "WROTE_SETUP_ROUTED DIODE [diode_count]"
  exit 0
}

if {$phase eq "hold"} {
  load_ff $out/setup4_routed.odb
  dont_use_exclude
  foreach inst [[ord::get_db_block] getInsts] {
    set n [$inst getName]
    if {[regexp {^(clkbuf|delaybuf|clkload|rst_root|rst_reg)} $n]} { catch {set_dont_touch $n} }
    if {[string match "*__antenna" [[$inst getMaster] getName]]} {
      catch {unset_dont_touch $n}
      $inst setPlacementStatus PLACED
    }
  }
  destroy_signal_wires
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
  set_thread_count 16
  global_route -congestion_iterations 50 -verbose
  read_spef -corner min_ff_n40C_5v50 $out/spef/setup4.min.spef
  puts "HOLD_BEFORE"
  report_hold
  report_setup
  if {[catch {
    repair_timing -hold -allow_setup_violations -hold_margin 0.05 \
      -max_buffer_percent 10 -max_utilization 75 -verbose
  } msg]} { puts "HOLD_REPAIR_CAUGHT $msg" }
  puts "HOLD_AFTER"
  report_hold
  report_setup
  legalize
  write_db $out/hold_eco.odb
  write_def $out/hold_eco.def
  puts "WROTE_HOLD"
  exit 0
}

if {$phase eq "hold_route"} {
  read_db $out/hold_eco.odb
  route_fresh hold
  write_db $out/hold_routed.odb
  write_def $out/hold_routed.def
  puts "WROTE_HOLD_ROUTED DIODE [diode_count]"
  exit 0
}

if {$phase eq "elec"} {
  load_ss $out/hold_routed.odb
  define_process_corner -ext_model_index 0 CURRENT_CORNER
  extract_parasitics -ext_model_file $rcx_max -lef_res
  protect_specials
  dont_use_exclude
  puts "ELEC_BEFORE"
  report_setup
  puts "SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count] FANOUT [sta::max_fanout_violation_count]"
  unset_case_analysis [get_ports rst_n]
  puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count] FANOUT [sta::max_fanout_violation_count]"
  # Targeted reset-tree upsizing for remaining slew, then limited repair_design for electrical.
  set db [ord::get_db]
  set m16 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_16]
  foreach inst [[ord::get_db_block] getInsts] {
    set n [$inst getName]
    if {[string match "rst_reg*" $n] || $n eq "rst_root"} {
      catch {unset_dont_touch $n}
      if {$m16 ne "NULL"} {
        $inst swapMaster $m16
        puts "SWAP $n clkbuf_16"
      }
    }
  }
  catch {set_case_analysis 1 [get_ports rst_n]}
  puts "ELEC_REPAIR_DESIGN"
  if {[catch {
    repair_design -verbose -max_wire_length 0 -slew_margin 20 -cap_margin 20
  } emsg]} { puts "ELEC_REPAIR_CAUGHT $emsg" }
  puts "ELEC_AFTER"
  report_setup
  puts "SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count] FANOUT [sta::max_fanout_violation_count]"
  legalize
  write_db $out/elec_eco.odb
  write_def $out/elec_eco.def
  puts "WROTE_ELEC"
  exit 0
}

if {$phase eq "elec_route"} {
  read_db $out/elec_eco.odb
  route_fresh elec
  write_db $out/elec_routed.odb
  write_def $out/elec_routed.def
  puts "WROTE_ELEC_ROUTED DIODE [diode_count]"
  exit 0
}

if {$phase eq "ant"} {
  read_db $out/elec_routed.odb
  set_thread_count 16
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  puts "ANT_BEFORE DIODE [diode_count]"
  set ant [check_antennas]
  puts "ANT_RC $ant"
  if {$ant} {
    repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10
    catch {detailed_placement -max_displacement {500 100}}
    if {[catch {check_placement -verbose} cmsg]} { puts "PLACE $cmsg"; exit 1 }
    pg_connect
    # Incremental DRT only to attach diode pins. Do not loop.
    detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/ant.drc
  }
  puts "ANT_AFTER DIODE [diode_count]"
  set ant2 [check_antennas]
  puts "ANT_RC2 $ant2"
  check_antennas -verbose -report_file $out/antenna/final.rpt
  write_db $out/ant_routed.odb
  write_def $out/ant_routed.def
  puts "ANT_DONE"
  exit 0
}

if {$phase eq "fill"} {
  read_db $out/ant_routed.odb
  set db [ord::get_db]
  set fills {}
  set decaps {}
  foreach lib [$db getLibs] {
    foreach m [$lib getMasters] {
      set n [$m getName]
      if {[string match "gf180mcu_fd_sc_mcu9t5v0__fillcap_*" $n]} { lappend decaps $n }
      if {[string match "gf180mcu_fd_sc_mcu9t5v0__fill_*" $n]} { lappend fills $n }
    }
  }
  set fill_list [concat [lsort -decreasing $decaps] [lsort -decreasing $fills]]
  puts "FILL_LIST $fill_list"
  set n0 [llength [[ord::get_db_block] getInsts]]
  filler_placement $fill_list
  pg_connect
  set n1 [llength [[ord::get_db_block] getInsts]]
  puts "INST_BEFORE $n0 INST_AFTER $n1 ADDED [expr {$n1-$n0}]"
  if {[catch {check_placement -verbose} m]} { puts "PLACE $m"; exit 1 }
  set ant [check_antennas]
  puts "ANTENNA_CHECK $ant"
  write_db $out/filled.odb
  write_def $out/filled.def
  write_verilog -include_pwr_gnd $out/butterfold_top.final.pnl.v
  write_verilog $out/butterfold_top.final.v
  puts "FILL_DONE"
  exit 0
}

puts "UNKNOWN_PHASE $phase"
exit 1
